//
//  BudgetManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 15.11.2024.
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class BudgetManager: ObservableObject {
    static let shared = BudgetManager()
    
    private let context: NSManagedObjectContext
    private let currencyManager: CurrencyManager
    private let currencyConverter: CurrencyConverter
    private let repository: BudgetRepository
    
    @Published private(set) var isProcessing = false
    
    private init() {
        self.context = CoreDataStack.shared.context
        self.currencyManager = .shared
        self.currencyConverter = .shared
        self.repository = .shared
    }
    
    // MARK: - Create
    func createBudget(amount: Decimal?, alertThreshold: Decimal? = nil) async throws -> Budget {
        return try await repository.createBudget(amount: amount, alertThreshold: alertThreshold)
    }
    
    // MARK: - Update
    func updateBudget(_ budget: Budget, amount: Decimal, alertThreshold: Decimal? = nil) async throws {
        try await repository.updateBudget(budget, amount: amount, alertThreshold: alertThreshold)
    }
    
    // MARK: - Delete
    func deleteBudget(_ budget: Budget) async throws {
        try await repository.deleteBudget(budget)
    }
    
    func saveCategoryBudgets(for budget: Budget, categoryLimits: [Category: String]) async throws {
        try await repository.saveCategoryBudgets(for: budget, categoryLimits: categoryLimits)
    }
    
    @MainActor
    func updateBudgetAmountFromCategories(_ budget: Budget) async throws {
        try await repository.updateBudgetAmountFromCategories(budget)
    }
    
    // MARK: - Currency Change
    // This method can be called when we need to manually check if budgets were properly converted
    func verifyBudgetCurrency(expectedCurrency: Currency) async throws {
        let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
        let budgets = try await context.perform {
            try self.context.fetch(fetchRequest)
        }
        
        for budget in budgets {
            if budget.budgetCurrency != expectedCurrency {
                print("⚠️ Found budget with incorrect currency, expected: \(expectedCurrency.code ?? "unknown"), found: \(budget.budgetCurrency?.code ?? "unknown")")
            }
        }
    }
    
    // MARK: - Query Methods
    func getCurrentMonthBudget() async -> Budget? {
        return await repository.getCurrentMonthBudget()
    }
    
    func getBudgetFor(month date: Date) async -> Budget? {
        return await repository.getBudgetFor(month: date)
    }
    
    func getBudgetAmount(in targetCurrency: Currency) async throws -> (amount: Decimal, formatted: String)? {
        guard let budget = await repository.getCurrentMonthBudget(),
              let amount = budget.amount?.decimalValue,
              let sourceCurrency = budget.budgetCurrency else {
            return nil
        }
        
        let result = currencyConverter.convertAmount(
            amount,
            from: sourceCurrency,
            to: targetCurrency
        )
        
        if let result = result {
            return (result.amount, result.formatted)
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    public func parseAmount(_ formattedAmount: String) -> Decimal? {
        let cleanedAmount = formattedAmount
            .replacingOccurrences(of: currencyManager.defaultCurrency?.symbol ?? "$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        return Decimal(string: cleanedAmount)
    }
    
    // MARK: - future budgets
    private let futureBudgetMonths = 6
    
    func createFutureBudgets(from sourceBudget: Budget) async throws {
        try await repository.createFutureBudgets(from: sourceBudget, months: futureBudgetMonths)
    }
    
    // MARK: - auto next month budget
    func createNextMonthBudgetIfNeeded() async throws {
        try await repository.createNextMonthBudgetIfNeeded()
    }
    
    // Computing total category budget
    func calculateTotalCategoryBudget(for budget: Budget) -> Decimal {
        guard let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> else {
            return 0
        }
        
        return categoryBudgets.reduce(0) { total, categoryBudget in
            total + (categoryBudget.budgetAmount?.decimalValue ?? 0)
        }
    }
    
    // Computing everything else amount
    func calculateEverythingElseAmount(for budget: Budget) -> Decimal? {
        guard let budgetAmount = budget.amount?.decimalValue else { return nil }
        let totalCategoryBudget = calculateTotalCategoryBudget(for: budget)
        
        guard budgetAmount > totalCategoryBudget else {
            return nil
        }
        return budgetAmount - totalCategoryBudget
    }
    
    // Get expenses for a specific budget period
    @MainActor
    func expensesForBudget(_ budget: Budget) -> [Expense] {
        guard let budgetDate = budget.startDate else { return [] }
        
        // Create date range for the budget month
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: budgetDate))!
        let startOfNextMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!
        
        // Use Core Data fetch request with a date-based predicate
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfMonth as NSDate,
            startOfNextMonth as NSDate
        )
        
        // Add a sort descriptor for consistent ordering
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Expense.date, ascending: false)
        ]
        
        // Execute fetch request
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ Error fetching expenses for budget: \(error.localizedDescription)")
            return []
        }
    }
    
    // Calculate non-budgeted spending
    func calculateNonBudgetedSpending(for budget: Budget) -> Decimal {
        guard let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> else { return 0 }
        let budgetedCategories = categoryBudgets.compactMap { $0.category?.name }
        let monthExpenses = expensesForBudget(budget)
        
        return monthExpenses.reduce(Decimal(0)) { total, expense in
            if let categoryName = expense.category?.name,
               !budgetedCategories.contains(categoryName) {
                return total + (expense.convertedAmount?.decimalValue ?? 0)
            }
            return total
        }
    }
    
    // Calculate percentage for category budget
    func calculatePercentage(for categoryBudget: CategoryBudget, in budget: Budget) -> Double {
        let monthExpenses = expensesForBudget(budget)
        let spentAmount = ExpenseDataManager.shared.calculateCategoryAmount(
            for: monthExpenses,
            category: categoryBudget.category?.name ?? ""
        )
        guard let budgetAmount = categoryBudget.budgetAmount?.decimalValue,
              budgetAmount > 0 else { return 0 }
        
        return Double(NSDecimalNumber(decimal: spentAmount).doubleValue /
                     NSDecimalNumber(decimal: budgetAmount).doubleValue) * 100
    }
    
    // Calculate monthly percentage
    func calculateMonthlyPercentage(spent: Decimal, budget: Decimal) -> Double {
        guard budget > 0 else { return 0 }
        return Double(NSDecimalNumber(decimal: spent).doubleValue /
                     NSDecimalNumber(decimal: budget).doubleValue) * 100
    }
    
    // Format percentage
    func formatPercentage(_ percentage: Double) -> String {
        if percentage.isInfinite || percentage.isNaN {
            return "0%"
        }
        // For very small non-zero percentages
        if percentage > 0 && percentage < 1 {
            return "<1%"
        }
        // Cap at 999999% to avoid Int overflow
        let cappedPercentage = min(percentage, 999999)
        return "\(Int(cappedPercentage))%"
    }
    
    // Check if budget is for current month
    func isCurrentMonth(_ budget: Budget) -> Bool {
        guard let budgetDate = budget.startDate else { return false }
        return Calendar.current.isDate(budgetDate, equalTo: Date(), toGranularity: .month)
    }
    // MARK: - Error Handling
    enum BudgetError: LocalizedError {
        case budgetExistsForCurrentMonth
        case invalidAmount
        case invalidThreshold
        case noCurrencyAvailable
        case operationInProgress
        case saveFailed(Error)
        case invalidDate
        
        var errorDescription: String? {
            switch self {
            case .invalidDate:
                return "Invalid date for budget creation"
            case .budgetExistsForCurrentMonth:
                return "A budget for the current month already exists"
            case .invalidAmount:
                return "Please enter a valid amount greater than zero"
            case .invalidThreshold:
                return "Alert threshold must be greater than zero and less than the budget amount"
            case .noCurrencyAvailable:
                return "No default currency is set"
            case .operationInProgress:
                return "Another operation is in progress"
            case .saveFailed(let error):
                return "Failed to save budget: \(error.localizedDescription)"
            }
        }
    }

}

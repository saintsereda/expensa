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
    
    @Published private(set) var isProcessing = false
    
    private init() {
        self.context = CoreDataStack.shared.context
        self.currencyManager = .shared
        self.currencyConverter = .shared
    }
    
    // MARK: - Create
    func createBudget(amount: Decimal?, alertThreshold: Decimal? = nil) async throws -> Budget {
        guard !isProcessing else { throw BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            // Validate current month budget doesn't exist
            guard !self.hasExistingBudgetForCurrentMonth() else {
                throw BudgetError.budgetExistsForCurrentMonth
            }
            
            // Validate we have a default currency
            guard let defaultCurrency = self.currencyManager.defaultCurrency else {
                throw BudgetError.noCurrencyAvailable
            }
            
            let budget = Budget(context: self.context)
            budget.id = UUID()
            
            // Handle optional amount
            if let amount = amount {
                guard amount > 0 else {
                    throw BudgetError.invalidAmount
                }
                budget.amount = NSDecimalNumber(decimal: amount)
            }
            
            budget.startDate = Date()
            budget.budgetCurrency = defaultCurrency
            
            if let threshold = alertThreshold {
                guard threshold > 0,
                      let amount = amount,
                      threshold <= amount else {
                    throw BudgetError.invalidThreshold
                }
                budget.alertThreshold = NSDecimalNumber(decimal: threshold)
            }
            
            try self.context.save()
            print("✅ Created new budget: \(amount?.description ?? "no amount") \(defaultCurrency.code ?? "unknown")")
            return budget
        }
    }
    
    // MARK: - Update
    func updateBudget(_ budget: Budget, amount: Decimal, alertThreshold: Decimal? = nil) async throws {
        guard !isProcessing else { throw BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            // Validate amount
            guard amount > 0 else {
                throw BudgetError.invalidAmount
            }
            
            // Get current budget's date
            guard let startDate = budget.startDate else {
                throw BudgetError.invalidDate
            }
            
            // Update current budget
            budget.amount = NSDecimalNumber(decimal: amount)
            
            if let threshold = alertThreshold {
                guard threshold > 0, threshold <= amount else {
                    throw BudgetError.invalidThreshold
                }
                budget.alertThreshold = NSDecimalNumber(decimal: threshold)
            } else {
                budget.alertThreshold = nil
            }
            
            // Update all future budgets
            let calendar = Calendar.current
            let futureBudgets = try self.context.fetch(Budget.fetchRequest()).filter { futureBudget in
                guard let futureDate = futureBudget.startDate else { return false }
                return calendar.compare(futureDate, to: startDate, toGranularity: .month) == .orderedDescending
            }
            
            print("🔄 Updating \(futureBudgets.count) future budgets")
            
            for futureBudget in futureBudgets {
                futureBudget.amount = NSDecimalNumber(decimal: amount)
                futureBudget.alertThreshold = budget.alertThreshold
                
                if let futureDate = futureBudget.startDate {
                    print("✅ Updated budget for: \(futureDate.formatted())")
                }
            }
            
            try self.context.save()
            print("✅ Updated budget: \(amount) \(budget.budgetCurrency?.code ?? "unknown")")
        }
    }
    
    // MARK: - Delete
    func deleteBudget(_ budget: Budget) async throws {
        guard !isProcessing else { throw BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            // Get the start date of the budget to be deleted
            guard let startDate = budget.startDate else {
                throw BudgetError.invalidDate
            }
            
            // Find all budgets from this month forward
            let calendar = Calendar.current
            let budgetsToDelete = try self.context.fetch(Budget.fetchRequest()).filter { futureBudget in
                guard let futureDate = futureBudget.startDate else { return false }
                // Include budgets that are in the same month or later
                return calendar.compare(futureDate, to: startDate, toGranularity: .month) != .orderedAscending
            }
            
            print("🗑️ Deleting \(budgetsToDelete.count) budgets starting from: \(startDate.formatted())")
            
            // Delete each budget and its category budgets
            for budgetToDelete in budgetsToDelete {
                // Clean up category budgets first
                if let categoryBudgets = budgetToDelete.categoryBudgets as? Set<CategoryBudget> {
                    for categoryBudget in categoryBudgets {
                        self.context.delete(categoryBudget)
                    }
                }
                
                // Delete the budget
                self.context.delete(budgetToDelete)
                
                if let date = budgetToDelete.startDate {
                    print("✅ Deleted budget for: \(date.formatted())")
                }
            }
            
            try self.context.save()
            print("💾 Successfully deleted all budgets")
        }
    }
    
    func saveCategoryBudgets(for budget: Budget, categoryLimits: [Category: String]) async throws {
        guard !isProcessing else { throw BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            // First get all future budgets that were created from this budget
            let calendar = Calendar.current
            guard let startDate = budget.startDate else { return }
            
            // Get all budgets from this month forward
            let futureBudgets = try self.context.fetch(Budget.fetchRequest()).filter { futureBudget in
                guard let futureDate = futureBudget.startDate else { return false }
                return calendar.compare(futureDate, to: startDate, toGranularity: .month) != .orderedAscending
            }
            
            print("📊 Creating category budgets for \(futureBudgets.count) budgets")
            
            // Process each budget (current and future)
            for currentBudget in futureBudgets {
                // Remove existing category budgets if updating
                if let existingCategoryBudgets = currentBudget.categoryBudgets as? Set<CategoryBudget> {
                    for categoryBudget in existingCategoryBudgets {
                        self.context.delete(categoryBudget)
                    }
                }
                
                // Create new category budgets
                for (category, limitString) in categoryLimits {
                    guard let amount = self.parseAmount(limitString) else { continue }
                    
                    let categoryBudget = CategoryBudget(context: self.context)
                    categoryBudget.category = category
                    categoryBudget.budget = currentBudget
                    categoryBudget.budgetAmount = NSDecimalNumber(decimal: amount)
                    categoryBudget.budgetCurrency = self.currencyManager.defaultCurrency
                    categoryBudget.categoryName = category.name
                    
                    guard let budgetDate = currentBudget.startDate else { continue }
                    let components = calendar.dateComponents([.year, .month], from: budgetDate)
                    categoryBudget.year = Int16(components.year ?? 0)
                    categoryBudget.month = Int16(components.month ?? 0)
                    
                    print("✅ Created category budget for \(category.name ?? "") in \(budgetDate.formatted())")
                }
            }
            
            try self.context.save()
            print("💾 Saved all category budgets")
        }
    }
    
    @MainActor
    func updateBudgetAmountFromCategories(_ budget: Budget) async throws {
        print("🔄 Starting budget update from categories...")
        
        guard !isProcessing else {
            print("❌ Update skipped - operation in progress")
            throw BudgetError.operationInProgress
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        guard let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> else {
            print("❌ No category budgets found")
            return
        }
        
        let totalAmount = categoryBudgets.reduce(Decimal(0)) { total, categoryBudget in
            total + (categoryBudget.budgetAmount?.decimalValue ?? 0)
        }
        
        print("📊 Current budget amount: \(budget.amount?.decimalValue ?? 0)")
        print("📊 Total category amount: \(totalAmount)")
        
        // Only update if category total is higher
        if totalAmount > (budget.amount?.decimalValue ?? 0) {
            print("🔄 Updating budget amount...")
            do {
                budget.amount = NSDecimalNumber(decimal: totalAmount)
                try context.save()
                print("✅ Successfully updated budget amount to: \(totalAmount)")
            } catch {
                print("❌ Failed to update budget: \(error.localizedDescription)")
                throw error
            }
        } else {
            print("ℹ️ No update needed - category total is not higher than budget")
        }
    }
    
    public func parseAmount(_ formattedAmount: String) -> Decimal? {
        let cleanedAmount = formattedAmount
            .replacingOccurrences(of: currencyManager.defaultCurrency?.symbol ?? "$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        return Decimal(string: cleanedAmount)
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
        return await context.perform {
            let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
            fetchRequest.predicate = self.currentMonthPredicate
            fetchRequest.fetchLimit = 1
            return try? self.context.fetch(fetchRequest).first
        }
    }
    
    func getBudgetAmount(in targetCurrency: Currency) async throws -> (amount: Decimal, formatted: String)? {
        guard let budget = await getCurrentMonthBudget(),
              let amount = budget.amount?.decimalValue,
              let sourceCurrency = budget.budgetCurrency else {
            return nil
        }
        
        return currencyConverter.convertAmount(
            amount,
            from: sourceCurrency,
            to: targetCurrency
        )
    }
    
    // MARK: - Helper Methods
    private func hasExistingBudgetForCurrentMonth() -> Bool {
        let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
        fetchRequest.predicate = currentMonthPredicate
        let count = (try? context.count(for: fetchRequest)) ?? 0
        return count > 0
    }
    
    private var currentMonthPredicate: NSPredicate {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )
    }
    
    // MARK: - future budgets
    private let futureBudgetMonths = 6
    
    func createFutureBudgets(from sourceBudget: Budget) async throws {
        guard !isProcessing else { throw BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        print("📅 Starting future budget creation from source budget date: \(sourceBudget.startDate?.formatted() ?? "unknown")")
        
        return try await context.perform {
            let calendar = Calendar.current
            guard let startDate = sourceBudget.startDate else {
                print("❌ Source budget has no start date")
                throw BudgetError.invalidDate
            }
            
            // Create budgets for next 6 months
            for month in 1...self.futureBudgetMonths {
                guard let futureDate = calendar.date(byAdding: .month, value: month, to: startDate) else {
                    print("❌ Failed to create date for month \(month)")
                    continue
                }
                
                print("📆 Creating budget for: \(futureDate.formatted())")
                
                // Check if budget already exists for this month
                if try self.hasBudgetForDate(futureDate) {
                    print("⚠️ Budget already exists for \(futureDate.formatted())")
                    continue
                }
                
                let futureBudget = Budget(context: self.context)
                futureBudget.id = UUID()
                futureBudget.startDate = futureDate
                futureBudget.amount = sourceBudget.amount
                futureBudget.budgetCurrency = sourceBudget.budgetCurrency
                futureBudget.alertThreshold = sourceBudget.alertThreshold
                
                // Copy category budgets if they exist
                if let categoryBudgets = sourceBudget.categoryBudgets as? Set<CategoryBudget> {
                    for categoryBudget in categoryBudgets {
                        let futureCategoryBudget = CategoryBudget(context: self.context)
                        futureCategoryBudget.category = categoryBudget.category
                        futureCategoryBudget.budget = futureBudget
                        futureCategoryBudget.budgetAmount = categoryBudget.budgetAmount
                        futureCategoryBudget.budgetCurrency = categoryBudget.budgetCurrency
                        futureCategoryBudget.categoryName = categoryBudget.categoryName
                        
                        let components = calendar.dateComponents([.year, .month], from: futureDate)
                        futureCategoryBudget.year = Int16(components.year ?? 0)
                        futureCategoryBudget.month = Int16(components.month ?? 0)
                    }
                }
                
                print("✅ Successfully created budget for \(futureDate.formatted())")
            }
            
            try self.context.save()
            print("💾 Saved all future budgets")
        }
    }
    
    private func hasBudgetForDate(_ date: Date) throws -> Bool {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )
        
        let count = try context.count(for: fetchRequest)
        return count > 0
    }
    
    // MARK: - auto next month budget
    func createNextMonthBudgetIfNeeded() async throws {
        guard !isProcessing else { throw BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            let calendar = Calendar.current
            
            // Find the latest budget date
            let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
            fetchRequest.fetchLimit = 1
            
            guard let latestBudget = try self.context.fetch(fetchRequest).first,
                  let latestDate = latestBudget.startDate else {
                print("⚠️ No existing budgets found")
                return
            }
            
            // Calculate the target end date (should always be 6 months from current date)
            guard let targetEndDate = calendar.date(byAdding: .month, value: 6, to: Date()),
                  let startOfTargetMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: targetEndDate)) else {
                throw BudgetError.invalidDate
            }
            
            // If latest budget is before our target end date, we need to create a new budget
            if calendar.compare(latestDate, to: startOfTargetMonth, toGranularity: .month) == .orderedAscending {
                // Get the month after the latest budget
                guard let newBudgetDate = calendar.date(byAdding: .month, value: 1, to: latestDate) else {
                    throw BudgetError.invalidDate
                }
                
                print("🔄 Creating budget for: \(newBudgetDate.formatted())")
                
                // Create new budget
                let newBudget = Budget(context: self.context)
                newBudget.id = UUID()
                newBudget.startDate = newBudgetDate
                newBudget.amount = latestBudget.amount
                newBudget.budgetCurrency = latestBudget.budgetCurrency
                newBudget.alertThreshold = latestBudget.alertThreshold
                
                // Copy category budgets
                if let categoryBudgets = latestBudget.categoryBudgets as? Set<CategoryBudget> {
                    for categoryBudget in categoryBudgets {
                        let newCategoryBudget = CategoryBudget(context: self.context)
                        newCategoryBudget.category = categoryBudget.category
                        newCategoryBudget.budget = newBudget
                        newCategoryBudget.budgetAmount = categoryBudget.budgetAmount
                        newCategoryBudget.budgetCurrency = categoryBudget.budgetCurrency
                        newCategoryBudget.categoryName = categoryBudget.categoryName
                        
                        let components = calendar.dateComponents([.year, .month], from: newBudgetDate)
                        newCategoryBudget.year = Int16(components.year ?? 0)
                        newCategoryBudget.month = Int16(components.month ?? 0)
                    }
                }
                
                try self.context.save()
                print("✅ Successfully created budget for \(newBudgetDate.formatted())")
            } else {
                print("✅ Future budgets are up to date")
            }
        }
        
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
    func expensesForBudget(_ budget: Budget) -> [Expense] {
        guard let budgetDate = budget.startDate else { return [] }
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: budgetDate))!
        let startOfNextMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!
        
        return ExpenseDataManager.shared.fetchExpenses().filter { expense in
            guard let expenseDate = expense.date else { return false }
            return expenseDate >= startOfMonth && expenseDate < startOfNextMonth
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
}

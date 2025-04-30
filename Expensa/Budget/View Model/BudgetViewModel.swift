//
//  BudgetViewModel.swift
//  Expensa
//
//  Created by Andrew Sereda on 17.03.2025.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Display Data Structures

/// Holds pre-calculated and formatted budget data for display
struct BudgetDisplayData {
    let budget: Budget // Keep reference to original entity
    let amount: Decimal
    let amountFormatted: String
    let spent: Decimal
    let spentFormatted: String
    let monthlyPercentage: Double
    let monthlyPercentageFormatted: String
    let categoryBudgets: [CategoryBudgetDisplayData]
}

/// Holds pre-calculated and formatted category budget data for display
struct CategoryBudgetDisplayData: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let amountFormatted: String
    let spent: Decimal
    let spentFormatted: String
    let remaining: Decimal
    let remainingFormatted: String
    let percentage: Double
    let percentageFormatted: String
    let currency: Currency
    let expenseCount: Int
}

/// Contains extra data for budget editing
struct BudgetEditData: Identifiable {
    var id: UUID {
        budget.id ?? UUID()
    }
    let budget: Budget
}

// MARK: - Budget View Model
@MainActor
class BudgetViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentBudget: BudgetDisplayData?
    @Published private(set) var isLoading = false
    @Published var selectedDate = Date()
    @Published var errorMessage: String?
    @Published var budgetToEdit: BudgetEditData?
    @Published var showDeleteAlert = false
    @Published var showAddBudget = false
    
    // MARK: - Private Properties
    private let budgetManager = BudgetManager.shared
    private let expenseManager = ExpenseDataManager.shared
    private let currencyConverter = CurrencyConverter.shared
    private var fetchedBudgets: [String: Budget] = [:] // Cache by month key
    private var cachedDisplayData: [String: BudgetDisplayData] = [:] // Cache processed display data
    private var currencyChangeObserver: NSObjectProtocol?
    private var budgetUpdateObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    init() {
        // Observe currency changes
        currencyChangeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("DefaultCurrencyChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCurrencyChange()
        }
        
        // Add budget update observer
        budgetUpdateObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("BudgetUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.budgetModified()
        }
        
        // Initial data fetch
        fetchBudgetForSelectedDate()
    }

    deinit {
        if let observer = currencyChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = budgetUpdateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // Add a method to handle currency changes
    private func handleCurrencyChange() {
        // Clear all cached data
        clearAllCaches()
        
        // Refresh the current view
        fetchBudgetForSelectedDate()
    }
    
    // MARK: - Public Methods
    
    /// Changes the selected date and fetches the corresponding budget
    func dateChanged(to newDate: Date) {
        selectedDate = newDate
        fetchBudgetForSelectedDate()
    }
    
    /// Begins the edit process for the current budget
    func editCurrentBudget() {
        guard let budget = currentBudget?.budget else { return }
        budgetToEdit = BudgetEditData(budget: budget)
    }
    
    /// Deletes the current budget
    func deleteBudget() async {
        guard let budget = currentBudget?.budget else { return }
        
        isLoading = true
        do {
            try await budgetManager.deleteBudget(budget)
            
            // Clear cache since future budgets could also be deleted
            clearAllCaches()
            
            await MainActor.run {
                isLoading = false
                currentBudget = nil
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Called when budget is added or edited
    func budgetModified() {
        // Clear caches to ensure we get fresh data
        clearAllCaches()
        // Refresh the current view
        fetchBudgetForSelectedDate()
    }
    
    /// Check if selected month is current month
    var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }
    
    /// Dismiss any alerts or sheets
    func dismissAlerts() {
        errorMessage = nil
        showDeleteAlert = false
    }
    
    func fetchCurrentBudget() async {
        fetchBudgetForSelectedDate()
    }
    
    // MARK: - Private Methods
    
    /// Clears all cached data
    private func clearAllCaches() {
        fetchedBudgets.removeAll()
        cachedDisplayData.removeAll()
    }
    
    /// Fetches budget for selected date
    private func fetchBudgetForSelectedDate() {
        print("🎯 Fetching budget for date: \(selectedDate)")
        let monthKey = formatDateToMonthKey(selectedDate)
        print("🔑 Month key: \(monthKey)")
        
        // Check if we already have processed display data
        if let cachedData = cachedDisplayData[monthKey] {
            print("📋 Using cached display data")
            currentBudget = cachedData
            return
        }
        
        // Check if we have the raw budget data cached
        if let cachedBudget = fetchedBudgets[monthKey] {
            print("📦 Using cached raw budget")
            processBudget(cachedBudget, forKey: monthKey)
            return
        }
        
        // Otherwise fetch from Core Data
        isLoading = true
        print("🔄 Starting Core Data fetch")
        
        Task {
            do {
                let budget = try await fetchBudgetFromCoreData(for: selectedDate)
                
                // Cache the raw budget result
                if let budget = budget {
                    self.fetchedBudgets[monthKey] = budget
                    print("💾 Cached raw budget")
                }
                
                await MainActor.run {
                    isLoading = false
                    if let budget = budget {
                        print("✅ Processing fetched budget")
                        processBudget(budget, forKey: monthKey)
                    } else {
                        print("⚠️ No budget found for date")
                        currentBudget = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    currentBudget = nil
                    print("❌ Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Process budget into display data
    private func processBudget(_ budget: Budget, forKey key: String) {
        print("🔄 Processing budget for key: \(key)")
        let displayData = createBudgetDisplayData(for: budget)
        print("✅ Created display data with amount: \(displayData.amountFormatted)")
        cachedDisplayData[key] = displayData
        currentBudget = displayData
    }
    
    /// Fetch budget from Core Data
    private func fetchBudgetFromCoreData(for date: Date) async throws -> Budget? {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month], from: date)
                let startOfMonth = calendar.date(from: components)!
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)!
                
                print("🔍 Fetching budget between \(startOfMonth) and \(endOfMonth)")
                
                let context = CoreDataStack.shared.context
                let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "startDate >= %@ AND startDate <= %@",
                    startOfMonth as NSDate,
                    endOfMonth as NSDate
                )
                
                let results = try context.fetch(fetchRequest)
                print("📊 Found \(results.count) budgets")
                if let budget = results.first {
                    print("💰 Budget amount: \(budget.amount?.description ?? "nil")")
                }
                
                continuation.resume(returning: results.first)
            } catch {
                print("❌ Error fetching budget: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Create display data from budget entity
    private func createBudgetDisplayData(for budget: Budget) -> BudgetDisplayData {
        // Pre-calculate all the necessary data for display
        
        // Fetch expenses only once (most expensive operation)
        let expenses = budgetManager.expensesForBudget(budget)
        
        // Calculate total spent amount
        let totalSpent = expenseManager.calculateTotalAmount(for: expenses)
        
        // Calculate monthly percentage
        let monthlyPercentage = budgetManager.calculateMonthlyPercentage(
            spent: totalSpent,
            budget: budget.amount?.decimalValue ?? 0
        )
        
        // Process category budgets
        var categoryItems: [CategoryBudgetDisplayData] = []
        
        if let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> {
            // Sort them once according to business rules
            let sortedBudgets = Array(categoryBudgets).sorted { cat1, cat2 in
                let percent1 = budgetManager.calculatePercentage(for: cat1, in: budget)
                let percent2 = budgetManager.calculatePercentage(for: cat2, in: budget)
                
                // If both are overspent, sort by how much they're overspent
                if percent1 > 100 && percent2 > 100 {
                    return percent1 > percent2
                }
                // If only one is overspent, it should come first
                else if percent1 > 100 {
                    return true
                }
                else if percent2 > 100 {
                    return false
                }
                // If neither is overspent, sort by proximity to limit
                else {
                    return percent1 > percent2
                }
            }
            
            // Create the display items with all data pre-calculated
            for categoryBudget in sortedBudgets {
                if let category = categoryBudget.category,
                   let amount = categoryBudget.budgetAmount?.decimalValue {
                    
                    // Calculate spent amount for this category
                    let spent = expenseManager.calculateCategoryAmount(
                        for: expenses,
                        category: category.name ?? ""
                    )
                    
                    // Calculate percentage
                    let percentage = budgetManager.calculatePercentage(for: categoryBudget, in: budget)
                    let percentageFormatted = budgetManager.formatPercentage(percentage)
                    
                    // Format currency values
                    let currency = categoryBudget.budgetCurrency ?? Currency()
                    let amountFormatted = currencyConverter.formatAmount(amount, currency: currency)
                    let spentFormatted = currencyConverter.formatAmount(spent, currency: currency)
                    let remainingFormatted = currencyConverter.formatAmount(amount - spent, currency: currency)
                    
                    // Count expenses in this category
                    let expenseCount = expenses.filter { $0.category?.name == category.name }.count
                    
                    // Create the display item
                    categoryItems.append(CategoryBudgetDisplayData(
                        category: category,
                        amount: amount,
                        amountFormatted: amountFormatted,
                        spent: spent,
                        spentFormatted: spentFormatted,
                        remaining: amount - spent,
                        remainingFormatted: remainingFormatted,
                        percentage: percentage,
                        percentageFormatted: percentageFormatted,
                        currency: currency,
                        expenseCount: expenseCount
                    ))
                }
            }
        }
        
        // Format overall amounts
        let currency = budget.budgetCurrency ?? Currency()
        let amountFormatted = currencyConverter.formatAmount(
            budget.amount?.decimalValue ?? 0,
            currency: currency
        )
        
        let spentFormatted = currencyConverter.formatAmount(totalSpent, currency: currency)
        let percentageFormatted = budgetManager.formatPercentage(monthlyPercentage)
        
        // Create and return the display data
        return BudgetDisplayData(
            budget: budget,
            amount: budget.amount?.decimalValue ?? 0,
            amountFormatted: amountFormatted,
            spent: totalSpent,
            spentFormatted: spentFormatted,
            monthlyPercentage: monthlyPercentage,
            monthlyPercentageFormatted: percentageFormatted,
            categoryBudgets: categoryItems
        )
    }
    
    /// Format date to month-year key for caching
    private func formatDateToMonthKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

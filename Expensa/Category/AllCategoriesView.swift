//
//  AllCategoriesView.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import Foundation
import SwiftUI
import CoreData
import UIKit

struct AllCategoriesView: View {
    // Environment
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // State
    @StateObject private var filterManager = ExpenseFilterManager()
    @State private var showingDatePicker = false
    @State private var currentBudget: Budget?
    
    // Fetch Request
    @FetchRequest private var fetchedExpenses: FetchedResults<Expense>
    
    // Computed property for categorized expenses
    private var categorizedExpenses: [(Category, [Expense])] {
        guard !fetchedExpenses.isEmpty else {
            return []
        }
        
        let categories = Set(fetchedExpenses.compactMap { $0.category })
        let categoryTuples = categories.map { category in
            (
                category,
                fetchedExpenses.filter { $0.category == category }
            )
        }
        return categoryTuples.sorted { first, second in
            let firstAmount = ExpenseDataManager.shared.calculateTotalAmount(for: first.1)
            let secondAmount = ExpenseDataManager.shared.calculateTotalAmount(for: second.1)
            
            // First sort by amount spent (descending)
            if firstAmount != secondAmount {
                return firstAmount > secondAmount
            }
            
            // If amounts are equal, sort by category name (ascending)
            return (first.0.name ?? "") < (second.0.name ?? "")
        }
    }
    
    // Total expenses amount directly from ExpenseDataManager
    private var totalExpensesAmount: Decimal {
        ExpenseDataManager.shared.calculateTotalAmount(for: Array(fetchedExpenses))
    }
    
    // Add budget info struct
    private struct BudgetInfo {
        let amount: Decimal
        let remaining: Decimal
        let currency: Currency
        
        var formattedRemaining: String {
            CurrencyConverter.shared.formatAmount(remaining, currency: currency)
        }
        
        var formattedOverspent: String {
            CurrencyConverter.shared.formatAmount(abs(remaining), currency: currency)
        }
        
        var isOverspent: Bool {
            remaining < 0
        }
    }
    
    // Add computed property for budget info
    private var budgetInfo: BudgetInfo? {
        guard let budget = currentBudget,
              let amount = budget.amount?.decimalValue,
              let currency = currencyManager.defaultCurrency else {
            return nil
        }
        
        let remaining = amount - totalExpensesAmount
        return BudgetInfo(
            amount: amount,
            remaining: remaining,
            currency: currency
        )
    }
    
    // Initialization with custom fetch request
    init() {
        // Create and configure fetch request
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Expense.createdAt, ascending: false)
        ]
        
        // Initialize date filtering
        let filterManager = ExpenseFilterManager()
        let initialInterval = filterManager.currentPeriodInterval()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            initialInterval.start as NSDate,
            initialInterval.end as NSDate
        )
        
        // Initialize the fetch request
        self._fetchedExpenses = FetchRequest(
            fetchRequest: request
        )
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spent in \(filterManager.formattedPeriod())")
                        .font(.body)
                        .foregroundColor(.primary).opacity(0.64)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: filterManager.formattedPeriod())
                    
                    // Total Amount Display
                    if let defaultCurrency = currencyManager.defaultCurrency {
                        Text(CurrencyConverter.shared.formatAmount(
                            totalExpensesAmount,
                            currency: defaultCurrency
                        ))
                        .font(.system(size: 32, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: totalExpensesAmount)
                        
                        // Add budget status text
                        if let info = budgetInfo {
                            HStack(spacing: 12) {
                                if info.isOverspent {
                                    Text("👎🏻 Budget overspent by \(info.formattedOverspent)")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("👍🏻 Budget on track")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.secondary)
                                    
                                    Divider()
                                        .frame(width: 1, height: 20)
                                        .background(Color.secondary.opacity(0.4))
                                    
                                    Text("💰 \(info.formattedRemaining) left")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Segmented Line Chart
                SegmentedLineChartView(
                    categorizedExpenses: categorizedExpenses,
                    totalExpenses: totalExpensesAmount,
                    height: 24,
                    segmentSpacing: 2
                )
                .padding(.horizontal, 16)
                
                // Categories list with updated GroupedExpenseRow
                if !categorizedExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(spacing: 4) {
                            ForEach(categorizedExpenses, id: \.0.id) { categoryData in
                                let category = categoryData.0
                                let expenses = categoryData.1
                                
                                // Get the CategoryBudget if available
                                let categoryBudget = currentBudget?.categoryBudgets?
                                    .compactMap { $0 as? CategoryBudget }
                                    .first { $0.category == category }
                                
                                // Calculate total spent
                                let spent = expenses.reduce(Decimal(0)) { sum, expense in
                                    sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
                                }
                                
                                GroupedExpenseRow(
                                    category: category,
                                    expenses: expenses,
                                    budget: categoryBudget,
                                    totalSpent: spent,
                                    selectedDate: filterManager.selectedDate,
                                    filterManager: filterManager // Pass filter manager
                                )
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    // Empty state
                    VStack(spacing: 12) {
                        Text("No expenses for this period")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try selecting a different time period")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .navigationTitle("All categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Add the calendar button to the toolbar
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticFeedback.play()
                    showingDatePicker = true
                }) {
                    Image("calendar")
                        .renderingMode(.template)
                        .foregroundColor(.primary)
                }
            }
        }
        // Update when filter parameters change
        .onChange(of: filterManager.selectedDate) { _, _ in
            updateFetchRequestPredicate()
            updateBudget()
        }
        .onChange(of: filterManager.endDate) { _, _ in
            updateFetchRequestPredicate()
        }
        .onChange(of: filterManager.isRangeMode) { _, _ in
            updateFetchRequestPredicate()
        }
        
        // Initial loading
        .onAppear {
            updateBudget()
        }
        .sheet(isPresented: $showingDatePicker) {
            // Period picker sheet
            PeriodPickerView(filterManager: filterManager, showingDatePicker: $showingDatePicker)
        }
    }
    
    // Helper methods
    private func updateFetchRequestPredicate() {
        // Get current date interval based on filter mode
        let interval = filterManager.currentPeriodInterval()
        
        fetchedExpenses.nsPredicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            interval.start as NSDate,
            interval.end as NSDate
        )
    }
    
    private func updateBudget() {
        Task {
            // For range selection, we'll use the budget from the starting month
            // In a more comprehensive solution, we might want to aggregate budgets across months
            currentBudget = await BudgetManager.shared.getBudgetFor(month: filterManager.selectedDate)
        }
    }
}

// MARK: - Updated GroupedExpenseRow to display period-aware info
struct CategoryIconView: View {
    let category: Category
    let budget: CategoryBudget?
    let spent: Decimal
    var isPeriodMode: Bool = false // New parameter for period mode
    
    private var hasLimit: Bool {
        budget?.budgetAmount?.decimalValue != nil
    }
    
    var body: some View {
        ZStack {
            // Only show circular progress if this category has a budget limit AND we're not in multi-month mode
            if hasLimit && !isPeriodMode, let limit = budget?.budgetAmount?.decimalValue {
                // Show progress circle for single month with budget
                let percentage = Double(truncating: (spent / limit) as NSDecimalNumber)
                CircularProgressView(
                    progress: percentage,
                    isOverBudget: spent > limit
                )
                
                CategoryCircleIcon(
                    icon: category.icon ?? "❓",
                    size: 40,  // Smaller size when there's a progress circle
                    iconSize: 20,
                    color: Color.primary.opacity(0.08)
                )
            } else {
                // Larger icon when no budget limit is set or when in multi-month period mode
                CategoryCircleIcon(
                    icon: category.icon ?? "❓",
                    size: 48,  // Larger size (48px) when no progress circle
                    iconSize: 20,
                    color: Color.primary.opacity(0.08)
                )
            }
        }
    }
}

struct GroupedExpenseRow: View {
    let category: Category
    let expenses: [Expense]
    let budget: CategoryBudget?
    let totalSpent: Decimal
    let selectedDate: Date
    let filterManager: ExpenseFilterManager
    
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        NavigationLink(destination: ExpensesByCategoryView(
            category: category,
            selectedDate: selectedDate,
            filterManager: filterManager
            )
            .toolbar(.hidden, for: .tabBar)) {
            
            HStack(alignment: .center, spacing: 12) {
                // Left side with circular progress/icon - now with period mode awareness
                CategoryIconView(
                    category: category,
                    budget: budget,
                    spent: totalSpent,
                    isPeriodMode: filterManager.isMultiMonthPeriod() // Pass period mode
                )
                
                // Category info
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name ?? "Unknown")
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(expenses.count) expense\(expenses.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.64))
                }
                
                Spacer()
                
                // Right side - amount info
                CategoryAmountView(
                    category: category,
                    budget: budget,
                    spent: totalSpent,
                    isPeriodMode: filterManager.isMultiMonthPeriod()
                )
            }
            .padding(12)
        }
    }
}

// MARK: - Clarified CategoryAmountView
struct CategoryAmountView: View {
    let category: Category
    let budget: CategoryBudget?
    let spent: Decimal
    var isPeriodMode: Bool = false
    
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    private var hasLimit: Bool {
        budget?.budgetAmount?.decimalValue != nil
    }
    
    var body: some View {
        if let currency = budget?.budgetCurrency ?? currencyManager.defaultCurrency {
            VStack(alignment: .trailing, spacing: 4) {
                // Total spent amount - always shown
                Text(currencyManager.currencyConverter.formatAmount(
                    spent,
                    currency: currency
                ))
                .font(.body)
                .foregroundColor(.primary)
                
                // Only show secondary info if we're in single month mode
                if !isPeriodMode {
                    if hasLimit, let limit = budget?.budgetAmount?.decimalValue {
                        let remaining = limit - spent
                        
                        if remaining < 0 {
                            // Over budget - don't show minus sign
                            Text("\(currencyManager.currencyConverter.formatAmount(abs(remaining), currency: currency)) over")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        } else {
                            // Under budget
                            Text("\(currencyManager.currencyConverter.formatAmount(remaining, currency: currency)) left")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Show "Limit is not set" when in single month mode and there's no limit
                        // This matches the displayCategoriesWithBudgets logic
                        Text("Limit is not set")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                // In multi-month period mode, no secondary text is shown
            }
        } else if let defaultCurrency = currencyManager.defaultCurrency {
            // Fallback for when no budget is available - just show the amount
            Text(currencyManager.currencyConverter.formatAmount(
                spent,
                currency: defaultCurrency
            ))
            .font(.body)
            .foregroundColor(.primary)
        }
    }
}

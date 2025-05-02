//
//  AllCategoriesView.swift (Modified)
//  Expensa
//
//  Created by Andrew Sereda on 02.05.2025.
//

import Foundation
import SwiftUI
import CoreData
import UIKit

struct AllCategoriesView: View {
    // Environment
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // Using the new view model
    @StateObject private var viewModel = AllCategoriesViewModel()
    
    // State
    @State private var showingDatePicker = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spent in \(viewModel.filterManager.formattedPeriod())")
                        .font(.body)
                        .foregroundColor(.primary).opacity(0.64)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: viewModel.filterManager.formattedPeriod())
                    
                    // Total Amount Display
                    if let defaultCurrency = currencyManager.defaultCurrency {
                        Text(CurrencyConverter.shared.formatAmount(
                            viewModel.totalExpensesAmount,
                            currency: defaultCurrency
                        ))
                        .font(.system(size: 32, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: CurrencyConverter.shared.formatAmount(
                            viewModel.totalExpensesAmount,
                            currency: defaultCurrency
                        ))
                    }
                }
                .padding(.horizontal, 16)
                
                // Segmented Line Chart
                SegmentedLineChartView(
                    categorizedExpenses: viewModel.categorizedExpenses,
                    totalExpenses: viewModel.totalExpensesAmount,
                    height: 24,
                    segmentSpacing: 2
                )
                .padding(.horizontal, 16)
                
                // Categories list with updated GroupedExpenseRow
                if !viewModel.categorizedExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(spacing: 4) {
                            ForEach(viewModel.categorizedExpenses, id: \.0.id) { categoryData in
                                let category = categoryData.0
                                let expenses = categoryData.1
                                
                                // Get the CategoryBudget if available
                                let categoryBudget = viewModel.currentBudget?.categoryBudgets?
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
                                    selectedDate: viewModel.filterManager.selectedDate,
                                    filterManager: viewModel.filterManager // Pass filter manager
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
        
        // Initial loading
        .onAppear {
            // No need to update here as the viewModel handles this in init
        }
        .sheet(isPresented: $showingDatePicker) {
            // Period picker sheet with callback
            PeriodPickerView(
                filterManager: viewModel.filterManager,
                showingDatePicker: $showingDatePicker
            ) { startDate, endDate, isRangeMode in
                // Handle period selection through the view model
                viewModel.applyPeriodSelection(
                    startDate: startDate,
                    endDate: endDate,
                    isRangeMode: isRangeMode
                )
            }
        }
    }
}

// Keep existing components

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

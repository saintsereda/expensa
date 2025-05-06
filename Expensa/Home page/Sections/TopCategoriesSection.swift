//
//  TopCategoriesSection.swift
//  Expensa
//
//  Created on 04.03.2025.
//

//
//  TopCategoriesSection.swift
//  Expensa
//
//  Created on 04.03.2025.
//

import Foundation
import SwiftUI

struct CategoryCircleIcon: View {
    let icon: String
    let size: CGFloat
    let iconSize: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            
            Text(icon)
                .font(.system(size: iconSize))
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let isOverBudget: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    Color.primary.opacity(0.3),
                    lineWidth: 2
                )
                .frame(width: 48, height: 48)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    isOverBudget ?
                        LinearGradient(
                            colors: [.red, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [.white, .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 48, height: 48)
        }
    }
}

struct TopCategoriesSection: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    // Required for both scenarios
    let categorizedExpenses: [(Category, [Expense])]
    let fetchedExpenses: FetchedResults<Expense>
    
    // Required for budget scenario
    var budget: Budget?
    var budgetManager: BudgetManager?
    var expenseManager: ExpenseDataManager?
    
    // NEW: Add a parameter to control how many categories to show
    let maxCategories: Int
    let showViewAllButton: Bool
    
    // Cache the total expenses amount
    @State private var totalExpensesAmount: Decimal = 0
    
    // Initialize with default value for backward compatibility
    init(categorizedExpenses: [(Category, [Expense])],
         fetchedExpenses: FetchedResults<Expense>,
         budget: Budget? = nil,
         budgetManager: BudgetManager? = nil,
         expenseManager: ExpenseDataManager? = nil,
         maxCategories: Int = 3,
         showViewAllButton: Bool = true) {
        self.categorizedExpenses = categorizedExpenses
        self.fetchedExpenses = fetchedExpenses
        self.budget = budget
        self.budgetManager = budgetManager
        self.expenseManager = expenseManager
        self.maxCategories = maxCategories
        self.showViewAllButton = showViewAllButton
    }
    
    private var hasCategoryBudgets: Bool {
        if let budget = budget, let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> {
            return !categoryBudgets.isEmpty
        }
        return false
    }
    
    var body: some View {
        if !categorizedExpenses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top categories")
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.64))
                
                if hasCategoryBudgets, let budget = budget, let budgetManager = budgetManager, let expenseManager = expenseManager {
                    // Scenario 1: Show categories with budgets
                    displayCategoriesWithBudgets(budget: budget, budgetManager: budgetManager, expenseManager: expenseManager)
                } else {
                    // Scenario 2: Show categories without budgets
                    displayCategoriesWithoutBudgets()
                }
                
                    Divider()
                    
                    NavigationLink(value: NavigationDestination.allCategories) {
                        Text("View all \(categorizedExpenses.count) categories")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .onAppear {
                // Calculate total once on appear
                updateTotalExpenses()
            }
            .onChange(of: fetchedExpenses.count) { _, _ in
                // Update the total only when the count changes
                updateTotalExpenses()
            }
        }
    }
    
    // Display categories with budgets (Scenario 1)
    @ViewBuilder
    private func displayCategoriesWithBudgets(budget: Budget, budgetManager: BudgetManager, expenseManager: ExpenseDataManager) -> some View {
        let allExpenses = budgetManager.expensesForBudget(budget)
        let uniqueCategories = NSSet(array: allExpenses.compactMap { $0.category }).allObjects as? [Category] ?? []
        let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> ?? Set<CategoryBudget>()
        
        // Sort unique categories by the amount spent (descending)
        let sortedCategories = uniqueCategories.sorted { cat1, cat2 in
            let spent1 = expenseManager.calculateCategoryAmount(
                for: allExpenses,
                category: cat1.name ?? ""
            )
            
            let spent2 = expenseManager.calculateCategoryAmount(
                for: allExpenses,
                category: cat2.name ?? ""
            )
            
            return spent1 > spent2
        }
        
        ForEach(0..<min(maxCategories, sortedCategories.count), id: \.self) { index in
            let category = sortedCategories[index]
            let categoryBudget = categoryBudgets.first { $0.category == category }
            let hasLimit = categoryBudget?.budgetAmount?.decimalValue != nil
            
            let spent = expenseManager.calculateCategoryAmount(
                for: allExpenses,
                category: category.name ?? ""
            )
            
            let expenseCount = allExpenses.filter { $0.category?.name == category.name }.count
            
            NavigationLink(destination: ExpensesByCategoryView(category: category)
                .toolbar(.hidden, for: .tabBar)) {
                
                HStack(alignment: .center, spacing: 12) {
                    // Left side with circular progress
                    ZStack {
                        if hasLimit, let limit = categoryBudget?.budgetAmount?.decimalValue {
                            // Only show circular progress if this category has a budget limit
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
                            // Larger icon when no budget limit is set
                            CategoryCircleIcon(
                                icon: category.icon ?? "❓",
                                size: 48,  // Larger size (48px) when no progress circle
                                iconSize: 20,
                                color: Color.primary.opacity(0.08)
                            )
                        }
                    }
                    
                    // Category info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name ?? "Unknown")
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("\(expenseCount) expense\(expenseCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Right side - amount info
                    if let currency = categoryBudget?.budgetCurrency ?? currencyManager.defaultCurrency {
                        VStack(alignment: .trailing, spacing: 4) {
                            // Total spent
                            Text(currencyManager.currencyConverter.formatAmount(
                                spent,
                                currency: currency
                            ))
                            .font(.body)
                            .foregroundColor(.primary)
                            
                            // Remaining amount or "Limit is not set"
                            if hasLimit, let limit = categoryBudget?.budgetAmount?.decimalValue {
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
                                 Text("Limit is not set")
                                     .font(.subheadline)
                                     .foregroundColor(.secondary)
                             }
                         }
                    }
                }
            }
            
            if index != min(3, uniqueCategories.count) - 1 {
                Divider()
            }
        }
    }
    
    // Display categories without budgets (Scenario 2)
    @ViewBuilder
    private func displayCategoriesWithoutBudgets() -> some View {
        ForEach(0..<min(maxCategories, categorizedExpenses.count), id: \.self) { index in
            let category = categorizedExpenses[index].0
            let expenses = categorizedExpenses[index].1
            
            NavigationLink(destination: ExpensesByCategoryView(category: category)
                .toolbar(.hidden, for: .tabBar)) {
                
                    HStack(alignment: .center, spacing: 12) {
                        // Left side with icon
                        CategoryCircleIcon(
                            icon: category.icon ?? "❓",
                            size: 48,
                            iconSize: 20,
                            color:  Color.primary.opacity(0.08)
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
                        let categoryAmount = expenses.reduce(Decimal(0)) { sum, expense in
                            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
                        }
                            if let defaultCurrency = currencyManager.defaultCurrency {
                                Text(currencyManager.currencyConverter.formatAmount(
                                    categoryAmount,
                                    currency: defaultCurrency
                                ))
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
            }
            
            if index != min(3, categorizedExpenses.count) - 1 {
                Divider()
            }
        }
    }
    
    // Calculate the total expenses amount once and cache it
    private func updateTotalExpenses() {
        totalExpensesAmount = fetchedExpenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
    }
}

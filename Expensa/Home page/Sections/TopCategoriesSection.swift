//
//  TopCategoriesSection.swift
//  Expensa
//
//  Created on 04.03.2025.
//

import Foundation
import SwiftUI

struct TopCategoriesSection: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    // Required for both scenarios
    let categorizedExpenses: [(Category, [Expense])]
    let fetchedExpenses: FetchedResults<Expense>
    
    // Required for budget scenario
    var budget: Budget?
    var budgetManager: BudgetManager?
    var expenseManager: ExpenseDataManager?
    
    // Cache the total expenses amount
    @State private var totalExpensesAmount: Decimal = 0
    
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
                    .foregroundColor(.gray)
                
                if hasCategoryBudgets, let budget = budget, let budgetManager = budgetManager, let expenseManager = expenseManager {
                    // Scenario 1: Show categories with budgets
                    displayCategoriesWithBudgets(budget: budget, budgetManager: budgetManager, expenseManager: expenseManager)
                } else {
                    // Scenario 2: Show categories without budgets
                    displayCategoriesWithoutBudgets()
                }
                
                if categorizedExpenses.count > 3 {
                    Divider()
                    
                    NavigationLink(value: NavigationDestination.allCategories) {
                        Text("View all \(categorizedExpenses.count) categories")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
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
        
        ForEach(0..<min(3, sortedCategories.count), id: \.self) { index in
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
            
            VStack(spacing: 12) {
                // Top section
                HStack {
                    Text(category.icon ?? "❓")
                        .font(.system(size: 17))
                    
                    Text(category.name ?? "Unknown")
                        .font(.body)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    
                    // Middle section
                    HStack(alignment: .center) {
                        VStack(alignment: .leading) {
                            if let currency = categoryBudget?.budgetCurrency ?? currencyManager.defaultCurrency {
                                if hasLimit {
                                    let remaining = categoryBudget!.budgetAmount!.decimalValue - spent
                                    Text(currencyManager.currencyConverter.formatAmount(
                                        remaining,
                                        currency: currency
                                    ))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                } else {
                                    Text("Limit is not set")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            if let currency = categoryBudget?.budgetCurrency ?? currencyManager.defaultCurrency {
                                HStack(spacing: 2) {
                                    Text(currencyManager.currencyConverter.formatAmount(spent, currency: currency))
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Text("/ \(hasLimit ? currencyManager.currencyConverter.formatAmount(categoryBudget!.budgetAmount!.decimalValue, currency: currency) : currencyManager.currencyConverter.formatAmount(0, currency: currency))")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .opacity(0.64)
                                }
                            }
                        }
                    }
                    
                    // Progress bar section
                    if hasLimit, let limit = categoryBudget?.budgetAmount?.decimalValue {
                        let percentage = min(Double(truncating: (spent / limit) as NSDecimalNumber), 1.0)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(height: 4)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(spent > limit ?
                                          LinearGradient(
                                            colors: [.red, .red.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          ) :
                                            LinearGradient(
                                                colors: [.blue, .purple.opacity(0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(percentage), height: 4)
                            }
                        }
                        .frame(height: 4)
                    } else {
                        // When limit is not set, show a full progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(height: 4)
                                
                                // Full progress (100%)
                                RoundedRectangle(cornerRadius: 2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    
                    // Bottom section
                    HStack {
                        Text("\(expenseCount) expense\(expenseCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Add percentage spent of limit when a limit exists
                        if hasLimit, let limit = categoryBudget?.budgetAmount?.decimalValue, limit > 0 {
                            let percentSpent = budgetManager.calculateMonthlyPercentage(spent: spent, budget: limit)
                            Text(budgetManager.formatPercentage(percentSpent))
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

                ForEach(0..<min(3, categorizedExpenses.count), id: \.self) { index in
                    let category = categorizedExpenses[index].0
                    let expenses = categorizedExpenses[index].1
                    
                    NavigationLink(destination: ExpensesByCategoryView(category: category)
                        .toolbar(.hidden, for: .tabBar)) {
                    VStack(spacing: 8) {
                        // Top section
                        HStack {
                            // Left side - category emoji with name
                            HStack {
                                Text(category.icon ?? "❓")
                                    .font(.system(size: 17))
                                
                                Text(category.name ?? "Unknown")
                                    .font(.body)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Right side - total spent
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
                        
                        // Bottom section - expense count
                        HStack {
                            Text("\(expenses.count) expense\(expenses.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
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

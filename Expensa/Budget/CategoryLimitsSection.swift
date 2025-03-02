//
//  CategoryLimitsSection.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.02.2025.
//

import Foundation
import SwiftUI

struct CategoryLimitsSection: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject var budget: Budget
    let budgetManager: BudgetManager
    let expenseManager: ExpenseDataManager
    
    var body: some View {
        if let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget>, !categoryBudgets.isEmpty {
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Spending by category")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Sort categories by overspent status and proximity to limit
                ForEach(Array(categoryBudgets).sorted { cat1, cat2 in
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
                }.prefix(3), id: \.self) { categoryBudget in
                    if let category = categoryBudget.category,
                       let amount = categoryBudget.budgetAmount?.decimalValue {
                        CategoryLimitRow(
                            category: category,
                            amount: amount,
                            spent: expenseManager.calculateCategoryAmount(
                                for: budgetManager.expensesForBudget(budget),
                                category: category.name ?? ""
                            ),
                            percentage: budgetManager.formatPercentage(
                                budgetManager.calculatePercentage(for: categoryBudget, in: budget)
                            ),
                            currency: categoryBudget.budgetCurrency ?? Currency(),
                            expenseCount: budgetManager.expensesForBudget(budget)
                                .filter { $0.category?.name == category.name }
                                .count
                        )
                        
                        let sortedCategories = Array(categoryBudgets).sorted { cat1, cat2 in
                            let percent1 = budgetManager.calculatePercentage(for: cat1, in: budget)
                            let percent2 = budgetManager.calculatePercentage(for: cat2, in: budget)
                            
                            if percent1 > 100 && percent2 > 100 {
                                return percent1 > percent2
                            }
                            else if percent1 > 100 {
                                return true
                            }
                            else if percent2 > 100 {
                                return false
                            }
                            else {
                                return percent1 > percent2
                            }
                        }
                        
                        if categoryBudget != sortedCategories.prefix(3).last {
                            Divider()
                        }
                    }
                }
                
                if categoryBudgets.count > 3 {
                    Divider()
                    
                    NavigationLink(value: NavigationDestination.budgetview) {
                        Text("View all \(categoryBudgets.count) categories")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(12)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
}

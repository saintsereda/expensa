//
//  BudgetRow.swift
//  Expensa
//
//  Created by Andrew Sereda on 15.11.2024.
//

import Foundation
import SwiftUI

struct BudgetRow: View {
    @ObservedObject var budget: Budget
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var isUpdating = false
    
    private let budgetManager = BudgetManager.shared
    private let expenseManager = ExpenseDataManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonthlyBudgetSection()
            
            if let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget>,
               !categoryBudgets.isEmpty {
                HStack {
                    Text("Category limits")
                        .font(.body)
                }
                
                VStack(spacing: 12) {
                    let sortedCategoryBudgets = getSortedCategoryBudgets(categoryBudgets)
                    
                    ForEach(sortedCategoryBudgets, id: \.self) { categoryBudget in
                        if let category = categoryBudget.category,
                           let amount = categoryBudget.budgetAmount?.decimalValue {
                            // Using the simplified CategoryLimitRow that only shows icon, name and limit
                            CategoryLimitRow(
                                category: category,
                                amount: amount,
                                currency: categoryBudget.budgetCurrency ?? Currency()
                            )
                            if categoryBudget != sortedCategoryBudgets.last {
                                Divider()
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
            
            if budgetManager.isCurrentMonth(budget) {
                ActionButtons()
            }
        }
    }
    
    // Function to sort category budgets by overspent status and proximity to limit
    private func getSortedCategoryBudgets(_ categoryBudgets: Set<CategoryBudget>) -> [CategoryBudget] {
        return Array(categoryBudgets).sorted { first, second in
            guard let firstCategory = first.category, let firstAmount = first.budgetAmount?.decimalValue else {
                return false
            }
            guard let secondCategory = second.category, let secondAmount = second.budgetAmount?.decimalValue else {
                return true
            }
            
            let firstSpent = expenseManager.calculateCategoryAmount(
                for: budgetManager.expensesForBudget(budget),
                category: firstCategory.name ?? ""
            )
            
            let secondSpent = expenseManager.calculateCategoryAmount(
                for: budgetManager.expensesForBudget(budget),
                category: secondCategory.name ?? ""
            )
            
            // Calculate percentage spent for each category
            let firstPercentage = firstAmount.isZero ? 0 : (firstSpent / firstAmount) * 100
            let secondPercentage = secondAmount.isZero ? 0 : (secondSpent / secondAmount) * 100
            
            // First sort by overspent (over 100%)
            if firstPercentage >= 100 && secondPercentage < 100 {
                return true
            }
            if secondPercentage >= 100 && firstPercentage < 100 {
                return false
            }
            
            // Next sort by proximity to limit (higher percentage first)
            return firstPercentage > secondPercentage
        }
    }
    
    @ViewBuilder
    private func MonthlyBudgetSection() -> some View {
        VStack {
            HStack {
                Text("Monthly budget")
                    .font(.body)
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 4)
            
            if let amount = budget.amount?.decimalValue, let currency = budget.budgetCurrency {
                VStack(alignment: .leading, spacing: 8) {
                    Text(CurrencyConverter.shared.formatAmount(amount, currency: currency))
                        .font(.system(size: 34, weight: .regular))
                    
                    let totalSpent = expenseManager.calculateTotalAmount(
                        for: budgetManager.expensesForBudget(budget)
                    )
                    let monthlyPercentage = budgetManager.calculateMonthlyPercentage(spent: totalSpent, budget: amount)
                    
                    HStack {
                        Text(CurrencyConverter.shared.formatAmount(totalSpent, currency: currency))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(budgetManager.formatPercentage(monthlyPercentage)) spent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressBar(monthlyPercentage: monthlyPercentage)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func ProgressBar(monthlyPercentage: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                    .cornerRadius(4)
                Rectangle()
                    .fill(monthlyPercentage >= 100 ? Color.red :
                          monthlyPercentage >= 90 ? Color.orange : Color.blue)
                    .frame(width: min(geometry.size.width * CGFloat(monthlyPercentage / 100), geometry.size.width), height: 8)
                    .cornerRadius(4)
            }
        }
        .frame(height: 8)
    }
    
    @ViewBuilder
    private func ActionButtons() -> some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack {
                    Image(systemName: "pencil")
                        .imageScale(.small)
                    Text("Edit")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            
            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                        .imageScale(.small)
                    Text("Delete")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.top, 4)
    }
}

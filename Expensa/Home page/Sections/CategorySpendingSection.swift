//
//  CategorySpendingView.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.02.2025.
//

import Foundation
import SwiftUI

struct CategorySpendingSection: View {
    let categorizedExpenses: [(Category, [Expense])]
    let fetchedExpenses: FetchedResults<Expense>
    
    // Cache the total expenses amount
    @State private var totalExpensesAmount: Decimal = 0
    
    var body: some View {
        if !categorizedExpenses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spending by category")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Use the prefix directly without creating an Array
                ForEach(0..<min(3, categorizedExpenses.count), id: \.self) { index in
                    let categoryData = categorizedExpenses[index]
                    
                    CategoryExpensesRow(
                        category: categoryData.0,
                        expenses: categoryData.1,
                        totalExpenses: totalExpensesAmount
                    )
                    
                    if index != min(3, categorizedExpenses.count) - 1 {
                        Divider()
                    }
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
    
    // Calculate the total expenses amount once and cache it
    private func updateTotalExpenses() {
        totalExpensesAmount = fetchedExpenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
    }
}

//
//  RecentExpensesSection.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.02.2025.
//

import Foundation
import SwiftUI
import CoreData

struct RecentExpensesSection: View {
    let fetchedExpenses: FetchedResults<Expense>
    @Binding var selectedExpense: Expense?
    
    // Cache the first 3 expenses
    @State private var recentExpenses: [Expense] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent expenses")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.64))
            
            if fetchedExpenses.isEmpty {
                // "No expenses this month" message
                VStack(spacing: 8) {
                    Text("No expenses this month")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                }
            } else {
                // Use the cached expenses for rendering
                ForEach(recentExpenses, id: \.self) { expense in
                    ExpenseRow(
                        expense: expense,
                        onDelete: {
                            ExpenseDataManager.shared.deleteExpense(expense)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedExpense = expense
                    }
                    
                    if expense != recentExpenses.last {
                        // Empty block - removed unnecessary Divider
                    }
                }
            }
            
            Divider()
            
            NavigationLink(value: NavigationDestination.allExpenses) {
                Text("View all expenses")
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .onAppear {
            // Update the cache on appear
            updateRecentExpenses()
        }
        .onChange(of: fetchedExpenses.count) { _, _ in
            // Update the cache when expenses count changes
            updateRecentExpenses()
        }
    }
    
    // Update the cached recent expenses
    private func updateRecentExpenses() {
        // Take just the first 3 items
        recentExpenses = Array(fetchedExpenses.prefix(3))
    }
}

//
//  SubscriptionSectionView.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.02.2025.
//

import Foundation
import SwiftUI
import CoreData

struct SubscriptionsSection: View {
    let recurringExpenses: FetchedResults<RecurringExpense>
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // Filter for current month subscriptions
    private var currentMonthSubscriptions: [RecurringExpense] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return recurringExpenses.filter { subscription in
            guard let nextDueDate = subscription.nextDueDate else { return false }
            return nextDueDate >= startOfMonth && nextDueDate <= endOfMonth
        }
    }

    
    var body: some View {
        if !recurringExpenses.isEmpty && !currentMonthSubscriptions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming expenses")
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.64))
                
                // Show only current month subscriptions
                ForEach(Array(currentMonthSubscriptions.prefix(3))) { template in
                    RecurringExpenseRow(template: template)
                    
                    if template != currentMonthSubscriptions.prefix(3).last {
                        Divider()
                    }
                }
                    Divider()
                    
                    NavigationLink(value: NavigationDestination.allSubscriptions) {
                        Text("View all \(recurringExpenses.count) subscriptions")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.16))
            .cornerRadius(16)
        }
    }
}

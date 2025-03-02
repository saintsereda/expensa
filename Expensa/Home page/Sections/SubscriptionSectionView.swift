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
    
    var body: some View {
        if !recurringExpenses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Subscriptions")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading) {
                        Text("\(recurringExpenses.count)")
                            .font(.body)
                        Text("Active")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    
                    VStack(alignment: .trailing) {
                        if let defaultCurrency = currencyManager.defaultCurrency {
                            Text(currencyManager.currencyConverter.formatAmount(
                                RecurringExpenseManager.calculateMonthlyTotal(
                                    for: Array(recurringExpenses),
                                    defaultCurrency: defaultCurrency,
                                    currencyConverter: currencyManager.currencyConverter
                                ),
                                currency: defaultCurrency
                            ))
                            .font(.body)
                            
                            Text("monthly")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
                Divider()
                
                ForEach(Array(recurringExpenses.prefix(3))) { template in
                    RecurringExpenseRow(template: template)
                    
                    if template != recurringExpenses.prefix(3).last {
                        Divider()
                    }
                }
                
                if recurringExpenses.count > 3 {
                    Divider()
                    
                    NavigationLink(value: NavigationDestination.allSubscriptions) {
                        Text("View all \(recurringExpenses.count) subscriptions")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
}

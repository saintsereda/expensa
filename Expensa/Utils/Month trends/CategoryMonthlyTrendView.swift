//
//  CategoryMonthlyTrendView.swift
//  Expensa
//
//  Created by Andrew Sereda on 12.02.2025.
//

import Foundation
import SwiftUI
import CoreData

struct CategoryMonthlyTrendView: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    let category: Category
    let data: [(Date, Decimal)]

    private var totalSpentIn6Months: Decimal {
        let fetchRequest = NSFetchRequest<Expense>(entityName: "Expense")
        fetchRequest.predicate = NSPredicate(format: "category == %@", category)

        guard let expenses = try? CoreDataStack.shared.context.fetch(fetchRequest) else {
            return 0
        }

        return ExpenseAnalytics.shared.calculateTotalSpentLast6Months(for: expenses)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack (alignment: .center, spacing: 0) {
                Text("Spent ")
                    .font(.subheadline)

                if let defaultCurrency = currencyManager.defaultCurrency {
                    Text(currencyManager.currencyConverter.formatAmount(
                        totalSpentIn6Months,
                        currency: defaultCurrency
                    ))
                    .font(.subheadline)
                }
                Text(" in 6 months")
                        .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            MonthlyTrendChart(data: data)
                .frame(height: 240)
        }
        .cornerRadius(12)
        .padding(12)
    }
}

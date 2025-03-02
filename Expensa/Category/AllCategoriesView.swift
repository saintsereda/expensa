//
//  TopCategoriesView.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import Foundation
import SwiftUI

struct AllCategoriesView: View {
    let categorizedExpenses: [(Category, [Expense])]
    let fetchedExpenses: FetchedResults<Expense>
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(categorizedExpenses.enumerated()), id: \.element.0) { index, categoryData in
                    CategoryExpensesRow(
                        category: categoryData.0,
                        expenses: categoryData.1,
                        totalExpenses: ExpenseDataManager.shared.calculateTotalAmount(
                            for: Array(fetchedExpenses)
                        )
                    )
                    
                    if index != categorizedExpenses.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(12)
        }
        .navigationTitle("All categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

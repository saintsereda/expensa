//
//  CategoryGroupRow.swift
//  Expensa
//
//  Created by Andrew Sereda on 27.10.2024.
//

import SwiftUI

struct CategoryExpensesRow: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    let category: Category
    let expenses: [Expense]
    let totalExpenses: Decimal
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    private var categoryAmount: Decimal {
        expenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
    }
    
    private var percentage: Double {
        guard totalExpenses > 0 else { return 0 }
        return (NSDecimalNumber(decimal: categoryAmount).doubleValue /
                NSDecimalNumber(decimal: totalExpenses).doubleValue) * 100
    }
    
    var body: some View {
        NavigationLink(destination: ExpensesByCategoryView(category: category)
            .toolbar(.hidden, for: .tabBar)) {
            VStack() {
                // Header with icon and amount
                HStack {
                    Text(category.icon ?? "❓")
                        .font(.system(size: 24))

                    Text(category.name ?? "Unknown")
                        .font(.body)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let defaultCurrency = currencyManager.defaultCurrency {
                        Text(currencyManager.currencyConverter.formatAmount(
                            categoryAmount,
                            currency: defaultCurrency
                        ))
                        .font(.body)
                        .fixedSize()
                    }
                }
                
                // Progress bar and stats
                VStack() {
                    // Custom progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Blue progress bar
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: max(0, min(geometry.size.width * CGFloat(percentage / 100), geometry.size.width)), height: 4)
                                .cornerRadius(2)
                            
                            // Gray segments
                            if percentage < 100 {
                                ForEach(0..<Int(geometry.size.width / 9), id: \.self) { i in
                                    let startX = (geometry.size.width * CGFloat(percentage / 100)) + CGFloat(i) * 9
                                    if startX + 1 <= geometry.size.width {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.5))
                                            .frame(width: 2, height: 4)
                                            .cornerRadius(2)
                                            .offset(x: startX)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 4)
                    
                    // Stats row
                    HStack {
                        Text("\(expenses.count) expense\(expenses.count == 1 ? "" : "s")")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(percentage < 1 ? "<1%" : "\(numberFormatter.string(from: NSNumber(value: percentage)) ?? "0")%")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
            }
          //  .padding(.horizontal, 16) // Specific horizontal padding
        }
        .buttonStyle(PlainButtonStyle())
    }
}

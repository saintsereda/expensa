//
//  GroupedExpensesView.swift
//  Expensa
//

import SwiftUI
import CoreData

struct GroupedExpensesView: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    let expenses: [Expense]
    let onExpenseSelected: (Expense) -> Void
    
    private var groupedExpenses: [(Date, [Expense], Decimal)] {
        let calendar = Calendar.current
        
        // Group expenses by date
        let groupedDict = Dictionary(grouping: expenses) { expense in
            calendar.startOfDay(for: expense.date ?? Date())
        }
        
        // Convert to array and calculate totals
        let grouped = groupedDict.map { (date, expenses) -> (Date, [Expense], Decimal) in
            let dailyTotal = expenses.reduce(Decimal(0)) { total, expense in
                total + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
            }
            return (date, expenses, dailyTotal)
        }
        
        // Sort by date, newest first
        return grouped.sorted { $0.0 > $1.0 }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(groupedExpenses, id: \.0) { date, expenses, total in
                VStack(spacing: 0) {
                    // Date header with total
                    HStack {
                        Text(formattedDate(date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let defaultCurrency = currencyManager.defaultCurrency {
                            Text("" + currencyManager.currencyConverter.formatAmount(total, currency: defaultCurrency))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Expenses for this date
                    VStack(spacing: 12) {
                        ForEach(expenses) { expense in
                            ExpenseRow(expense: expense, onDelete: {
                                ExpenseDataManager.shared.deleteExpense(expense)
                            })
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onExpenseSelected(expense)
                            }
                            
                            if expense != expenses.last {
                            //    Divider()
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
}

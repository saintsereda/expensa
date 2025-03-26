//
//  DailySpendingProgressGraph.swift
//  Expensa
//
//  Created by Andrew Sereda on 04.11.2024.
//

import SwiftUI
import Charts

public struct DailySpendingProgressGraph: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    let expenses: [Expense]
    let selectedDate: Date
    
    public init(expenses: [Expense], selectedDate: Date) {
        self.expenses = expenses
        self.selectedDate = selectedDate
    }
    
    private var dailyTotals: [(date: Date, amount: Decimal)] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: selectedDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        
        var dayTotals: [(Date, Decimal)] = []
        
        // Initialize all days of the month with zero
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: startOfMonth) {
                dayTotals.append((date, 0))
            }
        }
        
        // Add up expenses for each day
        for expense in expenses {
            guard let date = expense.date else { continue }
            if let index = dayTotals.firstIndex(where: { calendar.isDate($0.0, inSameDayAs: date) }) {
                let amount = expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0
                dayTotals[index].1 += amount
            }
        }
        
        // Add a zero point at the beginning to ensure the line starts from zero
        // This helps with visibility on the 1st day
        if let firstDay = dayTotals.first {
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: firstDay.0) {
                dayTotals.insert((dayBefore, 0), at: 0)
            }
        }
        
        return dayTotals
    }
    
    private var todayIndex: Int? {
        let calendar = Calendar.current
        let today = Date()
        
        // Only get today's index if we're in the currently selected month
        if calendar.isDate(today, equalTo: selectedDate, toGranularity: .month) {
            return dailyTotals.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) })
        }
        return nil
    }
    
    private var maxAmount: Decimal {
        let max = dailyTotals.map { $0.amount }.max() ?? 0
        return max > 0 ? max : 1 // Ensure we have a non-zero max for scaling
    }
    
    // For plotting only until today or all month if viewing past months
    private var visibleData: [(date: Date, amount: Decimal)] {
        if let todayIdx = todayIndex {
            return Array(dailyTotals.prefix(through: todayIdx))
        } else {
            // For past or future months, show full month data
            return dailyTotals
        }
    }
    
    // Check if there are any expenses in the current month
    private var hasExpensesInMonth: Bool {
        return expenses.contains(where: { $0.amount?.decimalValue ?? 0 > 0 })
    }
    
    // Check if it's the most recent expense
    private func isRecentExpense(_ date: Date) -> Bool {
        guard let latestExpenseDate = expenses
            .compactMap({ $0.date })
            .sorted(by: { $0 > $1 })
            .first else { return false }
        
        let calendar = Calendar.current
        return calendar.isDate(date, inSameDayAs: latestExpenseDate)
    }
    
    public var body: some View {
        Chart {
            if hasExpensesInMonth {
                // Line with gradient for when we have expenses
                ForEach(visibleData, id: \.date) { day in
                    LineMark(
                        x: .value("Day", day.date),
                        y: .value("Amount", day.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom) // Smoother curve
                }
                
                // Area beneath the line with subtle gradient
                ForEach(visibleData, id: \.date) { day in
                    AreaMark(
                        x: .value("Day", day.date),
                        y: .value("Amount", day.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .blue.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            } else {
                // Gray line when no expenses for the month
                ForEach(visibleData, id: \.date) { day in
                    LineMark(
                        x: .value("Day", day.date),
                        y: .value("Amount", 0.5) // Slight offset to make it visible
                    )
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 5]))
                }
            }
        }
        .frame(height: 100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: [visibleData.first?.date ?? Date(), visibleData.last?.date ?? Date()])
        .chartYScale(domain: 0...(NSDecimalNumber(decimal: maxAmount).doubleValue * 1.1))
        .padding(.vertical, 8)
        // Add animation to make the transition smoother when new expenses are added
        .animation(.easeInOut(duration: 0.6), value: hasExpensesInMonth)
        .animation(.easeInOut(duration: 0.6), value: expenses.count)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}


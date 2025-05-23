//
//  ExpenseAnalytics.swift
//  Expensa
//
//  Created by Andrew Sereda on 12.02.2025.
//

import Foundation
import SwiftUI

struct WeeklyRecapData {
    let weekInterval: DateInterval
    let totalSpent: Decimal
    let transactionCount: Int
    let highestSpendingDay: DaySpendingData?
    let lowestSpendingDay: DaySpendingData?
    let comparisonWithPreviousWeek: WeekComparisonData
    let biggestExpense: ExpenseData?
}

struct DaySpendingData {
    let date: Date
    let amount: Decimal
    let expenseCount: Int
}

struct WeekComparisonData {
    let previousWeekSpent: Decimal
    let difference: Decimal
    let percentageChange: Double
    
    var isIncrease: Bool {
        return difference > 0
    }
}

struct ExpenseData {
    let expense: Expense
    let category: String
    let amount: Decimal
    let date: Date
}

class ExpenseAnalytics {
    static let shared = ExpenseAnalytics()
    private let expenseDataManager = ExpenseDataManager.shared
    
    private init() {}
    
    // MARK: - Trend Analysis
    func calculateMonthlyTrend(
        for expenses: [Expense],
        matching predicate: ((Expense) -> Bool)? = nil
    ) -> [(Date, Decimal)] {
        let calendar = Calendar.current
        let today = Date()
        
        // Get last 6 months including current
        let months = (0...5).compactMap { monthsAgo in
            calendar.date(byAdding: .month, value: -monthsAgo, to: today)
        }.reversed()
        
        return months.map { month in
            let interval = DateInterval(
                start: calendar.startOfMonth(for: month),
                end: calendar.endOfMonth(for: month)
            )
            var monthExpenses = expenses.filter {
                guard let date = $0.date else { return false }
                return interval.contains(date)
            }
            
            // Apply additional filtering if predicate provided
            if let predicate = predicate {
                monthExpenses = monthExpenses.filter(predicate)
            }
            
            let total = expenseDataManager.calculateTotalAmount(for: monthExpenses)
            return (month, total)
        }
    }
    
    func findPeakSpendingDay(
        for expenses: [Expense],
        matching predicate: ((Expense) -> Bool)? = nil
    ) -> (date: Date, amount: Decimal)? {
        let filteredExpenses = predicate.map { expenses.filter($0) } ?? expenses
        
        let groupedExpenses = Dictionary(grouping: filteredExpenses) { expense in
            DateFormatterUtil.shared.startOfDay(for: expense.date ?? Date())
        }
        
        return groupedExpenses
            .map { (date, expenses) -> (Date, Decimal) in
                let total = expenseDataManager.calculateTotalAmount(for: expenses)
                return (date, total)
            }
            .max { $0.1 < $1.1 }
    }
    
    // MARK: - Category Analysis
    func calculateTotalSpent(
        for expenses: [Expense],
        in category: Category? = nil
    ) -> Decimal {
        let filteredExpenses = category.map { category in
            expenses.filter { $0.category == category }
        } ?? expenses
        return expenseDataManager.calculateTotalAmount(for: filteredExpenses)
    }
    
    // MARK: - Time Period Analysis
    func calculateTotalSpent(
        for expenses: [Expense],
        in period: DateInterval
    ) -> Decimal {
        let periodExpenses = expenses.filter {
            guard let date = $0.date else { return false }
            return period.contains(date)
        }
        return expenseDataManager.calculateTotalAmount(for: periodExpenses)
    }

    func calculateTotalSpentLast6Months(
        for expenses: [Expense],
        matching predicate: ((Expense) -> Bool)? = nil
    ) -> Decimal {
        let calendar = Calendar.current
        let today = Date()
        guard let sixMonthsAgo = calendar.date(
            byAdding: .month,
            value: -6,
            to: calendar.startOfDay(for: today)
        ) else { return 0 }
        
        let period = DateInterval(start: sixMonthsAgo, end: today)
        
        var filteredExpenses = expenses.filter {
            guard let date = $0.date else { return false }
            return period.contains(date)
        }
        
        if let predicate = predicate {
            filteredExpenses = filteredExpenses.filter(predicate)
        }
        
        return calculateTotalSpent(for: filteredExpenses)
    }
    func getLastWeekDateInterval() -> DateInterval {
        let calendar = Calendar.current
        let today = Date()
        
        // Find the most recent Monday before today
        var comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: today)
        comps.weekday = 2 // Monday
        
        // Get current week's Monday
        guard let currentMonday = calendar.date(from: comps) else {
            // Fallback to simple calculation if components fail
            return fallbackLastWeekCalculation()
        }
        
        // Get last week's Monday and Sunday
        guard let lastMonday = calendar.date(byAdding: .day, value: -7, to: currentMonday),
              let lastSunday = calendar.date(byAdding: .day, value: 6, to: lastMonday) else {
            return fallbackLastWeekCalculation()
        }
        
        // Set time to 23:59:59 for Sunday
        let lastSundayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastSunday) ?? lastSunday
        
        return DateInterval(start: lastMonday, end: lastSundayEnd)
    }
    
    // Get the week before last week
    func getWeekBeforeLastInterval() -> DateInterval {
        let calendar = Calendar.current
        let lastWeekInterval = getLastWeekDateInterval()
        
        // Go back one more week from last week's start
        guard let twoWeeksAgoMonday = calendar.date(byAdding: .day, value: -7, to: lastWeekInterval.start),
              let twoWeeksAgoSunday = calendar.date(byAdding: .day, value: 6, to: twoWeeksAgoMonday) else {
            // Fallback to simple calculation
            return DateInterval(
                start: calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
                end: calendar.date(byAdding: .day, value: -8, to: Date()) ?? Date()
            )
        }
        
        // Set time to 23:59:59 for Sunday
        let twoWeeksAgoSundayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: twoWeeksAgoSunday) ?? twoWeeksAgoSunday
        
        return DateInterval(start: twoWeeksAgoMonday, end: twoWeeksAgoSundayEnd)
    }
    
    private func fallbackLastWeekCalculation() -> DateInterval {
        // Simple fallback calculation if the calendar components method fails
        let calendar = Calendar.current
        let today = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        return DateInterval(start: sevenDaysAgo, end: today)
    }
    
    func getWeeklyRecapData(for expenses: [Expense]) -> WeeklyRecapData {
        let weekInterval = getLastWeekDateInterval()
        let previousWeekInterval = getWeekBeforeLastInterval()
        
        // Debug info
        print("Last week interval: \(weekInterval.start) to \(weekInterval.end)")
        print("Previous week interval: \(previousWeekInterval.start) to \(previousWeekInterval.end)")
        
        // Filter expenses within the last week
        let weeklyExpenses = expenses.filter { expense in
            guard let date = expense.date else { return false }
            let isInWeek = weekInterval.contains(date)
            return isInWeek
        }
        
        // Filter expenses for the week before last
        let previousWeekExpenses = expenses.filter { expense in
            guard let date = expense.date else { return false }
            let isInPreviousWeek = previousWeekInterval.contains(date)
            return isInPreviousWeek
        }
        
        print("Found \(weeklyExpenses.count) expenses for last week")
        print("Found \(previousWeekExpenses.count) expenses for previous week")
        
        // Calculate total amount for last week
        let totalAmount = expenseDataManager.calculateTotalAmount(for: weeklyExpenses)
        
        // Calculate total amount for week before last
        let previousWeekAmount = expenseDataManager.calculateTotalAmount(for: previousWeekExpenses)
        
        print("Last week total: \(totalAmount)")
        print("Previous week total: \(previousWeekAmount)")
        
        // Calculate week-over-week difference
        let difference = totalAmount - previousWeekAmount
        
        // Calculate percentage change
        let percentageChange: Double
        if previousWeekAmount == 0 {
            // If previous week was zero, handle that case
            percentageChange = totalAmount > 0 ? 100.0 : 0.0
        } else {
            percentageChange = Double(truncating: NSDecimalNumber(
                decimal: (difference / previousWeekAmount) * 100
            ))
        }
        
        // Get number of transactions
        let transactionCount = weeklyExpenses.count
        
        // Find day with most spending
        let dayWithMostSpending = findDayWithMostSpending(in: weeklyExpenses)
        
        // Find day with least spending
        let dayWithLeastSpending = findDayWithLeastSpending(in: weeklyExpenses, weekInterval: weekInterval)
        
        // Find the biggest expense
        let biggestExpense = findBiggestExpense(in: weeklyExpenses)
        
        // Create comparison data
        let comparisonData = WeekComparisonData(
            previousWeekSpent: previousWeekAmount,
            difference: difference,
            percentageChange: percentageChange
        )
        
        return WeeklyRecapData(
            weekInterval: weekInterval,
            totalSpent: totalAmount,
            transactionCount: transactionCount,
            highestSpendingDay: dayWithMostSpending,
            lowestSpendingDay: dayWithLeastSpending,
            comparisonWithPreviousWeek: comparisonData,
            biggestExpense: biggestExpense
        )
    }
    
    // Find the biggest expense in the given list
    private func findBiggestExpense(in expenses: [Expense]) -> ExpenseData? {
        guard let biggestExpense = expenses.max(by: {
            (expense1, expense2) -> Bool in
            let amount1 = expense1.convertedAmount?.decimalValue ?? expense1.amount?.decimalValue ?? 0
            let amount2 = expense2.convertedAmount?.decimalValue ?? expense2.amount?.decimalValue ?? 0
            return amount1 < amount2
        }) else {
            return nil
        }
        
        let amount = biggestExpense.convertedAmount?.decimalValue ?? biggestExpense.amount?.decimalValue ?? 0
        let categoryName = biggestExpense.category?.name ?? "Uncategorized"
        let date = biggestExpense.date ?? Date()
        
        return ExpenseData(
            expense: biggestExpense,
            category: categoryName,
            amount: amount,
            date: date
        )
    }
    
    private func findDayWithMostSpending(in expenses: [Expense]) -> DaySpendingData? {
        let calendar = Calendar.current
        
        // Group expenses by day
        let groupedByDay = Dictionary(grouping: expenses) { expense in
            guard let date = expense.date else { return Date() }
            return calendar.startOfDay(for: date)
        }
        
        // Calculate total amount for each day
        let dailyTotals = groupedByDay.mapValues { expenses in
            expenseDataManager.calculateTotalAmount(for: expenses)
        }
        
        // Find the day with highest spending
        if let (maxDay, maxAmount) = dailyTotals.max(by: { $0.value < $1.value }) {
            return DaySpendingData(
                date: maxDay,
                amount: maxAmount,
                expenseCount: groupedByDay[maxDay]?.count ?? 0
            )
        }
        
        return nil
    }
    
    private func findDayWithLeastSpending(in expenses: [Expense], weekInterval: DateInterval) -> DaySpendingData? {
        let calendar = Calendar.current
        
        // Group expenses by day
        let groupedByDay = Dictionary(grouping: expenses) { expense in
            guard let date = expense.date else { return Date() }
            return calendar.startOfDay(for: date)
        }
        
        // Calculate total amount for each day that has expenses
        let dailyTotals = groupedByDay.mapValues { expenses in
            expenseDataManager.calculateTotalAmount(for: expenses)
        }
        
        // Filter out days with no expenses (we only want days with at least 1 transaction)
        let daysWithExpenses = dailyTotals.filter { _, amount in
            amount > 0
        }
        
        // If no days have expenses, return nil
        guard !daysWithExpenses.isEmpty else {
            return nil
        }
        
        // Find the day with lowest spending among days that have expenses
        if let (minDay, minAmount) = daysWithExpenses.min(by: { $0.value < $1.value }) {
            return DaySpendingData(
                date: minDay,
                amount: minAmount,
                expenseCount: groupedByDay[minDay]?.count ?? 0
            )
        }
        
        return nil
    }
}

// Helper extension
private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return self.date(byAdding: components, to: startOfMonth(for: date)) ?? date
    }
}

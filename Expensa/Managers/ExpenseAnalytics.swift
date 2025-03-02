//
//  ExpenseAnalytics.swift
//  Expensa
//
//  Created by Andrew Sereda on 12.02.2025.
//

import Foundation
import SwiftUI

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

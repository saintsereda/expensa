//
//  TotalSpentRow.swift
//  Expensa
//
//  Created by Andrew Sereda on 27.10.2024.
//

import SwiftUI
import CoreData

private struct BudgetInfo {
    let amount: Decimal
    let remaining: Decimal
    let currency: Currency
    
    var formattedRemaining: String {
        CurrencyConverter.shared.formatAmount(remaining, currency: currency)
    }
    
    var formattedTotal: String {
        CurrencyConverter.shared.formatAmount(amount, currency: currency)
    }
}

struct TotalSpentRow: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // Accept FetchedResults instead of array
    let expenses: FetchedResults<Expense>
    let selectedDate: Date
    
    // Remove unused fetch request
    // @FetchRequest private var expenseChanges: FetchedResults<Expense>
    
    @FetchRequest private var currentMonthBudget: FetchedResults<Budget>
    
    // Cache the total spent value
    @State private var cachedTotalSpent: Decimal = 0
    
    // MARK: - Base Properties
    private var totalSpent: Decimal {
        // Use cached value, we'll update this when necessary
        cachedTotalSpent
    }
    
    private var formattedMonth: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: selectedDate)
    }
    
    // MARK: - Budget Info
    private var budgetInfo: BudgetInfo? {
        guard let budget = currentMonthBudget.first,
              let amount = budget.amount?.decimalValue,
              let currency = currencyManager.defaultCurrency else {
            return nil
        }
        
        let remaining = amount - totalSpent
        return BudgetInfo(
            amount: amount,
            remaining: remaining,
            currency: currency
        )
    }
    
    // MARK: - Init
    init(expenses: FetchedResults<Expense>, selectedDate: Date) {
        self.expenses = expenses
        self.selectedDate = selectedDate
        
        // Set up budget fetch request predicate
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )
        
        _currentMonthBudget = FetchRequest(
            entity: Budget.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)],
            predicate: predicate
        )
    }
    
    // MARK: - View Components
    @ViewBuilder
    private func titleText(_ info: BudgetInfo?) -> some View {
        Text(info == nil ? "Spent so far in \(formattedMonth)" : "Total remaining for \(formattedMonth)")
            .font(.system(size: 17, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func amountText(_ info: BudgetInfo?) -> some View {
        let amount = info?.remaining ?? totalSpent
        let color: Color = amount < 0 ? .red : .primary
        
        if let defaultCurrency = currencyManager.defaultCurrency {
            let formattedText = amount < 0
                ? "-" + currencyManager.currencyConverter.formatAmount(abs(amount), currency: defaultCurrency)
                : currencyManager.currencyConverter.formatAmount(amount, currency: defaultCurrency)
            
            Text(formattedText)
                .font(.system(size: 52, design: .rounded))
                .fontWeight(.regular)
                .foregroundColor(color)
                // Only animate when necessary
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.95), value: amount)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
        }
    }
    
    
    @ViewBuilder
    private func expenseCount() -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Use lazy filtering and calculation
        let todayExpenses = expenses.lazy.filter {
            guard let expenseDate = $0.date else { return false }
            return calendar.startOfDay(for: expenseDate) == today
        }
        
        let yesterdayExpenses = expenses.lazy.filter {
            guard let expenseDate = $0.date else { return false }
            return calendar.startOfDay(for: expenseDate) == yesterday
        }
        
        // Calculate totals once
        let todayTotal = todayExpenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
        
        let yesterdayTotal = yesterdayExpenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
        
        if todayTotal != 0 || yesterdayTotal != 0 {
            let difference = todayTotal - yesterdayTotal
            let isHigher = difference > 0
            
            HStack(spacing: 4) {
                Image(systemName: isHigher ? "arrow.up.forward.circle.fill" : "arrow.down.backward.circle.fill")
                    .foregroundColor(isHigher ? .gray : .gray)
                if let defaultCurrency = currencyManager.defaultCurrency {
                    Text(currencyManager.currencyConverter.formatAmount(abs(difference), currency: defaultCurrency))
                        .foregroundColor(.secondary)
                    Text("today")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Body
    var body: some View {
        let info = budgetInfo
        
        VStack(spacing: 4) {
            titleText(info)
            amountText(info)
                .frame(maxWidth: .infinity, alignment: .center)
            expenseCount()
        }
        .padding(.vertical)
        .onAppear {
            // Calculate total once on appear
            updateTotalSpent()
        }
        .onChange(of: expenses.count) { _, _ in
            // Recalculate only when expense count changes
            updateTotalSpent()
        }
    }
    
    // Update the cached total spent value
    private func updateTotalSpent() {
        // Calculate total directly using reduce for better performance
        cachedTotalSpent = expenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
    }
}

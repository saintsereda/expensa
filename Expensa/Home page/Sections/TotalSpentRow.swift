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
    
    var formattedOverspent: String {
        CurrencyConverter.shared.formatAmount(abs(remaining), currency: currency)
    }
    
    var isOverspent: Bool {
        remaining < 0
    }
}

struct TotalSpentRow: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // Accept FetchedResults instead of array
    let expenses: FetchedResults<Expense>
    let selectedDate: Date
    
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
        // Add extensive logging
        print("🔍 Attempting to get budget")
        print("Budget count: \(currentMonthBudget.count)")
        
        guard let budget = currentMonthBudget.first,
              let amount = budget.amount?.decimalValue,
              let currency = currencyManager.defaultCurrency else {
            print("❌ Budget retrieval failed:")
            print("  - Budget exists: \(currentMonthBudget.count > 0)")
            print("  - Default Currency: \(currencyManager.defaultCurrency.debugDescription)")
            return nil
        }
        
        let remaining = amount - totalSpent
        print("✅ Budget found:")
        print("  - Amount: \(amount)")
        print("  - Remaining: \(remaining)")
        
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
        
        let calendar = Calendar.current
        
        // Print out detailed date information
        print("🔍 Selected Date Details:")
        print("Original Date: \(selectedDate)")
        print("Year: \(calendar.component(.year, from: selectedDate))")
        print("Month: \(calendar.component(.month, from: selectedDate))")
        print("Day: \(calendar.component(.day, from: selectedDate))")
        
        // Check how the date components are extracted
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        
        print("🕒 Date Components:")
        print("Components Year: \(components.year ?? -1)")
        print("Components Month: \(components.month ?? -1)")
        
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            // Fallback predicate
            _currentMonthBudget = FetchRequest(
                entity: Budget.entity(),
                sortDescriptors: [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)],
                predicate: NSPredicate(value: false)
            )
            return
        }
        
        print("🕒 Calculated Dates:")
        print("Start of Month: \(startOfMonth)")
        print("End of Month: \(endOfMonth)")
        
        // Set end of month to 23:59:59
        let endOfMonthWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth
        
        let predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startOfMonth as NSDate,
            endOfMonthWithTime as NSDate
        )
        
        _currentMonthBudget = FetchRequest(
            entity: Budget.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)],
            predicate: predicate
        )
    }
    
    // MARK: - View Components
    @ViewBuilder
    private func titleText() -> some View {
        Text("Spent in \(formattedMonth)")
            .font(.system(size: 17, weight: .regular, design: .rounded))
            .foregroundColor(.white)
            .opacity(0.64)
    }
    
    @ViewBuilder
    private func amountText() -> some View {
        if let defaultCurrency = currencyManager.defaultCurrency {
            let formattedText = currencyManager.currencyConverter.formatAmount(totalSpent, currency: defaultCurrency)
            
            Text(formattedText)
                .font(.system(size: 52, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.95), value: totalSpent)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func budgetStatusText() -> some View {
        if let info = budgetInfo {
            HStack(spacing: 12) {
                if info.isOverspent {
                    Text("👎🏻 Budget overspent by \(info.formattedOverspent)")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.64))
                } else {
                    Text("👍🏻 Budget on track")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.64))
                    
                    Divider()
                        .frame(width: 1, height: 20)
                        .background(Color.white.opacity(0.4))
                    
                    Text("💰 \(info.formattedRemaining) left")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.64))
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 4) {
            titleText()
            amountText()
                .frame(maxWidth: .infinity, alignment: .center)
                
            budgetStatusText()
        }
        .onAppear {
            updateTotalSpent()
            // Add notification observer for currency changes
            NotificationCenter.default.addObserver(
                forName: Notification.Name("DefaultCurrencyChanged"),
                object: nil,
                queue: .main
            ) { _ in
                updateTotalSpent()
            }
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

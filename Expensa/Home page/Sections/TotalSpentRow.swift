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

private struct OverspentCategoryInfo {
    let name: String
    let amount: Decimal
    let budgetAmount: Decimal
    let overAmount: Decimal
    let currency: Currency
    
    var formattedOverAmount: String {
        CurrencyConverter.shared.formatAmount(overAmount, currency: currency)
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
    
    // Store overspent categories information
    @State private var overspentCategories: [OverspentCategoryInfo] = []
    
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
    
    @ViewBuilder
    private func budgetProgressCard() -> some View {
        if let info = budgetInfo {
            VStack(alignment: .leading, spacing: 12) {
                // Budget status text with three cases
                VStack(alignment: .leading, spacing: 4) {
                    if info.isOverspent {
                        // Case 3: Budget is overspent
                        Text("🙈 Budget overspent")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                        Text("You're \(info.formattedOverspent) over your monthly budget")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white)
                    } else if !overspentCategories.isEmpty {
                        // Case 2: Budget on track but categories are overspent
                        Text("👌🏻 Budget still on track")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                        
                        if overspentCategories.count == 1 {
                            Text("You've overspent \"\(overspentCategories[0].name)\" category")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white)
                        } else {
                            let firstCategory = overspentCategories[0]
                            let remainingCount = overspentCategories.count - 1
                            
                            Text("You've overspent \"\(firstCategory.name)\" and \(remainingCount) \(remainingCount == 1 ? "category" : "categories")")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white)
                        }
                    } else {
                        // Case 1: Budget on track, no categories overspent
                        Text("👌🏻 Budget on track")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                // Progress bar
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((info.isOverspent ? Color(hex: "FF9090").opacity(0.16) : Color.white.opacity(0.12)), lineWidth: 1)
                        .frame(height: 44)
                    
                    // Fill
                    let percentage = min(1.0, Double(truncating: (totalSpent / info.amount) as NSDecimalNumber))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(info.isOverspent ? Color(hex: "FF9090").opacity(0.16) : Color.white.opacity(0.16))
                        .frame(width: max(0, CGFloat(percentage) * (UIScreen.main.bounds.width - 54)), height: 44)
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: percentage)
                    
                    // Text overlay showing remaining / total
                    HStack {
                        // Remaining amount on the left
                        Text(info.isOverspent
                            ? "\(info.formattedOverspent) over"
                            : "\(info.formattedRemaining) left")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.leading, 12)
                        
                        Spacer()
                        
                        // "of total" on the right
                        Text("of \(info.formattedTotal)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.trailing, 12)
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .padding(.top, 12)
        }
    }
    
    @ViewBuilder
    private func overspentCategoriesText() -> some View {
        if !overspentCategories.isEmpty {
            VStack(alignment: .center, spacing: 4) {
                if overspentCategories.count == 1 {
                    // Single category overspent
                    let category = overspentCategories[0]
                    Text("You've overspent \"\(category.name)\"")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.64))
                        .multilineTextAlignment(.center)
                } else {
                    // Multiple categories overspent
                    let firstCategory = overspentCategories[0]
                    let remainingCount = overspentCategories.count - 1
                    
                    Text("You've overspent \"\(firstCategory.name)\" and \(remainingCount) \(remainingCount == 1 ? "category" : "categories")")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.64))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 6)
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 4) {
            titleText()
            amountText()
                .frame(maxWidth: .infinity, alignment: .center)
                
        //    budgetStatusText()
            
            budgetProgressCard()
            
            // Add the category overspent warning
          //  overspentCategoriesText()
        }
        .onAppear {
            updateTotalSpent()
            checkOverspentCategories()
            
            // Add notification observer for currency changes
            NotificationCenter.default.addObserver(
                forName: Notification.Name("DefaultCurrencyChanged"),
                object: nil,
                queue: .main
            ) { _ in
                updateTotalSpent()
                checkOverspentCategories()
            }
            
            // Listen for budget updates
            NotificationCenter.default.addObserver(
                forName: Notification.Name("BudgetUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                checkOverspentCategories()
            }
        }
        .onChange(of: expenses.count) { _, _ in
            // Recalculate only when expense count changes
            updateTotalSpent()
            checkOverspentCategories()
        }
        .onChange(of: currentMonthBudget.count) { _, _ in
            // Recalculate when budget changes
            checkOverspentCategories()
        }
    }
    
    // Update the cached total spent value
    private func updateTotalSpent() {
        // Calculate total directly using reduce for better performance
        cachedTotalSpent = expenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
    }
    
    // Check for overspent categories
    private func checkOverspentCategories() {
        guard let budget = currentMonthBudget.first,
              let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget>,
              !categoryBudgets.isEmpty,
              let defaultCurrency = currencyManager.defaultCurrency else {
            overspentCategories = []
            return
        }
        
        let budgetManager = BudgetManager.shared
        let expenseManager = ExpenseDataManager.shared
        let allBudgetExpenses = budgetManager.expensesForBudget(budget)
        
        var overspentInfo: [OverspentCategoryInfo] = []
        
        for categoryBudget in categoryBudgets {
            guard let category = categoryBudget.category,
                  let categoryName = category.name,
                  let budgetAmount = categoryBudget.budgetAmount?.decimalValue else {
                continue
            }
            
            let spent = expenseManager.calculateCategoryAmount(
                for: allBudgetExpenses,
                category: categoryName
            )
            
            // Check if overspent
            if spent > budgetAmount {
                overspentInfo.append(OverspentCategoryInfo(
                    name: categoryName,
                    amount: spent,
                    budgetAmount: budgetAmount,
                    overAmount: spent - budgetAmount,
                    currency: categoryBudget.budgetCurrency ?? defaultCurrency
                ))
            }
        }
        
        // Sort categories by the amount overspent (descending)
        overspentCategories = overspentInfo.sorted { $0.overAmount > $1.overAmount }
    }
}

//
//  BudgetProgressCard.swift
//  Expensa
//
//  Created on 06.05.2025.
//

import SwiftUI
import CoreData

struct BudgetInfo {
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

struct OverspentCategoryInfo {
    let name: String
    let amount: Decimal
    let budgetAmount: Decimal
    let overAmount: Decimal
    let currency: Currency
    
    var formattedOverAmount: String {
        CurrencyConverter.shared.formatAmount(overAmount, currency: currency)
    }
}

struct BudgetProgressCard: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    let expenses: FetchedResults<Expense>
    let budget: Budget?
    let totalSpent: Decimal
    
    // Store overspent categories information
    @State private var overspentCategories: [OverspentCategoryInfo] = []
    
    // MARK: - Budget Info
    private var budgetInfo: BudgetInfo? {
        guard let budget = budget,
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
    
    var body: some View {
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
            .onAppear {
                checkOverspentCategories()
                
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
                checkOverspentCategories()
            }
        }
    }
    
    // Check for overspent categories
    private func checkOverspentCategories() {
        guard let budget = budget,
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

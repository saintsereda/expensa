//
//  BudgetWarningMessages.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.11.2024.
//

import Foundation
import SwiftUI
import CoreData

enum BudgetWarningType {
    case approaching // 80-99% of limit
    case exceeding  // 100%+ of limit
}

struct BudgetWarningMessage {
    let type: BudgetWarningType
    let message: String
    let emoji: String
}

struct CategoryBudgetMessages {
    static func getMessage(amount: Decimal, limit: Decimal, remaining: Decimal, over: Decimal, currency: Currency?) -> BudgetWarningMessage {
        let percentage = (amount / limit) * 100
        guard let currency = currency else { return BudgetWarningMessage(type: .approaching, message: "", emoji: "") }
        
        let converter = CurrencyConverter.shared
        
        if percentage >= 100 {
            return BudgetWarningMessage(
                type: .exceeding,
                message: "Over budget by \(converter.formatAmount(over, currency: currency))",
                emoji: "📊"
            )
        } else {
            return BudgetWarningMessage(
                type: .approaching,
                message: "\(converter.formatAmount(remaining, currency: currency)) left in budget",
                emoji: "📈"
            )
        }
    }
}

class BudgetWarningHelper {
    static func checkBudgetWarning(
        for category: Category,
        amount: Decimal,
        context: NSManagedObjectContext
    ) async -> (message: String, emoji: String)? {
        let currentDate = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentDate)
        
        let fetchRequest: NSFetchRequest<CategoryBudget> = CategoryBudget.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "category == %@ AND year == %d AND month == %d",
            category,
            Int16(components.year ?? 0),
            Int16(components.month ?? 0)
        )
        
        do {
            // Try to get monthly budget first
            let categoryBudgets = try context.fetch(fetchRequest)
            if let categoryBudget = categoryBudgets.first,
               let budgetAmount = categoryBudget.budgetAmount?.decimalValue {
                return checkWarningMessage(
                    for: category,
                    amount: amount,
                    limit: budgetAmount,
                    currency: categoryBudget.budgetCurrency
                )
            }
            
            // Fallback to category's general budget limit
            if let budgetLimit = category.budgetLimit?.decimalValue,
               budgetLimit > 0 {
                // For general limit, use default currency
                let currency = try? context.fetch(Currency.fetchRequest()).first { $0.code == "USD" }
                return checkWarningMessage(
                    for: category,
                    amount: amount,
                    limit: budgetLimit,
                    currency: currency
                )
            }
        } catch {
            print("Error fetching category budget: \(error)")
        }
        
        return nil
    }
    
    private static func checkWarningMessage(
        for category: Category,
        amount: Decimal,
        limit: Decimal,
        currency: Currency?
    ) -> (message: String, emoji: String)? {
        let percentage = (amount / limit) * 100
        
        // Only show message if we're at least at 80% of budget
        guard percentage >= 80 else { return nil }
        
        let remaining = limit - amount
        let over = amount - limit
        
        let message = CategoryBudgetMessages.getMessage(
            amount: amount,
            limit: limit,
            remaining: remaining > 0 ? remaining : 0,
            over: over > 0 ? over : 0,
            currency: currency
        )
        
        return (message.message, message.emoji)
    }
}

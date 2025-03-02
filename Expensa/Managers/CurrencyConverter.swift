//
//  CurrencyConverter.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//
import SwiftUI
import CoreData
import Foundation
import Combine

class CurrencyConverter {
    static let shared = CurrencyConverter()
    private let rateManager: HistoricalRateManager
    
    @Published private(set) var isConverting = false
    
    init(rateManager: HistoricalRateManager = .shared) {
        self.rateManager = rateManager
    }
    
    func convertAmount(
        _ amount: Decimal,
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        on date: Date? = nil
    ) -> (amount: Decimal, formatted: String)? {
        guard let sourceCode = sourceCurrency.code,
              let targetCode = targetCurrency.code else {
            print("❌ Missing currency codes")
            return nil
        }
        
        if sourceCode == targetCode {
            let formatted = formatAmount(amount, currency: targetCurrency)
            return (amount, formatted)
        }
        
        let date = date ?? Date()
        guard let sourceRate = rateManager.getRate(for: sourceCode, on: date),
              let targetRate = rateManager.getRate(for: targetCode, on: date) else {
            print("❌ Missing rates for \(sourceCode) or \(targetCode)")
            return nil
        }
        
        let amountInUSD = amount / sourceRate
        let finalAmount = amountInUSD * targetRate
        let formatted = formatAmount(finalAmount, currency: targetCurrency)
        
        return (finalAmount, formatted)
    }
    
    @MainActor
    func performBatchConversion(from oldCurrency: Currency, to newCurrency: Currency) async throws {
        guard !isConverting else { return }
        isConverting = true
        defer { isConverting = false }
        
        let context = CoreDataStack.shared.context
        print("\n🔄 Starting batch currency conversion")
        
        // 1. Fetch all required data at once
        async let expenses = context.perform {
            try? context.fetch(Expense.fetchRequest())
        }
        async let budgets = context.perform {
            try? context.fetch(Budget.fetchRequest())
        }
        async let recurringExpenses = context.perform {
            try? context.fetch(RecurringExpense.fetchRequest())
        }
        
        let (fetchedExpenses, fetchedBudgets, fetchedRecurringExpenses) = await (expenses ?? [], budgets ?? [], recurringExpenses ?? [])
        
        // 2. Prepare batch updates
        var updates: [() -> Void] = []
        
        // Process expenses
        for expense in fetchedExpenses {
            guard let date = expense.date,
                  let amount = expense.amount?.decimalValue,
                  let sourceCurrency = CurrencyManager.shared.fetchCurrency(withCode: expense.currency ?? "") else {
                continue
            }
            
            if let (convertedAmount, _) = convertAmount(
                amount,
                from: sourceCurrency,
                to: newCurrency,
                on: date
            ) {
                updates.append {
                    expense.convertedAmount = NSDecimalNumber(decimal: convertedAmount)
                }
            }
        }
        
        // Process budgets and their categories
        for budget in fetchedBudgets where budget.budgetCurrency == oldCurrency {
            guard let date = budget.startDate,
                  let amount = budget.amount?.decimalValue else {
                continue
            }
            
            if let (convertedAmount, _) = convertAmount(
                amount,
                from: oldCurrency,
                to: newCurrency,
                on: date
            ) {
                updates.append {
                    budget.amount = NSDecimalNumber(decimal: convertedAmount)
                    budget.budgetCurrency = newCurrency
                    
                    // Convert category budgets
                    if let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> {
                        for categoryBudget in categoryBudgets {
                            if let catAmount = categoryBudget.budgetAmount?.decimalValue,
                               let (catConvertedAmount, _) = self.convertAmount(
                                catAmount,
                                from: oldCurrency,
                                to: newCurrency,
                                on: date
                               ) {
                                categoryBudget.budgetAmount = NSDecimalNumber(decimal: catConvertedAmount)
                                categoryBudget.budgetCurrency = newCurrency
                            }
                        }
                    }
                }
            }
        }
        
        // Process recurring expenses (new code)
        for recurringExpense in fetchedRecurringExpenses {
            // Get either the nextDueDate or today's date if it's nil
            let date = recurringExpense.nextDueDate ?? Date()
            
            guard let amount = recurringExpense.amount?.decimalValue,
                  let currencyCode = recurringExpense.currency,
                  let sourceCurrency = CurrencyManager.shared.fetchCurrency(withCode: currencyCode) else {
                continue
            }
            
            // Only process if the currency matches the old default or we need to update the converted amount
            if currencyCode != newCurrency.code {
                if let (convertedAmount, _) = convertAmount(
                    amount,
                    from: sourceCurrency,
                    to: newCurrency,
                    on: date
                ) {
                    updates.append {
                        recurringExpense.convertedAmount = NSDecimalNumber(decimal: convertedAmount)
                    }
                }
            }
        }
        
        // 3. Execute all updates in a single context save
        if !updates.isEmpty {
            await context.perform {
                for update in updates {
                    update()
                }
                try? context.save()
            }
        }
        
        print("✅ Batch conversion completed")
    }
    
    // Batch conversion configuration
    struct BatchConversionConfig<T> {
        let getDate: (T) -> Date?
        let getAmount: (T) -> Decimal?
        let getCurrentCurrency: (T) -> Currency?
        let updateAmount: (T, Decimal) -> Void
    }
    
    struct BatchConversionResult {
        let successCount: Int
        let failureCount: Int
    }
    
    func formatAmount(_ amount: Decimal, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = " "
        
        guard let amountString = formatter.string(from: amount as NSDecimalNumber) else {
            return "\(amount)"
        }
        
        let symbol = currency.symbol ?? currency.code ?? ""
        let isUSD = currency.code == "USD"
        
        return isUSD ? "\(symbol)\(amountString)" : "\(amountString) \(symbol)"
    }
}

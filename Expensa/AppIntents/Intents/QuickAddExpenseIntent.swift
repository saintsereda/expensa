//
//  QuickAddExpenseIntent.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.11.2024.
//

import Foundation
import AppIntents
import SwiftUI
import CoreData

@available(iOS 16.0, *)
public struct QuickAddExpenseIntent: AppIntent {
    public static var title: LocalizedStringResource = "Add Expense"
    
    public static var description = IntentDescription("Quickly add an expense to Expensa.")
    
    @Parameter(
        title: "Amount",
        description: "Enter the expense amount",
        requestValueDialog: IntentDialog("How much did you spend?")
    )
    public var amount: Double
    
    @Parameter(
        title: "Category",
        description: "Select an expense category",
        requestValueDialog: IntentDialog("What category does this expense belong to?")
    )
    public var categoryId: CategoryEntity
    
    public init() {}
    
    public static var parameterSummary: some ParameterSummary {
        Summary("Add an expense of \(\.$amount) in \(\.$categoryId)") {
            \.$amount
            \.$categoryId
        }
    }
    
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Validate and fetch the category
        guard let uuid = UUID(uuidString: categoryId.id),
              let category = CategoryManager.shared.fetchCategory(withId: uuid) else {
            throw IntentError.categoryNotFound
        }
        
        // Get the default currency from CurrencyManager
        guard let defaultCurrency = CurrencyManager.shared.defaultCurrency else {
            throw IntentError.currencyNotFound
        }
        
        // Format amount with currency for the dialog
        let formattedAmount = formatAmount(Decimal(amount), currency: defaultCurrency)
        
        // Add the expense
        let success = await ExpenseDataManager.shared.addExpense(
            amount: Decimal(amount),
            category: category,
            date: Date(),
            notes: nil,
            currency: defaultCurrency,
            tags: []
        )
        
        if success {
            return await .result(
                dialog: IntentDialog("Added expense: \(formattedAmount)"),
                view: SuccessView()
            )
        } else {
            throw IntentError.failedToCreateExpense
        }
    }
    
    // Helper function to format amount with currency
    private func formatAmount(_ amount: Decimal, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currency.symbol
        
        // Use the currency code to determine locale
        if let currencyCode = currency.code {
            // Try to find a locale that uses this currency
            let locales = Locale.availableIdentifiers.map { Locale(identifier: $0) }
            if let locale = locales.first(where: { $0.currency?.identifier == currencyCode }) {
                formatter.locale = locale
            }
        }
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currency.symbol ?? "")\(amount)"
    }
}

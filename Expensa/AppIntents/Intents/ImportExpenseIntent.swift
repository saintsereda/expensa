////
////  ImportExpenseIntent.swift
////  Expensa
////
////  Created by Andrew Sereda on 11.11.2024.
////
//
//import Foundation
//import AppIntents
//import CoreData
//
//@available(iOS 16.0, *)
//public struct ImportExpenseIntent: AppIntent {
//    public static var title: LocalizedStringResource = "Import expense"
//
//    @Parameter(
//        title: "Transaction",
//        description: "Transaction amount with currency"
//    )
//    public var transactionInput: String
//
//    @Parameter(
//        title: "Category",
//        description: "Select expense category"
//    )
//    public var categoryId: CategoryEntity?
//
//    @Parameter(
//        title: "Merchant",
//        description: "Merchant name"
//    )
//    public var merchantInput: String?
//
//    public init() {
//        self.transactionInput = ""
//        self.categoryId = nil
//        self.merchantInput = nil
//    }
//
//    public static var parameterSummary: some ParameterSummary {
//        Summary("Import \(\.$transactionInput) with \(\.$categoryId)") {
//            \.$merchantInput
//        }
//    }
//
//    private func parseTransaction() throws -> Decimal {
//        print("📱 Raw transaction input: \(transactionInput)")
//        print("📱 Merchant input: \(merchantInput ?? "none")")
//
//        // Handle empty or whitespace-only input
//        guard !transactionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
//            print("📱 Empty input")
//            throw IntentError.invalidTransactionFormat
//        }
//
//        let components = transactionInput.split(separator: " ")
//        guard let amountStr = components.first else {
//            throw IntentError.invalidTransactionFormat
//        }
//
//        let normalizedAmount = String(amountStr).replacingOccurrences(of: ",", with: ".")
//        print("📱 Normalized amount: \(normalizedAmount)")
//
//        guard let amount = Decimal(string: normalizedAmount) else {
//            throw IntentError.invalidTransactionFormat
//        }
//
//        return amount
//    }
//
//    public func perform() async throws -> some IntentResult {
//        let amount = try parseTransaction()
//
//        // Get category or use "No Category"
//        let category: Category
//        if let selectedCategory = categoryId,
//           let uuid = UUID(uuidString: selectedCategory.id),
//           let foundCategory = CategoryManager.shared.fetchCategory(withId: uuid) {
//            category = foundCategory
//        } else {
//            if let noCategory = CategoryManager.shared.getNoCategoryCategory() {
//                category = noCategory
//            } else {
//                throw IntentError.categoryNotFound
//            }
//        }
//
//        guard let currency = CurrencyManager.shared.defaultCurrency else {
//            throw IntentError.currencyNotFound
//        }
//
//        let success = await ExpenseDataManager.shared.addExpense(
//            amount: amount,
//            category: category,
//            date: Date(),
//            notes: merchantInput,  // Use separate merchant input
//            currency: currency,
//            tags: []
//        )
//
//        if success {
//            return .result()
//        } else {
//            throw IntentError.failedToCreateExpense
//        }
//    }
//}
//
//  ImportExpenseIntent.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.11.2024.
//

import Foundation
import AppIntents
import CoreData

@available(iOS 16.0, *)
public struct ImportExpenseIntent: AppIntent {
    public static var title: LocalizedStringResource = "Import expense"
    
    @Parameter(
        title: "Transaction",
        description: "Transaction amount with currency"
    )
    public var transactionInput: String
    
    @Parameter(
        title: "Category",
        description: "Select expense category"
    )
    public var categoryId: CategoryEntity?
    
    @Parameter(
        title: "Merchant",
        description: "Merchant name"
    )
    public var merchantInput: String?
    
    public init() {
        self.transactionInput = ""
        self.categoryId = nil
        self.merchantInput = nil
    }
    
    public static var parameterSummary: some ParameterSummary {
        Summary("Import \(\.$transactionInput) with \(\.$categoryId)") {
            \.$merchantInput
        }
    }
    
    private func parseTransaction() throws -> Decimal {
        print("📱 Raw transaction input: \(transactionInput)")
        print("📱 Merchant input: \(merchantInput ?? "none")")
        
        // Handle empty or whitespace-only input
        guard !transactionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("📱 Empty input")
            throw IntentError.invalidTransactionFormat
        }
        
        let components = transactionInput.split(separator: " ")
        guard let amountStr = components.first else {
            throw IntentError.invalidTransactionFormat
        }
        
        let normalizedAmount = String(amountStr).replacingOccurrences(of: ",", with: ".")
        print("📱 Normalized amount: \(normalizedAmount)")
        
        guard let amount = Decimal(string: normalizedAmount) else {
            throw IntentError.invalidTransactionFormat
        }
        
        return amount
    }
    
    public func perform() async throws -> some IntentResult {
        let amount = try parseTransaction()
        
        // Get category if provided, otherwise leave as nil
        var category: Category? = nil
        if let selectedCategory = categoryId,
           let uuid = UUID(uuidString: selectedCategory.id),
           let foundCategory = CategoryManager.shared.fetchCategory(withId: uuid) {
            category = foundCategory
        }
        // We intentionally leave category as nil if none is provided
        
        guard let currency = CurrencyManager.shared.defaultCurrency else {
            throw IntentError.currencyNotFound
        }
        
        let success = await ExpenseDataManager.shared.addExpense(
            amount: amount,
            category: category,  // This can be nil now
            date: Date(),
            notes: merchantInput,
            currency: currency,
            tags: []
        )
        
        if success {
            return .result()
        } else {
            throw IntentError.failedToCreateExpense
        }
    }
}

//
//  QuickAddExpenseIntent.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.11.2024.
//  Updated on 16.05.2025.
//

import Foundation
import AppIntents
import SwiftUI
import CoreData

@available(iOS 16.0, *)
public struct CurrencyEntity: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    public static var defaultQuery = CurrencyQuery()
    
    public let id: String
    public let displayString: String
    public let code: String
    public let symbol: String
    
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)"
        )
    }
    
    public init(id: String, code: String, symbol: String, displayString: String) {
        self.id = id
        self.code = code
        self.symbol = symbol
        self.displayString = displayString
    }
}

@available(iOS 16.0, *)
public struct CurrencyQuery: EntityQuery {
    public init() {}
    
    public func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        return identifiers.compactMap { id in
            guard let uuid = UUID(uuidString: id),
                  let fetchRequest: NSFetchRequest<Currency> = Currency.fetchRequest() as? NSFetchRequest<Currency> else {
                return nil
            }
            
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            fetchRequest.fetchLimit = 1
            
            let context = CoreDataStack.shared.context
            guard let currency = try? context.fetch(fetchRequest).first else {
                return nil
            }
            
            return CurrencyEntity(
                id: id,
                code: currency.code ?? "USD",
                symbol: currency.symbol ?? "$",
                displayString: "\(currency.symbol ?? "$") \(currency.code ?? "USD")"
            )
        }
    }
    
    public func entities(matching string: String) async throws -> [CurrencyEntity] {
        let fetchRequest: NSFetchRequest<Currency> = Currency.fetchRequest()
        let searchTerm = string.lowercased()
        
        // Search by code, name, or symbol
        fetchRequest.predicate = NSPredicate(
            format: "code CONTAINS[cd] %@ OR name CONTAINS[cd] %@ OR symbol CONTAINS[cd] %@",
            searchTerm, searchTerm, searchTerm
        )
        
        // Sort by relevance - exact code matches first, then by code
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Currency.code, ascending: true)
        ]
        
        let context = CoreDataStack.shared.context
        do {
            let results = try context.fetch(fetchRequest)
            print("🔍 Search for '\(string)' found \(results.count) currencies")
            
            // Prioritize results where the code starts with the search string
            let prioritized = results.sorted { (currency1, currency2) -> Bool in
                let code1 = currency1.code?.lowercased() ?? ""
                let code2 = currency2.code?.lowercased() ?? ""
                
                // If one starts with the search term and the other doesn't, prioritize the one that does
                if code1.hasPrefix(searchTerm) && !code2.hasPrefix(searchTerm) {
                    return true
                }
                if !code1.hasPrefix(searchTerm) && code2.hasPrefix(searchTerm) {
                    return false
                }
                
                // Otherwise sort alphabetically
                return code1 < code2
            }
            
            return prioritized.compactMap { currency in
                guard let id = currency.id?.uuidString else { return nil }
                return CurrencyEntity(
                    id: id,
                    code: currency.code ?? "USD",
                    symbol: currency.symbol ?? "$",
                    displayString: "\(currency.symbol ?? "$") \(currency.code ?? "USD") - \(currency.name ?? "")"
                )
            }
        } catch {
            print("❌ Error searching currencies: \(error)")
            return []
        }
    }
    
    public func suggestedEntities() async -> [CurrencyEntity] {
        let fetchRequest: NSFetchRequest<Currency> = Currency.fetchRequest()
        
        // Add commonly used currencies first
        let commonCodes = ["USD", "EUR", "GBP", "JPY", "PLN", "UAH"]
        
        // Also include current default currency if not in the common list
        if let defaultCurrency = CurrencyManager.shared.defaultCurrency,
           let defaultCode = defaultCurrency.code,
           !commonCodes.contains(defaultCode) {
            fetchRequest.predicate = NSPredicate(
                format: "code IN %@ OR code == %@",
                commonCodes, defaultCode
            )
        } else {
            fetchRequest.predicate = NSPredicate(format: "code IN %@", commonCodes)
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Currency.code, ascending: true)]
        
        let context = CoreDataStack.shared.context
        
        do {
            let preferredCurrencies = try context.fetch(fetchRequest)
            
            // Highlight the default currency
            return preferredCurrencies.compactMap { currency in
                guard let id = currency.id?.uuidString else { return nil }
                
                let isDefault = currency.code == CurrencyManager.shared.defaultCurrency?.code
                let displayString: String
                
                if isDefault {
                    displayString = "\(currency.symbol ?? "$") \(currency.code ?? "USD") (Default)"
                } else {
                    displayString = "\(currency.symbol ?? "$") \(currency.code ?? "USD")"
                }
                
                return CurrencyEntity(
                    id: id,
                    code: currency.code ?? "USD",
                    symbol: currency.symbol ?? "$",
                    displayString: displayString
                )
            }
        } catch {
            print("Error fetching suggested currencies: \(error)")
            return []
        }
    }
}

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
        title: "Currency",
        description: "Select the currency",
        requestValueDialog: IntentDialog("Which currency was this expense in?")
    )
    public var currencyId: CurrencyEntity
    
    @Parameter(
        title: "Category",
        description: "Select an expense category",
        requestValueDialog: IntentDialog("What category does this expense belong to?")
    )
    public var categoryId: CategoryEntity
    
    @Parameter(
        title: "Notes",
        description: "Add optional notes for this expense",
        requestValueDialog: IntentDialog("Any notes for this expense?")
    )
    public var notes: String?
    
    public init() {}
    
    public static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) \(\.$currencyId) for \(\.$categoryId)") {
            \.$notes
        }
    }
    
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Validate and fetch the category
        guard let uuid = UUID(uuidString: categoryId.id),
              let category = CategoryManager.shared.fetchCategory(withId: uuid) else {
            throw IntentError.categoryNotFound
        }
        
        // Get the selected currency by code from CurrencyEntity
        print("🔍 Selected currency code from entity: \(currencyId.code)")
        
        // Fetch currency by CODE using CurrencyManager (not by ID)
        guard let currency = CurrencyManager.shared.fetchCurrency(withCode: currencyId.code) else {
            print("⚠️ Currency with code \(currencyId.code) not found, falling back to default")
            guard let defaultCurrency = CurrencyManager.shared.defaultCurrency else {
                throw IntentError.currencyNotFound
            }
            print("✅ Using default currency: \(defaultCurrency.code ?? "unknown")")
            return try await addExpenseWithCurrency(defaultCurrency, category: category)
        }
        
        print("✅ Found currency by code: \(currency.code ?? "unknown")")
        return try await addExpenseWithCurrency(currency, category: category)
    }
    
    private func addExpenseWithCurrency(_ currency: Currency, category: Category) async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Format amount with currency for the dialog
        let formattedAmount = formatAmount(Decimal(amount), currency: currency)
        print("💰 Adding expense: \(formattedAmount) with currency \(currency.code ?? "unknown")")
        
        // Add the expense - explicitly pass the currency object
        let success = await ExpenseDataManager.shared.addExpense(
            amount: Decimal(amount),
            category: category,
            date: Date(),
            notes: notes,
            currency: currency,
            tags: []
        )
        
        if success {
            print("✅ Expense added successfully with currency: \(currency.code ?? "unknown")")
            return .result(
                dialog: IntentDialog("Added expense: \(formattedAmount) in \(category.name ?? "category")"),
                view: SuccessView()
            )
        } else {
            print("❌ Failed to add expense")
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

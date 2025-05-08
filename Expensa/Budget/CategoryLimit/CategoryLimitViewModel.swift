//
//  CategoryLimitViewModel.swift
//  Expensa
//
//  Created on 08.05.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CategoryLimitViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var amount: String = ""
    @Published var errorMessage: String?
    @Published var showErrorAlert = false
    @Published var showDeleteAlert = false
    @Published var shakeAmount: CGFloat = 0
    @Published var lastEnteredDigit = ""
    
    // MARK: - Public Properties
    let category: Category
    
    // MARK: - Private Properties
    private let currencyManager = CurrencyManager.shared
    private let currencyConverter = CurrencyConverter.shared
    private var categoryLimitsBinding: Binding<[Category: String]>
    private var selectedCategoriesBinding: Binding<Set<Category>>
    
    // MARK: - Computed Properties
    var defaultCurrency: Currency? {
        currencyManager.defaultCurrency
    }
    
    var isValidInput: Bool {
        !amount.isEmpty && (parseAmount(amount) ?? 0) > 0
    }
    
    var formattedAmount: String {
        // Clean up amount to avoid double currency symbols
        let cleanedAmount = amount
            .replacingOccurrences(of: defaultCurrency?.symbol ?? "$", with: "")
            .trim()
        
        return KeypadInputHelpers.formatUserInput(cleanedAmount)
    }
    
    var hasExistingLimit: Bool {
        categoryLimitsBinding.wrappedValue[category] != nil
    }
    
    // MARK: - Initialization
    init(
        category: Category,
        categoryLimits: Binding<[Category: String]>,
        selectedCategories: Binding<Set<Category>>
    ) {
        self.category = category
        self.categoryLimitsBinding = categoryLimits
        self.selectedCategoriesBinding = selectedCategories
        
        // Pre-fill existing amount if any
        if let existingAmount = categoryLimits.wrappedValue[category] {
            self.amount = KeypadInputHelpers.cleanDisplayAmount(
                existingAmount,
                currencySymbol: currencyManager.defaultCurrency?.symbol
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// Handles number input from keypad
    func handleNumberInput(value: String) {
        KeypadInputHelpers.handleNumberInput(
            value: value,
            amount: &amount,
            lastEnteredDigit: &lastEnteredDigit,
            triggerShake: { self.triggerShake() }
        )
    }
    
    /// Handles backspace/delete from keypad
    func handleDelete() {
        KeypadInputHelpers.handleDelete(amount: &amount)
    }
    
    /// Saves the current limit value
    func saveLimit() -> Bool {
        if !amount.isEmpty {
            if let amountDecimal = parseAmount(amount) {
                let formattedLimit = formatAmount(amountDecimal)
                categoryLimitsBinding.wrappedValue[category] = formattedLimit
                return true
            } else {
                errorMessage = "Invalid amount"
                showErrorAlert = true
                return false
            }
        }
        return false
    }
    
    /// Removes the category and its limit
    func removeCategory() {
        // Remove both the limit and the category
        categoryLimitsBinding.wrappedValue.removeValue(forKey: category)
        selectedCategoriesBinding.wrappedValue.remove(category)
    }
    
    /// Triggers animation for invalid input
    func triggerShake() {
        withAnimation(.linear(duration: 0.3)) {
            shakeAmount = 1
        }
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.shakeAmount = 0
        }
    }
    
    // MARK: - Helper Methods
    
    /// Parses a formatted amount string to Decimal
    func parseAmount(_ formattedAmount: String) -> Decimal? {
        return KeypadInputHelpers.parseAmount(formattedAmount, currencySymbol: defaultCurrency?.symbol)
    }
    
    /// Formats a Decimal amount to a currency string
    func formatAmount(_ amount: Decimal) -> String {
        return currencyConverter.formatAmount(
            amount,
            currency: currencyManager.defaultCurrency ?? Currency()
        )
    }
}

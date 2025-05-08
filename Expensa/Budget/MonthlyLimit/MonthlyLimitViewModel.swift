//
//  MonthlyLimitViewModel.swift
//  Expensa
//
//  Created on 08.05.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MonthlyLimitViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var localAmount: String = ""
    @Published var errorMessage: String?
    @Published var showErrorAlert = false
    @Published var shakeAmount: CGFloat = 0
    @Published var lastEnteredDigit = ""
    
    // MARK: - Private Properties
    private let currencyManager = CurrencyManager.shared
    private let currencyConverter = CurrencyConverter.shared
    private var cancellables = Set<AnyCancellable>()
    private var amountBinding: Binding<String>
    
    // MARK: - Computed Properties
    var defaultCurrency: Currency? {
        currencyManager.defaultCurrency
    }
    
    var isValidInput: Bool {
        !localAmount.isEmpty && (parseAmount(localAmount) ?? 0) > 0
    }
    
    var formattedAmount: String {
        // Clean up amount to avoid double currency symbols
        let cleanedAmount = localAmount
            .replacingOccurrences(of: defaultCurrency?.symbol ?? "$", with: "")
            .trim()
        
        return KeypadInputHelpers.formatUserInput(cleanedAmount)
    }
    
    // MARK: - Initialization
    init(amountBinding: Binding<String>) {
        self.amountBinding = amountBinding
        
        // Pre-fill with existing amount
        if !amountBinding.wrappedValue.isEmpty {
            let symbol = currencyManager.defaultCurrency?.symbol ?? "$"
            self.localAmount = KeypadInputHelpers.cleanDisplayAmount(
                amountBinding.wrappedValue,
                currencySymbol: symbol
            )
        }
    }
    
    // MARK: - Public Methods
    func handleNumberInput(value: String) {
        KeypadInputHelpers.handleNumberInput(
            value: value,
            amount: &localAmount,
            lastEnteredDigit: &lastEnteredDigit,
            triggerShake: { self.triggerShake() }
        )
    }
    
    func handleDelete() {
        KeypadInputHelpers.handleDelete(amount: &localAmount)
    }
    
    func saveAmount() -> Bool {
        if !localAmount.isEmpty {
            if let amountDecimal = parseAmount(localAmount) {
                // Update the binding when save/continue is tapped
                amountBinding.wrappedValue = formatAmount(amountDecimal)
                return true
            } else {
                errorMessage = "Invalid amount"
                showErrorAlert = true
                return false
            }
        }
        return false
    }
    
    func cancelInput() {
        // Clear amount before dismissing
        localAmount = ""
        amountBinding.wrappedValue = ""
    }
    
    // Add a method that preserves the original amount when going back
    func preserveAmount() {
        // Just save the current amount without clearing
        if !localAmount.isEmpty {
            if let amountDecimal = parseAmount(localAmount) {
                amountBinding.wrappedValue = formatAmount(amountDecimal)
            }
        }
    }
    
    // MARK: - Helper Methods
    func parseAmount(_ formattedAmount: String) -> Decimal? {
        return KeypadInputHelpers.parseAmount(formattedAmount, currencySymbol: defaultCurrency?.symbol)
    }
    
    func formatAmount(_ amount: Decimal) -> String {
        return currencyConverter.formatAmount(
            amount,
            currency: currencyManager.defaultCurrency ?? Currency()
        )
    }
    
    func triggerShake() {
        withAnimation(.linear(duration: 0.3)) {
            shakeAmount = 1
        }
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.shakeAmount = 0
        }
    }
}

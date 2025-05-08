//
//  CategoryLimitSheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 18.03.2025.
//

import Foundation
import SwiftUI

struct CategoryLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category
    @Binding var categoryLimits: [Category: String]
    @Binding var selectedCategories: Set<Category>
    
    // State for numeric keypad
    @State private var amount: String = ""
    @State private var shakeAmount: CGFloat = 0
    @State private var lastEnteredDigit = ""
    @State private var showDeleteAlert = false
    
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    private let currencyConverter = CurrencyConverter.shared
    
    private var defaultCurrency: Currency? {
        currencyManager.defaultCurrency
    }
    
    private var formattedAmount: String {
        // Clean up amount to avoid double currency symbols
        var cleanedAmount = amount
            .replacingOccurrences(of: defaultCurrency?.symbol ?? "$", with: "")
            .trim()
        
        return KeypadInputHelpers.formatUserInput(cleanedAmount)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // Category Info
                VStack(spacing: 8) {
                    Text(category.icon ?? "🔹")
                        .font(.system(size: 48))
                    Text(category.name ?? "")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 16)
                
                // Instructions
                Text("Set monthly limit")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                
                // Amount display section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 0) {
                        if amount.isEmpty {
                            if let currency = defaultCurrency {
                                let symbol = currency.symbol ?? currency.code ?? ""
                                let isUSD = currency.code == "USD"
                                Text(isUSD ? "\(symbol)0" : "0 \(symbol)")
                                    .font(.system(size: 72, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(UIColor.systemGray2))
                                    .minimumScaleFactor(0.3)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 16)
                            }
                        } else {
                            if let currency = defaultCurrency {
                                let symbol = currency.symbol ?? currency.code ?? ""
                                let isUSD = currency.code == "USD"
                                
                                Text(isUSD ? "\(symbol)\(formattedAmount)" : "\(formattedAmount) \(symbol)")
                                    .font(.system(size: 72, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                    .contentTransition(.numericText())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .modifier(ShakeEffect(amount: 10, shakesPerUnit: 3, animatableData: shakeAmount))
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Numeric keypad
                NumericKeypad(
                    onNumberTap: { value in
                        // Use shared helper method
                        KeypadInputHelpers.handleNumberInput(
                            value: value,
                            amount: &amount,
                            lastEnteredDigit: &lastEnteredDigit,
                            triggerShake: triggerShake
                        )
                    },
                    onDelete: {
                        // Use shared helper method
                        KeypadInputHelpers.handleDelete(amount: &amount)
                    }
                )
                .padding(.bottom, 20)
                
                // Bottom actions
                HStack {
                    // Show delete button if this category already has a limit
                    if categoryLimits[category] != nil {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        }
                    } else {
                        // Add Cancel button for new limits
                        Button("Cancel") {
                            // If it's a new category with no limit, remove it from selected categories
                            if categoryLimits[category] == nil {
                                selectedCategories.remove(category)
                            }
                            dismiss()
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    
                    Spacer()
                    
                    // Change button text based on whether we're setting a new limit or updating
                    let buttonLabel = categoryLimits[category] == nil ? "Set limit" : "Update limit"
                    
                    SaveButton(
                        isEnabled: !amount.isEmpty,
                        label: buttonLabel,
                        action: saveLimit
                    )
                    .tint(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Category Limit")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Remove Category Budget", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    // Remove both the limit and the category
                    categoryLimits.removeValue(forKey: category)
                    selectedCategories.remove(category)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove the budget for \(category.name ?? "")?")
            }
            .onAppear {
                // Pre-fill existing amount if any
                if let existingAmount = categoryLimits[category] {
                    // Clean the amount before displaying it
                    amount = KeypadInputHelpers.cleanDisplayAmount(
                        existingAmount,
                        currencySymbol: currencyManager.defaultCurrency?.symbol
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func triggerShake() {
        withAnimation(.linear(duration: 0.3)) {
            shakeAmount = 1
        }
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeAmount = 0
        }
    }
    
    private func saveLimit() {
        if !amount.isEmpty {
            if let amountDecimal = KeypadInputHelpers.parseAmount(
                amount,
                currencySymbol: currencyManager.defaultCurrency?.symbol
            ) {
                categoryLimits[category] = currencyConverter.formatAmount(
                    amountDecimal,
                    currency: currencyManager.defaultCurrency ?? Currency()
                )
            }
        }
        dismiss()
    }
}

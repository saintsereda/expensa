//
//  MonthlyLimitView.swift
//  Expensa
//
//  Created by Andrew Sereda on 18.03.2025.
//

import SwiftUI
import Foundation

struct MonthlyLimitView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var amount: String
    
    // Local state for amount editing
    @State private var localAmount: String = ""
    @State private var shakeAmount: CGFloat = 0
    @State private var lastEnteredDigit = ""
    
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // Add callback for save action
    var onSave: (() -> Void)?
    
    private var defaultCurrency: Currency? {
        currencyManager.defaultCurrency
    }
    
    private var formattedAmount: String {
        // Use helper to format amount
        let cleanedAmount = localAmount
            .replacingOccurrences(of: defaultCurrency?.symbol ?? "$", with: "")
            .trim()
        
        return KeypadInputHelpers.formatUserInput(cleanedAmount)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instructions
                Text("Set monthly limit")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.top, 16)
                
                // Amount display section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 0) {
                        if localAmount.isEmpty {
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
                            amount: &localAmount,
                            lastEnteredDigit: &lastEnteredDigit,
                            triggerShake: triggerShake
                        )
                    },
                    onDelete: {
                        // Use shared helper method
                        KeypadInputHelpers.handleDelete(amount: &localAmount)
                    }
                )
                .padding(.bottom, 20)
                
                // Bottom action
                HStack {
                    Spacer()
                    SaveButton(isEnabled: true, label: "Set limit", action: saveAmount)
                        .tint(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Monthly Budget")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Pre-fill with existing amount
                if !amount.isEmpty {
                    let symbol = defaultCurrency?.symbol ?? "$"
                    // Use clean display helper
                    localAmount = KeypadInputHelpers.cleanDisplayAmount(amount, currencySymbol: symbol)
                }
            }
        }
    }
    
    // We only need to keep the triggerShake method locally since it references local state
    private func triggerShake() {
        withAnimation(.linear(duration: 0.3)) {
            shakeAmount = 1
        }
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeAmount = 0
        }
    }
    
    private func saveAmount() {
        // Only update the binding when save is explicitly tapped
        if !localAmount.isEmpty {
            amount = localAmount
        }
        
        // Call the onSave callback if provided
        onSave?()
        
        // Return to parent view
        dismiss()
    }
}

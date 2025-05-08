//
//  MonthlyLimitView.swift
//  Expensa
//
//  Created on 18.03.2025.
//  Updated on 08.05.2025.
//

import SwiftUI
import Foundation

struct MonthlyLimitView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MonthlyLimitViewModel
    
    // Add callback for save action
    var onSave: (() -> Void)?
    
    init(amount: Binding<String>, onSave: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: MonthlyLimitViewModel(amountBinding: amount))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title and instruction
                VStack(spacing: 12) {
                    // Emoji icon
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 64, height: 64)
                        
                        Text("🗓")
                            .font(.system(size: 32))
                    }
                    .padding(.top, 20)
                    
                    Text("Set monthly budget")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        
                    Text("Enter the total amount you want to budget for the month")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
                
                // Amount display section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 0) {
                        if viewModel.localAmount.isEmpty {
                            if let currency = viewModel.defaultCurrency {
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
                            if let currency = viewModel.defaultCurrency {
                                let symbol = currency.symbol ?? currency.code ?? ""
                                let isUSD = currency.code == "USD"
                                
                                Text(isUSD ? "\(symbol)\(viewModel.formattedAmount)" : "\(viewModel.formattedAmount) \(symbol)")
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
                    .modifier(ShakeEffect(amount: 10, shakesPerUnit: 3, animatableData: viewModel.shakeAmount))
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Numeric keypad
                NumericKeypad(
                    onNumberTap: { value in
                        viewModel.handleNumberInput(value: value)
                    },
                    onDelete: {
                        viewModel.handleDelete()
                    }
                )
                .padding(.bottom, 20)
                
                // Bottom action
                HStack {
                    // Cancel button
                    Button("Cancel") {
                        viewModel.cancelInput()
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    Spacer()
                    
                    SaveButton(
                        isEnabled: viewModel.isValidInput,
                        label: "Continue",
                        action: {
                            if viewModel.saveAmount() {
                                // Call the onSave callback if provided
                                onSave?()
                                // Return to parent view
                                dismiss()
                            }
                        }
                    )
                    .tint(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Monthly иudget")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled()
            .alert(isPresented: $viewModel.showErrorAlert) {
                Alert(
                    title: Text("Invalid фmount"),
                    message: Text(viewModel.errorMessage ?? "Please enter a valid amount"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

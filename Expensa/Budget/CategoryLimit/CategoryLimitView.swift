//
//  CategoryLimitSheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 18.03.2025.
//  Updated on 08.05.2025.
//

import Foundation
import SwiftUI

struct CategoryLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CategoryLimitViewModel
    
    init(
        category: Category,
        categoryLimits: Binding<[Category: String]>,
        selectedCategories: Binding<Set<Category>>,
        isNewCategory: Bool = false
    ) {
        _viewModel = StateObject(wrappedValue: CategoryLimitViewModel(
            category: category,
            categoryLimits: categoryLimits,
            selectedCategories: selectedCategories,
            isNewCategory: isNewCategory
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // Category Info
                VStack(spacing: 8) {
                    Text(viewModel.category.icon ?? "🔹")
                        .font(.system(size: 48))
                    Text(viewModel.category.name ?? "")
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
                        if viewModel.amount.isEmpty {
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
                
                // Bottom actions
                HStack {
                    // Show different button based on context
                    if viewModel.isNewCategory {
                        // Cancel button for new categories
                        Button("Cancel") {
                            // No need to add the category to selectedCategories since it's canceled
                            dismiss()
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    } else if viewModel.hasExistingLimit {
                        // Delete button for existing limits
                        Button(role: .destructive) {
                            viewModel.showDeleteAlert = true
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
                        // Cancel button for existing categories with no limit
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    
                    Spacer()
                    
                    // Determine button label based on context
                    let buttonLabel = viewModel.hasExistingLimit ? "Update limit" : "Set limit"
                    
                    SaveButton(
                        isEnabled: viewModel.isValidInput,
                        label: buttonLabel,
                        action: {
                            if viewModel.saveLimit() {
                                // Now the category will only be added to selectedCategories
                                // if the user taps Save and it's a new category (handled in viewModel.saveLimit())
                                dismiss()
                            }
                        }
                    )
                    .tint(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Category limit")
            .navigationBarTitleDisplayMode(.inline)
            // Replace alert with confirmationDialog
            .confirmationDialog(
                "Remove category budget",
                isPresented: $viewModel.showDeleteAlert,
                titleVisibility: .visible
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    viewModel.removeCategory()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove the budget for \(viewModel.category.name ?? "")?")
            }
            .alert(isPresented: $viewModel.showErrorAlert) {
                Alert(
                    title: Text("Invalid amount"),
                    message: Text(viewModel.errorMessage ?? "Please enter a valid amount"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

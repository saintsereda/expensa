//
//  BudgetForm.swift
//  Expensa
//
//  Created on 01.05.2025.
//

import Foundation
import CoreData
import SwiftUI

struct BudgetForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: BudgetFormViewModel
    @State private var isInNavigationFlow: Bool = false
    
    // Initialize for new budget
    init(initialAmount: String = "", isInNavigationFlow: Bool = false) {
        _viewModel = StateObject(wrappedValue: BudgetFormViewModel(initialAmount: initialAmount))
        self._isInNavigationFlow = State(initialValue: isInNavigationFlow)
    }
    
    // Initialize for editing
    init(budget: Budget, isInNavigationFlow: Bool = false) {
        _viewModel = StateObject(wrappedValue: BudgetFormViewModel(budget: budget))
        self._isInNavigationFlow = State(initialValue: isInNavigationFlow)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Monthly budget section
                    VStack(spacing: 16) {
                        if viewModel.amount.isEmpty {
                            // Show CardView when no budget is set
                            CardView(
                                emoji: "🗓",
                                title: "Limit for all expenses",
                                description: "Take control of your budget by setting a single spending limit for the entire month",
                                buttonTitle: "Set limit",
                                buttonAction: { viewModel.showMonthlyLimitView = true }
                            )
                        } else {
                            // Show BudgetSetCardView when budget is set
                            BudgetSetCardView(
                                emoji: "🗓",
                                amount: viewModel.formatAmount(viewModel.parseAmount(viewModel.amount) ?? 0),
                                action: { viewModel.showMonthlyLimitView = true }
                            )
                        }
                    }
                    
                    // Categories Section
                    VStack(spacing: 16) {
                        if viewModel.selectedCategories.isEmpty {
                            // Category Limits Card
                            CardView(
                                categoryIcons: true,
                                title: "Limits for specific categories",
                                description: "Customize your spending by setting individual limits for different categories",
                                buttonTitle: "Select categories",
                                buttonAction: { viewModel.showCategorySheet = true },
                                isDisabled: false
                            )
                        } else {
                            // Categories header
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Categories")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                // Simplified category limits stats
                                let stats = viewModel.formattedCategoryLimitStats()
                                let leftToAllocateText = viewModel.formatLeftToAllocate()
                                
                                CategoryLimitsStats(
                                    categoriesWithLimits: stats.withLimits,
                                    totalCategories: stats.total,
                                    leftToAllocateText: leftToAllocateText,
                                    showLeftToAllocate: leftToAllocateText != nil
                                )
                            }
                            .padding(.top, 8)
                            
                            // Category list
                            VStack(spacing: 8) {
                                ForEach(Array(viewModel.selectedCategories), id: \.self) { category in
                                    CategoryBudgetRow(
                                        category: category,
                                        limit: viewModel.categoryLimits[category],
                                        onSetLimit: {
                                            viewModel.selectedCategoryForLimit = category
                                        }
                                    )
                                }
                                
                                // Add SecondarySmallButton for adding more categories
                                SecondarySmallButton(
                                    isEnabled: true,
                                    label: "Adjust categories",
                                    action: { viewModel.showCategorySheet = true }
                                )
                                .padding(.top, 8)
                            }
                        }
                        
                        // Footer text
                        if viewModel.leftToAllocate != nil && viewModel.leftToAllocate! > 0 {
                            Text("Remaining amount will be allocated to \"Everything else\" category")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Note text at bottom
                    if !viewModel.isEditing {
                        Text("Note: Only one budget can be created per month")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 16)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle(viewModel.isEditing ? "Edit budget" : "Add budget")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.primary),
                trailing: Button("Save") {
                    Task {
                        await viewModel.validateAndSaveBudget()
                        dismiss()
                    }
                }
                .foregroundColor(.primary)
                .disabled(!viewModel.isValidInput)
            )
            .navigationBarBackButtonHidden(isInNavigationFlow)
            .navigationDestination(isPresented: $viewModel.showCategorySheet) {
                CategorySheet(selectedCategories: $viewModel.selectedCategories)
            }
            // Using navigationDestination instead of sheet for consistent experience
            .navigationDestination(item: $viewModel.selectedCategoryForLimit) { category in
                CategoryLimitSheet(
                    category: category,
                    categoryLimits: $viewModel.categoryLimits,
                    selectedCategories: $viewModel.selectedCategories
                )
            }
            .interactiveDismissDisabled()
            .disabled(viewModel.isProcessing)
            .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                switch viewModel.alertType {
                case .error:
                    Button("OK", role: .cancel) { }
                case .limitExceeded:
                    Button("Edit Limits", role: .cancel) { }
                    Button("Save Anyway") {
                        Task {
                            await viewModel.saveBudget()
                            dismiss()
                        }
                    }
                }
            }
            // Navigation destination to the monthly limit view
            .navigationDestination(isPresented: $viewModel.showMonthlyLimitView) {
                MonthlyLimitView(amount: $viewModel.amount)
            }
            .interactiveDismissDisabled()
        }
    }
}

// Simplified CategoryLimitsStats view to avoid type-checking issues
struct CategoryLimitsStats: View {
    let categoriesWithLimits: Int
    let totalCategories: Int
    let leftToAllocateText: String?
    let showLeftToAllocate: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            // Limits set statistics
            VStack(spacing: 4) {
                Text("Limits set")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(categoriesWithLimits)/\(totalCategories)")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            
            if showLeftToAllocate {
                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.2) : Color(UIColor.systemGray4))
                    .frame(height: 30)
                
                // Left to allocate section
                if let leftText = leftToAllocateText {
                    VStack(spacing: 4) {
                        Text("Left to allocate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(leftText)
                            .font(.body)
                            .foregroundColor(leftText.hasPrefix("-") ? .red : .primary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color(UIColor.systemGray4), lineWidth: 1)
        )
    }
}

struct CategoryBudgetRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let category: Category
    let limit: String?
    let onSetLimit: () -> Void
    
    var body: some View {
        Button(action: onSetLimit) {
            HStack {
                HStack(spacing: 12) {
                    // Category icon
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Text(category.icon ?? "🔹")
                            .font(.system(size: 20))
                    }
                    
                    // Category name
                    Text(category.name ?? "")
                        .foregroundColor(.primary)
                }
                Spacer()
                
                // Different UI based on whether limit is set
                if let limit = limit {
                    // Show limit value and chevron when limit is set
                    HStack(spacing: 8) {
                        Text(limit)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Show "Set limit" button when no limit is set
                    Text("Set limit")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            .padding(12)
            .frame(height: 72)
            .background(
                limit != nil
                ? (colorScheme == .dark ? Color(UIColor.systemGray5).opacity(0.5) : Color(UIColor.systemGray6))
                : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        limit != nil
                        ? Color.clear
                        : (colorScheme == .dark ? Color.white.opacity(0.2) : Color(UIColor.systemGray4)),
                        lineWidth: 1
                    )
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

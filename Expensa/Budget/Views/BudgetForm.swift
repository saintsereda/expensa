//
//  UpdatedBudgetForm.swift
//  Expensa
//
//  Created on 20.03.2025.
//

import Foundation
import CoreData
import SwiftUI

struct BudgetForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var amount: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .error
    @State private var isProcessing = false
    @State private var showCategorySheet = false
    @State private var selectedCategories: Set<Category> = []
    @State private var categoryLimits: [Category: String] = [:]
    @State private var selectedCategoryForLimit: Category?
    @State private var showMonthlyLimitView = false
    @State private var isInNavigationFlow: Bool = false
    
    private let budgetManager = BudgetManager.shared
    private let currencyManager = CurrencyManager.shared
    private let currencyConverter = CurrencyConverter.shared
    private let existingBudget: Budget?
    
    private enum AlertType {
        case error
        case limitExceeded
    }
    
    private var defaultCurrency: Currency? {
        currencyManager.defaultCurrency
    }
    
    private var isValidInput: Bool {
        // Allow empty amount if there are category budgets
        if amount.isEmpty {
            return !categoryLimits.isEmpty
        }
        
        // Otherwise check if amount is valid
        guard !isProcessing,
              let amountDecimal = KeypadInputHelpers.parseAmount(amount, currencySymbol: defaultCurrency?.symbol),
              amountDecimal > 0 else {
            return false
        }
        return true
    }
    
    // Initialize for new budget
    init(initialAmount: String = "", isInNavigationFlow: Bool = false) {
        self.existingBudget = nil
        self._amount = State(initialValue: initialAmount)
        self._isInNavigationFlow = State(initialValue: isInNavigationFlow)
    }
    
    // Initialize for editing with proper currency formatting
    init(budget: Budget) {
        self.existingBudget = budget
        
        // Format amount using CurrencyConverter
        let formattedAmount: String
        if let decimalAmount = budget.amount?.decimalValue,
           let currency = budget.budgetCurrency {
            formattedAmount = currencyConverter.formatAmount(decimalAmount, currency: currency)
        } else {
            formattedAmount = ""
        }
        
        self._amount = State(initialValue: formattedAmount)
        
        // Load existing category budgets if any
        if let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> {
            self._selectedCategories = State(initialValue: Set(categoryBudgets.compactMap { $0.category }))
            
            // Initialize category limits
            var limits: [Category: String] = [:]
            for categoryBudget in categoryBudgets {
                if let category = categoryBudget.category,
                   let amount = categoryBudget.budgetAmount?.decimalValue,
                   let currency = categoryBudget.budgetCurrency {
                    limits[category] = currencyConverter.formatAmount(amount, currency: currency)
                }
            }
            self._categoryLimits = State(initialValue: limits)
        }
    }
    
    private var allocatedAmount: Decimal {
        categoryLimits.values.compactMap { KeypadInputHelpers.parseAmount($0, currencySymbol: defaultCurrency?.symbol) }
        .reduce(0, +)
    }
    
    private var leftToAllocate: Decimal? {
        guard let totalBudget = KeypadInputHelpers.parseAmount(amount, currencySymbol: defaultCurrency?.symbol),
              totalBudget > 0 else {
            return nil
        }
        return totalBudget - allocatedAmount
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Monthly budget section
                    VStack(spacing: 16) {
                        if amount.isEmpty {
                            // Show CardView when no budget is set
                            CardView(
                                emoji: "🗓",
                                title: "Limit for all expenses",
                                description: "Take control of your budget by setting a single spending limit for the entire month",
                                buttonTitle: "Set limit",
                                buttonAction: { showMonthlyLimitView = true }
                            )
                        } else {
                            // Show BudgetSetCardView when budget is set
                            BudgetSetCardView(
                                emoji: "🗓",
                                amount: formatAmount(KeypadInputHelpers.parseAmount(amount, currencySymbol: defaultCurrency?.symbol) ?? 0),
                                action: { showMonthlyLimitView = true }
                            )
                        }
                    }
                    
                    // Categories Section
                    VStack(spacing: 16) {
                        if selectedCategories.isEmpty {
                            // Category Limits Card
                            CardView(
                                categoryIcons: true,
                                title: "Limits for specific categories",
                                description: "Customize your spending by setting individual limits for different categories",
                                buttonTitle: "Select categories",
                                buttonAction: { showCategorySheet = true },
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
                                
                                // Category limits stats with "Left to allocate"
                                CategoryLimitsStats(
                                    categoriesWithLimits: categoryLimits.count,
                                    totalCategories: selectedCategories.count,
                                    leftToAllocate: leftToAllocate,
                                    currency: currencyManager.defaultCurrency,
                                    currencyFormatter: currencyConverter.formatAmount
                                )
                            }
                            .padding(.top, 8)
                            
                            // Category list
                            VStack(spacing: 8) {
                                ForEach(Array(selectedCategories), id: \.self) { category in
                                    CategoryBudgetRow(
                                        category: category,
                                        limit: categoryLimits[category],
                                        onSetLimit: {
                                            selectedCategoryForLimit = category
                                        }
                                    )
                                }
                                
                                // Add SecondarySmallButton for adding more categories
                                SecondarySmallButton(
                                    isEnabled: true,
                                    label: "Adjust categories",
                                    action: { showCategorySheet = true }
                                )
                                .padding(.top, 8)
                            }
                        }
                        
                        // Footer text
                        if leftToAllocate != nil && leftToAllocate! > 0 {
                            Text("Remaining amount will be allocated to \"Everything else\" category")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Note text at bottom
                    if existingBudget == nil {
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
            .navigationTitle(existingBudget != nil ? "Edit budget" : "Add budget")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.primary),
                trailing: Button("Save") {
                    Task {
                        await validateAndSaveBudget()
                    }
                }
                .foregroundColor(.primary)
                .disabled(!isValidInput)
            )
            .navigationBarBackButtonHidden(isInNavigationFlow)
            .navigationDestination(isPresented: $showCategorySheet) {
                CategorySheet(selectedCategories: $selectedCategories)
            }
            // Using navigationDestination instead of sheet for consistent experience
            .navigationDestination(item: $selectedCategoryForLimit) { category in
                CategoryLimitSheet(
                    category: category,
                    categoryLimits: $categoryLimits,
                    selectedCategories: $selectedCategories
                )
            }
            .interactiveDismissDisabled()
            .disabled(isProcessing)
            .alert(alertMessage, isPresented: $showAlert) {
                switch alertType {
                case .error:
                    Button("OK", role: .cancel) { }
                case .limitExceeded:
                    Button("Edit Limits", role: .cancel) { }
                    Button("Save Anyway") {
                        Task {
                            await saveBudget()
                        }
                    }
                }
            }
            // Navigation destination to the monthly limit view
            .navigationDestination(isPresented: $showMonthlyLimitView) {
                MonthlyLimitView(amount: $amount)
            }
            .interactiveDismissDisabled()
        }
    }
    
    struct CategoryLimitsStats: View {
        let categoriesWithLimits: Int
        let totalCategories: Int
        let leftToAllocate: Decimal?
        let currency: Currency?
        let currencyFormatter: (Decimal, Currency) -> String
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
                
                if leftToAllocate != nil && currency != nil {
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.2) : Color(UIColor.systemGray4))
                        .frame(height: 30)
                }
                
                // Left to allocate (if applicable)
                if let left = leftToAllocate,
                   let currency = currency {
                    VStack(spacing: 4) {
                        Text("Left to allocate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(currencyFormatter(left, currency))
                            .font(.body)
                            .foregroundColor(left >= 0 ? .primary : .red)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.clear) // Transparent background
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
    
    private func validateAndSaveBudget() async {
        // If no amount is set but we have category limits, save directly
        if amount.isEmpty && !categoryLimits.isEmpty {
            await saveBudget()
            return
        }
        
        guard let totalBudget = KeypadInputHelpers.parseAmount(amount, currencySymbol: defaultCurrency?.symbol) else {
            alertType = .error
            alertMessage = BudgetManager.BudgetError.invalidAmount.errorDescription ?? ""
            showAlert = true
            return
        }
        
        // Calculate sum of category limits
        var totalCategoryLimits: Decimal = 0
        
        for (_, limitString) in categoryLimits {
            if let limitAmount = KeypadInputHelpers.parseAmount(limitString, currencySymbol: defaultCurrency?.symbol) {
                totalCategoryLimits += limitAmount
            }
        }
        
        // Check if category limits exceed total budget
        if totalCategoryLimits > totalBudget {
            alertType = .limitExceeded
            alertMessage = "The sum of category limits (\(formatAmount(totalCategoryLimits))) exceeds your monthly budget (\(formatAmount(totalBudget))). Do you want to edit the limits or proceed anyway?"
            showAlert = true
        } else {
            await saveBudget()
        }
    }
    
    private func saveBudget() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let totalAmount = KeypadInputHelpers.parseAmount(amount, currencySymbol: defaultCurrency?.symbol)
            
            let budget: Budget
            if let existingBudget = self.existingBudget {
                // Update existing budget
                try await budgetManager.updateBudget(
                    existingBudget,
                    amount: totalAmount ?? 0
                )
                budget = existingBudget
            } else {
                // Create new budget
                budget = try await budgetManager.createBudget(
                    amount: totalAmount
                )
                
                // Create future budgets after creating new budget
                try await budgetManager.createFutureBudgets(from: budget)
            }
            
            // Save category budgets using manager
            try await budgetManager.saveCategoryBudgets(
                for: budget,
                categoryLimits: categoryLimits
            )
            
            // Update budget amount if needed
            try? await budgetManager.updateBudgetAmountFromCategories(budget)
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertType = .error
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        return currencyConverter.formatAmount(
            amount,
            currency: currencyManager.defaultCurrency ?? Currency()
        )
    }
}

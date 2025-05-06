//
//  BudgetFormViewModel.swift
//  Expensa
//
//  Created on 01.05.2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
class BudgetFormViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var amount: String = ""
    @Published var selectedCategories: Set<Category> = []
    @Published var categoryLimits: [Category: String] = [:]
    @Published var selectedCategoryForLimit: Category?
    @Published var showCategorySheet = false
    @Published var showMonthlyLimitView = false
    @Published var isProcessing = false
    @Published var alertMessage = ""
    @Published var alertType: AlertType = .error
    @Published var showAlert = false
    
    // MARK: - Alert Types
    enum AlertType {
        case error
        case limitExceeded
    }
    
    // MARK: - Private Properties
    private let budgetManager = BudgetManager.shared
    private let currencyManager = CurrencyManager.shared
    private let currencyConverter = CurrencyConverter.shared
    private let existingBudget: Budget?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var defaultCurrency: Currency? {
        currencyManager.defaultCurrency
    }
    
    var isValidInput: Bool {
        // Allow empty amount if there are category budgets
        if amount.isEmpty {
            return !categoryLimits.isEmpty
        }
        
        // Otherwise check if amount is valid
        guard !isProcessing,
              let amountDecimal = parseAmount(amount),
              amountDecimal > 0 else {
            return false
        }
        
        return true
    }
    
    var allocatedAmount: Decimal {
        categoryLimits.values.compactMap { parseAmount($0) }
            .reduce(0, +)
    }
    
    var leftToAllocate: Decimal? {
        guard let totalBudget = parseAmount(amount),
              totalBudget > 0 else {
            return nil
        }
        return totalBudget - allocatedAmount
    }
    
    var isEditing: Bool {
        existingBudget != nil
    }
    
    // MARK: - Initialization
    
    // Initialize for new budget
    init(initialAmount: String = "") {
        self.existingBudget = nil
        self.amount = initialAmount
    }
    
    // Initialize for editing with proper currency formatting
    init(budget: Budget) {
        self.existingBudget = budget
        
        // Format amount using CurrencyConverter
        if let decimalAmount = budget.amount?.decimalValue,
           let currency = budget.budgetCurrency {
            self.amount = currencyConverter.formatAmount(decimalAmount, currency: currency)
        }
        
        // Load existing category budgets if any
        if let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> {
            self.selectedCategories = Set(categoryBudgets.compactMap { $0.category })
            
            // Initialize category limits
            for categoryBudget in categoryBudgets {
                if let category = categoryBudget.category,
                   let amount = categoryBudget.budgetAmount?.decimalValue,
                   let currency = categoryBudget.budgetCurrency {
                    self.categoryLimits[category] = currencyConverter.formatAmount(amount, currency: currency)
                }
            }
        }
    }
    
    // MARK: - Public Methods
    func validateAndSaveBudget() async {
        // If no amount is set but we have category limits, save directly
        if amount.isEmpty && !categoryLimits.isEmpty {
            await saveBudget()
            return
        }
        
        guard let totalBudget = parseAmount(amount) else {
            alertType = .error
            alertMessage = BudgetManager.BudgetError.invalidAmount.errorDescription ?? ""
            showAlert = true
            return
        }
        
        // Calculate sum of category limits
        let totalCategoryLimits = allocatedAmount
        
        // Check if category limits exceed total budget
        if totalCategoryLimits > totalBudget {
            alertType = .limitExceeded
            alertMessage = "The sum of category limits (\(formatAmount(totalCategoryLimits))) exceeds your monthly budget (\(formatAmount(totalBudget))). Do you want to edit the limits or proceed anyway?"
            showAlert = true
        } else {
            await saveBudget()
        }
    }
    
    func saveBudget() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let totalAmount = parseAmount(amount)
            
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
            
            NotificationCenter.default.post(name: Notification.Name("BudgetUpdated"), object: nil)
        } catch {
            await MainActor.run {
                alertType = .error
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    func selectCategory(_ category: Category) {
        selectedCategories.insert(category)
    }
    
    func removeCategory(_ category: Category) {
        selectedCategories.remove(category)
        categoryLimits.removeValue(forKey: category)
    }
    
    func setCategoryLimit(for category: Category, limit: String) {
        categoryLimits[category] = limit
    }
    
    func formattedCategoryLimitStats() -> (withLimits: Int, total: Int) {
        return (categoryLimits.count, selectedCategories.count)
    }
    
    // Add this method to create the formatted text for the left to allocate amount
    func formatLeftToAllocate() -> String? {
        guard let leftAmount = leftToAllocate,
              let currency = defaultCurrency else {
            return nil
        }
        
        return currencyConverter.formatAmount(leftAmount, currency: currency)
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
}

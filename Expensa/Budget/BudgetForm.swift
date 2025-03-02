//
//  AddBudgetForm.swift
//  Expensa
//
//  Created by Andrew Sereda on 15.11.2024.
//

import Foundation
import CoreData
import SwiftUI

struct BudgetForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .error
    @State private var isProcessing = false
    @State private var showCategorySheet = false
    @State private var selectedCategories: Set<Category> = []
    @State private var categoryLimits: [Category: String] = [:]
    @State private var selectedCategoryForLimit: Category?
    
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
              let amountDecimal = parseAmount(amount),
              amountDecimal > 0 else {
            return false
        }
        return true
    }
    
    // Initialize for new budget
    init() {
        self.existingBudget = nil
        self._amount = State(initialValue: "")
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
        categoryLimits.values.compactMap { parseAmount($0) }
        .reduce(0, +)
    }
    
    private var leftToAllocate: Decimal? {
        guard let totalBudget = parseAmount(amount),
              totalBudget > 0 else {
            return nil
        }
        return totalBudget - allocatedAmount
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Budget Details")) {
                    TextField("Monthly Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    if let left = leftToAllocate,
                       let currency = currencyManager.defaultCurrency {
                        HStack {
                            Text("Left to allocate")
                            Spacer()
                            Text(currencyConverter.formatAmount(left, currency: currency))
                                .foregroundColor(left >= 0 ? .gray : .red)
                        }
                    }
                }
                
                Section(
                    header: Text("Category Budgets"),
                    footer: Group {
                        if leftToAllocate != nil && leftToAllocate! > 0 {
                            Text("Remaining amount will be allocated to \"Everything else\" category")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                ) {
                    Button(action: {
                        showCategorySheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add expense categories")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ForEach(Array(selectedCategories), id: \.self) { category in
                        VStack {
                            HStack {
                                Text(category.icon ?? "🔹")
                                Text(category.name ?? "")
                                Spacer()
                                if let limit = categoryLimits[category] {
                                    Text(limit)
                                        .foregroundColor(.gray)
                                }
                                Button("Set limit") {
                                    selectedCategoryForLimit = category
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                
                if existingBudget == nil {
                    Section {
                        Text("Note: Only one budget can be created per month")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle(existingBudget != nil ? "Edit Budget" : "Add Budget")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        await validateAndSaveBudget()
                    }
                }
                .disabled(!isValidInput)
            )
            .sheet(isPresented: $showCategorySheet) {
                CategorySheet(selectedCategories: $selectedCategories)
            }
            .sheet(item: $selectedCategoryForLimit) { category in
                CategoryLimitSheet(
                    category: category,
                    categoryLimits: $categoryLimits,
                    selectedCategories: $selectedCategories  // Pass the binding
                )
            }
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
        }
    }
    
    private func parseAmount(_ formattedAmount: String) -> Decimal? {
        let cleanedAmount = formattedAmount
            .replacingOccurrences(of: currencyManager.defaultCurrency?.symbol ?? "$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        return Decimal(string: cleanedAmount)
    }
    
    private func validateAndSaveBudget() async {
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
          var totalCategoryLimits: Decimal = 0
          
          for (_, limitString) in categoryLimits {
              if let limitAmount = parseAmount(limitString) {
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


struct CategorySelectionRow: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(category.icon ?? "🔹")
                Text(category.name ?? "")
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct CategoryLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category
    @Binding var categoryLimits: [Category: String]
    @Binding var selectedCategories: Set<Category>  // Add binding to selectedCategories
    @State private var amount: String = ""
    @State private var showDeleteAlert = false
    
    private let currencyManager = CurrencyManager.shared
    private let currencyConverter = CurrencyConverter.shared
    
    var body: some View {
        NavigationView {
            VStack(alignment: .center, spacing: 24) {
                // Category Info
                VStack(spacing: 8) {
                    Text(category.icon ?? "🔹")
                        .font(.system(size: 48))
                    Text(category.name ?? "")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 32)
                
                // Instructions
                Text("Set monthly limit on \(category.name ?? ""):")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                // Amount Input
                VStack {
                    Text(currencyManager.defaultCurrency?.symbol ?? "$")
                        .font(.body)
                    Form {
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Category Limit")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: HStack(spacing: 16) {
                    // Delete button
                    if categoryLimits[category] != nil {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Save button
                    Button("Save") {
                        if !amount.isEmpty,
                           let amountDecimal = Decimal(string: amount) {
                            categoryLimits[category] = currencyConverter.formatAmount(
                                amountDecimal,
                                currency: currencyManager.defaultCurrency ?? Currency()
                            )
                        }
                        dismiss()
                    }
                    .disabled(amount.isEmpty)
                }
            )
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                     to: nil, from: nil, for: nil)
                    }
                }
            }
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
                    amount = existingAmount
                        .replacingOccurrences(of: currencyManager.defaultCurrency?.symbol ?? "$", with: "")
                        .replacingOccurrences(of: " ", with: "")
                }
            }
        }
    }
}



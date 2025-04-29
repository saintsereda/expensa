//
//  TemplateEditView.swift
//  Expensa
//
//  Created by Andrew Sereda on 17.11.2024.
//

import Foundation
import SwiftUI
import CoreData

// Helper struct to hold template draft data
struct TemplateDraft {
    var amount: Decimal
    var category: Category?
    var currency: String
    var frequency: String
    var nextDueDate: Date
    var notes: String?
    var notificationEnabled: Bool
    
    init(from template: RecurringExpense) {
        self.amount = template.amount?.decimalValue ?? 0
        self.category = template.category
        self.currency = template.currency ?? "USD"
        self.frequency = template.frequency ?? "Monthly"
        self.nextDueDate = template.nextDueDate ?? Date()
        self.notes = template.notes
        self.notificationEnabled = template.notificationEnabled
    }
}

struct TemplateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var categoryManager: CategoryManager
    
    @Binding var isPresented: Bool
    let template: RecurringExpense
    
    // State for form fields
    @State private var amount: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedCurrency: String = ""
    @State private var frequency: String = ""
    @State private var nextDueDate: Date = Date()
    @State private var notes: String = ""
    @State private var notificationEnabled: Bool = true
    @State private var convertedAmount: String?
    
    @State private var showingCategorySelector = false
    @State private var showingCurrencyPicker = false
    @State private var showingNotesSheet = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    @State private var tempTags: Set<Tag> = []
    
    private let frequencyOptions = ["Daily", "Weekly", "Monthly", "Yearly"]
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // Date validation
    private var minimumDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private func validateNextDueDate(_ newDate: Date) {
        let startOfNewDate = Calendar.current.startOfDay(for: newDate)
        if startOfNewDate < minimumDate {
            nextDueDate = minimumDate
        }
    }
    
    private var defaultCurrency: Currency? {
        currencyManager.defaultCurrency
    }
    
    private var shouldShowConvertedAmount: Bool {
        convertedAmount != nil &&
        selectedCurrency != defaultCurrency?.code
    }
    
    private var isUsingHistoricalRates: Bool {
        !Calendar.current.isDateInToday(nextDueDate)
    }
    
    var body: some View {
        Form {
            // Amount Section
            Section("Amount") {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                
                if shouldShowConvertedAmount {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Converted: \(convertedAmount ?? "")")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        
                        if isUsingHistoricalRates {
                            Text("(Historical rate from \(dateFormatter.string(from: nextDueDate)))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // Currency Section
            Section("Currency") {
                Button {
                    showingCurrencyPicker = true
                } label: {
                    HStack {
                        Text("Currency")
                        Spacer()
                        Text(selectedCurrency)
                        Image(systemName: "chevron.right")
                    }
                }
            }
            
            // Details Section
            Section("Details") {
                Button {
                    showingCategorySelector = true
                } label: {
                    HStack {
                        Text("Category")
                        Spacer()
                        if let category = selectedCategory {
                            Text(category.icon ?? "🔹")
                            Text(category.name ?? "Unknown")
                        } else {
                            Text("Select category")
                        }
                        Image(systemName: "chevron.right")
                    }
                }
                
                Picker("Frequency", selection: $frequency) {
                    ForEach(frequencyOptions, id: \.self) { frequency in
                        Text(frequency).tag(frequency)
                    }
                }
                
                DatePicker(
                    "Next payment",
                    selection: $nextDueDate,
                    in: minimumDate...,
                    displayedComponents: .date
                )
                .onChange(of: nextDueDate) {_, newDate in
                    validateNextDueDate(newDate)
                }
                
                Toggle("Notifications", isOn: $notificationEnabled)
            }
            
            // Notes Section
            Section("Notes") {
                Button {
                    showingNotesSheet = true
                } label: {
                    HStack {
                        if !notes.isEmpty {
                            Text(notes)
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                        } else {
                            Text("Add notes")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
            }
            
            Section {
                Button("Save changes") {
                    saveTemplate()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Edit template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectorView(selectedCategory: $selectedCategory)
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyListView(selectedCurrency: Binding(
                get: { currencyManager.fetchCurrency(withCode: selectedCurrency) },
                set: {
                    if let newCurrency = $0 {
                        selectedCurrency = newCurrency.code ?? "USD"
                        Task {
                            await updateConvertedAmount()
                        }
                    }
                }
            ))
        }
        .sheet(isPresented: $showingNotesSheet) {
            NotesModalView(
                notes: $notes,
                tempTags: $tempTags
            )
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: amount) {
            Task {
                await updateConvertedAmount()
            }
        }
        .onChange(of: nextDueDate) {
            Task {
                if isUsingHistoricalRates {
                    await updateConvertedAmount()
                }
            }
        }
        .onAppear {
            loadTemplateData()
        }
    }
    
    private func loadTemplateData() {
        print("🔄 Loading template data...")
        
        if let decimalAmount = template.amount?.decimalValue {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            formatter.groupingSeparator = ","
            formatter.decimalSeparator = "."
            
            if let formattedString = formatter.string(from: NSDecimalNumber(decimal: decimalAmount)) {
                amount = formattedString
            } else {
                amount = decimalAmount.description
            }
        }
        
        selectedCategory = template.category
        print("📂 Loaded category: \(template.category?.name ?? "unknown")")
        
        selectedCurrency = template.currency ?? "USD"
        frequency = template.frequency ?? "Monthly"
        
        if let templateDate = template.nextDueDate {
            let validDate = max(templateDate, minimumDate)
            nextDueDate = validDate
        } else {
            nextDueDate = minimumDate
        }
        
        notes = template.notes ?? ""
        notificationEnabled = template.notificationEnabled
        
        Task {
            await updateConvertedAmount()
        }
        
        print("✅ Template data loaded")
    }
    
    private func updateConvertedAmount() async {
        guard let amountValue = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
              let selectedCurrencyObj = currencyManager.fetchCurrency(withCode: selectedCurrency),
              let defaultCurrency = defaultCurrency,
              selectedCurrency != defaultCurrency.code else {
            await MainActor.run {
                convertedAmount = nil
            }
            return
        }
        
        let conversionResult = CurrencyConverter.shared.convertAmount(
            amountValue,
            from: selectedCurrencyObj,
            to: defaultCurrency,
            on: nextDueDate
        )
        
        await MainActor.run {
            if let result = conversionResult {
                convertedAmount = currencyManager.currencyConverter.formatAmount(
                    result.amount,
                    currency: defaultCurrency
                )
            } else {
                convertedAmount = nil
            }
        }
    }
    
    private func saveTemplate() {
        let cleanedAmount = amount.replacingOccurrences(of: ",", with: "")
        
        guard let amountDecimal = Decimal(string: cleanedAmount),
              let category = selectedCategory else {
            errorMessage = "Please fill in all required fields"
            showingErrorAlert = true
            return
        }
        
        guard amountDecimal > 0 else {
            errorMessage = "Amount must be greater than zero"
            showingErrorAlert = true
            return
        }
        
        Task {
            let success = await RecurringExpenseManager.shared.updateRecurringTemplate(
                template: template,
                amount: amountDecimal,
                category: category,
                currency: selectedCurrency,
                frequency: frequency,
                startDate: nextDueDate,
                notes: notes,
                notificationEnabled: notificationEnabled
            )
            
            await MainActor.run {
                if success {
                    isPresented = false
                } else {
                    errorMessage = "Failed to update template. Please try again."
                    showingErrorAlert = true
                }
            }
        }
    }
}

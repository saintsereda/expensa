//
//  RecurringExpenseDetailView.swift
//  Expensa
//
//  Created by Andrew Sereda on 08.11.2024.
//

import Foundation
import SwiftUI
import CoreData

struct RecurringExpenseDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var categoryManager: CategoryManager
    
    @Binding var template: RecurringExpense?
    var onDelete: () -> Void
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    private func loadTemplateDetails() -> RecurringExpense? {
        guard let templateId = template?.id else { return nil }
        
        let fetchRequest: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", templateId as CVarArg)
        fetchRequest.relationshipKeyPathsForPrefetching = ["category"]
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("❌ Error fetching template details: \(error)")
            return nil
        }
    }
    
    private func deleteTemplate() {
        guard let templateToDelete = loadTemplateDetails() else {
            print("❌ Could not load template for deletion")
            return
        }
        
        // Mark template as inactive instead of deleting
        templateToDelete.status = "Inactive"
        templateToDelete.updatedAt = Date()
        
        // Delete future expenses
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "recurringExpense == %@ AND date > %@",
            templateToDelete,
            Date() as NSDate
        )
        
        do {
            let futureExpenses = try viewContext.fetch(fetchRequest)
            for expense in futureExpenses {
                viewContext.delete(expense)
            }
            
            try viewContext.save()
            
            // Save to CloudKit (if needed)
            Task {
                do {
                    try await CloudKitManager().saveRecord(templateToDelete)
                    print("✅ Template status updated in CloudKit")
                } catch {
                    print("❌ Failed to update template in CloudKit: \(error)")
                }
            }
            
            print("✅ Successfully deactivated template and deleted future expenses")
            onDelete()
            template = nil
            dismiss()
            
            // Notify that templates have changed
            DispatchQueue.main.async {
                RecurringExpenseManager.shared.loadActiveTemplates()
                NotificationCenter.default.post(
                    name: NSNotification.Name("ExpensesUpdated"),
                    object: nil
                )
            }
        } catch {
            print("❌ Error deactivating template: \(error)")
            viewContext.rollback()
        }
    }
    
    @State private var tempTemplate: TemplateDraft?
    
    var body: some View {
        if let template = template {
            NavigationView {
                List {
                    // Amount Section
                    Section("Amount") {
                        // Original Amount
                        HStack {
                            Text("Original")
                            Spacer()
                            if let amount = template.amount?.decimalValue,
                               let currency = template.currency,
                               let originalCurrency = currencyManager.fetchCurrency(withCode: currency) {
                                Text(currencyManager.currencyConverter.formatAmount(
                                    amount,
                                    currency: originalCurrency
                                ))
                                .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Converted Amount
                        if let defaultCurrency = currencyManager.defaultCurrency,
                           template.currency != defaultCurrency.code,
                           let convertedAmount = template.convertedAmount?.decimalValue {
                            HStack {
                                Text("Converted")
                                Spacer()
                                Text(currencyManager.currencyConverter.formatAmount(
                                    convertedAmount,
                                    currency: defaultCurrency
                                ))
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Details Section
                    Section("Details") {
                        // Category
                        if let category = template.category {
                            HStack {
                                Text("Category")
                                Spacer()
                                Text(category.icon ?? "🔹")
                                Text(category.name ?? "Unknown")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Frequency
                        HStack {
                            Text("Frequency")
                            Spacer()
                            Text(template.frequency ?? "Monthly")
                                .foregroundStyle(.secondary)
                        }
                        
                        // Next Due Date
                        if let nextDue = template.nextDueDate {
                            HStack {
                                Text("Next due")
                                Spacer()
                                Text(nextDue.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Notifications
                        HStack {
                            Text("Notifications")
                            Spacer()
                            Text(template.notificationEnabled ? "Enabled" : "Disabled")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Notes Section (if present)
                    if let notes = template.notes, !notes.isEmpty {
                        Section("Notes") {
                            Text(notes)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Action Buttons
                    Section {
                        Button {
                            if let loadedTemplate = loadTemplateDetails() {
                                print("📝 Editing template: \(loadedTemplate.id?.uuidString ?? "unknown")")
                                print("Category: \(loadedTemplate.category?.name ?? "unknown")")
                                print("Amount: \(loadedTemplate.amount?.stringValue ?? "0")")
                                print("Currency: \(loadedTemplate.currency ?? "unknown")")
                                showingEditSheet = true
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Edit template")
                                Spacer()
                            }
                        }
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete template")
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Template details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showingEditSheet) {
                    if let loadedTemplate = loadTemplateDetails() {
                        NavigationView {
                            TemplateEditView(
                                isPresented: $showingEditSheet,
                                template: loadedTemplate
                            )
                            .environmentObject(currencyManager)
                            .environmentObject(categoryManager)
                        }
                    }
                }
                .alert("Delete recurring expense", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        deleteTemplate()
                    }
                } message: {
                    Text("This will stop future expenses from being generated. Existing expenses will not be affected.")
                }
            }
        }
    }
}

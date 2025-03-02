//
//  ExpenseDetailView.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI
import CoreData

struct ExpenseDetailView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var tagManager: TagManager
    
    // MARK: - Bindings & Properties
    @Binding var expense: Expense?  // Changed to optional
    var onDelete: () -> Void
    
    // MARK: - State
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingNotesSheet = false
    @State private var expenseUpdated = false
    
    // MARK: - Trend chart
    private var categoryMonthlyData: [(Date, Decimal)]? {
        guard let category = expense?.category else { return nil }
        
        let fetchRequest = NSFetchRequest<Expense>(entityName: "Expense")
        fetchRequest.predicate = NSPredicate(format: "category == %@", category)
        
        guard let expenses = try? CoreDataStack.shared.context.fetch(fetchRequest) else {
            return nil
        }
        
        return ExpenseAnalytics.shared.calculateMonthlyTrend(for: expenses)
    }
    
    // MARK: - Body
    var body: some View {
        if let expense = expense {  // Unwrap the optional
            NavigationView {
                List {
                    // Amount Section
                    Section("Amount") {
                        // Original Amount
                        HStack {
                            Text("Original")
                            Spacer()
                            if let amount = expense.amount?.decimalValue,
                               let currency = expense.currency,
                               let originalCurrency = currencyManager.fetchCurrency(withCode: currency) {
                                Text(currencyManager.currencyConverter.formatAmount(
                                    amount,
                                    currency: originalCurrency
                                ))
                                .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Converted Amount (if in different currency)
                        if let defaultCurrency = currencyManager.defaultCurrency,
                           expense.currency != defaultCurrency.code {
                            HStack {
                                Text("Converted")
                                Spacer()
                                Text(CurrencyConverter.shared.formatAmount(
                                    expense.convertedAmount?.decimalValue ?? 0,
                                    currency: defaultCurrency
                                ))
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Details Section
                    Section("Details") {
                        // Category
                        if let category = expense.category {
                            HStack {
                                Text("Category")
                                Spacer()
                                Text(category.icon ?? "🔹")
                                Text(category.name ?? "Unknown")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Date
                        if let date = expense.date {
                            HStack {
                                Text("Date")
                                Spacer()
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
//                    if let monthlyData = categoryMonthlyData,
//                       let category = expense.category {
//                        Section("Category Monthly Trend") {
//                            CategoryMonthlyTrendView(
//                                category: category,
//                                data: monthlyData
//                            )
//                            .listRowInsets(EdgeInsets())
//                        }
//                    }
                    
                    // Notes Section (if present)
                    Section("Notes") {
                        Button(action: {
                            // Simply show the sheet - we'll use bindings to expense directly
                            showingNotesSheet = true
                        }) {
                            HStack {
                                if let expenseNotes = expense.notes, !expenseNotes.isEmpty {
                                    Text(expenseNotes)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text("Add notes or tags")
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Image(systemName: "pencil.and.scribble")
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    // Metadata Section
//                    Section("Metadata") {
//                        if let created = expense.createdAt {
//                            HStack {
//                                Text("Created")
//                                Spacer()
//                                Text(created.formatted(date: .abbreviated, time: .shortened))
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
//                        
//                        if let updated = expense.updatedAt {
//                            HStack {
//                                Text("Updated")
//                                Spacer()
//                                Text(updated.formatted(date: .abbreviated, time: .shortened))
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
//                    }
                    
                    // Action Buttons
                    Section {
                        // Edit Button
                        Button {
                            showingEditSheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Edit expense")
                                Spacer()
                            }
                        }
                    }
                    
                    // Delete Button
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete expense")
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Expense details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                        }
                    }
                }
                .sheet(isPresented: $showingEditSheet) {
                    ExpenseEntryView(
                        isPresented: $showingEditSheet,
                        expense: expense
                    )
                }
                .sheet(isPresented: $showingNotesSheet) {
                    // Create a binding that works directly with the expense's notes
                    let notesBinding = Binding<String>(
                        get: { expense.notes ?? "" },
                        set: { newValue in
                            expense.notes = newValue
                            expense.updatedAt = Date()
                            try? CoreDataStack.shared.context.save()
                        }
                    )
                    
                    // Create a binding for tags
                    let tagsBinding = Binding<Set<Tag>>(
                        get: { expense.tags as? Set<Tag> ?? [] },
                        set: { newValue in
                            expense.tags = newValue as NSSet
                            try? CoreDataStack.shared.context.save()
                        }
                    )
                    
                    NotesModalView(notes: notesBinding, tempTags: tagsBinding)
                        .presentationCornerRadius(32)
                        .environmentObject(tagManager)
                }
                .alert("Delete expense", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to delete this expense? This action cannot be undone.")
                }
            }
        }
    }
}

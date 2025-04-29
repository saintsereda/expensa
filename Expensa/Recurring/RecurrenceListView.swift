//
//  RecurrenceListView.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import SwiftUI
import CoreData

struct RecurrenceListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\RecurringExpense.nextDueDate, order: .forward),
            SortDescriptor(\RecurringExpense.createdAt, order: .forward)
        ],
        predicate: NSPredicate(format: "status == %@", "Active"),
        animation: .default
    ) private var templates: FetchedResults<RecurringExpense>
    
    @State private var selectedTemplate: RecurringExpense?
    @State private var showingDetailView = false
    @State private var showingAddExpense = false
    @State private var showingYearlyTotal = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Header Section
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading) {
                            Text("\(templates.count)")
                                .font(.system(size: 28, weight: .medium))
                            Text("Active templates")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        
                        VStack(alignment: .trailing) {
                            if let defaultCurrency = currencyManager.defaultCurrency {
                                let monthlyTotal = RecurringExpenseManager.calculateMonthlyTotal(
                                    for: Array(templates),
                                    defaultCurrency: defaultCurrency,
                                    currencyConverter: currencyManager.currencyConverter
                                )
                                
                                Text(currencyManager.currencyConverter.formatAmount(
                                    showingYearlyTotal ? monthlyTotal * 12 : monthlyTotal,
                                    currency: defaultCurrency
                                ))
                                .font(.system(size: 28, weight: .medium))
                                .contentTransition(.numericText())
                                
                                Text(showingYearlyTotal ? "yearly total" : "monthly total")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .contentTransition(.numericText())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                showingYearlyTotal.toggle()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Templates List
                if !templates.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(templates) { template in
                            RecurringExpenseRow(template: template)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTemplate = template
                                    showingDetailView = true
                                }
                            
                            if template != templates.last {
                                Divider()
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                } else {
                    // Empty State
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "repeat.circle")
                                .foregroundColor(.gray)
                            Text("No recurring expenses set up")
                                .foregroundColor(.gray)
                        }
                        
                        Button {
                            showingAddExpense = true
                        } label: {
                            Text("Add your first recurring expense")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingDetailView) {
            RecurringExpenseDetailView(
                template: $selectedTemplate,
                onDelete: {
                    if let template = selectedTemplate {
                        deleteTemplate(template)
                        selectedTemplate = nil
                        showingDetailView = false
                    }
                }
            )
            .environmentObject(currencyManager)
        }
        .sheet(isPresented: $showingAddExpense) {
            NavigationView {
                ExpenseEntryView(
                    isPresented: $showingAddExpense,
                    expense: nil
                )
                .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private func deleteTemplate(_ template: RecurringExpense) {
        viewContext.performAndWait {
            template.status = "Inactive"
            try? viewContext.save()
        }
    }
}

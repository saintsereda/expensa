//
//  UncategorizedExpensesView.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.02.2025.
//

import Foundation
import SwiftUI
import CoreData

struct UncategorizedExpensesView: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // Direct fetch request for uncategorized expenses (with nil category OR "No Category")
    @FetchRequest private var uncategorizedExpenses: FetchedResults<Expense>
    
    // Computed property for total amount
    private var categoryAmount: Decimal {
        uncategorizedExpenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
    }
    
    // Initialize with a dedicated fetch request for uncategorized expenses
    init(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        
        // Only fetch expenses with nil category
        fetchRequest.predicate = NSPredicate(format: "category == nil")
        
        // Optional: Add sorting if needed
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        // Create the fetch request
        _uncategorizedExpenses = FetchRequest(fetchRequest: fetchRequest, animation: .default)
    }
    
    var body: some View {
        if !uncategorizedExpenses.isEmpty {
            NavigationLink(value: NavigationDestination.uncategorizedExpenses) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 48, height: 48)
                        Text("❓")
                            .font(.system(size: 20))
                    }
                    VStack(alignment: .leading)  {
                        if let defaultCurrency = currencyManager.defaultCurrency {
                            Text(currencyManager.currencyConverter.formatAmount(
                                categoryAmount,
                                currency: defaultCurrency
                            ) + " uncategorized")
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        }
                        
                        Text("\(uncategorizedExpenses.count) expense\(uncategorizedExpenses.count == 1 ? "" : "s") needs attention")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .contentTransition(.numericText())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

//
//  UncategorizedExpensesListView.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.02.2025.
//

import SwiftUI
import CoreData

struct UncategorizedExpensesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    @State private var selectedExpense: Expense?
    
    @FetchRequest private var uncategorizedExpenses: FetchedResults<Expense>
    
    init() {
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "category == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        _uncategorizedExpenses = FetchRequest(fetchRequest: fetchRequest, animation: .default)
    }
    
    var body: some View {
        List {
            ForEach(uncategorizedExpenses) { expense in
                ExpenseRow(expense: expense)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedExpense = expense
                    }
            }
        }
        .navigationTitle("Uncategorized Expenses")
        .listStyle(PlainListStyle())
        .sheet(item: $selectedExpense) { _ in
            ExpenseDetailView(
                expense: $selectedExpense,
                onDelete: {
                    if let expense = selectedExpense {
                        ExpenseDataManager.shared.deleteExpense(expense)
                        selectedExpense = nil
                    }
                }
            )
            .environmentObject(currencyManager)
        }
    }
}

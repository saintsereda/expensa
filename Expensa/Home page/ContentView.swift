//
//  ContentView.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI
import CoreData

struct ContentView: View {
    // MARK: - Environment & Managers
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    @StateObject private var filterManager = ExpenseFilterManager()
    
    // MARK: - State Properties
    @State private var isPresentingExpenseEntry = false
    @State private var selectedExpense: Expense?
    @State private var currentBudget: Budget?
    
    // MARK: - Fetch Request
    private var fetchRequest: FetchRequest<Expense>
    private var fetchedExpenses: FetchedResults<Expense> { fetchRequest.wrappedValue }
    
    // MARK: - Initialization
    init() {
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.sortDescriptors = [
//            NSSortDescriptor(keyPath: \Expense.date, ascending: false),
            NSSortDescriptor(keyPath: \Expense.createdAt, ascending: false)
        ]
        
        let filterManager = ExpenseFilterManager()
        let initialInterval = filterManager.dateInterval(for: Date())
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            initialInterval.start as NSDate,
            initialInterval.end as NSDate
        )
        
        self.fetchRequest = FetchRequest(
            fetchRequest: request,
            animation: .default
        )
        
        let tabBarAppearance = UITabBarAppearance()
//        tabBarAppearance.configureWithDefaultBackground()
//        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
    }
    
    // MARK: - Computed Properties
    private var categorizedExpenses: [(Category, [Expense])] {
        let categories = Set(fetchedExpenses.compactMap { $0.category })
        let categoryTuples = categories.map { category in
            (
                category,
                fetchedExpenses.filter { $0.category == category }
            )
        }
        return categoryTuples.sorted { first, second in
            let firstAmount = ExpenseDataManager.shared.calculateTotalAmount(for: first.1)
            let secondAmount = ExpenseDataManager.shared.calculateTotalAmount(for: second.1)
            return firstAmount > secondAmount
        }
    }
    
    // MARK: - Body
    var body: some View {
        TabView {
            NavigationStack {
                ExpensesTab(
                    isPresentingExpenseEntry: $isPresentingExpenseEntry,
                    selectedExpense: $selectedExpense,
                    fetchedExpenses: fetchedExpenses,
                    categorizedExpenses: categorizedExpenses,
                    filterManager: filterManager,
                    currentBudget: currentBudget
                )
            }
            .tabItem {
                Label("", systemImage: "creditcard.fill")
            }
            
            NavigationStack {
                BudgetView()
            }
            .tabItem {
                Label("", systemImage: "chart.pie.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("", systemImage: "gear")
            }
        }
        .task {
            currentBudget = await BudgetManager.shared.getCurrentMonthBudget()
        }
        .onChange(of: filterManager.selectedDate) { _, newDate in
            updateFetchRequestPredicate(for: newDate)
        }
    }
    
    // MARK: - Helper Methods
    private func updateFetchRequestPredicate(for date: Date) {
        let interval = filterManager.dateInterval(for: date)
        fetchRequest.wrappedValue.nsPredicate = NSPredicate(
            format: "date <= %@",
            interval.start as NSDate,
            interval.end as NSDate
        )
    }
}

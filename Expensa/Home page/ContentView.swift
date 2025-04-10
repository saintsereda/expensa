//
//  ContentView.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI
import CoreData
import UIKit

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
        // Always set filterManager to current month
        let filterManager = ExpenseFilterManager()
        let initialInterval = filterManager.dateInterval(for: Date())
        
        // Create fetch request with current month filter
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Expense.createdAt, ascending: false)
        ]
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            initialInterval.start as NSDate,
            initialInterval.end as NSDate
        )
        
        self.fetchRequest = FetchRequest(
            fetchRequest: request,
            animation: .default
        )
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
    
    // MARK: - State for sheets
    @State private var isPresentingBudgetView = false
    @State private var isPresentingSettingsView = false
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: "0042B5"), location: 0.0),
                        .init(color: Color(hex: "000000"), location: 0.8)  // 80%
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main content
                    HomePage(
                        isPresentingExpenseEntry: $isPresentingExpenseEntry,
                        selectedExpense: $selectedExpense,
                        fetchedExpenses: fetchedExpenses,
                        categorizedExpenses: categorizedExpenses,
                        filterManager: filterManager,
                        currentBudget: $currentBudget
                    )
                }
                
                // Top buttons row (on top of the blur)
                HStack(spacing: 12) {
                    IconButton(
                        icon: "pie-chart",
                        action: {
                            isPresentingBudgetView = true
                        }
                    )
                    
                    Spacer()
                    
                    IconButton(
                        icon: "settings",
                        action: {
                            isPresentingSettingsView = true
                        }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(height: 60)
            }
        }
        .task {
            // Always get current month's budget
            currentBudget = await BudgetManager.shared.getCurrentMonthBudget()
        }
        .onChange(of: filterManager.selectedDate) { _, newDate in
            updateFetchRequestPredicate(for: newDate)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BudgetUpdated"))) { _ in
            Task {
                currentBudget = await BudgetManager.shared.getCurrentMonthBudget()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Reset to current month when coming back to the app
            filterManager.selectedDate = Date()
            updateFetchRequestPredicate(for: Date())
            
            Task {
                currentBudget = await BudgetManager.shared.getCurrentMonthBudget()
            }
        }
        
        .sheet(isPresented: $isPresentingBudgetView) {
            BudgetView()
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $isPresentingSettingsView) {
            NavigationStack {
                SettingsView()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateFetchRequestPredicate(for date: Date) {
        let interval = filterManager.dateInterval(for: date)
        fetchRequest.wrappedValue.nsPredicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            interval.start as NSDate,
            interval.end as NSDate
        )
    }
}

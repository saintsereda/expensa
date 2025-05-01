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
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    @StateObject private var filterManager = ExpenseFilterManager()
    @StateObject private var accentColorManager = AccentColorManager.shared
    
    // MARK: - State Properties
    @State private var isPresentingExpenseEntry = false
    @State private var selectedExpense: Expense?
    @State private var currentBudget: Budget?
    
    // MARK: - Fetch Request
    private var fetchRequest: FetchRequest<Expense>
    private var fetchedExpenses: FetchedResults<Expense> { fetchRequest.wrappedValue }
    
    // MARK: - Initialization
    init() {
        let filterManager = ExpenseFilterManager()
        let initialInterval = filterManager.dateInterval(for: Date())
        
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Expense.date, ascending: false)
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
        
        // Configure the navigation bar appearance
        let transparentAppearance = UINavigationBarAppearance()
        transparentAppearance.configureWithTransparentBackground()
        
        let blurAppearance = UINavigationBarAppearance()
        blurAppearance.configureWithDefaultBackground()
        
        // Apply the appearances
        UINavigationBar.appearance().scrollEdgeAppearance = transparentAppearance  // Top of scroll = transparent
        UINavigationBar.appearance().standardAppearance = blurAppearance          // When scrolled = blur
        UINavigationBar.appearance().compactAppearance = blurAppearance           // Compact state = blur
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
            ZStack {
                // Gradient background with dynamic accent color
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: accentColorManager.selectedAccentColor.color, location: 0.0),
                        .init(color: Color(hex: "000000"), location: 0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Main content
                HomePage(
                    isPresentingExpenseEntry: $isPresentingExpenseEntry,
                    selectedExpense: $selectedExpense,
                    fetchedExpenses: fetchedExpenses,
                    categorizedExpenses: categorizedExpenses,
                    filterManager: filterManager,
                    currentBudget: $currentBudget
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            HapticFeedback.play()
                            isPresentingBudgetView = true
                        }) {
                            // Using custom image from assets
                            Image("pie-chart")
                                .renderingMode(.template)
                                .foregroundColor(.white)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            HapticFeedback.play()
                            isPresentingSettingsView = true
                        }) {
                            // Using custom image from assets
                            Image("settings")
                                .renderingMode(.template)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .task {
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
                .presentationCornerRadius(32)
            }
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
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

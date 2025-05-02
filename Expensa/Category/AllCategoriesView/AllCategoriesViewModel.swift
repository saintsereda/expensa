//
//  AllCategoriesViewModel.swift
//  Expensa
//
//  Created by Andrew Sereda on 02.05.2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine

class AllCategoriesViewModel: ObservableObject {
    // Environment
    private let context: NSManagedObjectContext
    let currencyManager: CurrencyManager
    
    // State
    @Published var filterManager = ExpenseFilterManager()
    @Published var currentBudget: Budget?
    @Published var expenses: [Expense] = []
    
    // Computed property for categorized expenses
    var categorizedExpenses: [(Category, [Expense])] {
        guard !expenses.isEmpty else {
            return []
        }
        
        let categories = Set(expenses.compactMap { $0.category })
        let categoryTuples = categories.map { category in
            (
                category,
                expenses.filter { $0.category == category }
            )
        }
        return categoryTuples.sorted { first, second in
            let firstAmount = ExpenseDataManager.shared.calculateTotalAmount(for: first.1)
            let secondAmount = ExpenseDataManager.shared.calculateTotalAmount(for: second.1)
            
            // First sort by amount spent (descending)
            if firstAmount != secondAmount {
                return firstAmount > secondAmount
            }
            
            // If amounts are equal, sort by category name (ascending)
            return (first.0.name ?? "") < (second.0.name ?? "")
        }
    }
    
    // Total expenses amount directly from ExpenseDataManager
    var totalExpensesAmount: Decimal {
        ExpenseDataManager.shared.calculateTotalAmount(for: expenses)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // Initialization
    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
        self.currencyManager = CurrencyManager.shared
        
        // Setup observers when filter parameters change
        setupObservers()
        
        // Initial load
        refreshData()
    }
    
    // Setup observers for filter changes
    private func setupObservers() {
        // Make sure observations happen on the main thread
        filterManager.$selectedDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshData() }
            .store(in: &cancellables)
        
        filterManager.$endDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshData() }
            .store(in: &cancellables)
        
        filterManager.$isRangeMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshData() }
            .store(in: &cancellables)
    }
    
    // Fetch expenses based on the current period interval
    func refreshData() {
        fetchExpenses()
        updateBudget()
    }
    
    private func fetchExpenses() {
        // Get current date interval based on filter mode
        let interval = filterManager.currentPeriodInterval()
        
        // Create and execute fetch request
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            interval.start as NSDate,
            interval.end as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Expense.createdAt, ascending: false)
        ]
        
        // Perform fetch on background thread, then update published property on main thread
        Task {
            do {
                let fetchedExpenses = try await context.perform {
                    try self.context.fetch(request)
                }
                
                // Update expenses on main thread
                await MainActor.run {
                    self.expenses = fetchedExpenses
                }
            } catch {
                print("Error fetching expenses: \(error)")
                await MainActor.run {
                    self.expenses = []
                }
            }
        }
    }
    
    // Update budget information based on the selected date
    func updateBudget() {
        Task {
            // For range selection, we'll use the budget from the starting month
            // In a more comprehensive solution, we might want to aggregate budgets across months
            let budget = await BudgetManager.shared.getBudgetFor(month: filterManager.selectedDate)
            
            // Update UI on main thread
            await MainActor.run {
                self.currentBudget = budget
                self.objectWillChange.send()
            }
        }
    }
    
    // Handle period selection
    func applyPeriodSelection(startDate: Date, endDate: Date, isRangeMode: Bool) {
        // Ensure filter updates happen on the main thread
        DispatchQueue.main.async {
            if isRangeMode {
                self.filterManager.setDateRange(start: startDate, end: endDate)
            } else {
                self.filterManager.resetToSingleMonthMode(date: startDate)
            }
            
            // No need to call refreshData() here as the observers will trigger it
        }
    }
}

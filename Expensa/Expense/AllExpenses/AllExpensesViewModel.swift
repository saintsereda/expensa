//
//  AllExpensesViewModel.swift
//  Expensa
//
//  Created on 11.05.2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine

class AllExpensesViewModel: ObservableObject {
    // Core Data context
    private let viewContext: NSManagedObjectContext
    
    // Published properties for UI updates
    @Published var searchText: String = ""
    @Published var selectedCategories: Set<Category> = []
    @Published var selectedTags: Set<Tag> = []
    @Published var hasTags: Bool = false
    @Published var currentPage: Int = 0
    @Published var selectedExpense: Expense?
    @Published var showingCategoryFilter: Bool = false
    @Published var showingTagFilter: Bool = false
    @Published var showingDateFilter: Bool = false
    
    // Date range filtering
    @Published var filterManager = ExpenseFilterManager()
    @Published var isDateFilterActive: Bool = false
    
    // Data storage
    @Published private(set) var allExpenses: [Expense] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasMoreData: Bool = true
    
    // Constants
    let itemsPerPage: Int = 50
    
    // Filtered expenses - this is computed based on all filters
    var filteredExpenses: [Expense] {
        var result = allExpenses
        
        // Date filtering
        if isDateFilterActive {
            let dateInterval = filterManager.currentPeriodInterval()
            result = result.filter { expense in
                guard let date = expense.date else { return false }
                return dateInterval.contains(date)
            }
        }
        
        // Text search
        if !searchText.isEmpty {
            result = result.filter { expense in
                let categoryMatch = expense.category?.name?.localizedCaseInsensitiveContains(searchText) ?? false
                let notesMatch = expense.notes?.localizedCaseInsensitiveContains(searchText) ?? false
                return categoryMatch || notesMatch
            }
        }
        
        // Category filtering
        if !selectedCategories.isEmpty {
            result = result.filter { expense in
                guard let category = expense.category else { return false }
                return selectedCategories.contains(category)
            }
        }
        
        // Tag filtering
        if !selectedTags.isEmpty {
            result = result.filter { expense in
                guard let tags = expense.tags as? Set<Tag> else { return false }
                return !tags.isDisjoint(with: selectedTags)
            }
        }
        
        return result
    }
    
    // Button label computed properties
    var categoryButtonLabel: String {
        if selectedCategories.isEmpty {
            return "Category"
        }
        if selectedCategories.count == 1 {
            return selectedCategories.first?.name ?? "Category"
        }
        return "\(selectedCategories.count) categories"
    }
    
    var tagButtonLabel: String {
        if selectedTags.isEmpty {
            return "Tags"
        }
        if selectedTags.count == 1 {
            return "#\(selectedTags.first?.name ?? "")"
        }
        return "\(selectedTags.count) tags"
    }
    
    var dateButtonLabel: String {
        if isDateFilterActive {
            return filterManager.formattedPeriod()
        }
        return "Dates"
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // Initialization
    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.viewContext = context
        
        // Initial data fetch
        fetchAllExpenses()
        checkForTags()
        
        // Set up observers for search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        // Set up observers for date changes
        filterManager.$selectedDate
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        filterManager.$endDate
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        filterManager.$isRangeMode
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Fetching
    
    func fetchAllExpenses() {
        // Reset for new fetch
        allExpenses = []
        currentPage = 0
        hasMoreData = true
        
        // Initial fetch
        loadMoreExpenses()
    }
    
    func loadMoreExpenses() {
        guard !isLoading && hasMoreData else { return }
        
        isLoading = true
        
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        // We fetch all expenses up to the current date
        fetchRequest.predicate = NSPredicate(format: "date <= %@", Date() as NSDate)
        
        // Set up pagination
        fetchRequest.fetchLimit = itemsPerPage
        fetchRequest.fetchOffset = currentPage * itemsPerPage
        
        Task {
            do {
                let fetchedExpenses = try await viewContext.perform {
                    try self.viewContext.fetch(fetchRequest)
                }
                
                await MainActor.run {
                    // If we got fewer items than requested, there's no more data
                    if fetchedExpenses.count < self.itemsPerPage {
                        self.hasMoreData = false
                    }
                    
                    // Add new expenses to our array
                    self.allExpenses.append(contentsOf: fetchedExpenses)
                    self.currentPage += 1
                    self.isLoading = false
                    self.objectWillChange.send()
                }
            } catch {
                print("Error fetching expenses: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.hasMoreData = false
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func resetFilters() {
        selectedCategories.removeAll()
        selectedTags.removeAll()
        searchText = ""
        isDateFilterActive = false
        checkForTags()
        objectWillChange.send()
    }
    
    func deleteExpense(_ expense: Expense) {
        ExpenseDataManager.shared.deleteExpense(expense)
        
        // Remove from our local array too
        if let index = allExpenses.firstIndex(of: expense) {
            allExpenses.remove(at: index)
        }
        
        selectedExpense = nil
        currentPage = 0  // Reset pagination when deleting
        objectWillChange.send()
    }
    
    func toggleCategoryFilter() {
        if !selectedCategories.isEmpty {
            selectedCategories.removeAll()
            objectWillChange.send()
        } else {
            showingCategoryFilter = true
        }
    }
    
    func toggleTagFilter() {
        if !selectedTags.isEmpty {
            selectedTags.removeAll()
            objectWillChange.send()
        } else {
            showingTagFilter = true
        }
    }
    
    func toggleDateFilter() {
        if isDateFilterActive {
            isDateFilterActive = false
            objectWillChange.send()
        } else {
            showingDateFilter = true
        }
    }
    
    // MARK: - Date Filter Methods
    
    func setDateFilter(startDate: Date, endDate: Date, isRangeMode: Bool) {
        if isRangeMode {
            filterManager.setDateRange(start: startDate, end: endDate)
        } else {
            filterManager.resetToSingleMonthMode(date: startDate)
        }
        
        isDateFilterActive = true
        objectWillChange.send()
    }
    
    func previousPeriod() {
        filterManager.changePeriod(next: false)
        objectWillChange.send()
    }
    
    func nextPeriod() {
        filterManager.changePeriod(next: true)
        objectWillChange.send()
    }
    
    func checkForTags() {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: fetchRequest)
            hasTags = count > 0
        } catch {
            print("Error checking for tags: \(error)")
            hasTags = false
        }
    }
    
    // MARK: - State Handlers
    
    func handleCategoryFilterDismiss() {
        objectWillChange.send()
    }
    
    func handleTagFilterDismiss() {
        objectWillChange.send()
    }
    
    func selectExpense(_ expense: Expense) {
        selectedExpense = expense
    }
}

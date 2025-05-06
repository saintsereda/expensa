//
//  BudgetRepository.swift
//  Expensa
//
//  Created on 01.05.2025.
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class BudgetRepository {
    static let shared = BudgetRepository()
    
    private let context: NSManagedObjectContext
    private let currencyManager: CurrencyManager
    
    @Published private(set) var isProcessing = false
    
    private init() {
        self.context = CoreDataStack.shared.context
        self.currencyManager = .shared
    }
    
    // MARK: - Create Operations
    
    func createBudget(amount: Decimal?, alertThreshold: Decimal? = nil) async throws -> Budget {
        guard !isProcessing else { throw BudgetManager.BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            // Validate current month budget doesn't exist
            guard !self.hasExistingBudgetForCurrentMonth() else {
                throw BudgetManager.BudgetError.budgetExistsForCurrentMonth
            }
            
            // Validate we have a default currency
            guard let defaultCurrency = self.currencyManager.defaultCurrency else {
                throw BudgetManager.BudgetError.noCurrencyAvailable
            }
            
            let budget = Budget(context: self.context)
            budget.id = UUID()
            
            // Handle optional amount
            if let amount = amount {
                guard amount > 0 else {
                    throw BudgetManager.BudgetError.invalidAmount
                }
                budget.amount = NSDecimalNumber(decimal: amount)
            }
            
            budget.startDate = Date()
            budget.budgetCurrency = defaultCurrency
            
            if let threshold = alertThreshold {
                guard threshold > 0,
                      let amount = amount,
                      threshold <= amount else {
                    throw BudgetManager.BudgetError.invalidThreshold
                }
                budget.alertThreshold = NSDecimalNumber(decimal: threshold)
            }
            
            try self.context.save()
            NotificationCenter.default.post(name: Notification.Name("BudgetUpdated"), object: nil)
            print("✅ Created new budget: \(amount?.description ?? "no amount") \(defaultCurrency.code ?? "unknown")")
            return budget
        }
    }
    
    func createFutureBudgets(from sourceBudget: Budget, months: Int = 6) async throws {
        guard !isProcessing else { throw BudgetManager.BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        print("📅 Starting future budget creation from source budget date: \(sourceBudget.startDate?.formatted() ?? "unknown")")
        
        return try await context.perform {
            let calendar = Calendar.current
            guard let startDate = sourceBudget.startDate else {
                print("❌ Source budget has no start date")
                throw BudgetManager.BudgetError.invalidDate
            }
            
            // Create budgets for specified number of months
            for month in 1...months {
                guard let futureDate = calendar.date(byAdding: .month, value: month, to: startDate) else {
                    print("❌ Failed to create date for month \(month)")
                    continue
                }
                
                print("📆 Creating budget for: \(futureDate.formatted())")
                
                // Check if budget already exists for this month
                if try self.hasBudgetForDate(futureDate) {
                    print("⚠️ Budget already exists for \(futureDate.formatted())")
                    continue
                }
                
                let futureBudget = Budget(context: self.context)
                futureBudget.id = UUID()
                futureBudget.startDate = futureDate
                futureBudget.amount = sourceBudget.amount
                futureBudget.budgetCurrency = sourceBudget.budgetCurrency
                futureBudget.alertThreshold = sourceBudget.alertThreshold
                
                // Copy category budgets if they exist
                if let categoryBudgets = sourceBudget.categoryBudgets as? Set<CategoryBudget> {
                    for categoryBudget in categoryBudgets {
                        let futureCategoryBudget = CategoryBudget(context: self.context)
                        futureCategoryBudget.category = categoryBudget.category
                        futureCategoryBudget.budget = futureBudget
                        futureCategoryBudget.budgetAmount = categoryBudget.budgetAmount
                        futureCategoryBudget.budgetCurrency = categoryBudget.budgetCurrency
                        futureCategoryBudget.categoryName = categoryBudget.categoryName
                        
                        let components = calendar.dateComponents([.year, .month], from: futureDate)
                        futureCategoryBudget.year = Int16(components.year ?? 0)
                        futureCategoryBudget.month = Int16(components.month ?? 0)
                    }
                }
                
                print("✅ Successfully created budget for \(futureDate.formatted())")
            }
            
            try self.context.save()
            print("💾 Saved all future budgets")
        }
    }
    
    func createNextMonthBudgetIfNeeded() async throws {
        guard !isProcessing else { throw BudgetManager.BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            let calendar = Calendar.current
            
            // Find the latest budget date
            let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
            fetchRequest.fetchLimit = 1
            
            guard let latestBudget = try self.context.fetch(fetchRequest).first,
                  let latestDate = latestBudget.startDate else {
                print("⚠️ No existing budgets found")
                return
            }
            
            // Calculate the target end date (should always be 6 months from current date)
            guard let targetEndDate = calendar.date(byAdding: .month, value: 6, to: Date()),
                  let startOfTargetMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: targetEndDate)) else {
                throw BudgetManager.BudgetError.invalidDate
            }
            
            // If latest budget is before our target end date, we need to create a new budget
            if calendar.compare(latestDate, to: startOfTargetMonth, toGranularity: .month) == .orderedAscending {
                // Get the month after the latest budget
                guard let newBudgetDate = calendar.date(byAdding: .month, value: 1, to: latestDate) else {
                    throw BudgetManager.BudgetError.invalidDate
                }
                
                print("🔄 Creating budget for: \(newBudgetDate.formatted())")
                
                // Create new budget
                let newBudget = Budget(context: self.context)
                newBudget.id = UUID()
                newBudget.startDate = newBudgetDate
                newBudget.amount = latestBudget.amount
                newBudget.budgetCurrency = latestBudget.budgetCurrency
                newBudget.alertThreshold = latestBudget.alertThreshold
                
                // Copy category budgets
                if let categoryBudgets = latestBudget.categoryBudgets as? Set<CategoryBudget> {
                    for categoryBudget in categoryBudgets {
                        let newCategoryBudget = CategoryBudget(context: self.context)
                        newCategoryBudget.category = categoryBudget.category
                        newCategoryBudget.budget = newBudget
                        newCategoryBudget.budgetAmount = categoryBudget.budgetAmount
                        newCategoryBudget.budgetCurrency = categoryBudget.budgetCurrency
                        newCategoryBudget.categoryName = categoryBudget.categoryName
                        
                        let components = calendar.dateComponents([.year, .month], from: newBudgetDate)
                        newCategoryBudget.year = Int16(components.year ?? 0)
                        newCategoryBudget.month = Int16(components.month ?? 0)
                    }
                }
                
                try self.context.save()
                print("✅ Successfully created budget for \(newBudgetDate.formatted())")
            } else {
                print("✅ Future budgets are up to date")
            }
        }
    }
    
    // MARK: - Update Operations
    
    func updateBudget(_ budget: Budget, amount: Decimal, alertThreshold: Decimal? = nil) async throws {
        guard !isProcessing else { throw BudgetManager.BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            // Validate amount
            guard amount > 0 else {
                throw BudgetManager.BudgetError.invalidAmount
            }
            
            // Get current budget's date
            guard let startDate = budget.startDate else {
                throw BudgetManager.BudgetError.invalidDate
            }
            
            // Update current budget
            budget.amount = NSDecimalNumber(decimal: amount)
            
            if let threshold = alertThreshold {
                guard threshold > 0, threshold <= amount else {
                    throw BudgetManager.BudgetError.invalidThreshold
                }
                budget.alertThreshold = NSDecimalNumber(decimal: threshold)
            } else {
                budget.alertThreshold = nil
            }
            
            // Update all future budgets
            let calendar = Calendar.current
            let futureBudgets = try self.context.fetch(Budget.fetchRequest()).filter { futureBudget in
                guard let futureDate = futureBudget.startDate else { return false }
                return calendar.compare(futureDate, to: startDate, toGranularity: .month) == .orderedDescending
            }
            
            print("🔄 Updating \(futureBudgets.count) future budgets")
            
            for futureBudget in futureBudgets {
                futureBudget.amount = NSDecimalNumber(decimal: amount)
                futureBudget.alertThreshold = budget.alertThreshold
                
                if let futureDate = futureBudget.startDate {
                    print("✅ Updated budget for: \(futureDate.formatted())")
                }
            }
            
            try self.context.save()
            print("✅ Updated budget: \(amount) \(budget.budgetCurrency?.code ?? "unknown")")
        }
    }
    
    func updateBudgetAmountFromCategories(_ budget: Budget) async throws {
        print("🔄 Starting budget update from categories...")
        
        guard !isProcessing else {
            print("❌ Update skipped - operation in progress")
            throw BudgetManager.BudgetError.operationInProgress
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        guard let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> else {
            print("❌ No category budgets found")
            return
        }
        
        let totalAmount = categoryBudgets.reduce(Decimal(0)) { total, categoryBudget in
            total + (categoryBudget.budgetAmount?.decimalValue ?? 0)
        }
        
        print("📊 Current budget amount: \(budget.amount?.decimalValue ?? 0)")
        print("📊 Total category amount: \(totalAmount)")
        
        // Only update if category total is higher
        if totalAmount > (budget.amount?.decimalValue ?? 0) {
            print("🔄 Updating budget amount...")
            do {
                budget.amount = NSDecimalNumber(decimal: totalAmount)
                try context.save()
                print("✅ Successfully updated budget amount to: \(totalAmount)")
            } catch {
                print("❌ Failed to update budget: \(error.localizedDescription)")
                throw error
            }
        } else {
            print("ℹ️ No update needed - category total is not higher than budget")
        }
    }
    
    func saveCategoryBudgets(for budget: Budget, categoryLimits: [Category: String]) async throws {
        guard !isProcessing else { throw BudgetManager.BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            // First get all future budgets that were created from this budget
            let calendar = Calendar.current
            guard let startDate = budget.startDate else { return }
            
            // Get all budgets from this month forward
            let futureBudgets = try self.context.fetch(Budget.fetchRequest()).filter { futureBudget in
                guard let futureDate = futureBudget.startDate else { return false }
                return calendar.compare(futureDate, to: startDate, toGranularity: .month) != .orderedAscending
            }
            
            print("📊 Creating category budgets for \(futureBudgets.count) budgets")
            
            // Process each budget (current and future)
            for currentBudget in futureBudgets {
                // Remove existing category budgets if updating
                if let existingCategoryBudgets = currentBudget.categoryBudgets as? Set<CategoryBudget> {
                    for categoryBudget in existingCategoryBudgets {
                        self.context.delete(categoryBudget)
                    }
                }
                
                // Create new category budgets
                for (category, limitString) in categoryLimits {
                    guard let amount = BudgetManager.shared.parseAmount(limitString) else { continue }
                    
                    let categoryBudget = CategoryBudget(context: self.context)
                    categoryBudget.category = category
                    categoryBudget.budget = currentBudget
                    categoryBudget.budgetAmount = NSDecimalNumber(decimal: amount)
                    categoryBudget.budgetCurrency = self.currencyManager.defaultCurrency
                    categoryBudget.categoryName = category.name
                    
                    guard let budgetDate = currentBudget.startDate else { continue }
                    let components = calendar.dateComponents([.year, .month], from: budgetDate)
                    categoryBudget.year = Int16(components.year ?? 0)
                    categoryBudget.month = Int16(components.month ?? 0)
                    
                    print("✅ Created category budget for \(category.name ?? "") in \(budgetDate.formatted())")
                }
            }
            
            try self.context.save()
            NotificationCenter.default.post(name: Notification.Name("BudgetUpdated"), object: nil)
            print("💾 Saved all category budgets")
        }
    }
    
    // MARK: - Delete Operations
    
    func deleteBudget(_ budget: Budget) async throws {
        guard !isProcessing else { throw BudgetManager.BudgetError.operationInProgress }
        isProcessing = true
        defer { isProcessing = false }
        
        return try await context.perform {
            // Get the start date of the budget to be deleted
            guard let startDate = budget.startDate else {
                throw BudgetManager.BudgetError.invalidDate
            }
            
            // Find all budgets from this month forward
            let calendar = Calendar.current
            let budgetsToDelete = try self.context.fetch(Budget.fetchRequest()).filter { futureBudget in
                guard let futureDate = futureBudget.startDate else { return false }
                // Include budgets that are in the same month or later
                return calendar.compare(futureDate, to: startDate, toGranularity: .month) != .orderedAscending
            }
            
            print("🗑️ Deleting \(budgetsToDelete.count) budgets starting from: \(startDate.formatted())")
            
            // Delete each budget and its category budgets
            for budgetToDelete in budgetsToDelete {
                // Clean up category budgets first
                if let categoryBudgets = budgetToDelete.categoryBudgets as? Set<CategoryBudget> {
                    for categoryBudget in categoryBudgets {
                        self.context.delete(categoryBudget)
                    }
                }
                
                // Delete the budget
                self.context.delete(budgetToDelete)
                
                if let date = budgetToDelete.startDate {
                    print("✅ Deleted budget for: \(date.formatted())")
                }
            }
            
            try self.context.save()
            print("💾 Successfully deleted all budgets")
        }
    }
    
    // MARK: - Query Operations
    
    func getCurrentMonthBudget() async -> Budget? {
        return await context.perform {
            let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
            fetchRequest.predicate = self.currentMonthPredicate
            fetchRequest.fetchLimit = 1
            return try? self.context.fetch(fetchRequest).first
        }
    }
    
    func getBudgetFor(month date: Date) async -> Budget? {
        return await context.perform {
            let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
            
            // Create a predicate based on the specified month
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            
            fetchRequest.predicate = NSPredicate(
                format: "startDate >= %@ AND startDate <= %@",
                startOfMonth as NSDate,
                endOfMonth as NSDate
            )
            fetchRequest.fetchLimit = 1
            
            return try? self.context.fetch(fetchRequest).first
        }
    }
    
    // MARK: - Helper Methods
    
    private func hasExistingBudgetForCurrentMonth() -> Bool {
        let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
        fetchRequest.predicate = currentMonthPredicate
        let count = (try? context.count(for: fetchRequest)) ?? 0
        return count > 0
    }
    
    private var currentMonthPredicate: NSPredicate {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )
    }
    
    private func hasBudgetForDate(_ date: Date) throws -> Bool {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let fetchRequest: NSFetchRequest<Budget> = Budget.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )
        
        let count = try context.count(for: fetchRequest)
        return count > 0
    }
}


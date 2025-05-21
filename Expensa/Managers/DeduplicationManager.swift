import Foundation
import CoreData

class DeduplicationManager {
    static let shared = DeduplicationManager()
    private let context: NSManagedObjectContext
    
    private init() {
        self.context = CoreDataStack.shared.context
    }
    
    // Main method to clean up duplicates - renamed to match how it's called elsewhere
    func cleanupDuplicates(completion: @escaping (Int, Int) -> Void) {
        let backgroundContext = CoreDataStack.shared.persistentContainer.newBackgroundContext()
        backgroundContext.perform {
            let categoryCount = self.deduplicateCategories(in: backgroundContext)
            let currencyCount = self.deduplicateCurrencies(in: backgroundContext)
            
            do {
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                    print("✅ Deduplication save successful")
                }
                
                DispatchQueue.main.async {
                    completion(categoryCount, currencyCount)
                }
            } catch {
                print("❌ Error saving after deduplication: \(error)")
                DispatchQueue.main.async {
                    completion(0, 0)
                }
            }
        }
    }
    
    private func deduplicateCategories(in context: NSManagedObjectContext) -> Int {
        print("🔍 Finding and merging duplicate categories...")
        
        // Use name as the unique identifier
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let allCategories = try context.fetch(fetchRequest)
            print("📊 Found \(allCategories.count) total categories")
            
            // Group by name (case insensitive)
            var groupedByName: [String: [Category]] = [:]
            
            for category in allCategories {
                guard let name = category.name?.lowercased(), !name.isEmpty else { continue }
                
                if groupedByName[name] == nil {
                    groupedByName[name] = []
                }
                groupedByName[name]!.append(category)
            }
            
            // Find duplicates (more than one category with same name)
            let duplicateGroups = groupedByName.filter { $0.value.count > 1 }
            
            var mergedCount = 0
            
            for (name, duplicates) in duplicateGroups {
                print("⚠️ Found \(duplicates.count) duplicates for category: \(name)")
                
                // Find the "best" category to keep (prefer older ones with data)
                var bestCategory = duplicates[0]
                
                // Try to find a category with expenses or earliest created date
                for duplicate in duplicates {
                    let hasExpenses = duplicate.expenses?.count ?? 0 > 0
                    let hasEarlierDate = (duplicate.createdAt ?? Date()) < (bestCategory.createdAt ?? Date())
                    
                    if hasExpenses || (hasEarlierDate && (bestCategory.expenses?.count ?? 0 == 0)) {
                        bestCategory = duplicate
                    }
                }
                
                // Transfer data from all duplicates to the best one
                for duplicate in duplicates {
                    if duplicate == bestCategory { continue }
                    
                    // Transfer expenses
                    if let expenses = duplicate.expenses as? Set<Expense> {
                        for expense in expenses {
                            expense.category = bestCategory
                        }
                    }
                    
                    // Transfer recurring expenses
                    if let recurringExpenses = duplicate.recurringExpense as? Set<RecurringExpense> {
                        for recurringExpense in recurringExpenses {
                            recurringExpense.category = bestCategory
                        }
                    }
                    
                    // Transfer category budgets
                    if let categoryBudgets = duplicate.categoryBudgets as? Set<CategoryBudget> {
                        for budget in categoryBudgets {
                            budget.category = bestCategory
                        }
                    }
                    
                    // If the duplicate has a better icon, copy it
                    if bestCategory.icon == nil && duplicate.icon != nil {
                        bestCategory.icon = duplicate.icon
                    }
                    
                    // Delete the duplicate
                    context.delete(duplicate)
                    mergedCount += 1
                }
            }
            
            print("✅ Merged \(mergedCount) duplicate categories")
            return mergedCount
            
        } catch {
            print("❌ Error deduplicating categories: \(error)")
            return 0
        }
    }
    
    private func deduplicateCurrencies(in context: NSManagedObjectContext) -> Int {
        print("🔍 Finding and merging duplicate currencies...")
        
        // Use code as the unique identifier
        let fetchRequest: NSFetchRequest<Currency> = Currency.fetchRequest()
        
        do {
            let allCurrencies = try context.fetch(fetchRequest)
            print("📊 Found \(allCurrencies.count) total currencies")
            
            // Group by code
            var groupedByCode: [String: [Currency]] = [:]
            
            for currency in allCurrencies {
                guard let code = currency.code?.uppercased(), !code.isEmpty else { continue }
                
                if groupedByCode[code] == nil {
                    groupedByCode[code] = []
                }
                groupedByCode[code]!.append(currency)
            }
            
            // Find duplicates (more than one currency with same code)
            let duplicateGroups = groupedByCode.filter { $0.value.count > 1 }
            
            var mergedCount = 0
            
            for (code, duplicates) in duplicateGroups {
                print("⚠️ Found \(duplicates.count) duplicates for currency: \(code)")
                
                // Find the "best" currency to keep (usually the oldest one)
                var bestCurrency = duplicates[0]
                
                // If any currency is the default one, prioritize that
                if let defaultCurrency = CurrencyManager.shared.defaultCurrency {
                    for duplicate in duplicates {
                        if duplicate.code == defaultCurrency.code {
                            bestCurrency = duplicate
                            break
                        }
                    }
                }
                
                // Check for any currency with relationships and prioritize it
                let currenciesWithRelationships = duplicates.filter { currency in
                    let hasRelationships =
                        (currency.budgets?.count ?? 0) > 0 ||
                        (currency.categoryBudgets?.count ?? 0) > 0 ||
                        (currency.currency != nil)
                    return hasRelationships
                }
                
                if !currenciesWithRelationships.isEmpty {
                    bestCurrency = currenciesWithRelationships.first!
                }
                
                // Transfer data from all duplicates to the best one
                for duplicate in duplicates {
                    if duplicate == bestCurrency { continue }
                    
                    // Transfer budgets
                    if let budgets = duplicate.budgets as? Set<Budget> {
                        for budget in budgets {
                            budget.budgetCurrency = bestCurrency
                            print("✳️ Transferred budget to best currency")
                        }
                    }
                    
                    // Transfer category budgets
                    if let categoryBudgets = duplicate.categoryBudgets as? Set<CategoryBudget> {
                        for budget in categoryBudgets {
                            budget.budgetCurrency = bestCurrency
                            print("✳️ Transferred category budget to best currency")
                        }
                    }
                    
                    // Transfer exchange rate history
                    if let exchangeRateHistory = duplicate.currency {
                        exchangeRateHistory.currency = bestCurrency
                        print("✳️ Transferred exchange rate history to best currency")
                    }
                    
                    // Ensure best currency has complete data
                    if bestCurrency.name == nil && duplicate.name != nil {
                        bestCurrency.name = duplicate.name
                    }
                    if bestCurrency.symbol == nil && duplicate.symbol != nil {
                        bestCurrency.symbol = duplicate.symbol
                    }
                    if bestCurrency.flag == nil && duplicate.flag != nil {
                        bestCurrency.flag = duplicate.flag
                    }
                    if bestCurrency.lastUpdated == nil && duplicate.lastUpdated != nil {
                        bestCurrency.lastUpdated = duplicate.lastUpdated
                    }
                    
                    // Delete the duplicate
                    context.delete(duplicate)
                    mergedCount += 1
                }
            }
            
            // Also check for invalid currencies (missing required fields)
            for currency in allCurrencies {
                var needsUpdate = false
                
                if currency.id == nil {
                    currency.id = UUID()
                    needsUpdate = true
                    print("⚠️ Fixed missing ID for currency: \(currency.code ?? "unknown")")
                }
                
                if currency.code == nil || currency.code!.isEmpty {
                    // Skip deletion of malformed currencies, just log them
                    print("⚠️ Found currency with missing code, will be skipped in views")
                }
                
                if currency.name == nil {
                    currency.name = currency.code ?? "Unknown Currency"
                    needsUpdate = true
                    print("⚠️ Fixed missing name for currency: \(currency.code ?? "unknown")")
                }
                
                if currency.symbol == nil {
                    currency.symbol = currency.code ?? "$"
                    needsUpdate = true
                    print("⚠️ Fixed missing symbol for currency: \(currency.code ?? "unknown")")
                }
                
                if currency.flag == nil {
                    currency.flag = "🌐"
                    needsUpdate = true
                    print("⚠️ Fixed missing flag for currency: \(currency.code ?? "unknown")")
                }
                
                if needsUpdate {
                    print("✅ Updated currency with missing fields: \(currency.code ?? "unknown")")
                }
            }
            
            print("✅ Merged \(mergedCount) duplicate currencies")
            return mergedCount
            
        } catch {
            print("❌ Error deduplicating currencies: \(error)")
            return 0
        }
    }
}

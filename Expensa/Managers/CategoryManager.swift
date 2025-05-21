//
//  CategoryManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import CoreData
import Foundation
import UIKit

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    private let context: NSManagedObjectContext
    
    private var cachedFrequentlyUsedCategories: [Category] = []
    private var lastCacheUpdate = Date(timeIntervalSince1970: 0)
    
    @Published var categories: [Category] = [] {
        didSet {
            print("📱 Categories updated, count: \(categories.count)")
        }
    }
    
    private var hasInitialized = false
    private var isReloading = false  // Add reload lock

    private init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
        DispatchQueue.main.async {
            self.loadInitialCategories()
        }
    }

    private func loadInitialCategories() {
        // Check if already loaded (prevents double initialization)
        guard !hasInitialized else {
            print("📱 CategoryManager already initialized, skipping load")
            return
        }
        
        // First, attempt to load existing categories from database
        reloadCategories()
        
        // Get device ID for tracking
        let deviceId = getDeviceIdentifier()
        let deviceInitKey = "categoriesInitialized-\(deviceId)"
        
        // Check if categories were loaded successfully
        if categories.isEmpty {
            // No categories found, add predefined categories immediately
            print("📱 No categories found, adding default categories")
            addPredefinedCategories()
            reloadCategories() // Reload after adding
            
            // Mark this device as initialized
            UserDefaults.standard.set(true, forKey: deviceInitKey)
        } else {
            // Categories already exist (either from initial creation or CloudKit)
            print("📱 Found \(categories.count) existing categories")
            UserDefaults.standard.set(true, forKey: deviceInitKey)
        }
        
        hasInitialized = true
    }

    // Helper method to get device identifier
    private func getDeviceIdentifier() -> String {
        let key = "device-unique-id"
        
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        
        // Create a new UUID
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    func getCategories() -> [Category] {
        // Return cached categories if available
        if !categories.isEmpty {
            return categories
        }
        
        // If empty, try one reload
        reloadCategories()
        return categories
    }
    
    // MARK: - Notification Helpers
    private func postCategoriesUpdatedNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("CategoriesUpdated"),
                object: nil
            )
        }
    }
    
    // MARK: - Category Usage Tracking
    private func getCategoryUsageKey(_ category: Category) -> String? {
        guard let id = category.id?.uuidString else { return nil }
        return "category_usage_\(id)"
    }
    
    func getUsageCount(for category: Category) -> Int {
        guard let key = getCategoryUsageKey(category) else { return 0 }
        return UserDefaults.standard.integer(forKey: key)
    }
    
    func incrementUsage(for category: Category) {
        guard let key = getCategoryUsageKey(category) else { return }
        let currentCount = getUsageCount(for: category)
        UserDefaults.standard.set(currentCount + 1, forKey: key)
    }
    
        
        // Update existing method with caching
    func getMostUsedCategories(limit: Int = 3) -> [Category] {
        // Return cached result if less than 5 minutes old
        let cacheAge = Date().timeIntervalSince(lastCacheUpdate)
        if !cachedFrequentlyUsedCategories.isEmpty && cacheAge < 300 {
            return cachedFrequentlyUsedCategories
        }
        
        // Get categories that have been used with expenses
        let categoriesWithExpenses = categories.filter { category in
            // Check if the category has any associated expenses
            if let expenses = category.expenses as? Set<Expense>, !expenses.isEmpty {
                return true
            }
            return false
        }
        
        // Sort by usage count and take the top 'limit' categories
        let result = categoriesWithExpenses
            .sorted { getUsageCount(for: $0) > getUsageCount(for: $1) }
            .prefix(limit)
            .filter { getUsageCount(for: $0) > 0 }
        
        cachedFrequentlyUsedCategories = Array(result)
        lastCacheUpdate = Date()
        return cachedFrequentlyUsedCategories
    }

    // MARK: - Add Predefined Categories with Icons
    func addPredefinedCategories() {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                self.addPredefinedCategories()
            }
            return
        }
        
        // Get device-specific key
        let deviceId = getDeviceIdentifier()
        let hasLoadedDefaults = UserDefaults.standard.bool(forKey: "hasLoadedDefaultCategories-\(deviceId)")
        
        guard !hasLoadedDefaults else {
            print("📱 Predefined categories already loaded on this device")
            return
        }
        
        // NO CloudKit CHECK - just add hardcoded categories
        print("📱 Adding predefined categories...")
        
        let predefinedCategories: [String: String] = [
            // Housing
            "Rent": "🏠",
            "Groceries": "🛒",
            "Utilities": "💡",
            "Transportation": "🚗",
            "Healthcare": "🩺",
            "Insurance": "🛡️",
            "Personal Care": "🧴",
            "Clothing": "👕",
            "Education": "🎓",
            "Entertainment": "🎉",
            "Pets": "🐾",
            "Gifts & Donations": "🎁",
            "Debt Repayment": "💳",
            "Travel": "✈️",
            "Home Maintenance": "🛠️",
            "Other": "♾️"
        ]

        context.performAndWait {
            for (categoryName, icon) in predefinedCategories {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", categoryName)
                fetchRequest.fetchLimit = 1

                // Only create if it doesn't already exist
                let count = (try? context.count(for: fetchRequest)) ?? 0
                if count == 0 {
                    let newCategory = Category(context: context)
                    newCategory.id = UUID()
                    newCategory.name = categoryName
                    newCategory.icon = icon
                    newCategory.createdAt = Date()
                    print("✅ Added category: \(categoryName) with icon: \(icon)")
                } else {
                    print("📱 Category '\(categoryName)' already exists")
                }
            }
            
            saveContext()
            UserDefaults.standard.set(true, forKey: "hasLoadedDefaultCategories-\(deviceId)")
        }
        
        print("📱 Finished adding predefined categories")
        reloadCategories()
    }

    // Helper to count existing categories
    private func countExistingCategories() -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        fetchRequest.resultType = .countResultType
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("❌ Error counting categories: \(error)")
            return 0
        }
    }
    
    
    func getNoCategoryCategory() -> Category? {
        print("⚠️ Warning: getNoCategoryCategory() is deprecated. This function now returns nil by design.")
        return nil
    }
    
//    func getNoCategoryCategory() -> Category? {
//        print("🔍 Looking for No Category...")
//
//        // First try to find in memory
//        if let existingCategory = categories.first(where: { $0.name == "No Category" }) {
//            print("✅ Found No Category in memory")
//            return existingCategory
//        }
//
//        // If not in memory, try to fetch from CoreData
//        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "name == %@", "No Category")
//        fetchRequest.fetchLimit = 1
//
//        do {
//            if let existingCategory = try context.fetch(fetchRequest).first {
//                print("✅ Found No Category in CoreData")
//                return existingCategory
//            }
//
//            // If not found in CoreData, create new one
//            print("📝 Creating new No Category...")
//            let noCategory = Category(context: context)
//            noCategory.id = UUID()
//            noCategory.name = "No Category"
//            noCategory.icon = "❓"
//            noCategory.createdAt = Date()
//
//            try context.save()
//            print("✅ Created No Category with ID: \(noCategory.id?.uuidString ?? "unknown")")
//
//            // Make sure to reload categories to include the new one
//            reloadCategories()
//
//            return noCategory
//        } catch {
//            print("❌ Error handling No Category: \(error)")
//            return nil
//        }
//    }
    
    // MARK: - Reload Categories
    func reloadCategories() {
        // Prevent concurrent reloads
        guard !isReloading else {
            print("📱 Skip reload - already in progress")
            return
        }
        
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.reloadCategories()
            }
            return
        }
        
        isReloading = true
        print("📱 Reloading categories...")
        
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.name, ascending: true),
            NSSortDescriptor(keyPath: \Category.createdAt, ascending: true)
        ]
        
        context.performAndWait {
            do {
                let fetchedCategories = try context.fetch(fetchRequest)
                self.categories = fetchedCategories
                print("✅ Categories reloaded successfully, count: \(fetchedCategories.count)")
                
                // Debug first few categories
                for (index, category) in fetchedCategories.prefix(3).enumerated() {
                    print("Category \(index): \(category.name ?? "unnamed") (\(category.icon ?? "no icon"))")
                }
            } catch {
                print("❌ Error reloading categories: \(error)")
                self.categories = []
            }
        }
        
        isReloading = false
    }
    
    private func cleanupInvalidCategories() {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let allCategories = try context.fetch(fetchRequest)
            var needsSave = false
            
            for category in allCategories {
                if category.id == nil {
                    category.id = UUID()
                    needsSave = true
                    print("✅ Fixed missing ID for category: \(category.name ?? "unnamed")")
                }
                
                if category.name == nil || category.name!.isEmpty {
                    category.name = "Category \(category.id?.uuidString.prefix(4) ?? "Unknown")"
                    needsSave = true
                    print("✅ Fixed missing name for category: \(category.id?.uuidString ?? "unknown ID")")
                }
                
                if category.icon == nil {
                    category.icon = "🔹"
                    needsSave = true
                    print("✅ Fixed missing icon for category: \(category.name ?? "unnamed")")
                }
                
                if category.createdAt == nil {
                    category.createdAt = Date()
                    needsSave = true
                    print("✅ Fixed missing creation date for category: \(category.name ?? "unnamed")")
                }
            }
            
            if needsSave {
                try context.save()
                print("✅ Saved fixes for invalid categories")
                // Reload categories after fixing
                reloadCategories()
            }
        } catch {
            print("❌ Error cleaning up invalid categories: \(error)")
        }
    }

    // MARK: - Add Custom Category
    func addCustomCategory(name: String, icon: String? = nil) {
        guard !name.isEmpty else { return }

        print("📱 Adding custom category: \(name)")
        let newCategory = Category(context: context)
        newCategory.id = UUID()
        newCategory.name = name
        newCategory.icon = icon ?? "🔹"
        newCategory.createdAt = Date()

        saveContext()
        reloadCategories()
        postCategoriesUpdatedNotification()
    }
    
    // MARK: - Update Category
    func updateCategory(_ category: Category, name: String, icon: String) {
        guard !name.isEmpty else { return }
        
        print("📱 Updating category: \(name)")
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", category.id! as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let categoryToUpdate = results.first {
                categoryToUpdate.name = name
                categoryToUpdate.icon = icon
                
                saveContext()
                reloadCategories()
                postCategoriesUpdatedNotification()
                print("✅ Successfully updated category: \(name)")
            } else {
                print("❌ Category not found for update")
            }
        } catch {
            print("❌ Error updating category: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Category
    func deleteCategory(_ category: Category) {
        print("📱 Deleting category: \(category.name ?? "unknown")")
        context.delete(category)
        saveContext()
        reloadCategories()
        postCategoriesUpdatedNotification()
    }
    
    // MARK: - Batch Delete Categories
    func deleteCategories(_ categories: Set<Category>) {
        let context = CoreDataStack.shared.context
        
        context.perform {
            for category in categories {
                // Update associated expenses
                if let expenses = category.expenses as? Set<Expense> {
                    for expense in expenses {
                        expense.category = nil
                    }
                }
                
                // Delete the category
                context.delete(category)
            }
            
            // Save changes
            do {
                try context.save()
                
                // Notify observers on the main thread
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                    self.postCategoriesUpdatedNotification()
                }
            } catch {
                print("❌ Error deleting categories: \(error)")
                context.rollback()
            }
        }
        postCategoriesUpdatedNotification()
    }
    
    // MARK: - Fetch Specific Category
    func fetchCategory(withId id: UUID) -> Category? {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("❌ Error fetching specific category: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Fetch All Categories
    func fetchCategories() -> [Category] {
        // Ensure we're on the main thread
        
        if !categories.isEmpty {
            return categories
        }
        
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                return self.fetchCategories()
            }
        }
        
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        
        var result: [Category] = []
        context.performAndWait {
            do {
                result = try context.fetch(fetchRequest)
                print("📱 Fetched \(result.count) categories")
            } catch {
                print("❌ Error fetching categories: \(error.localizedDescription)")
            }
        }
        return result
    }
    
    // MARK: - Reset Categories
    func resetCategories() {
        print("📱 Resetting all categories")
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Category.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            saveContext()
            UserDefaults.standard.removeObject(forKey: "hasLoadedDefaultCategories")
            categories = []
            print("✅ Successfully reset categories")
            
            // Reload predefined categories
            addPredefinedCategories()
            reloadCategories()
            postCategoriesUpdatedNotification()
        } catch {
            print("❌ Error resetting categories: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers
    private func saveContext() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                self.saveContext()
            }
            return
        }
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Context saved successfully")
            } catch {
                print("❌ Error saving context: \(error.localizedDescription)")
            }
        }
    }
}

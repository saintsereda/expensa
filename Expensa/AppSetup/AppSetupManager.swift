//
//  AppSetupManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 09.11.2024.
//

import SwiftUI
import BackgroundTasks
import CoreData
import AppIntents
import CloudKit
import UIKit

class AppSetupManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupBackgroundTasks()
    }
    
    // Primary entry point for app initialization
    func performInitialSetup() {
        print("📱 Starting application setup...")
        
        // Generate a unique device identifier
        let deviceId = getDeviceIdentifier()
        
        // Device-specific initialization flag
        let initKey = "initialSetupCompleted-\(deviceId)"
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: initKey)
        
        if hasCompletedSetup {
            print("📱 Setup already completed on this device")
            
            // Always run deduplication on app start as a safety measure
            DeduplicationManager.shared.cleanupDuplicates { categoryCount, currencyCount in
                if categoryCount > 0 || currencyCount > 0 {
                    print("✅ Cleaned up \(categoryCount) categories and \(currencyCount) currencies")
                    
                    // Reload managers if anything was cleaned up
                    CategoryManager.shared.reloadCategories()
                    self.printEntityCounts()
                }
            }
            
            // Continue with normal startup tasks
            setupInitialData()
            setupCurrencyTasks()
            return
        }
        
        // First-time setup - need to wait for CloudKit
        CloudKitSyncMonitor.shared.waitForInitialSync { [weak self] syncSucceeded in
            guard let self = self else { return }
            
            // First run deduplication to clean up any CloudKit duplicates
            DeduplicationManager.shared.cleanupDuplicates { categoryCount, currencyCount in
                print("🧹 Initial deduplication complete: cleaned \(categoryCount) categories and \(currencyCount) currencies")
                
                // Now check if we already have data
                if self.checkForExistingData() {
                    print("📱 Found existing data from CloudKit, skipping initial data creation")
                } else {
                    print("📱 No existing data found, adding initial data")
                    self.setupInitialData()
                }
                
                // Continue with other tasks
                self.setupCurrencyTasks()
                
                // Mark setup as completed for this device
                UserDefaults.standard.set(true, forKey: initKey)
                
                // Print diagnostic info
                self.printEntityCounts()
            }
        }
    }
    
    // In AppSetupManager.setupInitialData()
    private func setupInitialData() {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try context.count(for: fetchRequest)
            if count == 0 {
                print("📱 No categories found, adding predefined categories")
                CategoryManager.shared.addPredefinedCategories()
                
                try context.save()
                CategoryManager.shared.reloadCategories()
                
                // Mark this device as initialized
                let deviceId = getDeviceIdentifier()
                UserDefaults.standard.set(true, forKey: "categoriesInitialized-\(deviceId)")
                
                print("📱 Predefined categories setup complete")
                let verifyCount = try context.count(for: fetchRequest)
                print("📱 Categories after setup: \(verifyCount)")
            } else {
                print("📱 Found existing categories: \(count)")
                // Still mark as initialized
                let deviceId = getDeviceIdentifier()
                UserDefaults.standard.set(true, forKey: "categoriesInitialized-\(deviceId)")
            }
        } catch {
            print("❌ Error setting up initial categories: \(error)")
        }
    }
    
    func setupShortcuts() {
        if #available(iOS 16.0, *) {
            // No need to call `updateAppShortcuts()`; just defining the AppShortcutsProvider is sufficient.
            print("✅ App Shortcuts set up successfully")
        }
    }
    
    // Helper to check if we have existing data
    private func checkForExistingData() -> Bool {
        let categoryCount = countEntities(ofType: "Category")
        let currencyCount = countEntities(ofType: "Currency")
        
        print("📱 Found \(categoryCount) categories and \(currencyCount) currencies")
        
        // Return true if we have at least some data already
        return categoryCount > 0 && currencyCount > 0
    }
    
    // Helper to count entities
    private func countEntities(ofType entityName: String) -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.resultType = .countResultType
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("❌ Error counting \(entityName): \(error)")
            return 0
        }
    }
    
    // Helper to get a unique device ID
    private func getDeviceIdentifier() -> String {
        let key = "device-unique-id"
        
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        
        // Create a new unique ID
        let newId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    func setupBackgroundTasks() {
        print("Setting up background tasks...")
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.sereda.Expensa.recurringExpenses",
            using: .main
        ) { task in
            self.handleRecurringExpensesTask(task as! BGProcessingTask)
        }
        print("✅ Registered recurring expenses task")
        
        // Register budget task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.sereda.Expensa.automaticBudget",
            using: .main
        ) { task in
            BackgroundTaskManager.shared.handleAutomaticBudgetTask(task)
        }
        print("✅ Registered automatic budget task")
        
        // Only schedule tasks on a real device, not in simulator
        #if !targetEnvironment(simulator)
        BackgroundTaskManager.shared.scheduleAutomaticBudgetTask()
        #else
        print("⚠️ Skipping budget task scheduling in simulator")
        #endif
        
        // Register notification check task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.sereda.Expensa.notificationCheck",
            using: .main
        ) { task in
            self.handleNotificationCheckTask(task as! BGProcessingTask)
        }
        print("✅ Registered notification check task")
        
        #if !targetEnvironment(simulator)
        scheduleNotificationCheckTask()
        #else
        print("⚠️ Skipping notification task scheduling in simulator")
        #endif
    }
    
    func scheduleNotificationCheckTask() {
        let request = BGProcessingTaskRequest(identifier: "com.sereda.Expensa.notificationCheck")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        // Schedule to run once per day (24 hours)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600) // Check every 6 hours
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled notification check task")
        } catch {
            print("❌ Could not schedule notification check task: \(error)")
        }
    }
    
    func handleNotificationCheckTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Check for upcoming expenses that need notifications
        RecurringExpenseManager.shared.scheduleNotificationsForUpcomingExpenses()
        
        // Schedule the next check
        scheduleNotificationCheckTask()
        task.setTaskCompleted(success: true)
    }
    
    func scheduleRecurringExpensesTask() {
        #if targetEnvironment(simulator)
        print("⚠️ Skipping recurring expenses task scheduling in simulator")
        return
        #endif
        
        let request = BGProcessingTaskRequest(identifier: "com.sereda.Expensa.recurringExpenses")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        // Schedule for every 12 hours
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled recurring expenses task")
        } catch {
            print("❌ Could not schedule recurring expenses task: \(error)")
        }
    }
    
    func handleRecurringExpensesTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        Task {
            await RecurringExpenseManager.shared.generateUpcomingExpenses()
        }
        scheduleRecurringExpensesTask()
        task.setTaskCompleted(success: true)
    }
    
    func setupCurrencyTasks() {
        HistoricalRateManager.shared.fetchRatesIfNeeded()
        HistoricalRateManager.shared.debugRateFetching()
        scheduleHistoricalRateCleanup()
    }
    
    private func scheduleHistoricalRateCleanup() {
        let calendar = Calendar.current
        let now = Date()
        if calendar.component(.month, from: now) == 1 &&
            calendar.component(.day, from: now) == 1 {
            HistoricalRateManager.shared.performYearlyCleanup()
        }
    }
    
    private func handleHistoricalRatesCleanup(_ task: BGProcessingTask) {
        task.expirationHandler = {
            // Handle task expiration if needed
        }
        
        HistoricalRateManager.shared.performYearlyCleanup()
        scheduleNextYearlyCleanup()
        task.setTaskCompleted(success: true)
    }
    
    private func scheduleNextYearlyCleanup() {
        #if targetEnvironment(simulator)
        print("⚠️ Skipping yearly cleanup task scheduling in simulator")
        return
        #endif
        
        let request = BGProcessingTaskRequest(identifier: "com.sereda.Expensa.historicalRatesCleanup")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        let calendar = Calendar.current
        guard let nextYear = calendar.date(
            byAdding: .year,
            value: 1,
            to: calendar.startOfDay(for: Date())
        ),
        let nextCleanupDate = calendar.date(
            from: DateComponents(
                year: calendar.component(.year, from: nextYear),
                month: 1,
                day: 1
            )
        ) else {
            return
        }
        
        request.earliestBeginDate = nextCleanupDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled historical rates cleanup")
        } catch {
            print("❌ Could not schedule historical rates cleanup: \(error)")
        }
    }
    
    // Print diagnostic information
    func printCloudKitDiagnostics() {
        print("📊 CloudKit Diagnostics:")
        
        // Check account status
        CKContainer(identifier: "iCloud.com.sereda.Expensa").accountStatus { status, error in
            let statusString: String
            switch status {
            case .available: statusString = "Available ✅"
            case .noAccount: statusString = "No Account ❌"
            case .couldNotDetermine: statusString = "Could Not Determine ⚠️"
            case .restricted: statusString = "Restricted ⚠️"
            case .temporarilyUnavailable: statusString = "Temporarily Unavailable ⚠️"
            @unknown default: statusString = "Unknown (?)"
            }
            
            print("   Account Status: \(statusString)")
            
            if let error = error {
                print("   Error: \(error.localizedDescription)")
            }
            
            // Check record counts
            self.printEntityCounts()
        }
    }
    
    // Print entity counts for diagnostic purposes
    func printEntityCounts() {
        let context = CoreDataStack.shared.context
        
        let entities = ["Category", "Currency", "Expense", "Budget", "Tag", "ExchangeRateHistory"]
        
        print("📊 Entity Counts:")
        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            fetchRequest.resultType = .countResultType
            
            do {
                let count = try context.count(for: fetchRequest)
                print("   - \(entity): \(count)")
            } catch {
                print("   - \(entity): Error (\(error.localizedDescription))")
            }
        }
        
        // Check for duplicate categories
        do {
            let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
            let categories = try context.fetch(categoryRequest)
            
            let grouped = Dictionary(grouping: categories) { $0.name?.lowercased() ?? "" }
            let duplicates = grouped.filter { $0.value.count > 1 }
            
            if duplicates.isEmpty {
                print("   Duplicate Categories: None ✅")
            } else {
                print("   Duplicate Categories: \(duplicates.count) ⚠️")
                for (name, dups) in duplicates {
                    print("      - \(name): \(dups.count)")
                }
            }
        } catch {
            print("   Duplicate Categories: Error checking")
        }
        
        // Check for duplicate currencies
        do {
            let currencyRequest: NSFetchRequest<Currency> = Currency.fetchRequest()
            let currencies = try context.fetch(currencyRequest)
            
            let grouped = Dictionary(grouping: currencies) { $0.code?.uppercased() ?? "" }
            let duplicates = grouped.filter { $0.value.count > 1 }
            
            if duplicates.isEmpty {
                print("   Duplicate Currencies: None ✅")
            } else {
                print("   Duplicate Currencies: \(duplicates.count) ⚠️")
                for (code, dups) in duplicates {
                    print("      - \(code): \(dups.count)")
                }
            }
        } catch {
            print("   Duplicate Currencies: Error checking")
        }
    }
}

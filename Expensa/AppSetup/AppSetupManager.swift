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
import Intents // Add this if not present

class AppSetupManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupBackgroundTasks()
    }
    
    func performInitialSetup() {
        setupInitialData()
        setupCurrencyTasks()
    }
    
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
                
                print("📱 Predefined categories setup complete")
                let verifyCount = try context.count(for: fetchRequest)
                print("📱 Categories after setup: \(verifyCount)")
            } else {
                print("📱 Found existing categories: \(count)")
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
        BackgroundTaskManager.shared.scheduleAutomaticBudgetTask()
    }
    
    func scheduleRecurringExpensesTask() {
        let request = BGProcessingTaskRequest(identifier: "com.sereda.Expensa.recurringExpenses")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        // Schedule for every 12 hours
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule recurring expenses task: \(error)")
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
       // HistoricalRateManager.shared.scheduleMidnightUpdate()
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
        } catch {
            print("Could not schedule historical rates cleanup: \(error)")
        }
    }

}

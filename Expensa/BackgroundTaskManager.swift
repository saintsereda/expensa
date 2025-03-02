//
//  BackgroundTaskManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 29.10.2024.
//

import Foundation
import BackgroundTasks

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private init() {}
    
    func scheduleRecurringExpenseTask() {
        let calendar = Calendar.current
        
        // Get first day of next month
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.month! += 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let nextFirstDay = calendar.date(from: components) else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: "com.sereda.Expensa.recurringExpenses") // Update with your bundle ID
        request.earliestBeginDate = nextFirstDay
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule recurring expenses task: \(error)")
        }
    }
    
    private let budgetTaskIdentifier = "com.sereda.Expensa.automaticBudget"
    
    func scheduleAutomaticBudgetTask() {
        let calendar = Calendar.current
        
        // Get first day of next month
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.month! += 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let nextFirstDay = calendar.date(from: components) else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: budgetTaskIdentifier)
        request.earliestBeginDate = nextFirstDay
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled automatic budget task for: \(nextFirstDay.formatted())")
        } catch {
            print("❌ Could not schedule automatic budget task: \(error)")
        }
    }
    
    func handleAutomaticBudgetTask(_ task: BGTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                try await BudgetManager.shared.createNextMonthBudgetIfNeeded()
                scheduleAutomaticBudgetTask() // Schedule next task
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Failed to create next month's budget: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
}

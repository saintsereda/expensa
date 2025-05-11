//
//  NotificationViewModel.swift
//  Expensa
//
//  Created by Andrew Sereda on 10.05.2025.
//

import Foundation
import SwiftUI
import Combine
import CoreData

/// ViewModel for managing notification state and business logic
class NotificationViewModel: ObservableObject {
    @Published var isNotificationsEnabled = false {
        didSet {
            if oldValue != isNotificationsEnabled {
                saveSettings()
            }
        }
    }
    
    @Published var selectedTimes: Set<ReminderTime> = [] {
        didSet {
            if oldValue != selectedTimes {
                saveSettings()
            }
        }
    }
    
    @Published var customTime = Date() {
        didSet {
            saveSettings()
        }
    }
    
    // Recurring expense notification properties
    @Published var isRecurringExpenseNotificationsEnabled = false {
        didSet {
            if oldValue != isRecurringExpenseNotificationsEnabled {
                saveSettings()
                updateRecurringExpenseNotifications()
            }
        }
    }
    
    @Published var recurringExpenseNotificationTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date() {
        didSet {
            saveSettings()
            updateRecurringExpenseNotifications()
        }
    }
    
    @Published var recurringExpenseReminderDays = 1 {
        didSet {
            saveSettings()
            updateRecurringExpenseNotifications()
        }
    }
    
    private let repository: NotificationRepository
    private let notificationManager = NotificationManager.shared
    
    init(context: NSManagedObjectContext) {
        self.repository = NotificationRepository(context: context)
        loadSettings()
        checkNotificationStatus()
    }
    
    func loadSettings() {
            if let preferences = repository.loadNotificationPreferences() {
                isNotificationsEnabled = preferences.isNotificationsEnabled
                selectedTimes = preferences.selectedTimes
                customTime = preferences.customTime
                
                // Load recurring expense notification settings
                isRecurringExpenseNotificationsEnabled = preferences.isRecurringExpenseNotificationsEnabled
                recurringExpenseNotificationTime = preferences.recurringExpenseNotificationTime
                recurringExpenseReminderDays = preferences.recurringExpenseReminderDays
                
                // Reschedule notifications if enabled
                if isNotificationsEnabled {
                    updateNotifications()
                }
                
                if isRecurringExpenseNotificationsEnabled {
                    updateRecurringExpenseNotifications()
                }
            }
        }
        
        func saveSettings() {
            let preferences = NotificationPreferences(
                isNotificationsEnabled: isNotificationsEnabled,
                selectedTimes: selectedTimes,
                customTime: customTime,
                isRecurringExpenseNotificationsEnabled: isRecurringExpenseNotificationsEnabled,
                recurringExpenseNotificationTime: recurringExpenseNotificationTime,
                recurringExpenseReminderDays: recurringExpenseReminderDays
            )
            
            repository.saveNotificationPreferences(preferences)
        }
    
    func checkNotificationStatus() {
        notificationManager.checkPermissionStatus { authorized in
            self.isNotificationsEnabled = authorized
            self.saveSettings()
        }
    }
    
    func requestPermission() {
        notificationManager.requestPermission { success in
            self.isNotificationsEnabled = success
            self.saveSettings()
        }
    }
    
    func updateNotifications() {
            notificationManager.removeAllScheduledNotifications()
            
            if isNotificationsEnabled {
                for reminderTime in selectedTimes {
                    if reminderTime == .custom {
                        notificationManager.scheduleNotification(for: reminderTime, customTime: customTime)
                    } else {
                        notificationManager.scheduleNotification(for: reminderTime)
                    }
                }
            }
        }
    
    func sendTestNotification() {
            notificationManager.sendTestNotification()
        }
        
    func updateRecurringExpenseNotifications() {
        // First remove any existing notifications for recurring expenses
        RecurringExpenseManager.shared.removeAllRecurringExpenseNotifications()
        
        // Then schedule new ones if enabled
        if isNotificationsEnabled && isRecurringExpenseNotificationsEnabled {
            RecurringExpenseManager.shared.scheduleNotificationsForUpcomingExpenses()
        }
    }
        
        // Available reminder day options
        var reminderDayOptions: [Int] {
            return [1, 3, 5, 7]
        }
}

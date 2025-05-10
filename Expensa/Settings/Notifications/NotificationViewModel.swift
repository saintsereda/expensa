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
            
            // Reschedule notifications if enabled
            if isNotificationsEnabled {
                updateNotifications()
            }
        }
    }
    
    func saveSettings() {
        let preferences = NotificationPreferences(
            isNotificationsEnabled: isNotificationsEnabled,
            selectedTimes: selectedTimes,
            customTime: customTime
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
}

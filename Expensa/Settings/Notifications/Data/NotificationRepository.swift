//
//  NotificationRepository.swift
//  Expensa
//
//  Created by Andrew Sereda on 10.05.2025.
//

import Foundation
import CoreData
import Combine

/// Repository handling the storage and retrieval of notification preferences
class NotificationRepository {
    private let managedObjectContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    func loadNotificationPreferences() -> NotificationPreferences? {
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let userSettings = try managedObjectContext.fetch(fetchRequest).first ?? createUserSettings()
            
            if let preferencesData = userSettings.notificationPreferences {
                return try JSONDecoder().decode(NotificationPreferences.self, from: preferencesData)
            }
        } catch {
            print("Error loading notification settings: \(error)")
        }
        
        return nil
    }
    
    func saveNotificationPreferences(_ preferences: NotificationPreferences) {
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let userSettings = try managedObjectContext.fetch(fetchRequest).first ?? createUserSettings()
            
            userSettings.notificationPreferences = try JSONEncoder().encode(preferences)
            
            try managedObjectContext.save()
        } catch {
            print("Error saving notification settings: \(error)")
        }
    }
    
    private func createUserSettings() -> UserSettings {
            let userSettings = UserSettings(context: managedObjectContext)
            userSettings.id = UUID()
            userSettings.theme = "system"  // Default theme
            userSettings.timeZone = TimeZone.current.identifier  // Current time zone
            
            // Set default notification time to 10:00 AM
            let calendar = Calendar.current
            let defaultTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
            
            // Set initial notification preferences
            let initialPreferences = NotificationPreferences(
                isNotificationsEnabled: false,
                selectedTimes: [],
                customTime: Date(),
                isRecurringExpenseNotificationsEnabled: false,
                recurringExpenseNotificationTime: defaultTime,
                recurringExpenseReminderDays: 1
            )
            userSettings.notificationPreferences = try? JSONEncoder().encode(initialPreferences)
            
            do {
                try managedObjectContext.save()
            } catch {
                print("Error creating user settings: \(error)")
            }
            
            return userSettings
        }
}

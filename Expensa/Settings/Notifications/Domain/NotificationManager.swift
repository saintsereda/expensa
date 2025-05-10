//
//  NotificationManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 10.05.2025.
//

import UserNotifications
import Foundation
import Combine

/// Handles all notification-related operations
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func checkPermissionStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                completion(success)
            }
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for reminderTime: ReminderTime, customTime: Date? = nil) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminderTime.rawValue]
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Expense Reminder"
        content.body = reminderTime == .morning ?
            "Start your day by planning your expenses!" :
            "Don't forget to log today's expenses!"
        content.sound = .default
        
        var components = DateComponents()
        
        if reminderTime == .custom, let customTime = customTime {
            let calendar = Calendar.current
            components = calendar.dateComponents([.hour, .minute], from: customTime)
        } else {
            components.hour = reminderTime.hour
            components.minute = reminderTime.minute
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: reminderTime.rawValue,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func removeAllScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is how your expense reminder will look"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

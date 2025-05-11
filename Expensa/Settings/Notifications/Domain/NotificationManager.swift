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
                    
                    // If permission was granted, schedule recurring expense notifications
                    if success {
                        RecurringExpenseManager.shared.scheduleNotificationsForUpcomingExpenses()
                    }
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
    
    func removeScheduledNotifications(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.filter { $0.identifier.contains(identifier) }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
    
    func scheduleRecurringExpenseNotification(time: Date, reminderDays: Int) {
        let calendar = Calendar.current
        
        // Extract hour and minute components from the selected time
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        // Create a notification content
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Recurring Expense"
        content.body = "You have recurring expenses due in \(reminderDays) day\(reminderDays > 1 ? "s" : "")"
        content.sound = .default
        content.categoryIdentifier = "RECURRING_EXPENSE"
        
        // Create a calendar trigger that repeats daily at the specified time
        var triggerComponents = DateComponents()
        triggerComponents.hour = timeComponents.hour
        triggerComponents.minute = timeComponents.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        
        // Create and schedule the notification request
        let request = UNNotificationRequest(
            identifier: "recurringExpenseReminder-\(reminderDays)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling recurring expense notification: \(error.localizedDescription)")
            } else {
                print("Scheduled recurring expense notification for \(reminderDays) days before")
            }
        }
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

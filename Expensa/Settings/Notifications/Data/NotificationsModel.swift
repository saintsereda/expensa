//
//  NotificationsModel.swift
//  Expensa
//
//  Created by Andrew Sereda on 10.05.2025.
//

import Foundation

/// Structure to hold notification preferences for encoding/decoding
struct NotificationPreferences: Codable {
    var isNotificationsEnabled: Bool
    var selectedTimes: Set<ReminderTime>
    var customTime: Date
}

/// Represents different times for notification reminders
enum ReminderTime: String, CaseIterable, Codable {
    case morning = "Morning (9:00 AM)"
    case evening = "Evening (9:00 PM)"
    case custom = "Custom Time"
    
    var hour: Int {
        switch self {
        case .morning: return 9
        case .evening: return 21
        case .custom: return 12
        }
    }
    
    var minute: Int {
        return 0
    }
}

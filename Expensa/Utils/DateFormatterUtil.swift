//
//  DateFormatterUtil.swift
//  Expensa
//
//  Created by Andrew Sereda on 03.11.2024.
//

import Foundation
import SwiftUI

enum DateFormatType {
    case onlyMonth     // "MMMM yyyy" -> "January 2024"
    case fullMonth     // "MMMM yyyy" -> "January 2024"
    case shortMonth    // "MMM yyyy"  -> "Jan 2024"
    case dayMonthYear  // "dd MMM yyyy" -> "01 Jan 2024"
    case dayMonth      // "dd MMM" -> "01 Jan"
    case relative      // "Today", "Yesterday", etc.
    case custom(String)
    
    var format: String {
        switch self {
        case .onlyMonth:
            return "MMM"
        case .fullMonth:
            return "MMMM yyyy"
        case .shortMonth:
            return "MMM yyyy"
        case .dayMonthYear:
            return "dd MMM yyyy"
        case .dayMonth:
            return "dd MMM"
        case .relative:
            return "dd MMM yyyy"  // Fallback format for relative dates
        case .custom(let format):
            return format
        }
    }
}

final class DateFormatterUtil {
    static let shared = DateFormatterUtil()
    
    private var formatters: [String: DateFormatter] = [:]
    private let calendar = Calendar.current
    
    private init() {}
    
    func formatter(for type: DateFormatType) -> DateFormatter {
        let format = type.format
        
        if let existingFormatter = formatters[format] {
            return existingFormatter
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatters[format] = formatter
        return formatter
    }
    
    func string(from date: Date, format: DateFormatType) -> String {
        switch format {
        case .relative:
            return relativeString(from: date)
        default:
            return formatter(for: format).string(from: date)
        }
    }
    
    func date(from string: String, format: DateFormatType) -> Date? {
        return formatter(for: format).date(from: string)
    }
    
    // Get the letter for the frequency indicator
    func frequencyLetter(for frequency: String?) -> String {
        guard let frequency = frequency?.lowercased() else { return "m" }
        
        switch frequency {
        case "daily":
            return "D"
        case "weekly":
            return "W"
        case "monthly":
            return "M"
        case "yearly", "annually":
            return "Y"
        case "quarterly":
            return "Q"
        case "biweekly":
            return "B"
        default:
            // First letter of the frequency as fallback
            if let firstChar = frequency.first {
                return String(firstChar)
            }
            return "M" // Default to monthly
        }
    }
    
    // MARK: - Relative Date Formatting
    
    private func relativeString(from date: Date) -> String {
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        
        guard let days = calendar.dateComponents([.day], from: startOfToday, to: startOfDate).day else {
            return formatter(for: .dayMonthYear).string(from: date)
        }
        
        switch days {
        case 0:
            return "Today"
        case -1:
            return "Yesterday"
        default:
            // All other dates
            if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
                // This year
                let thisYearFormatter = DateFormatter()
                thisYearFormatter.dateFormat = "d MMM"
                return thisYearFormatter.string(from: date)
            } else {
                // Previous years
                return formatter(for: .dayMonthYear).string(from: date)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func startOfDay(for date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
    
    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    // MARK: - Recurring Expense Date Utilities
    
    /// Calculate the next date based on frequency
    func nextDate(from date: Date, frequency: String) -> Date? {
        print("\n📅 Calculating next date")
        print("From date: \(date)")
        
        // Get start of day in user's time zone
        let startOfDay = calendar.startOfDay(for: date)
        print("Start of day: \(startOfDay)")
        
        var dateComponent = DateComponents()
        
        switch frequency.lowercased() {
        case "daily":
            dateComponent.day = 1
            print("Adding 1 day")
        case "weekly":
            dateComponent.weekOfYear = 1
            print("Adding 1 week")
        case "monthly":
            dateComponent.month = 1
            print("Adding 1 month")
        case "yearly", "annually":
            dateComponent.year = 1
            print("Adding 1 year")
        case "quarterly":
            dateComponent.month = 3
            print("Adding 3 months")
        case "biweekly":
            dateComponent.day = 14
            print("Adding 14 days (biweekly)")
        default:
            print("❌ Invalid frequency: \(frequency)")
            return nil
        }
        
        let nextDate = calendar.date(byAdding: dateComponent, to: startOfDay)
        print("Next date calculated: \(nextDate ?? Date())")
        return nextDate
    }
    
    /// Get date interval for current month
    func currentMonthInterval() -> DateInterval {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        let endOfMonth = calendar.date(byAdding: .second, value: -1, to: nextMonth)!
        
        return DateInterval(start: startOfMonth, end: endOfMonth)
    }
}

// MARK: - Date Extensions
extension Date {
    func formatted(_ format: DateFormatType) -> String {
        return DateFormatterUtil.shared.string(from: self, format: format)
    }
}

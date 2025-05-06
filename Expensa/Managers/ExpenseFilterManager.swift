//
//  ExpenseFilterManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import Foundation
import CoreData

class ExpenseFilterManager: ObservableObject {
    // Primary date selection
    @Published var selectedDate: Date
    
    // Support for date range selection
    @Published var endDate: Date
    @Published var isRangeMode: Bool = false
    
    init() {
        self.selectedDate = Date()
        
        // Initialize endDate to end of current month
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth),
              let endOfMonth = calendar.date(byAdding: DateComponents(day: range.count - 1), to: startOfMonth) else {
            self.endDate = Date()
            return
        }
        
        self.endDate = calendar.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: endOfMonth
        ) ?? endOfMonth
    }
    
    // Original single month interval calculation
    func dateInterval(for date: Date) -> DateInterval {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: components) else {
            return DateInterval(start: Date(), duration: 86400)
        }
        
        // Get the range of the month
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth),
              let endOfMonth = calendar.date(byAdding: DateComponents(day: range.count - 1), to: startOfMonth) else {
            return DateInterval(start: startOfMonth, duration: 86400 * 30)
        }
        
        // Set time to beginning and end of day
        let startWithTime = calendar.startOfDay(for: startOfMonth)
        let endWithTime = calendar.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: endOfMonth
        ) ?? endOfMonth
        
        return DateInterval(start: startWithTime, end: endWithTime)
    }
    
    // Get the current interval (either month or range)
    func currentPeriodInterval() -> DateInterval {
        if isRangeMode {
            // Return custom range
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: selectedDate)
            let endDay = calendar.date(
                bySettingHour: 23,
                minute: 59,
                second: 59,
                of: endDate
            ) ?? endDate
            
            return DateInterval(start: startDay, end: endDay)
        } else {
            // Return single month interval
            return dateInterval(for: selectedDate)
        }
    }
    
    // Format the period for display
    func formattedPeriod() -> String {
         let dateFormatter = DateFormatter()
         
         if isRangeMode {
             // Get year and month components
             let calendar = Calendar.current
             let startYear = calendar.component(.year, from: selectedDate)
             let endYear = calendar.component(.year, from: endDate)
             let startMonth = calendar.component(.month, from: selectedDate)
             let endMonth = calendar.component(.month, from: endDate)
             
             // Check if it's actually just a single month period displayed as a range
             if startYear == endYear && startMonth == endMonth {
                 // It's a single month - display as "Month Year"
                 dateFormatter.dateFormat = "MMM yyyy"
                 return dateFormatter.string(from: selectedDate)
             } else if startYear == endYear {
                 // Same year format: "Jan - Apr 2025"
                 dateFormatter.dateFormat = "MMM"
                 let startMonthStr = dateFormatter.string(from: selectedDate)
                 let endMonthStr = dateFormatter.string(from: endDate)
                 dateFormatter.dateFormat = "yyyy"
                 let year = dateFormatter.string(from: selectedDate)
                 return "\(startMonthStr) - \(endMonthStr) \(year)"
             } else {
                 // Different years format: "Dec 2024 - Feb 2025"
                 dateFormatter.dateFormat = "MMM yyyy"
                 let startFormatted = dateFormatter.string(from: selectedDate)
                 let endFormatted = dateFormatter.string(from: endDate)
                 return "\(startFormatted) - \(endFormatted)"
             }
         } else {
             // Single month format: "January 2025"
             dateFormatter.dateFormat = "MMM yyyy"
             return dateFormatter.string(from: selectedDate)
         }
     }
    
    // Set a custom date range
    func setDateRange(start: Date, end: Date) {
        let calendar = Calendar.current
        
        // Set start to beginning of its day
        selectedDate = calendar.startOfDay(for: start)
        
        // Set end to end of its day
        endDate = calendar.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: end
        ) ?? end
        
        isRangeMode = true
    }
    
    func isMultiMonthPeriod() -> Bool {
        let calendar = Calendar.current
        
        // Get month/year components for start and end date
        let startComponents = calendar.dateComponents([.year, .month], from: selectedDate)
        let endComponents = calendar.dateComponents([.year, .month], from: endDate)
        
        // If year or month differs, it's a multi-month period
        return startComponents.year != endComponents.year ||
               startComponents.month != endComponents.month
    }
    
    // Set a month range (e.g., January - April 2025)
    func setMonthRange(startMonth: Int, startYear: Int, endMonth: Int, endYear: Int) {
        let calendar = Calendar.current
        
        var startComponents = DateComponents()
        startComponents.year = startYear
        startComponents.month = startMonth
        startComponents.day = 1
        
        var endComponents = DateComponents()
        endComponents.year = endYear
        endComponents.month = endMonth
        
        if let endMonthDate = calendar.date(from: endComponents) {
            // Get the last day of the end month
            guard let range = calendar.range(of: .day, in: .month, for: endMonthDate),
                  let lastDay = calendar.date(byAdding: DateComponents(day: range.count - 1), to: endMonthDate) else {
                return
            }
            
            if let startDate = calendar.date(from: startComponents) {
                setDateRange(start: startDate, end: lastDay)
            }
        }
    }
    
    // Return to single month mode
    func resetToSingleMonthMode(date: Date? = nil) {
        let dateToUse = date ?? selectedDate
        isRangeMode = false
        selectedDate = dateToUse
        
        // Update end date to match the month's end
        let interval = dateInterval(for: dateToUse)
        endDate = interval.end
    }
    
    // Change to next/previous period
    func changePeriod(next: Bool) {
        let calendar = Calendar.current
        
        if isRangeMode {
            // Calculate the duration of the current range
            let components = calendar.dateComponents([.day], from: selectedDate, to: endDate)
            let daysInRange = max(components.day ?? 30, 1) // Ensure at least 1 day
            
            // Create DateComponents for the shift
            var dateComponents = DateComponents()
            dateComponents.day = next ? daysInRange : -daysInRange
            
            // Apply the shift to both dates
            if let newStart = calendar.date(byAdding: dateComponents, to: selectedDate),
               let newEnd = calendar.date(byAdding: dateComponents, to: endDate) {
                
                // Don't allow going into the future
                if !next || newEnd <= Date() {
                    selectedDate = newStart
                    endDate = newEnd
                }
            }
        } else {
            // Shift by one month for single month mode
            if let newDate = calendar.date(
                byAdding: .month,
                value: next ? 1 : -1,
                to: selectedDate
            ) {
                // Don't allow going into the future
                if !next || newDate <= Date() {
                    selectedDate = newDate
                    // Update end date to match the month's end
                    let interval = dateInterval(for: newDate)
                    endDate = interval.end
                }
            }
        }
    }
}

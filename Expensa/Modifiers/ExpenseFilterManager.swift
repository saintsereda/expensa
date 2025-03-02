//
//  ExpenseFilterManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import Foundation
import CoreData

class ExpenseFilterManager: ObservableObject {
    @Published var selectedDate: Date
    
    init() {
        self.selectedDate = Date()
    }
    
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
}

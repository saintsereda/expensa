//
//  RecurringExpenseManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 29.10.2024.
//

import SwiftUI
import Foundation
import CoreData
import Combine

class RecurringExpenseManager: ObservableObject {
    static let shared = RecurringExpenseManager()
    private let context: NSManagedObjectContext
    
    @Published private(set) var activeTemplates: [RecurringExpense] = []
    @Published private(set) var isGeneratingExpenses = false
    
    private init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
        loadActiveTemplates()
    }
    
    // MARK: - Notification Management
        
        func scheduleNotificationsForUpcomingExpenses() {
            // First, get notification preferences from repository
            let repository = NotificationRepository(context: context)
            guard let preferences = repository.loadNotificationPreferences(),
                  preferences.isNotificationsEnabled &&
                  preferences.isRecurringExpenseNotificationsEnabled else {
                print("📱 Recurring expense notifications not enabled")
                return
            }
            
            // Get the reminder days before setting
            let reminderDays = preferences.recurringExpenseReminderDays
            let notificationTime = preferences.recurringExpenseNotificationTime
            
            print("📱 Checking for expenses due in \(reminderDays) days")
            
            // Calculate the range of dates to check for notifications
            // We want to find expenses that are due exactly N days from now
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let targetDate = calendar.date(byAdding: .day, value: reminderDays, to: today)!
            
            // Fetch templates that have a next due date matching our target date
            let fetchRequest: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "(status == %@) AND (notificationEnabled == YES) AND (nextDueDate >= %@) AND (nextDueDate < %@)",
                "Active",
                targetDate as NSDate,
                calendar.date(byAdding: .day, value: 1, to: targetDate)! as NSDate
            )
            
            do {
                let templates = try context.fetch(fetchRequest)
                
                if templates.isEmpty {
                    print("📱 No templates found with expenses due in \(reminderDays) days")
                    return
                }
                
                print("📱 Found \(templates.count) templates with expenses due in \(reminderDays) days")
                
                // Schedule notifications for these templates
                for template in templates {
                    scheduleNotificationFor(
                        template: template,
                        reminderDays: reminderDays,
                        notificationTime: notificationTime
                    )
                }
            } catch {
                print("❌ Error fetching templates for notifications: \(error)")
            }
        }
        
        private func scheduleNotificationFor(template: RecurringExpense, reminderDays: Int, notificationTime: Date) {
            guard let templateId = template.id,
                  let dueDate = template.nextDueDate,
                  let category = template.category else {
                return
            }
            
            // Extract the hour and minute from the notification time preference
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: notificationTime)
            
            // Create a date for the notification that combines the target date with the preferred time
            var notificationDateComponents = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: Date()))
            notificationDateComponents.hour = timeComponents.hour
            notificationDateComponents.minute = timeComponents.minute
            
            guard let notificationDate = calendar.date(from: notificationDateComponents) else { return }
            
            // Only schedule if notification time is in the future
            if notificationDate <= Date() {
                print("📱 Skipping notification for past time: \(notificationDate)")
                return
            }
            
            // Format the amount for the notification
            let amountString: String
            if let amount = template.amount?.decimalValue,
               let currencyCode = template.currency,
               let currency = CurrencyManager.shared.fetchCurrency(withCode: currencyCode) {
                amountString = CurrencyManager.shared.currencyConverter.formatAmount(amount, currency: currency)
            } else {
                amountString = "Unknown amount"
            }
            
            // Create the notification
            let content = UNMutableNotificationContent()
            content.title = "Upcoming Recurring Expense"
            content.body = "\(category.name ?? "An expense") of \(amountString) is due \(reminderDays == 1 ? "tomorrow" : "in \(reminderDays) days")"
            content.sound = .default
            
            // Create an identifier that includes the template ID to avoid duplicates
            let identifier = "recurringExpense-\(templateId.uuidString)"
            
            // Set up the trigger for the notification time
            let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            // Create and schedule the notification request
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling notification: \(error)")
                } else {
                    print("✅ Scheduled notification for \(template.category?.name ?? "expense") due on \(dueDate.formatted())")
                }
            }
        }
        
        func removeAllRecurringExpenseNotifications() {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let identifiers = requests.filter { $0.identifier.hasPrefix("recurringExpense-") }
                                         .map { $0.identifier }
                
                if !identifiers.isEmpty {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
                    print("📱 Removed \(identifiers.count) recurring expense notifications")
                }
            }
        }
    
    // MARK: - Template Management
    
    func loadActiveTemplates() {
        let fetchRequest: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", "Active")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.nextDueDate, ascending: true)]
        
        // Important: Reset the relationship fault
        fetchRequest.relationshipKeyPathsForPrefetching = ["expenses"]
        
        do {
            let templates = try context.fetch(fetchRequest)
            DispatchQueue.main.async {
                self.activeTemplates = templates
            }
        } catch {
            print("❌ Error loading active templates: \(error)")
            DispatchQueue.main.async {
                self.activeTemplates = []
            }
        }
    }
    
    func createRecurringExpense(
        amount: Decimal,
        category: Category,
        currency: String,
        frequency: String,
        startDate: Date,
        notes: String?,
        notificationEnabled: Bool = true
    ) -> RecurringExpense? {
        // Set template's next due date to start of day (midnight)
        let expenseDate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: startDate)!
        
        guard let defaultCurrency = CurrencyManager.shared.defaultCurrency,
              let sourceCurrency = CurrencyManager.shared.fetchCurrency(withCode: currency) else {
            print("❌ Currency setup invalid")
            return nil
        }
        
        let convertedAmount: Decimal?
        if currency != defaultCurrency.code {
            convertedAmount = CurrencyConverter.shared.convertAmount(
                amount,
                from: sourceCurrency,
                to: defaultCurrency,
                on: expenseDate
            )?.0
        } else {
            convertedAmount = amount
        }
        
        var template: RecurringExpense?
        
        context.performAndWait {
            template = RecurringExpense(context: context)
            
            template?.id = UUID()
            template?.amount = NSDecimalNumber(decimal: amount)
            template?.convertedAmount = convertedAmount.map { NSDecimalNumber(decimal: $0) }
            template?.currency = currency
            template?.frequency = frequency
            template?.notes = notes
            template?.category = category
            template?.status = "Active"
            template?.notificationEnabled = notificationEnabled
            template?.nextDueDate = expenseDate
            template?.createdAt = Date()
            template?.updatedAt = Date()
            
            do {
                try context.save()
            } catch {
                print("❌ Error saving template: \(error)")
                context.rollback()
                template = nil
                return
            }
            if notificationEnabled {
                let repository = NotificationRepository(context: context)
                if let preferences = repository.loadNotificationPreferences(),
                   preferences.isNotificationsEnabled &&
                    preferences.isRecurringExpenseNotificationsEnabled {
                    if let template = template {
                        scheduleNotificationFor(
                            template: template,
                            reminderDays: preferences.recurringExpenseReminderDays,
                            notificationTime: preferences.recurringExpenseNotificationTime
                        )
                    }
                }
            }
        }
        
        if let template = template, Calendar.current.isDateInToday(expenseDate) {
            context.performAndWait {
                guard let conversion = CurrencyConverter.shared.convertAmount(
                    amount,
                    from: sourceCurrency,
                    to: defaultCurrency,
                    on: expenseDate
                ) else {
                    print("❌ Currency conversion failed")
                    return
                }
                let convertedAmount = conversion.amount
                let conversionRate = conversion.rate
                
                // Create the expense with current time instead of midnight
                let now = Date()
                let calendar = Calendar.current
                let currentTimeExpenseDate = calendar.date(
                    bySettingHour: calendar.component(.hour, from: now),
                    minute: calendar.component(.minute, from: now),
                    second: calendar.component(.second, from: now),
                    of: calendar.startOfDay(for: startDate)
                )!
                
                let expense = Expense(context: context)
                expense.id = UUID()
                expense.amount = NSDecimalNumber(decimal: amount)
                expense.convertedAmount = NSDecimalNumber(decimal: convertedAmount)
                expense.conversionRate = NSDecimalNumber(decimal: conversionRate)
                expense.category = category
                expense.date = currentTimeExpenseDate  // Using current time instead of midnight
                expense.notes = notes
                expense.currency = currency
                expense.createdAt = Date()
                expense.updatedAt = Date()
                
                expense.isRecurring = true
                expense.recurrenceStatus = "Generated"
                expense.recurrenceType = frequency
                expense.recurringExpense = template
                expense.isPaid = true
                
                template.lastGeneratedDate = expenseDate  // This can still use midnight
                template.nextDueDate = calculateNextDate(from: expenseDate, frequency: frequency)
                
                do {
                    try context.save()
                    DispatchQueue.main.async {
                        self.loadActiveTemplates()
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ExpensesUpdated"),
                            object: nil
                        )
                    }
                } catch {
                    print("❌ Error saving expense: \(error)")
                    context.rollback()
                }
            }
        } else {
            DispatchQueue.main.async {
                self.loadActiveTemplates()
            }
        }
        
        return template
    }
    
    func generateUpcomingExpenses() {
        let fetchRequest: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@ AND nextDueDate <= %@",
                                           "Active", Date() as NSDate)
        
        do {
            let templates = try context.fetch(fetchRequest)
            for template in templates {
                if let nextDueDate = template.nextDueDate,
                   nextDueDate <= Date() {
                    createExpenseFromTemplate(template: template, forDate: nextDueDate)
                    
                    // Update template
                    template.lastGeneratedDate = nextDueDate
                    template.nextDueDate = calculateNextDate(from: nextDueDate,
                                                           frequency: template.frequency ?? "Monthly")
                    template.updatedAt = Date()
                }
            }
            saveContext()
            
            // Notify of changes
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ExpensesUpdated"),
                    object: nil
                )
            }
        } catch {
            print("❌ Error generating expenses: \(error)")
        }
    }
    
    private func shouldCreateExpenseFor(date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        return targetDate == today
    }
    
    func updateRecurringTemplate(
        template: RecurringExpense,
        amount: Decimal,
        category: Category,
        currency: String,
        frequency: String,
        startDate: Date,
        notes: String?,
        notificationEnabled: Bool
    ) -> Bool {
        guard let defaultCurrency = CurrencyManager.shared.defaultCurrency,
              let sourceCurrency = CurrencyManager.shared.fetchCurrency(withCode: currency) else {
            return false
        }
        
        // Calculate converted amount
        let convertedAmount: Decimal?
        if currency != defaultCurrency.code {
            convertedAmount = CurrencyConverter.shared.convertAmount(
                amount,
                from: sourceCurrency,
                to: defaultCurrency,
                on: startDate
            )?.0
        } else {
            convertedAmount = amount
        }
        
        let oldFrequency = template.frequency
        let oldStartDate = template.nextDueDate
        
        // Update template properties
        template.amount = NSDecimalNumber(decimal: amount)
        template.convertedAmount = convertedAmount.map { NSDecimalNumber(decimal: $0) }
        template.category = category
        template.currency = currency
        template.frequency = frequency
        template.notes = notes
        template.notificationEnabled = notificationEnabled
        template.updatedAt = Date()
        
        if oldFrequency != frequency || oldStartDate != startDate {
            // Delete all future expenses
            deleteFutureExpenses(for: template)
            
            // Update next due date
            template.nextDueDate = startDate
            
            // Only create expense if start date is today AND no expense exists for today
            if shouldCreateExpenseFor(date: startDate) && !hasExpenseForDate(template: template, date: startDate) {
                createExpenseFromTemplate(template: template, forDate: startDate)
            }
        }
        
        do {
            try context.save()
            return true
        } catch {
            print("❌ Error updating template: \(error)")
            context.rollback()
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateMissingExpenses(for template: RecurringExpense, from startDate: Date, to endDate: Date) {
        var currentDate = startDate
        
        while currentDate <= endDate {
            if !hasExpenseForDate(template: template, date: currentDate) {
                createExpenseFromTemplate(template: template, forDate: currentDate)
            }
            
            guard let nextDate = calculateNextDate(from: currentDate, frequency: template.frequency ?? "Monthly") else {
                break
            }
            currentDate = nextDate
        }
    }
    
    private func hasExpenseForDate(template: RecurringExpense, date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "recurringExpense == %@ AND date >= %@ AND date < %@",
            template,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        let count = try? context.count(for: fetchRequest)
        return (count ?? 0) > 0
    }
    
    private func deleteFutureExpenses(for template: RecurringExpense) {
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "recurringExpense == %@ AND date > %@",
            template,
            Date() as NSDate
        )
        
        do {
            let futureExpenses = try context.fetch(fetchRequest)
            for expense in futureExpenses {
                context.delete(expense)
            }
        } catch {
            print("❌ Error deleting future expenses: \(error)")
        }
        saveContext()
    }
    
    private func createExpenseFromTemplate(template: RecurringExpense, forDate date: Date) {
        print("\n📅 Creating recurring expense")
        print("Input date: \(date)")
        print("Is today: \(Calendar.current.isDateInToday(date))")
        print("Start of day: \(Calendar.current.startOfDay(for: date))")
        
        guard let defaultCurrency = CurrencyManager.shared.defaultCurrency,
              let amount = template.amount?.decimalValue,
              let currency = template.currency,
              let sourceCurrency = CurrencyManager.shared.fetchCurrency(withCode: currency) else {
            print("❌ Invalid template data")
            return
        }
        
        let now = Date()
        let calendar = Calendar.current
        let expenseDate = calendar.date(
            bySettingHour: calendar.component(.hour, from: now),
            minute: calendar.component(.minute, from: now),
            second: calendar.component(.second, from: now),
            of: calendar.startOfDay(for: date)
        )!
        print("Expense date set to: \(expenseDate)")

        guard let conversion = CurrencyConverter.shared.convertAmount(
            amount,
            from: sourceCurrency,
            to: defaultCurrency,
            on: expenseDate
        ) else {
            print("❌ Currency conversion failed")
            return
        }

        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = template.amount
        expense.convertedAmount = NSDecimalNumber(decimal: conversion.amount)
        expense.conversionRate = NSDecimalNumber(decimal: conversion.rate)
        expense.currency = template.currency
        expense.date = expenseDate  // Use expenseDate here
        expense.notes = template.notes
        expense.category = template.category
        
        expense.isRecurring = true
        expense.recurrenceStatus = "Generated"
        expense.recurrenceType = template.frequency
        expense.recurringExpense = template
        expense.isPaid = true
        
        expense.createdAt = Date()
        expense.updatedAt = Date()
        
        print("Final expense date: \(expense.date ?? Date())")
    }
    
    public func calculateNextDate(from date: Date, frequency: String) -> Date? {
        print("\n📅 Calculating next date")
        print("From date: \(date)")
        
        // Get start of day for the input date
        let startOfDay = Calendar.current.startOfDay(for: date)
        print("Start of day: \(startOfDay)")
        
        var dateComponent = DateComponents()
        
        switch frequency {
        case "Daily":
            dateComponent.day = 1
            print("Adding 1 day")
        case "Weekly":
            dateComponent.weekOfYear = 1
            print("Adding 1 week")
        case "Monthly":
            dateComponent.month = 1
            print("Adding 1 month")
        case "Yearly":
            dateComponent.year = 1
            print("Adding 1 year")
        default:
            print("❌ Invalid frequency: \(frequency)")
            return nil
        }
        
        let nextDate = Calendar.current.date(byAdding: dateComponent, to: startOfDay)
        print("Next date calculated: \(nextDate ?? Date())")
        return nextDate
    }
    
    func cleanupAndRegenerateFutureExpenses() {
        // Keep expenses up to today, and generate for next 2 months
        let today = Date()
        let twoMonthsFromNow = Calendar.current.date(byAdding: .month, value: 2, to: today)!
        
        // Fetch all active templates
        let fetchRequest: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", "Active")
        
        do {
            let templates = try context.fetch(fetchRequest)
            
            for template in templates {
                // Delete expenses beyond 2 months
                let futureFetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
                futureFetchRequest.predicate = NSPredicate(
                    format: "recurringExpense == %@ AND date > %@",
                    template,
                    twoMonthsFromNow as NSDate
                )
                
                let futureExpenses = try context.fetch(futureFetchRequest)
                for expense in futureExpenses {
                    context.delete(expense)
                }
                
                // Generate expenses up to 2 months from now
                if let nextDueDate = template.nextDueDate,
                   nextDueDate <= twoMonthsFromNow {
                    generateMissingExpenses(
                        for: template,
                        from: nextDueDate,
                        to: twoMonthsFromNow
                    )
                }
            }
            
            try context.save()
            
            // Notify of changes
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ExpensesUpdated"),
                    object: nil
                )
            }
        } catch {
            print("❌ Error in cleanup and regeneration: \(error)")
            context.rollback()
        }
    }
    
    private func saveContext() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("❌ Error saving context: \(error)")
            context.rollback()
        }
    }
}

extension RecurringExpenseManager {
    static func calculateMonthlyTotal(
        for recurringExpenses: [RecurringExpense],
        defaultCurrency: Currency,
        currencyConverter: CurrencyConverter
    ) -> Decimal {
        var monthlyTotal: Decimal = 0
        
        for template in recurringExpenses {
            guard let amount = template.amount?.decimalValue,
                  let currencyCode = template.currency else { continue }
            
            let amountToUse: Decimal
            if currencyCode == defaultCurrency.code {
                amountToUse = amount
            } else if let convertedAmount = template.convertedAmount?.decimalValue {
                amountToUse = convertedAmount
            } else {
                continue
            }
            
            // Apply frequency multiplier
            let monthlyAmount: Decimal
            switch template.frequency?.lowercased() {
            case "daily":
                monthlyAmount = amountToUse * 30
            case "weekly":
                monthlyAmount = amountToUse * 4.33
            case "yearly":
                monthlyAmount = amountToUse / 12
            default: // Monthly
                monthlyAmount = amountToUse
            }
            
            monthlyTotal += monthlyAmount
        }
        
        return monthlyTotal
    }
}

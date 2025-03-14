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
                
                let expense = Expense(context: context)
                expense.id = UUID()
                expense.amount = NSDecimalNumber(decimal: amount)
                expense.convertedAmount = NSDecimalNumber(decimal: convertedAmount)
                expense.conversionRate = NSDecimalNumber(decimal: conversionRate)
                expense.category = category
                expense.date = expenseDate
                expense.notes = notes
                expense.currency = currency
                expense.createdAt = Date()
                expense.updatedAt = Date()
                
                expense.isRecurring = true
                expense.recurrenceStatus = "Generated"
                expense.recurrenceType = frequency
                expense.recurringExpense = template
                expense.isPaid = true
                
                template.lastGeneratedDate = expenseDate
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
        
        // If frequency or date changed, we need to handle future expenses
        if oldFrequency != frequency || oldStartDate != startDate {
            // Delete future expenses
            deleteFutureExpenses(for: template)
            
            // Update next due date
            template.nextDueDate = startDate
            
            // Generate new future expenses
            generateMissingExpenses(
                for: template,
                from: startDate,
                to: Calendar.current.date(byAdding: .month, value: 2, to: Date())!
            )
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
        
        let expenseDate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date)!
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

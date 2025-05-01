//
//  ExpenseDataManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import CoreData
import Foundation

class ExpenseDataManager: ObservableObject {
    static let shared = ExpenseDataManager()
    @Published private(set) var isConverting = false
    private let context: NSManagedObjectContext
    private let tagManager = TagManager.shared
    private let syncManager = CloudKitSyncManager.shared

    private init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
    }
    
    // MARK: - Expense Calculations
    func calculateTotalAmount(for expenses: [Expense]) -> Decimal {
        expenses.reduce(Decimal(0)) { sum, expense in
            // Use convertedAmount if available (for expenses in different currencies),
            // otherwise use the original amount (for expenses in default currency)
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
    }
    
    func calculateCategoryAmount(for expenses: [Expense], category: String) -> Decimal {
        let categoryExpenses = expenses.filter { $0.category?.name == category }
        return calculateTotalAmount(for: categoryExpenses)
    }
    
    // Updated to use the consistent calculation
    func calculateCategoryPercentage(for categoryExpenses: [Expense], category: String, totalExpenses: [Expense]) -> Double {
        let totalAmount = calculateTotalAmount(for: totalExpenses)
        let categoryAmount = calculateTotalAmount(for: categoryExpenses)
        
        guard totalAmount > 0 else { return 0 }
        return (NSDecimalNumber(decimal: categoryAmount).doubleValue /
                NSDecimalNumber(decimal: totalAmount).doubleValue) * 100
    }
    
    func formatPercentage(percentage: Double, categoryAmount: Decimal, totalAmount: Decimal) -> String {
        let numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            return formatter
        }()
        
        if categoryAmount == totalAmount {
            return "100%"
        } else if percentage < 0.1 {
            return "<0.1%"
        } else if percentage >= 99.9 {
            return "99.9%"
        } else if percentage < 1 {
            return "<1%"
        }
        return "\(numberFormatter.string(from: NSNumber(value: percentage)) ?? "0")%"
    }
    
    func getCategoryRowData(for category: Category, expenses: [Expense], totalExpenses: Decimal) -> (amount: Decimal, percentage: Double, percentageDisplay: String, count: Int) {
        let categoryExpenses = expenses.filter { $0.category == category }
        let categoryAmount = calculateTotalAmount(for: categoryExpenses)
        let percentage = calculatePercentage(categoryAmount: categoryAmount, totalAmount: totalExpenses)
        let percentageDisplay = formatPercentage(percentage: percentage, categoryAmount: categoryAmount, totalAmount: totalExpenses)
        
        return (
            amount: categoryAmount,
            percentage: percentage,
            percentageDisplay: percentageDisplay,
            count: categoryExpenses.count
        )
    }
    
    // Calculate percentage that a category represents of total expenses
    func calculatePercentage(categoryAmount: Decimal, totalAmount: Decimal) -> Double {
        guard totalAmount > 0 else { return 0 }
        let calculated = (NSDecimalNumber(decimal: categoryAmount).doubleValue /
                NSDecimalNumber(decimal: totalAmount).doubleValue) * 100
        
        if calculated < 0.1 {
            return 0.1 // Show at least 0.1% if there's any amount
        } else if calculated >= 99.9 {
            // Only show 100% if the amounts are exactly equal
            return categoryAmount == totalAmount ? 100 : 99.9
        }
        return calculated
    }

    // MARK: - CRUD Operations
    @MainActor
    func addExpense(
        amount: Decimal,
        category: Category?,
        date: Date,
        notes: String?,
        currency: Currency,
        tags: Set<Tag>
    ) -> Bool {
        guard let defaultCurrency = CurrencyManager.shared.defaultCurrency else {
            print("❌ No default currency set")
            return false
        }
        
        // Use unified conversion method with appropriate fallback behavior
        // For past dates, we don't want to fall back to current rates
        // Use the updated method that returns the rate
        let conversionResult = CurrencyConverter.shared.convertAmount(
            amount,
            from: currency,
            to: defaultCurrency,
            on: date
        )
        
        guard let convertedAmount = conversionResult?.amount,
              let conversionRate = conversionResult?.rate else {
            print("❌ Currency conversion failed")
            return false
        }
        
        let newExpense = Expense(context: context)
        newExpense.id = UUID()
        newExpense.amount = NSDecimalNumber(decimal: amount)
        newExpense.convertedAmount = NSDecimalNumber(decimal: convertedAmount)
        newExpense.conversionRate = NSDecimalNumber(decimal: conversionRate)
        newExpense.category = category
        newExpense.date = date
        newExpense.notes = notes
        newExpense.currency = currency.code
        newExpense.createdAt = Date()
        newExpense.updatedAt = Date()
        
        newExpense.isPaid = true
        newExpense.isRecurring = false
        
        // Process tags within the same context
        if !tags.isEmpty {
            let processedTags = tags.map { tag -> Tag in
                if let name = tag.name {
                    if let existingTag = tagManager.findTag(name: name) {
                        return existingTag
                    } else {
                        return tagManager.createTag(name: name) ?? tag
                    }
                }
                return tag
            }
            newExpense.tags = NSSet(array: Array(processedTags))
        }
        
        do {
            try context.save()
            syncManager.queueExpenseForSync(newExpense)
            print("📋 Added expense and queued for sync")
            return true
        } catch {
            print("❌ Error saving expense: \(error)")
            context.rollback()
            return false
        }
    }
    
    func updateExpense(
        _ expense: Expense,
        amount: Decimal,
        category: Category?,
        date: Date,
        notes: String?,
        currency: Currency,
        tags: Set<Tag>
    ) -> Bool {
        guard let defaultCurrency = CurrencyManager.shared.defaultCurrency else {
            print("❌ No default currency set")
            return false
        }
        
        // Use the same conversion logic as in addExpense
        // Use the updated method that returns the rate
        let conversionResult = CurrencyConverter.shared.convertAmount(
            amount,
            from: currency,
            to: defaultCurrency,
            on: date
        )
        
        guard let convertedAmount = conversionResult?.amount,
              let conversionRate = conversionResult?.rate else {
            print("❌ Currency conversion failed")
            return false
        }
        
        expense.amount = NSDecimalNumber(decimal: amount)
        expense.convertedAmount = NSDecimalNumber(decimal: convertedAmount)
        expense.conversionRate = NSDecimalNumber(decimal: conversionRate)
        expense.category = category
        expense.date = date
        expense.notes = notes
        expense.currency = currency.code
        expense.updatedAt = Date()
        
        expense.isPaid = true
        expense.isRecurring = false
        
        // Process tags within the same context
        if !tags.isEmpty {
            let processedTags = tags.map { tag -> Tag in
                if let name = tag.name {
                    if let existingTag = tagManager.findTag(name: name) {
                        return existingTag
                    } else {
                        return tagManager.createTag(name: name) ?? tag
                    }
                }
                return tag
            }
            expense.tags = NSSet(array: Array(processedTags))
        } else {
            expense.tags = nil
        }
        
        do {
            try context.save()
            syncManager.queueExpenseForSync(expense)
            print("📋 Added expense and queued for sync")
                    return true
        } catch {
            print("❌ Error updating expense: \(error)")
            context.rollback()
            return false
        }
    }

    func fetchExpenses(sortedBy sortDescriptors: [NSSortDescriptor] = [
        NSSortDescriptor(keyPath: \Expense.date, ascending: false)
    ]) -> [Expense] {
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.sortDescriptors = sortDescriptors

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching expenses: \(error)")
            return []
        }
    }

    func deleteExpense(_ expense: Expense) {
        if let expenseID = expense.id {
            // Queue the deletion for CloudKit sync
            syncManager.queueExpenseDeletion(expenseID)
            print("🗑️ Expense deletion queued for sync: \(expenseID.uuidString)")
        }
        context.delete(expense)
        saveContext()
    }
    
    func convertAllExpenses(from oldCurrency: Currency, to newCurrency: Currency) async {
        do {
            try await CurrencyConverter.shared.performBatchConversion(
                from: oldCurrency,
                to: newCurrency
            )
        } catch {
            print("❌ Currency conversion failed: \(error)")
        }
    }
     
    
    private func saveContext() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
            context.rollback()
        }
    }
}

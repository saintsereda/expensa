//
//  importData.swift
//  Expensa
//
//  Created by Andrew Sereda on 07.11.2024.
//

import Foundation
import CoreData
import UIKit

// Function to import expenses from CSV with completion handler
func importData(from url: URL, context: NSManagedObjectContext, completion: @escaping (Bool, Int) -> Void = { _, _ in }) {
    // Read and parse CSV on a background thread
    DispatchQueue.global(qos: .userInitiated).async {
        var rowsToImport = [String]()
        do {
            // Read the contents of the CSV file
            let csvData = try String(contentsOf: url, encoding: .utf8)
            // Split the data into rows by newline
            let rows = csvData.components(separatedBy: "\n")
            // Ensure the header is skipped and data rows are processed
            guard rows.count > 1 else {
                DispatchQueue.main.async {
                    completion(false, 0)
                }
                return
            }
            rowsToImport = Array(rows.dropFirst())
        } catch {
            print("❌ Failed to read CSV file: \(error)")
            DispatchQueue.main.async {
                completion(false, 0)
            }
            return
        }
        
        // Now perform all Core Data operations on the context’s queue
        context.perform {
            var importedCount = 0
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            // Fetch the default currency (this should be safe to do on the context queue)
            guard let defaultCurrency = CurrencyManager.shared.defaultCurrency else {
                print("❌ No default currency set")
                DispatchQueue.main.async {
                    completion(false, 0)
                }
                return
            }
            
            for row in rowsToImport {
                // Skip empty rows
                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                
                let columns = row.components(separatedBy: ",")
                // Check if the row has the expected number of columns
                guard columns.count >= 5 else { continue }
                
                // Extract and trim data from columns
                let date = dateFormatter.date(from: columns[0].trimmingCharacters(in: .whitespaces)) ?? Date()
                let categoryName = columns[1].trimmingCharacters(in: .whitespaces)
                let amount = Decimal(string: columns[2].trimmingCharacters(in: .whitespaces)) ?? 0.0
                let currencyCode = columns[3].trimmingCharacters(in: .whitespaces)
                let note = columns[4].trimmingCharacters(in: .whitespaces)
                
                // Fetch or create the currency
                guard let currency = CurrencyManager.shared.fetchCurrency(withCode: currencyCode) else {
                    print("❌ Currency \(currencyCode) not found, skipping row")
                    continue
                }
                
                // Convert the amount to the default currency
                let convertedAmount = CurrencyConverter.shared.convertAmount(
                    amount,
                    from: currency,
                    to: defaultCurrency,
                    on: date
                )?.amount ?? amount
                
                // Check if an expense with the same category, amount, converted amount, and date already exists
                let expenseFetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
                expenseFetchRequest.predicate = NSPredicate(
                    format: "category.name == %@ AND amount == %@ AND convertedAmount == %@ AND date == %@",
                    categoryName,
                    NSDecimalNumber(decimal: amount),
                    NSDecimalNumber(decimal: convertedAmount),
                    date as CVarArg
                )
                
                if let existingExpense = try? context.fetch(expenseFetchRequest).first, existingExpense != nil {
                    print("⚠️ Skipping duplicate expense: \(existingExpense)")
                    continue
                }
                
                // Create new Expense entity and set attributes
                let newExpense = Expense(context: context)
                newExpense.id = UUID()
                newExpense.date = date
                newExpense.amount = NSDecimalNumber(decimal: amount)
                newExpense.convertedAmount = NSDecimalNumber(decimal: convertedAmount)
                newExpense.currency = currencyCode
                newExpense.notes = note
                newExpense.isPaid = false
                newExpense.isRecurring = false
                newExpense.createdAt = Date()
                newExpense.updatedAt = Date()
                
                // Fetch or create the Category entity
                if let category = CategoryManager.shared.fetchCategories().first(where: { $0.name == categoryName }) {
                    newExpense.category = category
                } else {
                    CategoryManager.shared.addCustomCategory(name: categoryName)
                    if let newCategory = CategoryManager.shared.fetchCategories().first(where: { $0.name == categoryName }) {
                        newExpense.category = newCategory
                    }
                }
                
                // Parse tags if any and create Tag entities
                if columns.count > 5 {
                    let tagNames = columns[5].components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                    for tagName in tagNames where !tagName.isEmpty {
                        if let tag = TagManager.shared.findTag(name: tagName) {
                            newExpense.addToTags(tag)
                        } else if let newTag = TagManager.shared.createTag(name: tagName) {
                            newExpense.addToTags(newTag)
                        }
                    }
                }
                
                importedCount += 1
            }
            
            do {
                // Save the context on its designated queue
                try context.save()
                
                // Now update the UI on the main thread
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("ExpensesUpdated"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("CategoriesUpdated"), object: nil)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("✅ \(importedCount) expenses imported successfully.")
                        completion(true, importedCount)
                    }
                }
            } catch {
                print("❌ Failed to import data from CSV file: \(error)")
                DispatchQueue.main.async {
                    completion(false, 0)
                }
            }
        }
    }
}

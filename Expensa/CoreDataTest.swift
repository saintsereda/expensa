import UIKit
import CoreData

class CoreDataTest {
    func runTest() {
        // Create a sample Category
        let category = Category(context: CoreDataStack.shared.context)
        category.id = UUID()
        category.name = "Groceries"
        category.icon = "groceries_icon"
        category.budgetLimit = 500.0
        category.createdAt = Date()

        // Create a sample Tag
        let tag = Tag(context: CoreDataStack.shared.context)
        tag.id = UUID()
        tag.name = "Personal"
        tag.color = "#FF5733"
        tag.createdAt = Date()

        // Create a sample Expense
        let expense = Expense(context: CoreDataStack.shared.context)
        expense.id = UUID()
        expense.amount = 45.0
        expense.currency = "USD"
        expense.date = Date()
        expense.notes = "Bought fruits and vegetables"
        expense.isRecurring = false
        expense.isPaid = true
        expense.createdAt = Date()
        expense.updatedAt = Date()
        
        // Assign relationships
        expense.category = category
        expense.addToTags(tag) // Since this is a many-to-many relationship
        
        // Save to Core Data
        CoreDataStack.shared.saveContext()

        // Fetch all Expenses to verify
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        do {
            let expenses = try CoreDataStack.shared.context.fetch(fetchRequest)
            for exp in expenses {
                // Unwrap the optional values safely using nil-coalescing
                print("Expense ID: \(exp.id?.uuidString ?? "N/A")")
                print("Amount: \(exp.amount?.stringValue ?? "N/A")")  // Optional NSDecimalNumber
                print("Currency: \(exp.currency ?? "N/A")")  // Optional String
                print("Category: \(exp.category?.name ?? "No Category")")  // Optional relationship to Category
                print("Tags: \(exp.tags?.compactMap { ($0 as? Tag)?.name } ?? [])")  // Optional relationship to Tag
                print("Notes: \(exp.notes ?? "No Notes")")  // Optional String
                print("Created At: \(exp.createdAt ?? Date())")  // Optional Date
                print("Is Paid: \(exp.isPaid)")
            }
        } catch {
            print("Failed to fetch expenses: \(error)")
        }
    }
}

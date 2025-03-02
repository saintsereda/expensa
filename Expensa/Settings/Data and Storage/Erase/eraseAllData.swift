//
//  eraseAllData.swift
//  Expensa
//
//  Created by Andrew Sereda on 02.11.2024.
//

import Foundation
import CoreData

func eraseAllData(context: NSManagedObjectContext, completion: @escaping (Bool) -> Void = { _ in }) {
    let entityNames = [
        "Expense",
        "CategoryBudget",
        "Budget",
        "RecurringExpense",
        "Tag"
    ]
    
    DispatchQueue.global(qos: .userInitiated).async {
        context.perform {
            // Set merge policy to resolve conflicts by discarding in-memory changes
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            var overallSuccess = true
            
            for entityName in entityNames {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                batchDeleteRequest.resultType = .resultTypeObjectIDs
                
                do {
                    if let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult,
                       let objectIDs = result.result as? [NSManagedObjectID] {
                        
                        // Merge changes into the context
                        let changes = [NSDeletedObjectsKey: objectIDs]
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                    }
                    
                    print("✅ Successfully deleted all \(entityName) objects")
                    
                } catch {
                    print("❌ Error deleting \(entityName): \(error)")
                    overallSuccess = false
                }
            }
            
            do {
                try context.save()
                
                DispatchQueue.main.async {
                    // Post notifications for the UI updates
                    NotificationCenter.default.post(name: NSNotification.Name("ExpensesUpdated"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("CategoriesUpdated"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("BudgetsUpdated"), object: nil)
                    
                    // This is important for refreshing SwiftUI fetch requests
                    context.refreshAllObjects()
                    
                    // Force SwiftUI to refresh its views by posting a custom notification
                    NotificationCenter.default.post(name: NSNotification.Name("ForceViewRefresh"), object: nil)
                    
                    RecurringExpenseManager.shared.loadActiveTemplates()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        completion(overallSuccess)
                    }
                }
                
                print("✅ All data erased successfully")
            } catch {
                print("❌ Error saving context after deletion: \(error)")
                context.rollback()
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}

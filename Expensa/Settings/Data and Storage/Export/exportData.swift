//
//  exportExpensesToCSV.swift
//  Expensa
//
//  Created by Andrew Sereda on 02.11.2024.
//

import Foundation
import CoreData
import UIKit

// Save the last exported file path for deferred sharing
var lastExportedFilePath: URL?

// Main export function with completion handler
func exportData(
    context: NSManagedObjectContext,
    categories: [Category],
    startDate: Date? = nil,
    endDate: Date? = nil,
    completion: @escaping (Bool, String?) -> Void = { _, _ in }
) {
    let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
    
    // Create predicates array to combine multiple filters
    var predicates: [NSPredicate] = []
    
    // Add category filter if specified
    if !categories.isEmpty {
        predicates.append(NSPredicate(format: "category IN %@", categories))
    }
    
    // Add date range filter if specified
    if let start = startDate, let end = endDate {
        predicates.append(NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate))
    }
    
    // Combine predicates if we have multiple
    if predicates.count > 1 {
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    } else if predicates.count == 1 {
        fetchRequest.predicate = predicates.first
    }
    
    // Add sort descriptor to sort by date (ascending order)
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
    
    do {
        // Fetch expenses from Core Data
        let expenses = try context.fetch(fetchRequest)
        
        // Check if there are no expenses to export
        if expenses.isEmpty {
            print("No expenses to export.")
            // Return error message instead of showing alert
            completion(false, "No expenses to export for the selected filters.")
            return
        }
        
        // CSV Header
        var csvText = "Date,Category,Amount,Currency,Note,Tag\n"
        
        // Date formatter for the date field
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Iterate over fetched expenses and append each to CSV text
        for expense in expenses {
            let date = dateFormatter.string(from: expense.date ?? Date())
            let category = expense.category?.name ?? "Uncategorized"
            let amount = String(describing: expense.amount ?? 0.0)
            let currency = expense.currency ?? "Unknown Currency"
            let note = expense.notes?.replacingOccurrences(of: ",", with: " ") ?? ""
            
            // Convert tags from NSSet to [Tag] and join names
            let tagsArray = (expense.tags as? Set<Tag>) ?? []
            let tags = tagsArray.map { $0.name ?? "" }.joined(separator: ";")
            
            let row = "\(date),\(category),\(amount),\(currency),\(note),\(tags)\n"
            csvText.append(row)
        }
        
        // Create a more descriptive filename including date range
        let startDateStr = dateFormatter.string(from: startDate ?? Date())
        let endDateStr = dateFormatter.string(from: endDate ?? Date())
        let dateRangeStr = startDate != nil && endDate != nil ? "_\(startDateStr)_to_\(endDateStr)" : ""
        
        let fileName = "ExpensaExport\(dateRangeStr)_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)).csv"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        try csvText.write(to: path, atomically: true, encoding: .utf8)
        
        // Store the path for later sharing
        lastExportedFilePath = path
        
        // Add a small delay to simulate processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Notify completion with success
            completion(true, nil)
            
            // We'll handle the share sheet later
        }
        
    } catch {
        print("Failed to fetch expenses or write CSV file: \(error)")
        // Return error message instead of showing alert
        completion(false, "Failed to export data. Please try again.")
    }
}

// Function to show alerts
//func showAlert(message: String) {
//    DispatchQueue.main.async {
//        let alert = UIAlertController(title: "Export", message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .default))
//        
//        // Find the active scene to present the alert
//        if let windowScene = UIApplication.shared.connectedScenes
//            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
//            windowScene.windows.first?.rootViewController?.present(alert, animated: true)
//        }
//    }
//}

// Function to present the share sheet after dismissal of export sheet
func presentShareSheetAfterDismissal() {
    guard let fileURL = lastExportedFilePath else {
        print("No file URL available for sharing")
        return
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        shareFile(url: fileURL)
    }
}

// Function to present the share sheet
func shareFile(url: URL) {
    DispatchQueue.main.async {
        // Verify file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            print("File does not exist at path: \(url.path)")
            return
        }
        
        let activityView = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Handle iPad presentation
        if let popoverController = activityView.popoverPresentationController {
            popoverController.sourceView = UIApplication.shared.windows.first
            popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        // Find the active scene to present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Check if root view controller is already presenting something
            if let presented = rootViewController.presentedViewController {
                presented.present(activityView, animated: true)
            } else {
                rootViewController.present(activityView, animated: true)
            }
        }
    }
}

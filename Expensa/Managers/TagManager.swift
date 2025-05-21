//
//  TagManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import CoreData
import Foundation
import SwiftUI
import Combine

class TagManager: ObservableObject {
    static let shared = TagManager()
    private var context = CoreDataStack.shared.context
    
    @Published private(set) var tags: [Tag] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
        setupObservers()
        fetchAllTags()
    }
    
    // MARK: - Notification Helpers
    private func postTagsUpdatedNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("TagsUpdated"),
                object: nil
            )
        }
    }
    
    // MARK: - Fetch Operations
    func fetchAllTags() {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let fetchedTags = try context.fetch(request)
            tags = fetchedTags
        } catch {
            print("Error fetching tags: \(error)")
            tags = []
        }
    }
    
    func findTag(name: String) -> Tag? {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name.lowercased())
        request.fetchLimit = 1 // Optimization for single result
        return try? context.fetch(request).first
    }
    
    // MARK: - Tag Creation
    func createTag(name: String) -> Tag? {
        // First check if tag already exists
        if let existingTag = findTag(name: name) {
            return existingTag
        }
        
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name.lowercased()
        tag.color = generateRandomColor()
        tag.createdAt = Date()
        
        do {
            try context.save()
            postTagsUpdatedNotification()
            return tag
        } catch {
            print("Error saving tag: \(error)")
            return nil
        }
    }
    
    func createTemporaryTag(name: String) -> Tag {
        // Always try to reuse existing tag first
        if let existingTag = findTag(name: name) {
            return existingTag
        }
        
        // Create temporary tag without saving
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name.lowercased()
        tag.color = generateRandomColor()
        return tag
    }
    
    // MARK: - Tag Management
    func saveTempTags(_ tempTags: Set<Tag>) {
        // Process each tag
        for tempTag in tempTags {
            guard let name = tempTag.name?.lowercased(),
                  !name.isEmpty else { continue }
            
            // Only create if it doesn't exist
            if findTag(name: name) == nil {
                let tag = Tag(context: context)
                tag.id = UUID()
                tag.name = name
                tag.color = tempTag.color ?? generateRandomColor()
                tag.createdAt = Date()
            }
        }
        postTagsUpdatedNotification()
        saveContext()
    }
    
    func deleteTag(_ tag: Tag) {
        context.perform {
            // Store the tag name before deletion for text replacement
            let tagName = tag.name ?? ""
            
            // Remove tag from all associated expenses and update notes
            if let expenses = tag.expenses as? Set<Expense> {
                for expense in expenses {
                    // Remove the tag reference
                    expense.removeFromTags(tag)
                    
                    // Update notes text to remove the hashtag
                    if let notes = expense.notes {
                        // Remove the hashtag and any following whitespace
                        let updatedNotes = notes.replacingOccurrences(
                            of: "#\(tagName)\\s*",
                            with: "",
                            options: [.regularExpression]
                        )
                        expense.notes = updatedNotes
                    }
                }
            }
            
            // Delete the tag
            self.context.delete(tag)
            
            // Save changes
            do {
                try self.context.save()
            } catch {
                print("❌ Error deleting tag: \(error)")
                self.context.rollback()
                
                DispatchQueue.main.async {
                    self.postTagsUpdatedNotification()
                    print("Failed to delete tag: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Utilities
    func generateRandomColor() -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEEAD", "#D4A5A5", "#9B59B6", "#3498DB"]
        return colors.randomElement() ?? "#FF6B6B"
    }
    
    private func saveContext() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
            context.rollback() // Add rollback on error
        }
    }
    
    // MARK: - Observers
    private func setupObservers() {
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .filter { notification in
                let context = notification.object as? NSManagedObjectContext
                return context == self.context
            }
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.fetchAllTags()
                    self?.postTagsUpdatedNotification() // Add this line
                }
            }
            .store(in: &cancellables)
    }
}

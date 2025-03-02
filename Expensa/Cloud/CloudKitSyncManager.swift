//
//  CloudKitSyncManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 01.03.2025.
//

import Foundation
import CoreData
import CloudKit
import Combine
import UIKit

class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()
    
    // CloudKit manager instance
    private let cloudKitManager = CloudKitManager()
    
    // Debounce timer
    private var syncTimer: Timer?
    private let syncDelay: TimeInterval = 300 // 5 minutes in seconds
    
    // Pending expenses to sync
    private var pendingExpenses = Set<UUID>()
    
    // Deleted expenses to sync
    private var deletedExpenseIDs = Set<UUID>()
    
    // Activity indicator
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private init() {
        loadPendingOperations()
        
        // Register for app termination notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(savePendingOperations),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // Also save when entering background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(savePendingOperations),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    // MARK: - Queue Management
    
    func queueExpenseForSync(_ expense: Expense) {
        guard let id = expense.id else { return }
        pendingExpenses.insert(id)
        print("📝 Queued expense \(id.uuidString) for sync")
        scheduleSync()
    }
    
    func queueExpenseDeletion(_ expenseID: UUID) {
        // If it's a pending expense that hasn't been synced yet, just remove it from the queue
        if pendingExpenses.contains(expenseID) {
            pendingExpenses.remove(expenseID)
            print("📝 Removed expense \(expenseID.uuidString) from sync queue")
        } else {
            // Otherwise, add it to the deleted queue
            deletedExpenseIDs.insert(expenseID)
            print("🗑️ Queued expense \(expenseID.uuidString) for deletion")
        }
        scheduleSync()
    }
    
    // MARK: - Sync Scheduling
    
    private func scheduleSync() {
        // Cancel any existing timer
        syncTimer?.invalidate()
        
        print("⏱️ Scheduled sync in 5 minutes")
        
        // Schedule a new sync after the delay
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performSync()
            }
        }
    }
    
    // MARK: - Perform Sync
    
    @MainActor
    private func performSync() async {
        guard !isSyncing else { return }
        
        // No items to sync
        if pendingExpenses.isEmpty && deletedExpenseIDs.isEmpty {
            print("✓ No pending operations to sync")
            return
        }
        
        isSyncing = true
        syncError = nil
        
        print("🔄 Starting sync of \(pendingExpenses.count) expenses")
        
        do {
            // Convert UUIDs to Expense objects
            let context = CoreDataStack.shared.context
            let expenseIds = pendingExpenses
            
            for expenseId in expenseIds {
                let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", expenseId as CVarArg)
                fetchRequest.fetchLimit = 1
                
                let expenses = try context.fetch(fetchRequest)
                if let expense = expenses.first {
                    try await cloudKitManager.saveExpense(expense)
                    pendingExpenses.remove(expenseId)
                    print("✅ Synced expense \(expenseId.uuidString)")
                }
            }
            
            // Process deletions
            let expenseIDsToDelete = deletedExpenseIDs
            for expenseID in expenseIDsToDelete {
                do {
                    try await cloudKitManager.deleteExpense(withID: expenseID)
                    deletedExpenseIDs.remove(expenseID)
                    print("✅ Deleted expense \(expenseID.uuidString) from CloudKit")
                } catch {
                    print("❌ Failed to delete expense \(expenseID.uuidString): \(error)")
                    // Keep in queue for retry if it's a transient error
                }
            }
            
            // Update sync date
            lastSyncDate = Date()
            print("✅ Sync completed at \(lastSyncDate?.formatted() ?? "unknown time")")
            
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            print("❌ CloudKit sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    // Force immediate sync
    func forceSyncNow() {
        syncTimer?.invalidate()
        print("🔄 Forcing immediate sync")
        
        Task { @MainActor in
            await performSync()
        }
    }
    
    // Cancel pending syncs
    func cancelPendingSyncs() {
        syncTimer?.invalidate()
        pendingExpenses.removeAll()
        deletedExpenseIDs.removeAll()
        print("❌ Canceled all pending syncs")
        
        // Remove persisted operations
        UserDefaults.standard.removeObject(forKey: "PendingExpenseSyncs")
        UserDefaults.standard.removeObject(forKey: "PendingExpenseDeletions")
    }
    
    // MARK: - Persistence
    
    @objc private func savePendingOperations() {
        // Save pending additions
        if !pendingExpenses.isEmpty {
            let pendingExpenseStrings = pendingExpenses.map { $0.uuidString }
            UserDefaults.standard.set(pendingExpenseStrings, forKey: "PendingExpenseSyncs")
            print("💾 Saved \(pendingExpenses.count) pending expense syncs")
        } else {
            UserDefaults.standard.removeObject(forKey: "PendingExpenseSyncs")
        }
        
        // Save pending deletions
        if !deletedExpenseIDs.isEmpty {
            let deletedExpenseStrings = deletedExpenseIDs.map { $0.uuidString }
            UserDefaults.standard.set(deletedExpenseStrings, forKey: "PendingExpenseDeletions")
            print("💾 Saved \(deletedExpenseIDs.count) pending expense deletions")
        } else {
            UserDefaults.standard.removeObject(forKey: "PendingExpenseDeletions")
        }
    }
    
    private func loadPendingOperations() {
        // Load pending additions
        if let pendingExpenseStrings = UserDefaults.standard.stringArray(forKey: "PendingExpenseSyncs") {
            pendingExpenses = Set(pendingExpenseStrings.compactMap { UUID(uuidString: $0) })
            print("📂 Loaded \(pendingExpenses.count) pending expense syncs")
            
            if !pendingExpenses.isEmpty {
                scheduleSync()
            }
        }
        
        // Load pending deletions
        if let deletedExpenseStrings = UserDefaults.standard.stringArray(forKey: "PendingExpenseDeletions") {
            deletedExpenseIDs = Set(deletedExpenseStrings.compactMap { UUID(uuidString: $0) })
            print("📂 Loaded \(deletedExpenseIDs.count) pending expense deletions")
            
            if !deletedExpenseIDs.isEmpty {
                scheduleSync()
            }
        }
    }
}

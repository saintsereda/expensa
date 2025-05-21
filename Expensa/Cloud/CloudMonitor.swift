//
//  CloudMonitor.swift
//  Expensa
//
//  Created by Andrew Sereda on 21.05.2025.
//

import Foundation
import CloudKit
import CoreData

class CloudKitSyncMonitor {
    static let shared = CloudKitSyncMonitor()
    
    private let cloudKitContainer: CKContainer
    private let context: NSManagedObjectContext
    
    private init() {
        self.cloudKitContainer = CKContainer(identifier: "iCloud.com.sereda.Expensa")
        self.context = CoreDataStack.shared.context
        setupNotificationObservers()
    }
    
    // Status tracking
    private(set) var isSyncInProgress = false
    private(set) var lastSyncDate: Date?
    private(set) var hasInitialSyncCompleted = false
    
    // Sync completion handlers
    private var syncCompletionHandlers: [(Bool) -> Void] = []
    
    // Listen for CloudKit sync events
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange(_:)),
            name: NSNotification.Name.NSPersistentStoreRemoteChange,
            object: CoreDataStack.shared.persistentContainer.persistentStoreCoordinator
        )
    }
    
    @objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
        // A remote change happened (CloudKit sync occurred)
        print("📱 CloudKit sync change detected")
        
        isSyncInProgress = false
        lastSyncDate = Date()
        
        if !hasInitialSyncCompleted {
            hasInitialSyncCompleted = true
            print("✅ Initial CloudKit sync completed")
            
            // Notify all waiting handlers
            notifyCompletionHandlers(success: true)
        }
    }
    
    // Wait for initial sync before performing an action
    func waitForInitialSync(timeout: TimeInterval = 10.0, completion: @escaping (Bool) -> Void) {
        // If sync already completed, call completion immediately
        if hasInitialSyncCompleted {
            print("📱 Initial sync already completed, continuing")
            completion(true)
            return
        }
        
        print("⏳ Waiting for initial CloudKit sync...")
        
        // Check account status first
        checkAccountStatus { isAvailable in
            if !isAvailable {
                print("⚠️ CloudKit account not available, continuing without sync")
                self.hasInitialSyncCompleted = true
                completion(false)
                return
            }
            
            // Add completion handler to the queue
            self.syncCompletionHandlers.append(completion)
            
            // Set up a timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self = self else { return }
                
                // If sync still hasn't completed by timeout, force continuation
                if !self.hasInitialSyncCompleted {
                    print("⚠️ CloudKit sync timeout - continuing anyway")
                    self.hasInitialSyncCompleted = true
                    self.notifyCompletionHandlers(success: false)
                }
            }
        }
    }
    
    // Check CloudKit account status
    func checkAccountStatus(completion: @escaping (Bool) -> Void) {
        cloudKitContainer.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                let isAvailable = status == .available
                
                if !isAvailable {
                    print("⚠️ CloudKit account not available: \(status.rawValue)")
                    if let error = error {
                        print("⚠️ CloudKit error: \(error.localizedDescription)")
                    }
                }
                
                // If no account, mark sync as completed to avoid waiting
                if status == .noAccount {
                    self?.hasInitialSyncCompleted = true
                }
                
                completion(isAvailable)
            }
        }
    }
    
    // Notify all waiting handlers and clear the queue
    private func notifyCompletionHandlers(success: Bool) {
        let handlers = syncCompletionHandlers
        syncCompletionHandlers.removeAll()
        
        for handler in handlers {
            handler(success)
        }
    }
}

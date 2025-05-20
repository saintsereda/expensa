//
//  ExpensaApp.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI
import BackgroundTasks
import CoreData
import StoreKit

@main
struct ExpensaApp: App {
    let persistenceController = CoreDataStack.shared
    private let appSetupManager: AppSetupManager
    
    // MARK: - Environment Objects
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var currencyManager = CurrencyManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var recurringManager = RecurringExpenseManager.shared
    @StateObject private var tagManager = TagManager.shared
    @StateObject private var cloudKitManager = CloudKitManager()
    @StateObject private var cloudKitSyncManager = CloudKitSyncManager.shared // Add sync manager

    
    // MARK: - State
    @State private var isPasscodeSet = KeychainHelper.shared.getPasscode() != nil
    @State private var isPasscodeEntered = false
    
    // MARK: - Initialization
    init() {
        // Ensure CoreData stack is initialized first
        _ = persistenceController.context
        
        // Initialize app setup manager
        self.appSetupManager = AppSetupManager(context: CoreDataStack.shared.context)
        
        // Perform setup tasks that don't require StateObjects
        appSetupManager.performInitialSetup()
        appSetupManager.setupCurrencyTasks()
        appSetupManager.setupShortcuts()
        print("\n--- App Initialization ---")
        CurrencyManager.shared.debugCurrencies()
        // Register background tasks
        registerBackgroundTasks()
    }
    
    // MARK: - App's Main View
    var body: some Scene {
        WindowGroup {
            if isPasscodeSet && !isPasscodeEntered {
                PasscodeEntryView(isPasscodeEntered: $isPasscodeEntered)
            } else {
                ContentView()
                    .environmentObject(cloudKitManager)
                    .environmentObject(cloudKitSyncManager) // Add sync manager to environment
                    .environmentObject(categoryManager)
                    .preferredColorScheme(themeManager.selectedTheme.colorScheme)
                    .environmentObject(themeManager)
                    .environmentObject(currencyManager)
                    .environmentObject(recurringManager)
                    .environmentObject(tagManager)
                    .environment(\.managedObjectContext, persistenceController.context)
                    .onAppear {
                        // Move StateObject-dependent initialization here
                        setupAfterViewLoad()
                        Task {
                            await recurringManager.generateUpcomingExpenses()
                            
                            // Check iCloud status
                            await cloudKitManager.getiCloudStatus()
                        }
                        if categoryManager.categories.isEmpty {
                            print("⚠️ Categories empty on ContentView appear, attempting reload")
                            categoryManager.reloadCategories()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        Task {
                            await recurringManager.generateUpcomingExpenses()
                            try? await BudgetManager.shared.createNextMonthBudgetIfNeeded()
                            
                            // Force sync when app becomes active if there are pending changes
                            cloudKitSyncManager.forceSyncNow()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        // Optionally, force sync when app is going to background
                        // cloudKitSyncManager.forceSyncNow()
                    }
            }
        }
    }
    
    // MARK: - Setup After View Load
    private func setupAfterViewLoad() {
        // Generate recurring expenses after view and StateObjects are properly initialized
        Task {
            recurringManager.generateUpcomingExpenses()
            
            // Schedule notifications for upcoming recurring expenses
            // This will only run if notifications are enabled in settings
            recurringManager.scheduleNotificationsForUpcomingExpenses()
        }
    }
    
    // MARK: - Background Tasks
    private func registerBackgroundTasks() {
        // Register a background task for CloudKit sync
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.sereda.Expensa.cloudKitSync", using: nil) { task in
            handleCloudKitSyncTask(task as! BGProcessingTask)
        }
    }
    
    private func handleCloudKitSyncTask(_ task: BGProcessingTask) {
        // Create a task that forces a sync
        let syncTask = Task {
            cloudKitSyncManager.forceSyncNow()
        }
        
        // Setup expiration handler to cancel the task if needed
        task.expirationHandler = {
            syncTask.cancel()
            task.setTaskCompleted(success: false)
        }
        
        // Wait for the sync to complete
        Task {
            // Wait for a moment to ensure sync completes
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5 seconds
            task.setTaskCompleted(success: true)
            
            // Schedule the next background task
            scheduleCloudKitSyncTask()
        }
    }
    
    private func scheduleCloudKitSyncTask() {
        let request = BGProcessingTaskRequest(identifier: "com.sereda.Expensa.cloudKitSync")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled background CloudKit sync task")
        } catch {
            print("❌ Could not schedule CloudKit sync task: \(error)")
        }
    }
}

// Extension to add StoreKit configuration to the app
extension ExpensaApp {
    // Initialize StoreKit
    func configureStoreKit() {
        // Initialize the StoreManager
        _ = StoreManager.shared
        
        #if DEBUG
        // Set up transaction observer for debug purposes
        Task {
            // Process any pending transactions
            for await verification in Transaction.unfinished {
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
            }
            
            // Print debug info
            print("StoreKit configured! Available products:")
            do {
                let products = try await Product.products(for: TipProductID.all)
                for product in products {
                    print(" - \(product.id): \(product.displayPrice) - \(product.displayName)")
                }
            } catch {
                print("Failed to load products: \(error)")
            }
            
            // Print purchase history
            StoreManager.shared.printPurchaseHistory()
        }
        #endif
    }
    
    #if DEBUG
    // Add a debug method for testing StoreKit
    func testStoreKit() {
        print("=== Testing StoreKit Configuration ===")
        
        Task {
            do {
                let products = try await Product.products(for: TipProductID.all)
                print("Successfully loaded \(products.count) products:")
                for product in products {
                    print("- \(product.displayName): \(product.displayPrice)")
                }
                
                print("\nPurchase History:")
                StoreManager.shared.printPurchaseHistory()
                
            } catch {
                print("StoreKit test failed: \(error)")
            }
        }
    }
    #endif
}

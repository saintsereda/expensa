//
//  StoreManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 19.05.2025.
//

import Foundation
import StoreKit

class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var purchasedTips: [String: Int] = [:]
    @Published var purchaseHistory: [String: Date] = [:]
    
    // Transaction listener
    private var transactionListener: Task<Void, Error>?
    
    private init() {
        // Start listening for transactions
        startTransactionListener()
        
        // Load saved purchase history
        loadPurchaseHistory()
    }
    
    deinit {
        // Cancel the transaction listener when the manager is deallocated
        transactionListener?.cancel()
    }
    
    // Set up a transaction listener to handle transactions
    private func startTransactionListener() {
        transactionListener = Task.detached { [weak self] in
            // Iterate through unfinished transactions
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.handleVerificationResult(result)
                    
                    // Always finish the transaction
                    await transaction?.finish()
                } catch {
                    // Handle verification error
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func handleVerificationResult(_ result: VerificationResult<Transaction>) throws -> Transaction? {
        switch result {
        case .verified(let transaction):
            // The transaction is verified, add it to purchase history
            if transaction.revocationDate == nil {
                // Add to history
                DispatchQueue.main.async { [weak self] in
                    self?.recordPurchase(productID: transaction.productID)
                }
            }
            return transaction
            
        case .unverified:
            // The transaction couldn't be verified
            return nil
        }
    }
    
    // MARK: - Purchase Tracking
    
    /// Record a tip purchase
    func recordPurchase(productID: String) {
        // Update purchase count
        purchasedTips[productID] = (purchasedTips[productID] ?? 0) + 1
        
        // Record purchase time
        purchaseHistory[productID] = Date()
        
        // Save to UserDefaults
        savePurchaseHistory()
    }
    
    /// Load purchase history from UserDefaults
    private func loadPurchaseHistory() {
        if let savedPurchases = UserDefaults.standard.dictionary(forKey: "ExpensaTipPurchases") as? [String: Int] {
            purchasedTips = savedPurchases
        }
        
        // Load dates
        if let dateData = UserDefaults.standard.dictionary(forKey: "ExpensaTipPurchaseDates") as? [String: Double] {
            for (key, timeInterval) in dateData {
                purchaseHistory[key] = Date(timeIntervalSince1970: timeInterval)
            }
        }
        
        // Get past purchases from StoreKit
        Task {
            try? await loadPastTransactions()
        }
    }
    
    /// Save purchase history to UserDefaults
    private func savePurchaseHistory() {
        UserDefaults.standard.set(purchasedTips, forKey: "ExpensaTipPurchases")
        
        // Convert dates to timeIntervals for storage
        var dateData: [String: Double] = [:]
        for (key, date) in purchaseHistory {
            dateData[key] = date.timeIntervalSince1970
        }
        UserDefaults.standard.set(dateData, forKey: "ExpensaTipPurchaseDates")
    }
    
    /// Load past transactions from StoreKit
    func loadPastTransactions() async throws {
        // Get all past transactions from StoreKit
        let transactions = await Transaction.currentEntitlements
        
        for await result in transactions {
            // Handle the verification result
            _ = try handleVerificationResult(result)
        }
    }
    
    /// Get total amount of tips received
    var totalTipAmount: Decimal {
        var total: Decimal = 0
        
        // Small tips
        if let smallCount = purchasedTips[TipProductID.smallTip.rawValue] {
            total += Decimal(smallCount) * Decimal(0.99)
        }
        
        // Medium tips
        if let mediumCount = purchasedTips[TipProductID.mediumTip.rawValue] {
            total += Decimal(mediumCount) * Decimal(1.99)
        }
        
        // Large tips
        if let largeCount = purchasedTips[TipProductID.largeTip.rawValue] {
            total += Decimal(largeCount) * Decimal(4.99)
        }
        
        // XLarge tips
        if let xlargeCount = purchasedTips[TipProductID.xlargeTip.rawValue] {
            total += Decimal(xlargeCount) * Decimal(9.99)
        }
        
        return total
    }
    
    /// Get total number of tips received
    var totalTipCount: Int {
        purchasedTips.values.reduce(0, +)
    }
    
    /// Format the total amount as a currency string
    func formattedTotalAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        
        return formatter.string(from: totalTipAmount as NSDecimalNumber) ?? "$0.00"
    }
    
    // Debug methods for testing
    #if DEBUG
    func resetPurchaseHistory() {
        purchasedTips = [:]
        purchaseHistory = [:]
        savePurchaseHistory()
    }
    
    func simulatePurchase(productID: String) {
        recordPurchase(productID: productID)
    }
    
    func printPurchaseHistory() {
        print("=== Purchase History ===")
        for (productID, count) in purchasedTips {
            let dateString = purchaseHistory[productID]?.description ?? "unknown"
            print("\(productID): \(count) purchase(s), last on \(dateString)")
        }
        print("Total count: \(totalTipCount)")
        print("Total amount: \(formattedTotalAmount())")
        print("========================")
    }
    #endif
}

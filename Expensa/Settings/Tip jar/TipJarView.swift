//
//  TipJarView.swift
//  Expensa
//
//  Created by Andrew Sereda on 19.05.2025.
//

import SwiftUI
import StoreKit
import UIKit

/// Constants for tip product IDs
enum TipProductID: String {
    case smallTip = "com.sereda.Expensa.tip.small"    // $0.99
    case mediumTip = "com.sereda.Expensa.tip.medium"  // $1.99
    case largeTip = "com.sereda.Expensa.tip.large"    // $4.99
    case xlargeTip = "com.sereda.Expensa.tip.xlarge"  // $9.99
    
    static var all: [String] {
        return [
            smallTip.rawValue,
            mediumTip.rawValue,
            largeTip.rawValue,
            xlargeTip.rawValue
        ]
    }
}

struct TipItem: Identifiable {
    let id = UUID()
    let title: String
    var price: String
    let priceValue: Decimal
    let description: String
    var productId: String
    
    // Visual elements
    let emoji: String  // Changed from icon to emoji
    let color: Color
}

class TipJarViewModel: ObservableObject {
    @Published var tipItems: [TipItem] = [
        TipItem(
            title: "Kind Tip",
            price: "$0.99",
            priceValue: 0.99,
            description: "A small token of appreciation",
            productId: TipProductID.smallTip.rawValue,
            emoji: "☕️",
            color: .pink
        ),
        TipItem(
            title: "Great Tip",
            price: "$1.99",
            priceValue: 1.99,
            description: "Thanks for the support!",
            productId: TipProductID.mediumTip.rawValue,
            emoji: "🍰",
            color: .orange
        ),
        TipItem(
            title: "Amazing Tip",
            price: "$4.99",
            priceValue: 4.99,
            description: "Wow, you're incredible!",
            productId: TipProductID.largeTip.rawValue,
            emoji: "🥂",
            color: .yellow
        ),
        TipItem(
            title: "Outrageous Tip",
            price: "$9.99",
            priceValue: 9.99,
            description: "Your support means the world!",
            productId: TipProductID.xlargeTip.rawValue,
            emoji: "💎",
            color: .purple
        )
    ]
    
    @Published var isPurchasing = false
    @Published var showingThankYou = false
    @Published var purchasedTipTitle: String = ""
    
    @Published var products: [Product] = []
    @Published var error: String?
    
    @Published var purchaseStats: (count: Int, amount: String) = (0, "$0.00")
    
    private let storeManager = StoreManager.shared
    
    init() {
        // Initialize with default values for purchase stats
        // We'll update them properly when the view appears
        loadInitialStats()
        
        // Load products asynchronously
        Task {
            await loadProducts()
        }
    }
    
    private func loadInitialStats() {
        // Set initial stats directly without using the MainActor method
        let count = storeManager.totalTipCount
        let amount = storeManager.formattedTotalAmount()
        self.purchaseStats = (count, amount)
    }
    
    @MainActor
    func updatePurchaseStats() {
        purchaseStats = (
            storeManager.totalTipCount,
            storeManager.formattedTotalAmount()
        )
    }
    
    @MainActor
    func loadProducts() async {
        do {
            // Request products from the App Store
            products = try await Product.products(for: TipProductID.all)
            
            // Update displayed prices with actual values from App Store
            updatePricesFromProducts()
            
        } catch {
            self.error = error.localizedDescription
            print("Failed to load products: \(error)")
        }
    }
    
    @MainActor
    private func updatePricesFromProducts() {
        // Create a dictionary of products by their ID for easier lookup
        let productDict = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        
        // Update each tip item with its corresponding product info
        for i in 0..<tipItems.count {
            let productId = tipItems[i].productId
            if let product = productDict[productId] {
                tipItems[i].price = product.displayPrice
                
                // Debug: Print product matching
                print("Matched product: \(productId) -> \(product.displayPrice)")
            } else {
                // Debug: Print warning about missing product
                print("Warning: No product found for ID: \(productId)")
            }
        }
        
        // Debug: Print all loaded products
        print("Loaded \(products.count) products:")
        for product in products {
            print("- \(product.id): \(product.displayPrice)")
        }
    }
    
    // Purchase a tip
    func purchaseTip(_ tipItem: TipItem) {
        guard let product = products.first(where: { $0.id == tipItem.productId }) else {
            print("Product not found: \(tipItem.productId)")
            return
        }
        
        // Set purchasing state on main thread before starting the task
        DispatchQueue.main.async {
            self.isPurchasing = true
        }
        
        Task {
            do {
                // Request a purchase
                let result = try await product.purchase()
                
                // All UI updates must happen on the main thread
                await MainActor.run {
                    self.isPurchasing = false
                    
                    // Handle the result
                    switch result {
                    case .success(let verification):
                        // Check if the transaction is verified
                        switch verification {
                        case .verified(let transaction):
                            // Add to the store manager
                            storeManager.recordPurchase(productID: tipItem.productId)
                            self.updatePurchaseStats()
                            
                            // Finish the transaction
                            Task {
                                await transaction.finish()
                            }
                            
                        case .unverified(_, let error):
                            // Handle an unverified transaction
                            print("Transaction unverified: \(error)")
                            self.error = "Transaction could not be verified: \(error.localizedDescription)"
                        }
                        
                    case .userCancelled:
                        print("User cancelled the purchase")
                        
                    case .pending:
                        print("Purchase is pending")
                        
                    @unknown default:
                        print("Unknown purchase result")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isPurchasing = false
                    self.error = error.localizedDescription
                    print("Error during purchase: \(error)")
                }
            }
        }
    }
}

struct TipJarView: View {
    @StateObject private var viewModel = TipJarViewModel()
    @State private var selectedTip: TipItem?
    @State private var showingAlert = false
    
    // Redesigned view to match the screenshots
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("CHOOSE A TIP")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .padding(.top, 20)
            
            // Tips list with visual styling to match screenshots
            VStack(spacing: 0) {
                ForEach(viewModel.tipItems) { tipItem in
                    Button(action: {
                        viewModel.purchaseTip(tipItem)
                    }) {
                        HStack(spacing: 12) {
                            // Emoji
                            Text(tipItem.emoji)
                                .font(.title)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tipItem.title)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text(tipItem.description)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if viewModel.isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text(tipItem.price)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Add divider between items (except after the last one)
                    if tipItem.id != viewModel.tipItems.last?.id {
                        Divider()
                            .padding(.leading, 68) // Align with the text, not the emoji
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        .navigationTitle("Tip Jar")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .task {
            // Update purchase stats when view appears
            await viewModel.updatePurchaseStats()
            await viewModel.loadProducts()
        }
    }
}

// Preview Provider
struct TipJarView_Previews: PreviewProvider {
    static var previews: some View {
        TipJarView()
    }
}

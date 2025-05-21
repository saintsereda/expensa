//
//  TotalSpentRow.swift
//  Expensa
//
//  Created by Andrew Sereda on 27.10.2024.
//

import SwiftUI
import CoreData

struct TotalSpentRow: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // Accept FetchedResults instead of array
    let expenses: FetchedResults<Expense>
    let selectedDate: Date
    
    // Add a callback to notify parent when total is calculated
    var onTotalSpentCalculated: ((Decimal) -> Void)?
    
    // Cache the total spent value
    @State private var cachedTotalSpent: Decimal = 0
    
    // Use a UUID that will change when we want to force a refresh
    @State private var refreshID = UUID()
    
    // MARK: - Computed Properties
    private var totalSpent: Decimal {
        // Use cached value, we'll update this when necessary
        cachedTotalSpent
    }
    
    private var formattedMonth: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: selectedDate)
    }
    
    // MARK: - View Components
    @ViewBuilder
    private func titleText() -> some View {
        Text("Spent in \(formattedMonth)")
            .font(.system(size: 17, weight: .regular, design: .rounded))
            .foregroundColor(.white)
            .opacity(0.64)
    }
    
    @ViewBuilder
    private func amountText() -> some View {
        if let defaultCurrency = currencyManager.defaultCurrency {
            let formattedText = currencyManager.currencyConverter.formatAmount(totalSpent, currency: defaultCurrency)
            
            Text(formattedText)
                .font(.system(size: 52, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.95), value: totalSpent)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 4) {
            titleText()
            amountText()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .id(refreshID) // Force view refresh when refreshID changes
        .onAppear {
            updateTotalSpent()
            
            // Setup notification observers
            setupNotificationObservers()
        }
        .onChange(of: expenses.count) { _, _ in
            // Recalculate when expense count changes
            updateTotalSpent()
        }
    }
    
    // Setup notification observers
    private func setupNotificationObservers() {
        // Remove existing observers to avoid duplicates
        NotificationCenter.default.removeObserver(self)
        
        // Add notification observer for currency changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("DefaultCurrencyChanged"),
            object: nil,
            queue: .main
        ) { _ in
            updateTotalSpent()
        }
        
        // Add observer for CoreData context saves
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { notification in
            // Check if any expenses were updated
            if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
               !updatedObjects.isEmpty {
                // If we have updated objects, force refresh
                updateTotalSpent()
                
                // Generate new ID to force view refresh
                refreshID = UUID()
            }
        }
    }
    
    // Update the cached total spent value
    private func updateTotalSpent() {
        // Calculate total directly using reduce for better performance
        cachedTotalSpent = expenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
        
        // Notify parent view about the new value
        onTotalSpentCalculated?(cachedTotalSpent)
    }
}

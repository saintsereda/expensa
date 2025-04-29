//
//  RecurringExpenseRow.swift
//  Expensa
//
//  Created by Andrew Sereda on 29.10.2024.
//

import SwiftUI
import Foundation

struct RecurringExpenseRow: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    @ObservedObject var template: RecurringExpense
    @Environment(\.colorScheme) var colorScheme
    
    private var icon: String {
        template.category?.icon ?? "❓"
    }
    
    private var category: String {
        template.category?.name ?? "Unknown"
    }
    
    private var note: String? {
        template.notes
    }
    
    private var formattedOriginalAmount: String {
        guard let amount = template.amount?.decimalValue,
              let currencyCode = template.currency,
              let currency = currencyManager.fetchCurrency(withCode: currencyCode) else {
            return "-0"
        }
        
        return "" + currencyManager.currencyConverter.formatAmount(amount, currency: currency)
    }
    
    private var formattedConvertedAmount: String? {
        guard let amount = template.convertedAmount?.decimalValue,
              let defaultCurrency = currencyManager.defaultCurrency else {
            return nil
        }
        
        return "" + currencyManager.currencyConverter.formatAmount(amount, currency: defaultCurrency)
    }
    
    private var formattedNextDueDate: String {
        guard let nextDue = template.nextDueDate else { return "Not scheduled" }
        return nextDue.formatted(.dayMonth)
    }
    
    // Get the frequency letter using the utility
    private var frequencyLetter: String {
        return DateFormatterUtil.shared.frequencyLetter(for: template.frequency)
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 12) { // 12px spacing from circle to category
                // Left: Category Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                    
                    Text(icon)
                        .font(.system(size: 20))
                }
                
                // Center: Category and Next Payment info
                VStack(alignment: .leading, spacing: 4) { // 4px spacing between category and next payment
                    Text(category)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // Frequency indicator square
                        ZStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 20, height: 20)
                                .cornerRadius(4)
                            
                            Text(frequencyLetter)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        // Next payment date
                        Text("Next \(formattedNextDueDate)")
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.64))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Right: Amount
            VStack(alignment: .trailing, spacing: 4) { // 4px spacing between amounts
                if let convertedAmount = formattedConvertedAmount,
                   template.currency != currencyManager.defaultCurrency?.code {
                    Text(convertedAmount)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize()
                    
                    Text(formattedOriginalAmount)
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.64))
                        .fixedSize()
                } else {
                    Text(formattedOriginalAmount)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize()
                }
            }
        }
    }
}

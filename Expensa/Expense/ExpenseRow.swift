//
//  ExpenseRow.swift
//  Expensa
//

import SwiftUI
import Foundation

struct ExpenseRow: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    @ObservedObject var expense: Expense
    @State private var showingDeleteAlert = false
    
    // Add delete callback
    var onDelete: (() -> Void)?
    
    private var icon: String {
        expense.category?.icon ?? "❓"
    }
    
    private var category: String {
        expense.category?.name ?? "Unknown"
    }
    
    private var note: String? {
        expense.notes
    }
    
    private var formattedOriginalAmount: String {
        guard let amount = expense.amount?.decimalValue,
              let currencyCode = expense.currency,
              let currency = currencyManager.fetchCurrency(withCode: currencyCode) else {
            return "-0"
        }
        
        return "-" + currencyManager.currencyConverter.formatAmount(amount, currency: currency)
    }
    
    private var formattedConvertedAmount: String? {
        guard let amount = expense.convertedAmount?.decimalValue,
              let defaultCurrency = currencyManager.defaultCurrency else {
            return nil
        }
        
        return "-" + currencyManager.currencyConverter.formatAmount(amount, currency: defaultCurrency)
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                // Left: Category Icon (unchanged)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                    
                    Text(icon)
                        .font(.system(size: 20))
                }
                
                // Center: Category and Note (modified to truncate)
                VStack(alignment: .leading, spacing: 4) {
                    Text(category)
                        .font(.body)
                        .lineLimit(1)
                    
                    
                    if let note = note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.64))
                            .lineLimit(1)
                        
                    }
                }
            }
            
            Spacer()
            
            // Right: Amount (with fixed size)
            VStack(alignment: .trailing, spacing: 4) {
                if let convertedAmount = formattedConvertedAmount,
                   expense.currency != currencyManager.defaultCurrency?.code {
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
        .contextMenu {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete expense", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this expense? This action cannot be undone.")
        }
    }
}

extension ExpenseRow {
    static func from(expense: Expense, onDelete: (() -> Void)? = nil) -> ExpenseRow {
        return ExpenseRow(expense: expense, onDelete: onDelete)
    }
}

//
//  KeypadInputHelpers.swift
//  Expensa
//
//  Created by Andrew Sereda on 18.03.2025.
//

import Foundation
import SwiftUI
import Foundation

// MARK: - Helper Methods for Currency Input
class KeypadInputHelpers {
    
    // Format user input with proper spacing and decimal handling
    static func formatUserInput(_ amount: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        
        let cleanedAmount = amount.replacingOccurrences(of: " ", with: "")
        
        // If there's a decimal part, handle it separately
        if cleanedAmount.contains(",") {
            let parts = cleanedAmount.split(separator: ",", maxSplits: 1)
            let integerPart = String(parts[0])
            let decimalPart = parts.count > 1 ? String(parts[1]) : ""
            
            // Format the integer part
            if let number = Double(integerPart) {
                let formattedInteger = formatter.string(from: NSNumber(value: number)) ?? integerPart
                // Always return with comma and decimal part
                return formattedInteger + "," + decimalPart
            }
            return cleanedAmount
        }
        
        // Handle non-decimal numbers
        if let number = Double(cleanedAmount.replacingOccurrences(of: ",", with: ".")), !amount.hasSuffix(",") {
            return formatter.string(from: NSNumber(value: number)) ?? amount
        }
        return cleanedAmount
    }
    
    // Handle keyboard input with validation and formatting
    static func handleNumberInput(
        value: String,
        amount: inout String,
        lastEnteredDigit: inout String,
        triggerShake: @escaping () -> Void
    ) {
        HapticFeedback.play()
        var cleanAmount = amount.replacingOccurrences(of: " ", with: "")
        
        if value == "," {
            if !cleanAmount.contains(",") {
                if cleanAmount.isEmpty || cleanAmount == "0" {
                    amount = "0,"
                } else {
                    // Otherwise preserve formatting when adding comma
                    amount = formatUserInput(cleanAmount) + ","
                }
                lastEnteredDigit = value

            } else {
                triggerShake()
            }
            return
        }
        
        // Check if we're entering decimal places
        if cleanAmount.contains(",") {
            let parts = cleanAmount.split(separator: ",")
            if parts.count > 1 {
                let decimalPart = parts[1]
                if decimalPart.count >= 2 {
                    triggerShake()
                    return
                }
            }
            cleanAmount += value
        } else {
            // Handle integer part
            if cleanAmount == "0" && value != "," {
                cleanAmount = value
            } else {
                let integerPart = cleanAmount.split(separator: ",").first ?? ""
                if integerPart.count >= 10 && value != "," {
                    triggerShake()
                    return
                }
                cleanAmount += value
            }
        }
        lastEnteredDigit = value
        amount = formatUserInput(cleanAmount)
    }
    
    // Handle delete operations
    static func handleDelete(amount: inout String) {
        var cleanAmount = amount.replacingOccurrences(of: " ", with: "")
        
        if !cleanAmount.isEmpty {
            cleanAmount.removeLast()
            amount = formatUserInput(cleanAmount)
            HapticFeedback.play()
        }
    }
    
    // Parse amount string to Decimal for calculations
    static func parseAmount(_ formattedAmount: String, currencySymbol: String? = nil) -> Decimal? {
        let cleanedAmount = formattedAmount
            .replacingOccurrences(of: currencySymbol ?? "$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        return Decimal(string: cleanedAmount)
    }
    
    // Clean display values, removing currency symbols and unnecessary decimal places
    static func cleanDisplayAmount(_ amount: String, currencySymbol: String? = nil) -> String {
        let symbol = currencySymbol ?? "$"
        
        // Return empty string for empty input
        if amount.isEmpty {
            return ""
        }
        
        // Remove currency symbol if present
        let withoutSymbol = amount.replacingOccurrences(of: symbol, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clean up unnecessary zeros in decimal places
        if withoutSymbol.contains(",") {
            let parts = withoutSymbol.split(separator: ",", maxSplits: 1)
            let integerPart = String(parts[0])
            
            if parts.count > 1 {
                let decimalPart = String(parts[1])
                
                // If decimal part is all zeros, return just the integer part
                if decimalPart.allSatisfy({ $0 == "0" }) {
                    return integerPart
                }
                
                // Otherwise keep the necessary decimal part
                return "\(integerPart),\(decimalPart)"
            }
        }
        
        return withoutSymbol
    }
}

// MARK: - Extensions
extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

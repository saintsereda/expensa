//
//  File.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.11.2024.
//

import Foundation

public enum IntentError: Swift.Error {
    case categoryNotFound
    case currencyNotFound
    case failedToCreateExpense
    case invalidTransactionFormat
}

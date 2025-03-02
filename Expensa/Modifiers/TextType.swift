//
//  TextType.swift
//  Expensa
//
//  Created by Andrew Sereda on 29.10.2024.
//

import SwiftUI

enum TextType: Equatable {
    case string(String)
    case number(Int)
}

extension Array where Element == TextType {
    mutating func set(_ value: Character, index: Int) {
        // If it's a number or decimal separator, convert to animated number
        if let number = Int(String(value)) {
            self[index] = .number(number)
        } else {
            // If not a number (like currency symbol), use string
            self[index] = .string(String(value))
        }
    }
}

//
//  Theme.swift
//  expenses
//
//  Created by Andrew Sereda on 25.10.2024.
//

import Foundation
import SwiftUI

enum ColorScheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var colorScheme: SwiftUI.ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") private(set) var selectedTheme: ColorScheme = .system
    
    func setTheme(_ theme: ColorScheme) {
        selectedTheme = theme
    }
}

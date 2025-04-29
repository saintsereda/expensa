//
//  AccentColor.swift
//  Expensa
//
//  Created by Andrew Sereda on 10.04.2025.
//

import Foundation
import SwiftUI

enum AccentColorOption: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case orange = "Orange"
    case red = "Red"
    case green = "Green"
    case yellow = "Yellow"
    case purple = "Purple"
    case black = "Black"
    
    var id: String { self.rawValue }
    
    var hexCode: String {
        switch self {
        case .blue: return "0042B5"
        case .orange: return "BD5800"
        case .red: return "BD1000"
        case .green: return "00BD74"
        case .yellow: return "F4B802"
        case .purple: return "8400CB"
        case .black: return "1C1C1C"
        }
    }
    
    var color: Color {
        Color(hex: self.hexCode)
    }
}

class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()
    
    @Published var selectedAccentColor: AccentColorOption {
        didSet {
            UserDefaults.standard.set(selectedAccentColor.rawValue, forKey: "userAccentColor")
        }
    }
    
    private init() {
        // Get saved accent color or default to blue
        if let savedColorName = UserDefaults.standard.string(forKey: "userAccentColor"),
           let savedColor = AccentColorOption(rawValue: savedColorName) {
            self.selectedAccentColor = savedColor
        } else {
            self.selectedAccentColor = .blue
        }
    }
}

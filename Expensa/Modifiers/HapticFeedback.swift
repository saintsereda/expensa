//
//  HapticFeedback.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.11.2024.
//

import Foundation
import SwiftUI

enum HapticFeedback {
    static func play() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

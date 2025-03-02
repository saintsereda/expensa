//
//  NumberAnimation.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.11.2024.
//

import Foundation
import SwiftUI

struct NumberAnimationModifier: ViewModifier {
    var showNumberEffect: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(showNumberEffect ? 1 : 0.7)  // Scale animation
            .opacity(showNumberEffect ? 1 : 0.1)  // Fade in effect
            .blur(radius: showNumberEffect ? 0 : 8)  // Blur effect
    }
}

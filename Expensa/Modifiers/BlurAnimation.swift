//
//  BlurAnimation.swift
//  Expensa
//
//  Created by Andrew Sereda on 29.10.2024.
//

import SwiftUI

struct BlurAnimation: ViewModifier {
    var isAnimating: Bool
    
    func body(content: Content) -> some View {
                content
                    .opacity(isAnimating ? 1 : 0.1)
                    .blur(radius: isAnimating ? 0 : 8)
                    .scaleEffect(isAnimating ? 1 : 0.7)
    }
}

// Extension to make it easier to use the animation
extension View {
    func blurAnimation(isAnimating: Bool) -> some View {
        modifier(BlurAnimation(isAnimating: isAnimating))
    }
}

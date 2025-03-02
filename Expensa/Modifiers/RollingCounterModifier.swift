//
//  RollingCounterModifier.swift
//  Expensa
//
//  Created by Andrew Sereda on 29.10.2024.
//

import SwiftUI

struct RollingCounterModifier: AnimatableModifier {
    var value: Decimal
    var formatter: (Decimal, Currency?) -> String
    var currency: Currency?
    
    var animatableData: Double {
        get { Double(truncating: value as NSNumber) }
        set { value = Decimal(newValue) }
    }
    
    func body(content: Content) -> some View {
        // Remove the overlay and just return the text directly
        Text(formatter(value, currency))
            .font(.system(size: 48, weight: .regular))
            .multilineTextAlignment(.center)
            .contentTransition(.numericText())
    }
}

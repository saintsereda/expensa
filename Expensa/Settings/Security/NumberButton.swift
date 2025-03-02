//
//  NumberButton.swift
//  Expensa
//
//  Created by Andrew Sereda on 04.11.2024.
//

import Foundation
// PasscodeComponents.swift
import SwiftUI

struct NumberButton: View {
    let number: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.title)
                .fontWeight(.medium)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 5, x: 0, y: 2)
                )
                .foregroundColor(.primary)
        }
    }
}

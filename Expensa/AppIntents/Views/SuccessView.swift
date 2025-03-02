//
//  SuccessView.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.11.2024.
//

import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct SuccessView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.green)
            Text("Expense added successfully")
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding()
    }
}

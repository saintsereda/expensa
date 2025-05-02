//
//  EmptyBudgetView.swift
//  Expensa
//
//  Created on 20.03.2025.
//

import SwiftUI

struct EmptyBudgetView: View {
    let selectedDate: Date
    let isCurrentMonth: Bool
    var onAddBudget: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Emoji circle
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: 88, height: 88)
                Text("💰")
                    .font(.system(size: 24))
            }
            
            // Title text
            Text("Plan Smarter, Spend Better")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            // Description text
            Text("Set up your budget – categorize your spending, set limits, and track where your money goes")
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Add budget button for current month
            if isCurrentMonth {
                SaveButton(
                    isEnabled: true,
                    label: "Create budget",
                    action: onAddBudget
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

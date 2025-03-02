//
//  Components.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.11.2024.
//

import Foundation
import SwiftUI

struct ExpenseButton: View {
    let icon: String?  // Make icon optional
    let label: String
    let action: () -> Void
    
    // Add convenience initializer without icon
    init(label: String, action: @escaping () -> Void) {
        self.icon = nil
        self.label = label
        self.action = action
    }
    
    // Main initializer with optional icon
    init(icon: String? = nil, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                // Only show icon if it exists
                if let icon = icon {
                    HStack(alignment: .center, spacing: 0) {
                        Image(systemName: icon)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    .opacity(0.64)
                }
                
                Text(label)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                    .opacity(0.64)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.95), value: label)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 0)
            .frame(height: 40, alignment: .center)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(999)
        }
    }
}

struct CloseButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                    HStack(alignment: .center, spacing: 0) {
                        Image(systemName: icon)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    .opacity(0.64)
            }
            .frame(width: 40, height: 40, alignment: .center)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(999)
        }
    }
}

struct CategoryButton: View {
    let category: Category?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                Text("\(category?.icon ?? "🔹") \(category?.name ?? "Select category")")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.95), value: category)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 0)
            .frame(height: 48, alignment: .center)
            .background(Color(uiColor: .systemGray4))
            .cornerRadius(999)
        }
    }
}

struct SaveButton: View {
    let isEnabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Text("Save")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(isEnabled ? Color.white : Color(uiColor: .systemGray2))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 0)
            .frame(height: 48, alignment: .center)

            .background(isEnabled ? Color.accentColor : Color(uiColor: .systemGray4))
            .cornerRadius(999)
        }
        .disabled(!isEnabled)
    }
}

struct BottomActionSection: View {
    let category: Category?
    let isEnabled: Bool
    let onCategoryTap: () -> Void
    let onSaveTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center) {
            CategoryButton(category: category, action: onCategoryTap)
            Spacer()
            SaveButton(isEnabled: isEnabled, action: onSaveTap)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// Preview Provider
#Preview {
    ZStack {
        Color.black.edgesIgnoringSafeArea(.all) // Dark background for better preview
        ExpenseButton(
            icon: "calendar",
            label: "Today",
            action: { print("Calendar button tapped") }
        )
    }
}

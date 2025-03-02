//
//  SupportViews.swift
//  Expensa
//
//  Created by Andrew Sereda on 27.10.2024.
//

import SwiftUI

// MARK: - Navigation Buttons
struct NavigationLinkButton: View {
    let title: String
    let icon: String?
    let destination: AnyView
    let action: (() -> Void)?

    init(title: String, icon: String? = nil, destination: AnyView, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.destination = destination
        self.action = action
    }
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.blue)
                }
                Text(title)
                    .foregroundColor(.blue)
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                action?()
            }
        )
    }
}

struct RoundButton: View {
    let leftIcon: String?
    let label: String
    let rightIcon: String?
    let action: () -> Void

    // Initializer with optional icons
    init(leftIcon: String? = nil, label: String, rightIcon: String? = nil, action: @escaping () -> Void) {
        self.leftIcon = leftIcon
        self.label = label
        self.rightIcon = rightIcon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                if let leftIcon = leftIcon {
                    Image(systemName: leftIcon)
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(uiColor: .label))
                        .opacity(0.64)
                }

                Text(label)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                    .opacity(0.64)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.95), value: label)

                if let rightIcon = rightIcon {
                    Image(systemName: rightIcon)
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(uiColor: .label))
                        .opacity(0.64)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40, alignment: .center)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(999)
        }
    }
}


// MARK: - Action Buttons
struct FloatingActionButton: View {
    let title: String?
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 56, height: 56)
                    .shadow(radius: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Predefined Navigation Buttons
struct BudgetButton: View {
    var body: some View {
        NavigationLinkButton(
            title: "Budget",
            destination: AnyView(SettingsView())  // Navigate to BudgetView instead
        )
    }
}

struct SettingsButton: View {
    var body: some View {
        NavigationLinkButton(
            title: "",
            icon: "gearshape",
            destination: AnyView(SettingsView())
        )
    }
}

// MARK: - Helper View Extensions
extension View {
    func withNavigationButtons() -> some View {
        self.navigationBarItems(
            trailing: HStack(spacing: 16) {
                BudgetButton()
                SettingsButton()
            }
        )
    }
}

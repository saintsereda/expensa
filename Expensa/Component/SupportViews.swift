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
            .background(Color(uiColor: .systemGray5))
            .cornerRadius(999)
        }
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                    HStack(alignment: .center, spacing: 0) {
                        Image(icon)
                            .renderingMode(.template)
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color(uiColor: .label))
                    }
            }
            .frame(width: 40, height: 40, alignment: .center)
            .cornerRadius(999)
        }
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
            HStack(alignment: .center, spacing: 6) {
                if let leftIcon = leftIcon {
                    Image(leftIcon)
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(uiColor: .label))
                }

                Text(label)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.95), value: label)

                if let rightIcon = rightIcon {
                    Image(rightIcon)
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(uiColor: .label))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40, alignment: .center)
            .background(Color(uiColor: .systemGray5))
            .cornerRadius(999)
        }
    }
}

struct GhostButton: View {
    let leftIcon: String?
    let label: String?
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
            HStack(alignment: .center, spacing: 6) {
                if let leftIcon = leftIcon {
                    Image(leftIcon)
                        .renderingMode(.template)
                        .frame(width: 18, height: 18)
                        .foregroundColor(Color.primary)
                }

                Text(label ?? "Label")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.95), value: label)

                if let rightIcon = rightIcon {
                    Image(rightIcon)
                        .renderingMode(.template)
                        .frame(width: 18, height: 18)
                        .foregroundColor(Color.primary)
                }
            }
            .frame(height: 48, alignment: .leading)
        }
    }
}

//40px height primary small button
struct PrimarySmallButton: View {
    let isEnabled: Bool
    let label: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Text(label)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(
                        isEnabled
                        ? (colorScheme == .dark ? Color.black : Color.white)
                        : Color(uiColor: .systemGray2)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 0)
            .frame(height: 40, alignment: .center)
            .background(
                isEnabled
                ? (colorScheme == .dark ? Color.white : Color.black)
                : Color(uiColor: .systemGray4)
            )
            .cornerRadius(999)
        }
        .disabled(!isEnabled)
    }
}

struct SecondarySmallButton: View {
    let isEnabled: Bool
    let label: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Text(label)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(
                        isEnabled
                        ? (colorScheme == .dark ? Color.white : Color.black)
                        : Color(uiColor: .systemGray3)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 0)
            .frame(height: 40, alignment: .center)
            .background(Color.clear) // Transparent background
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(
                        isEnabled
                        ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))
                        : Color(uiColor: .systemGray4),
                        lineWidth: 1
                    )
            )
            .cornerRadius(999)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Action Buttons
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white : Color.black)
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
            }
        }
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

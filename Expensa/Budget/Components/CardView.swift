//
//  CardView.swift
//  Expensa
//
//  Created by Andrew Sereda on 20.03.2025.
// карточка емпті cta для створення бюджету 

import Foundation
import SwiftUI

// MARK: - Card View
struct CardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let emoji: String?
    let categoryIcons: Bool
    let title: String
    let description: String
    let buttonTitle: String
    let buttonAction: () -> Void
    let isDisabled: Bool
    let customContent: AnyView?
    
    init(
        emoji: String? = nil,
        categoryIcons: Bool = false,
        title: String,
        description: String,
        buttonTitle: String,
        buttonAction: @escaping () -> Void,
        isDisabled: Bool = false,
        customContent: AnyView? = nil
    ) {
        self.emoji = emoji
        self.categoryIcons = categoryIcons
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
        self.isDisabled = isDisabled
        self.customContent = customContent
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let emoji = emoji {
                // Single Emoji Icon
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 64, height: 64)
                    
                    Text(emoji)
                        .font(.system(size: 32))
                }
            } else if categoryIcons {
                // Category Icons Grid
                ZStack {
                    // Pizza emoji
                    IconCircle(emoji: "🍕", size: 40)
                        .offset(x: -20, y: -20)
                    
                    // Christmas tree emoji
                    IconCircle(emoji: "🎄", size: 32)
                        .offset(x: 10, y: -15)
                    
                    // Shopping cart emoji
                    IconCircle(emoji: "🛒", size: 32)
                        .offset(x: -20, y: 10)
                    
                    // +15 indicator
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Text("+15")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .offset(x: 10, y: 15)
                }
                .frame(height: 80)
            }
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text(description)
                .font(.system(size: 17))
                .lineSpacing(5)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            // Custom content if provided
            if let customContent = customContent {
                customContent
            } else {
                PrimarySmallButton(
                    isEnabled: !isDisabled,
                    label: buttonTitle,
                    action: buttonAction
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(colorScheme == .dark ? Color(UIColor.black.withAlphaComponent(0.2)) : Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct IconCircle: View {
    let emoji: String
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: size, height: size)
            
            Text(emoji)
                .font(.system(size: size * 0.4))
        }
    }
}

struct BudgetSetCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let emoji: String
    let amount: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Left circle with emoji
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Text(emoji)
                        .font(.system(size: 20))
                }
                Text("Monthly limit")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Right side - amount and chevron
                HStack(spacing: 8) {
                    Text(amount)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(colorScheme == .dark ? Color(UIColor.systemGray5).opacity(0.5) : Color(UIColor.systemGray6))
            .cornerRadius(16)
        }
    }
}

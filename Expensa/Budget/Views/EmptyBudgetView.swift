
//
//  EmptyBudgetView.swift
//  Expensa
//
//  Created on 19.03.2025.
//  Shows empty state when no budget is set

//import SwiftUI
//
//struct EmptyBudgetView: View {
//    let monthName: String
//    let isCurrentMonth: Bool
//    let onAddBudget: () -> Void
//    
//    var body: some View {
//        ZStack {
//            VStack(spacing: 16) {
//                // Monthly Limit Card
//                CardView(
//                    emoji: "🗓",
//                    title: "Limit for all expenses",
//                    description: "Take control of your budget by setting a single spending limit for the entire month",
//                    buttonTitle: "Set limit",
//                    buttonAction: onAddBudget,
//                    isDisabled: !isCurrentMonth
//                )
//                
//                // Category Limits Card
//                CardView(
//                    categoryIcons: true,
//                    title: "Limits for specific categories",
//                    description: "Customize your spending by setting individual limits for different categories",
//                    buttonTitle: "Select categories",
//                    buttonAction: {},
//                    isDisabled: true // Disabled as requested
//                )
//                
//                // Footer Text
//                Text("You can start with any option and adjust your limits anytime")
//                    .font(.system(size: 15))
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.top, 8)
//            }
//            .padding(.horizontal, 16)
//        }
//    }
//}
//
//// MARK: - Card View
//struct CardView: View {
//    @Environment(\.colorScheme) private var colorScheme
//
//    let emoji: String?
//    let categoryIcons: Bool
//    let title: String
//    let description: String
//    let buttonTitle: String
//    let buttonAction: () -> Void
//    let isDisabled: Bool
//    
//    init(
//        emoji: String? = nil,
//        categoryIcons: Bool = false,
//        title: String,
//        description: String,
//        buttonTitle: String,
//        buttonAction: @escaping () -> Void,
//        isDisabled: Bool = false
//    ) {
//        self.emoji = emoji
//        self.categoryIcons = categoryIcons
//        self.title = title
//        self.description = description
//        self.buttonTitle = buttonTitle
//        self.buttonAction = buttonAction
//        self.isDisabled = isDisabled
//    }
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            if let emoji = emoji {
//                // Single Emoji Icon
//                ZStack {
//                    Circle()
//                        .fill(Color.primary.opacity(0.1))
//                        .frame(width: 64, height: 64)
//                    
//                    Text(emoji)
//                        .font(.system(size: 16))
//                }
//            } else if categoryIcons {
//                // Category Icons Grid
//                ZStack {
//                    // Pizza emoji
//                    IconCircle(emoji: "🍕", size: 40)
//                        .offset(x: -20, y: -20)
//                    
//                    // Christmas tree emoji
//                    IconCircle(emoji: "🎄", size: 32)
//                        .offset(x: 10, y: -15)
//                    
//                    // Shopping cart emoji
//                    IconCircle(emoji: "🛒", size: 32)
//                        .offset(x: -20, y: 10)
//                    
//                    // +15 indicator
//                    ZStack {
//                        Circle()
//                            .fill(Color.primary.opacity(0.1))
//                            .frame(width: 40, height: 40)
//                        
//                        Text("+15")
//                            .font(.system(size: 13, weight: .medium))
//                            .foregroundColor(.secondary)
//                    }
//                    .offset(x: 10, y: 15)
//                }
//                .frame(height: 80)
//            }
//            
//            Text(title)
//                .font(.system(size: 15))
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//                .frame(maxWidth: .infinity)
//            
//            Text(description)
//                .font(.system(size: 17))
//                .lineSpacing(5)
//                .foregroundColor(.primary)
//                .multilineTextAlignment(.center)
//                .frame(maxWidth: .infinity)
//            
//            PrimarySmallButton(
//                isEnabled: !isDisabled,
//                label: buttonTitle,
//                action: buttonAction
//            )
//        }
//        .frame(maxWidth: .infinity)
//        .padding(20)
//        .background(colorScheme == .dark ? Color(UIColor.black.withAlphaComponent(0.2)) : Color(UIColor.systemGray6))
//        .clipShape(RoundedRectangle(cornerRadius: 28))
//        .overlay(
//            RoundedRectangle(cornerRadius: 28)
//                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
//        )
//    }
//}
//
//struct IconCircle: View {
//    let emoji: String
//    let size: CGFloat
//    
//    var body: some View {
//        ZStack {
//            Circle()
//                .fill(Color.primary.opacity(0.1))
//                .frame(width: size, height: size)
//            
//            Text(emoji)
//                .font(.system(size: size * 0.4))
//        }
//    }
//}
//
//#Preview {
//    EmptyBudgetView(
//        monthName: "March 2025",
//        isCurrentMonth: true,
//        onAddBudget: {}
//    )
//    .preferredColorScheme(.light)
//}
//
//#Preview {
//    EmptyBudgetView(
//        monthName: "March 2025",
//        isCurrentMonth: false,
//        onAddBudget: {}
//    )
//    .preferredColorScheme(.dark)
//}


//private func monthlyBudgetSection(_ budgetData: BudgetDisplayData) -> some View {
//    VStack(spacing: 20) {
//        ZStack {
//            Circle()
//                .fill(Color.primary.opacity(0.1))
//                .frame(width: 40, height: 40)
//            
//            Text("🗓️")
//                .font(.system(size: 16))
//        }
//        HStack {
//            Text("Monthly budget")
//                .font(.body)
//                .foregroundColor(.gray)
//        }
//        .padding(.bottom, 4)
//            Text(budgetData.amountFormatted)
//                .font(.system(size: 34, weight: .medium))
//                .foregroundColor(.primary)
//                .multilineTextAlignment(.center)
//                .frame(maxWidth: .infinity)
//
//            SecondarySmallButton(
//                isEnabled: true,
//                label: "Adjust limit",
//                action: {
//                    viewModel.editCurrentBudget()
//                }
//            )
//            .frame(maxWidth: .infinity, alignment: .center)
//        
//        //
//        //                HStack {
//        //                    Text(budgetData.spentFormatted)
//        //                        .font(.subheadline)
//        //                        .foregroundColor(.secondary)
//        //                    Text("•")
//        //                        .foregroundColor(.secondary)
//        //                    Text("\(budgetData.monthlyPercentageFormatted) spent")
//        //                        .font(.subheadline)
//        //                        .foregroundColor(.secondary)
//        //                }
//        //
//        //                // Progress bar
//        //                ProgressBar(percentage: budgetData.monthlyPercentage)
//        }
//    .frame(maxWidth: .infinity)
//    .padding(20)
////        .background(Color.black.opacity(0.12))
//    .background(colorScheme == .dark ? Color(UIColor.black.withAlphaComponent(0.2)) : Color(UIColor.systemGray6))
//    .clipShape(RoundedRectangle(cornerRadius: 28))
//    .overlay(
//        RoundedRectangle(cornerRadius: 28)
//            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
//    )
//}

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

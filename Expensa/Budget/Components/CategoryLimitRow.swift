//
//  CategoryLimitRow.swift
//  Expensa
//
//  Created by Andrew Sereda on 15.11.2024.
//
import Foundation
import SwiftUI

struct CategoryLimitRow: View {
    let category: Category?
    let name: String?
    let icon: String?
    let amount: Decimal
    let currency: Currency
    
    // Add convenience init for normal category case
    init(category: Category, amount: Decimal, currency: Currency) {
        self.category = category
        self.name = nil
        self.icon = nil
        self.amount = amount
        self.currency = currency
    }
    
    // Add init for "Everything else" case
    init(name: String, icon: String, amount: Decimal, currency: Currency) {
        self.category = nil
        self.name = name
        self.icon = icon
        self.amount = amount
        self.currency = currency
    }
    
    var body: some View {
        HStack {
            // Category icon circle
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 48, height: 48)
                Text(icon ?? category?.icon ?? "🔹")
                    .font(.system(size: 20))
            }
            
            // Category name
            Text(name ?? category?.name ?? "")
                .font(.body)
                .lineLimit(1)
            
            Spacer()
            
            // Limit amount
            Text(CurrencyConverter.shared.formatAmount(amount, currency: currency))
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize()
        }
        .padding(.vertical, 8)
    }
}

//import Foundation
//import SwiftUI
//
//struct CategoryLimitRow: View {
//    let category: Category?
//    let name: String?
//    let icon: String?
//    let amount: Decimal
//    let spent: Decimal
//    let percentage: String
//    let currency: Currency
//    let expenseCount: Int // Adding expense count
//    
//    // Add convenience init for normal category case
//    init(category: Category, amount: Decimal, spent: Decimal, percentage: String, currency: Currency, expenseCount: Int = 0) {
//        self.category = category
//        self.name = nil
//        self.icon = nil
//        self.amount = amount
//        self.spent = spent
//        self.percentage = percentage
//        self.currency = currency
//        self.expenseCount = expenseCount
//    }
//    
//    // Add init for "Everything else" case
//    init(name: String, icon: String, amount: Decimal, spent: Decimal, percentage: String, currency: Currency, expenseCount: Int = 0) {
//        self.category = nil
//        self.name = name
//        self.icon = icon
//        self.amount = amount
//        self.spent = spent
//        self.percentage = percentage
//        self.currency = currency
//        self.expenseCount = expenseCount
//    }
//    
//    private var remainingAmount: Decimal {
//        amount - spent
//    }
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            // Top section
//            HStack {
//                HStack {
//                    // Category icon circle
//                    ZStack {
//                        Circle()
//                            .fill(Color(UIColor.systemGray5))
//                            .frame(width: 48, height: 48)
//                        Text(icon ?? category?.icon ?? "🔹")
//                            .font(.system(size: 20))
//                    }
//                    
//                    // Category name and expense count
//                    VStack(alignment: .leading, spacing: 4)  {
//                        Text(name ?? category?.name ?? "")
//                            .font(.body)
//                            .lineLimit(1)
//                        Text("\(expenseCount) expense\(expenseCount == 1 ? "" : "s")")
//                            .font(.subheadline)
//                            .foregroundColor(.gray)
//                            .lineLimit(1)
//                    }
//                }
//                Spacer ()
//                
//                // Remaining amount
//                Text(CurrencyConverter.shared.formatAmount(remainingAmount, currency: currency))
//                    .font(.body)
//                    .foregroundColor(.primary)
//                    .fixedSize()
//            }
//            
//            // Middle section - Progress bar
//            ProgressBarView(percentage: percentage)
//            
//            // Bottom section
//            ZStack {
//                // Left and right amounts
//                HStack {
//                    // Total spent
//                    Text(CurrencyConverter.shared.formatAmount(spent, currency: currency))
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                        .lineLimit(1)
//                    
//                    Spacer()
//                    
//                    // Limit amount
//                    Text(CurrencyConverter.shared.formatAmount(amount, currency: currency))
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                        .lineLimit(1)
//                }
//                
//                // Centered percentage pill
//                Text(percentage)
//                    .font(.subheadline)
//                    .foregroundColor(.gray)
//                    .padding(.horizontal, 6)
//                    .frame(height: 20)
//                    .background(Color(UIColor.systemGray5))
//                    .cornerRadius(99)
//            }
//        }
//    }
//}
//
//struct ProgressBarView: View {
//    let percentage: String
//    
//    private var percentageValue: CGFloat {
//        CGFloat(Int(percentage.replacingOccurrences(of: "%", with: "")) ?? 0) / 100.0
//    }
//    
//    private var dayProgressPercentage: CGFloat {
//        let calendar = Calendar.current
//        let day = calendar.component(.day, from: Date())
//        let totalDays = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
//        return CGFloat(day) / CGFloat(totalDays)
//    }
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack(alignment: .leading) {
//                // Background bar
//                Rectangle()
//                    .fill(Color(UIColor.systemGray5))
//                    .frame(height: 8)
//                    .cornerRadius(8)
//                
//                // Progress bar
//                Rectangle()
//                    .fill(percentageValue >= 1 ? Color.red : Color.blue)
//                    .frame(width: max(0, min(percentageValue * geometry.size.width, geometry.size.width)), height: 8)
//                    .cornerRadius(8)
//                
//                // Today's line
////                Rectangle()
////                    .fill(Color(UIColor.systemGray3))
////                    .frame(width: 4, height: 8)
////                    .offset(x: dayProgressPercentage * geometry.size.width - 1, y: 0)
//            }
//        }
//        .frame(height: 8)
//    }
//}

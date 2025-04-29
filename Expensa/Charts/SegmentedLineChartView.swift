//
//  SegmentedLineChartView.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.04.2025.
//

import Foundation
import SwiftUI

struct SegmentedLineChartView: View {
    private let dataManager = ExpenseDataManager.shared
    
    let categorizedExpenses: [(Category, [Expense])]
    let totalExpenses: Decimal
    let segmentSpacing: CGFloat
    let height: CGFloat
    let minPercentage: Double
    
    init(
        categorizedExpenses: [(Category, [Expense])],
        totalExpenses: Decimal,
        height: CGFloat = 24,
        segmentSpacing: CGFloat = 2,
        minPercentage: Double = 1.0
    ) {
        // Sort categories by amount (descending)
        self.categorizedExpenses = categorizedExpenses.sorted { first, second in
            let firstAmount = ExpenseDataManager.shared.calculateTotalAmount(for: first.1)
            let secondAmount = ExpenseDataManager.shared.calculateTotalAmount(for: second.1)
            return firstAmount > secondAmount
        }
        self.totalExpenses = totalExpenses
        self.height = height
        self.segmentSpacing = segmentSpacing
        self.minPercentage = minPercentage
    }
    
    private struct SegmentData: Identifiable {
        let id: UUID
        let name: String
        let amount: Decimal
        let percentage: Double
        let colorIndex: Int
        
        var color: Color {
            return Color.customChartColors[colorIndex % Color.customChartColors.count]
        }
    }
    
    private var segmentData: [SegmentData] {
        // If no expenses, return an empty array
        guard !categorizedExpenses.isEmpty && totalExpenses > 0 else {
            return []
        }
        
        // Calculate all segments
        let allSegments = categorizedExpenses.enumerated().map { index, tuple in
            let (category, expenses) = tuple
            let amount = dataManager.calculateTotalAmount(for: expenses)
            let percentage = amount / totalExpenses * 100
            
            return SegmentData(
                id: category.id ?? UUID(),
                name: category.name ?? "Unknown",
                amount: amount,
                percentage: Double(truncating: percentage as NSNumber),
                colorIndex: index
            )
        }
        
        // Simply filter out segments that are less than minPercentage (e.g., 1%)
        // without creating an "Other" category
        return allSegments.filter { $0.percentage >= minPercentage }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // The segmented line chart
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if segmentData.isEmpty {
                        // Show empty state
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: geometry.size.width, height: height)
                    } else {
                        // Get total percentage (might not be exactly 100 due to rounding)
                        let totalPercentage = segmentData.reduce(0.0) { $0 + $1.percentage }
                        
                        // Calculate total width available for segments
                        let totalWidth = geometry.size.width
                        let totalSpacingWidth = segmentSpacing * CGFloat(segmentData.count - 1)
                        let availableWidth = totalWidth - totalSpacingWidth
                        
                        // Create the segmented line
                        HStack(spacing: segmentSpacing) {
                            ForEach(segmentData) { segment in
                                // Calculate width based on percentage, ensuring we don't exceed available width
                                let ratio = CGFloat(segment.percentage / totalPercentage)
                                let segmentWidth = availableWidth * ratio
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(segment.color)
                                    .frame(width: max(segmentWidth, 4), height: height) // Ensure minimum width for visibility
                            }
                        }
                        .frame(width: geometry.size.width, alignment: .leading)
                    }
                }
            }
            .frame(height: height)
            
            // Legend showing the top categories
            if !segmentData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(segmentData) { segment in
                            HStack(spacing: 6) {
                                // Color indicator
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(segment.color)
                                    .frame(width: 8, height: 8)
                                
                                // Category name
                                Text(segment.name)
                                    .font(.body)
                                
                                // Show both amount and percentage
                                    Text("\(Int(segment.percentage))%")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

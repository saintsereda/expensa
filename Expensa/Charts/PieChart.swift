//
//  CategoryPieChartView.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.02.2025.
//

import Foundation
import SwiftUI
import Charts

struct CategoryPieChartView: View {
    private let dataManager = ExpenseDataManager.shared
    
    let categorizedExpenses: [(Category, [Expense])]
    let totalExpenses: Decimal
    let monthDisplay: String
    
    // Add month change callback
    var onMonthChange: ((Bool) -> Void)? // true for next month, false for previous month
    
    // For drag gesture
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    init(categorizedExpenses: [(Category, [Expense])],
         totalExpenses: Decimal,
         monthDisplay: String = "this month",
         onMonthChange: ((Bool) -> Void)? = nil) {
        self.categorizedExpenses = categorizedExpenses
        self.totalExpenses = totalExpenses
        self.monthDisplay = monthDisplay
        self.onMonthChange = onMonthChange
    }
    
    private struct ChartData: Identifiable, Hashable {
        let id: String
        let name: String
        let amount: Decimal
        let percentage: Double
        let colorIndex: Int
        
        var color: Color {
            return Color.customChartColors[colorIndex % Color.customChartColors.count]
        }
        
        // Implement Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(amount)
            hasher.combine(percentage)
        }
        
        static func == (lhs: ChartData, rhs: ChartData) -> Bool {
            return lhs.id == rhs.id &&
                   lhs.amount == rhs.amount &&
                   lhs.percentage == rhs.percentage
        }
    }
    
    private var chartData: [ChartData] {
        // If no expenses, return an empty array
        guard !categorizedExpenses.isEmpty else {
            return []
        }
        
        // Get raw data with percentages
        let rawData = categorizedExpenses.map { category, expenses -> (Category, Decimal, Double) in
            let data = dataManager.getCategoryRowData(for: category, expenses: expenses, totalExpenses: totalExpenses)
            return (category, data.amount, data.percentage)
        }
        
        // Filter out categories with less than 1% contribution
        let filteredData = rawData.filter { $0.2 >= 1.0 }
        
        // Sort filtered categories by amount (descending)
        let sortedCategories = filteredData.sorted { $0.1 > $1.1 }
        
        // Create chart data for filtered categories
        return sortedCategories.enumerated().map { index, tuple in
            let (category, amount, percentage) = tuple
            
            return ChartData(
                id: category.id?.uuidString ?? UUID().uuidString,
                name: category.name ?? "Unknown",
                amount: amount,
                percentage: percentage,
                colorIndex: index // Use index for color assignment
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if #available(iOS 16.0, *) {
                // Full-width chart container with overlay for the total
                ZStack {
                    GeometryReader { geometry in
                        // Show gray sector if no expenses
                        if categorizedExpenses.isEmpty {
                            Chart {
                                SectorMark(
                                    angle: .value("Percentage", 100),
                                    innerRadius: .ratio(0.9),
                                    angularInset: 1
                                )
                                .cornerRadius(4)
                                .foregroundStyle(Color.gray.opacity(0.2))
                            }
                            .chartLegend(.hidden)
                            .animation(.easeInOut(duration: 0.5), value: 0)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .position(x: geometry.size.width / 2, y: geometry.size.width / 2)
                        } else {
                            // Existing chart for non-empty expenses
                            Chart(chartData) { item in
                                SectorMark(
                                    angle: .value("Percentage", item.percentage),
                                    innerRadius: .ratio(0.9),
                                    angularInset: 1 // Add spacing between sectors
                                )
                                .cornerRadius(4)
                                .foregroundStyle(item.color)
                            }
                            .transition(.push(from: .trailing))
                            .animation(.default, value: chartData)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .position(x: geometry.size.width / 2, y: geometry.size.width / 2)
                        }
                    }
                    .frame(height: UIScreen.main.bounds.width - 64)
                    
                    // Draggable overlay with the total amount in the center
                    GeometryReader { overlayGeometry in
                        VStack(spacing: 4) {
                            HStack(spacing: 0) {
                                Text("Spent in \(monthDisplay)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.4, dampingFraction: 0.95), value: monthDisplay)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                            }
                            
                            // Format amount using CurrencyConverter
                            if let defaultCurrency = CurrencyManager.shared.defaultCurrency {
                                Text(CurrencyConverter.shared.formatAmount(
                                    categorizedExpenses.isEmpty ? 0 : totalExpenses,
                                    currency: defaultCurrency
                                ))
                                .font(.system(size: 40, weight: .medium, design: .rounded))
                                .fontWeight(.medium)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.95), value: totalExpenses)
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                            }
                        }
                        .padding(.horizontal, 32)
                        .position(x: overlayGeometry.size.width / 2, y: overlayGeometry.size.height / 2)
                        .offset(x: dragOffset, y: 0)
                        // Create a masked container with blurred edges within the GeometryReader
                        .mask(
                            // Radial gradient mask for soft edges
                            RadialGradient(
                                gradient: Gradient(colors: [Color.white, Color.white.opacity(0)]),
                                center: .center,
                                startRadius: overlayGeometry.size.width * 0.37,
                                endRadius: overlayGeometry.size.width * 0.45
                            )
                        )
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isDragging = true
                                // Limit the drag offset to prevent moving too far off-center
                                // Maximum drag is 90% of the radius of the pie chart
                                let maxDrag: CGFloat = 110 // Slightly reduced to match the 0.9 scale
                                dragOffset = max(-maxDrag, min(maxDrag, gesture.translation.width))
                            }
                            .onEnded { gesture in
                                // Threshold for changing month (80 points)
                                let threshold: CGFloat = 80
                                
                                if dragOffset > threshold {
                                    // Dragged right enough - go to previous month
                                    onMonthChange?(false)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                } else if dragOffset < -threshold {
                                    // Dragged left enough - go to next month
                                    onMonthChange?(true)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                } else {
                                    // Not dragged enough - spring back
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                }
                                
                                // Reset dragging state after animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isDragging = false
                                }
                            }
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
                
                // Horizontal scrolling legend
                if !categorizedExpenses.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(chartData) { item in
                                HStack(spacing: 6) {
                                    // Color indicator
                                    Rectangle()
                                        .fill(item.color)
                                        .frame(width: 12, height: 12)
                                        .cornerRadius(2)
                                    
                                    // Category name and percentage
                                    Text(item.name)
                                        .font(.body)
                                    
                                    // Percentage with secondary color
                                    Text("\(dataManager.formatPercentage(percentage: item.percentage, categoryAmount: item.amount, totalAmount: totalExpenses))")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                
                // Messaging when no expenses
                if categorizedExpenses.isEmpty {
                    Text("No expenses this month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                Text("Charts require iOS 16 or later")
                    .foregroundColor(.secondary)
            }
        }
    }
}

extension Color {
    // Custom color palette for chart segments using the provided hex values
    static let customChartColors: [Color] = [
        Color(hex: "#FF006E"), // Red
        Color(hex: "#00FFF0"), // Orange
        Color(hex: "#3A86FE"), // Mint
        Color(hex: "#5214A9"), // Purple
        Color(hex: "#FFBE0C"), // Blue
        Color(hex: "#1796EC"), // Cyan
        Color(hex: "#15FFAB"), // Green
        Color(hex: "#84CE00"), // Lime
        Color(hex: "#DAC60F"), // Yellow
        Color(hex: "#E700B8"), // Pink
        Color(hex: "#01CC4A")  // Green (duplicate)
    ]
    
    // Initializer to create a color from a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

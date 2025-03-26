//
//  File.swift
//  Expensa
//
//  Created by Andrew Sereda on 04.11.2024.
//

import Foundation
import SwiftUI

private struct GraphCalculator {
    static func calculateYPosition(
        for amount: Decimal,
        maxAmount: Decimal,
        height: CGFloat
    ) -> CGFloat {
        // Prevent division by zero
        guard maxAmount != 0 else { return height }
        
        let amountDouble = NSDecimalNumber(decimal: amount).doubleValue
        let maxDouble = NSDecimalNumber(decimal: maxAmount).doubleValue
        
        // Prevent NaN
        guard maxDouble > 0, amountDouble.isFinite, maxDouble.isFinite else {
            return height
        }
        
        return height - (height * CGFloat(amountDouble / maxDouble))
    }
    
    static func safeMaxAmount(_ amounts: [Decimal]) -> Decimal {
        amounts.max() ?? 1
    }
    
    static func safeCurrentIndex(currentDayX: CGFloat, count: Int) -> Int {
        min(max(0, Int(currentDayX * CGFloat(count - 1))), count - 1)
    }
}

public struct SpendingProgressGraph: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    @Environment(\.colorScheme) private var colorScheme
    
    let expenses: [Expense]
    let selectedDate: Date
    
    public init(expenses: [Expense], selectedDate: Date) {
        self.expenses = expenses
        self.selectedDate = selectedDate
    }
    
    private var dailySpending: [(Date, Decimal)] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: selectedDate)
        
        return expenses
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
            .reduce(into: [(Date, Decimal)]()) { result, expense in
                guard let date = expense.date else { return }
                let amount = expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0
                
                if let lastIndex = result.lastIndex(where: { calendar.isDate($0.0, inSameDayAs: date) }) {
                    let newAmount = result[lastIndex].1 + amount
                    result[lastIndex] = (date, newAmount)
                } else {
                    result.append((date, amount))
                }
            }
    }
    
    private var cumulativeSpending: [(Date, Decimal)] {
        var cumulative: [(Date, Decimal)] = []
        var runningTotal: Decimal = 0
        
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: selectedDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        
        // Initialize all days with running totals
        for day in 0..<daysInMonth {
            guard let date = calendar.date(byAdding: .day, value: day, to: startOfMonth) else { continue }
            
            let dayExpenses = dailySpending.filter { calendar.isDate($0.0, inSameDayAs: date) }
            let dayTotal = dayExpenses.reduce(Decimal(0)) { $0 + $1.1 }
            runningTotal += dayTotal
            
            cumulative.append((date, runningTotal))
        }
        
        return cumulative
    }
    
    private var currentDayX: CGFloat {
        let currentDay = Calendar.current.component(.day, from: Date()) - 1
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        return CGFloat(currentDay) / CGFloat(max(1, daysInMonth - 1))
    }
    
    private var graphHeight: CGFloat = 100
    
    public var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if !cumulativeSpending.isEmpty {
                        let maxSpending = GraphCalculator.safeMaxAmount(cumulativeSpending.map { $0.1 })
                        let startX = currentDayX * geometry.size.width
                        let currentIndex = GraphCalculator.safeCurrentIndex(currentDayX: currentDayX, count: cumulativeSpending.count)
                        let currentAmount = cumulativeSpending[currentIndex].1
                        let currentY = GraphCalculator.calculateYPosition(
                            for: currentAmount,
                            maxAmount: maxSpending,
                            height: geometry.size.height
                        )
                        
                        // Blue gradient area
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geometry.size.height))
                            
                            for (index, (_, amount)) in cumulativeSpending.enumerated() {
                                let x = geometry.size.width * (CGFloat(index) / CGFloat(max(1, cumulativeSpending.count - 1)))
                                if x > startX { break }
                                
                                let y = GraphCalculator.calculateYPosition(
                                    for: amount,
                                    maxAmount: maxSpending,
                                    height: geometry.size.height
                                )
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            
                            path.addLine(to: CGPoint(x: startX, y: currentY))
                            path.addLine(to: CGPoint(x: startX, y: geometry.size.height))
                        }
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.05)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Gray gradient area for projection
                        Path { path in
                            path.move(to: CGPoint(x: startX, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: startX, y: currentY))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: currentY))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        }
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(UIColor.systemGray2).opacity(0.1),
                                    Color(UIColor.systemGray2).opacity(0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Actual spending line
                        Path { path in
                            if let firstAmount = cumulativeSpending.first?.1 {
                                path.move(to: CGPoint(
                                    x: 0,
                                    y: GraphCalculator.calculateYPosition(
                                        for: firstAmount,
                                        maxAmount: maxSpending,
                                        height: geometry.size.height
                                    )
                                ))
                                
                                for (index, (_, amount)) in cumulativeSpending.enumerated() {
                                    let x = geometry.size.width * (CGFloat(index) / CGFloat(max(1, cumulativeSpending.count - 1)))
                                    if x > startX { break }
                                    
                                    let y = GraphCalculator.calculateYPosition(
                                        for: amount,
                                        maxAmount: maxSpending,
                                        height: geometry.size.height
                                    )
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        
                        // Projected line
                        Path { path in
                            path.move(to: CGPoint(x: startX, y: currentY))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: currentY))
                        }
                        .stroke(
                            Color(UIColor.systemGray4),
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [5]
                            )
                        )
                    }
                }
            }
            .frame(height: graphHeight)
            
            // Day markers
            HStack {
                ForEach([1, 6, 11, 16, 21, 26, 31], id: \.self) { day in
                    Text("\(day)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if day != 31 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        guard let startOfMonth = self.date(from: dateComponents([.year, .month], from: date)) else { return date }
        return self.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? date
    }
}

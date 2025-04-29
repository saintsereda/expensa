//
//  MonthlyTrendChart.swift
//  Expensa
//
//  Created by Andrew Sereda on 02.11.2024.
//

import Foundation
import SwiftUI
import CoreData
import Charts

struct MonthlyTrendChart: View {
    let data: [(Date, Decimal)]
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    private var maxAmount: Decimal {
        data.map { $0.1 }.max() ?? 0
    }
    
    private var midAmount: Decimal {
        maxAmount / 2
    }
    
    private var dateFormatter: DateFormatter {
        DateFormatterUtil.shared.formatter(for: .onlyMonth)
    }
    
    // Generate last 6 months data points, filling in with zeros if needed
    private var processedData: [(Date, Decimal)] {
        let calendar = Calendar.current
        let today = Date()
        
        // Create array of the last 6 months
        let monthDates = (0..<6).map { monthsAgo in
            calendar.date(byAdding: .month, value: -monthsAgo, to: today)!
        }.reversed()
        
        // Map each month to its corresponding data point or zero
        return monthDates.map { date in
            let startOfMonth = calendar.startOfMonth(for: date)
            if let existingDataPoint = data.first(where: { calendar.isDate($0.0, equalTo: startOfMonth, toGranularity: .month) }) {
                return existingDataPoint
            } else {
                return (startOfMonth, 0)
            }
        }
    }
    
    var body: some View {
        Chart {
            ForEach(processedData, id: \.0) { item in
                BarMark(
                    x: .value("Month", dateFormatter.string(from: item.0)),
                    y: .value("Amount", item.1)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
            }
            
            // Grid lines for better readability
            RuleMark(y: .value("Max", maxAmount))
                .foregroundStyle(Color.gray.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: []))
                
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.gray.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: []))
        }
        .chartYAxis {
            // Move axis to trailing (right side)
            AxisMarks(position: .trailing) { value in
                if let decimal = value.as(Decimal.self) {
                    AxisValueLabel {
                        if let defaultCurrency = currencyManager.defaultCurrency {
                            Text(formatAmountShort(decimal, currency: defaultCurrency))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(formatAmount(decimal))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    AxisGridLine()
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .frame(height: 200)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
    }
    
    // Format amount with K/M suffix for better readability
    private func formatAmountShort(_ amount: Decimal, currency: Currency) -> String {
        let symbol = currency.symbol ?? currency.code ?? ""
        
        if amount == 0 {
            return "0"
        } else if amount >= 1_000_000 {
            let value = amount / 1_000_000
            let formatted = String(format: "%.1fM", NSDecimalNumber(decimal: value).doubleValue)
                .replacingOccurrences(of: ".", with: ",")
            return "\(formatted)"
        } else if amount >= 1_000 {
            let value = amount / 1_000
            let formatted = String(format: "%.1fK", NSDecimalNumber(decimal: value).doubleValue)
                .replacingOccurrences(of: ".", with: ",")
            return "\(formatted)"
        } else {
            return formatAmount(amount)
        }
    }
}

// Helper extension
private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

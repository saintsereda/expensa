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
    
    private var maxAmount: Decimal {
        data.map { $0.1 }.max() ?? 0
    }
    
    private var midAmount: Decimal {
        maxAmount / 2
    }
    
    private var dateFormatter: DateFormatter {
        DateFormatterUtil.shared.formatter(for: .onlyMonth)
    }
    
    var body: some View {
        Chart {
            ForEach(data, id: \.0) { item in
                BarMark(
                    x: .value("Month", dateFormatter.string(from: item.0)),
                    y: .value("Amount", item.1)
                )
                .foregroundStyle(Color.blue)
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
            AxisMarks(position: .leading) { value in
                if let decimal = value.as(Decimal.self) {
                    AxisValueLabel {
                        Text(formatAmount(decimal))
                            .font(.caption)
                            .foregroundColor(.secondary)
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
}

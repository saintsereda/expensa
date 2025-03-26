//
//  MonthlyComparisonChart.swift
//  Expensa
//
//  Created on 25.03.2025.
//

import SwiftUI
import Charts
import CoreData

public struct MonthlyComparisonChart: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    @Environment(\.managedObjectContext) private var viewContext
    
    // The two separate data sources
    let currentMonthExpenses: [Expense]
    let selectedDate: Date
    
    @State private var previousMonthExpenses: [Expense] = []
    
    public init(currentMonthExpenses: [Expense], selectedDate: Date) {
        self.currentMonthExpenses = currentMonthExpenses
        self.selectedDate = selectedDate
    }
    
    // Structure to hold our data series
    private struct ExpenseDataSeries: Identifiable {
        let id = UUID()
        let type: String
        let expenses: [Expense]
        let date: Date
    }
    
    // Create our data series
    private var data: [ExpenseDataSeries] {
        let calendar = Calendar.current
        var dataSeries: [ExpenseDataSeries] = []
        
        // Current month series
        dataSeries.append(ExpenseDataSeries(
            type: "Current Month",
            expenses: currentMonthExpenses,
            date: selectedDate
        ))
        
        // Previous month series
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            dataSeries.append(ExpenseDataSeries(
                type: "Previous Month",
                expenses: previousMonthExpenses,
                date: previousMonth
            ))
        }
        
        return dataSeries
    }
    
    // Calculate cumulative totals for a given month
    private func cumulativeTotals(for series: ExpenseDataSeries) -> [(date: Date, amount: Decimal)] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: series.date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: series.date)?.count ?? 30
        
        // Group expenses by day
        var expensesByDay: [Date: [Expense]] = [:]
        for expense in series.expenses {
            guard let expenseDate = expense.date else { continue }
            let dayDate = calendar.startOfDay(for: expenseDate)
            
            if expensesByDay[dayDate] == nil {
                expensesByDay[dayDate] = []
            }
            expensesByDay[dayDate]?.append(expense)
        }
        
        // Calculate cumulative total for each day
        var cumulativeTotals: [(Date, Decimal)] = []
        var runningTotal: Decimal = 0
        
        for day in 0..<daysInMonth {
            guard let currentDate = calendar.date(byAdding: .day, value: day, to: startOfMonth) else { continue }
            
            if let dayExpenses = expensesByDay[currentDate] {
                let dayTotal = dayExpenses.reduce(Decimal(0)) { sum, expense in
                    sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
                }
                runningTotal += dayTotal
            }
            
            cumulativeTotals.append((currentDate, runningTotal))
        }
        
        // Make sure we start with the first day of the month at zero
        let firstDayOfMonth = startOfMonth
        if cumulativeTotals.isEmpty || !calendar.isDate(cumulativeTotals.first?.0 ?? Date(), inSameDayAs: firstDayOfMonth) {
            cumulativeTotals.insert((firstDayOfMonth, 0), at: 0)
        }
        
        return cumulativeTotals
    }
    
    // For x-axis domain calculation
    private var xAxisDomain: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: selectedDate)
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return [startOfMonth, startOfMonth]
        }
        return [startOfMonth, endOfMonth]
    }
    
    // Get the number of days in the current month
    private var daysInCurrentMonth: Int {
        let calendar = Calendar.current
        return calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
    }
    
    // Find the maximum amount across all datasets for y-axis scaling
    private var maxAmount: Decimal {
        var max: Decimal = 0
        
        for series in data {
            let seriesData = cumulativeTotals(for: series)
            if let seriesMax = seriesData.map({ $0.amount }).max(), seriesMax > max {
                max = seriesMax
            }
        }
        
        return max > 0 ? max : 1 // Ensure we have a non-zero max for scaling
    }
    
    // Format the amount for display
    private func formatAmount(_ amount: Decimal) -> String {
        guard let defaultCurrency = currencyManager.defaultCurrency else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = defaultCurrency.code
        formatter.currencySymbol = defaultCurrency.symbol
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? ""
    }
    
    // Fetch previous month's expenses
    private func fetchPreviousMonthExpenses() {
        guard let previousMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) else {
            return
        }
        
        let calendar = Calendar.current
        let startOfPreviousMonth = calendar.startOfMonth(for: previousMonthDate)
        guard let endOfPreviousMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfPreviousMonth) else {
            return
        }
        
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@",
                                            startOfPreviousMonth as NSDate,
                                            calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfPreviousMonth)! as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]
        
        do {
            previousMonthExpenses = try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching previous month expenses: \(error)")
        }
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Chart {
                ForEach(data) { series in
                    let seriesData = cumulativeTotals(for: series)
                    
                    // For the current month series, we need to check if it's the actual current month
                    if series.type == "Current Month" {
                        let calendar = Calendar.current
                        let today = Date()
                        
                        // If we're viewing the current month, filter to today
                        if calendar.isDate(series.date, equalTo: today, toGranularity: .month) {
                            // Filter current month data to stop at today
                            let filteredData = seriesData.filter { dataPoint in
                                calendar.startOfDay(for: dataPoint.date) <= calendar.startOfDay(for: today)
                            }
                            
                            // Draw the line with filtered data
                            ForEach(filteredData, id: \.date) { dataPoint in
                                LineMark(
                                    x: .value("Day", dataPoint.date),
                                    y: .value("Amount", dataPoint.amount)
                                )
                                .foregroundStyle(by: .value("Type", series.type))
                                .lineStyle(StrokeStyle(
                                    lineWidth: 3,
                                    lineCap: .round,
                                    lineJoin: .round
                                ))
                                .interpolationMethod(.catmullRom)
                            }
                            
                            // Add point marker for today
                            if let lastDataPoint = filteredData.last, lastDataPoint.amount > 0 {
                                PointMark(
                                    x: .value("Day", lastDataPoint.date),
                                    y: .value("Amount", lastDataPoint.amount)
                                )
                                .foregroundStyle(by: .value("Type", series.type))
                                .symbolSize(50)
                            }
                        } else {
                            // For past months, show full data
                            ForEach(seriesData, id: \.date) { dataPoint in
                                LineMark(
                                    x: .value("Day", dataPoint.date),
                                    y: .value("Amount", dataPoint.amount)
                                )
                                .foregroundStyle(by: .value("Type", series.type))
                                .lineStyle(StrokeStyle(
                                    lineWidth: 3,
                                    lineCap: .round,
                                    lineJoin: .round
                                ))
                                .interpolationMethod(.catmullRom)
                            }
                            
                            // Add point marker for month end
                            if let lastDataPoint = seriesData.last, lastDataPoint.amount > 0 {
                                PointMark(
                                    x: .value("Day", lastDataPoint.date),
                                    y: .value("Amount", lastDataPoint.amount)
                                )
                                .foregroundStyle(by: .value("Type", series.type))
                                .symbolSize(50)
                            }
                        }
                    }
                    // For previous month, normalize dates to current month's range
                    else if series.type == "Previous Month" {
                        let calendar = Calendar.current
                        
                        // Create normalized data points that fit within current month's day range
                        let normalizedData = normalizeToCurrentMonth(seriesData)
                        
                        ForEach(normalizedData, id: \.date) { dataPoint in
                            LineMark(
                                x: .value("Day", dataPoint.date),
                                y: .value("Amount", dataPoint.amount)
                            )
                            .foregroundStyle(by: .value("Type", series.type))
                            .lineStyle(StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round
                            ))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                "Current Month": Color.primary,
                "Previous Month": Color.gray.opacity(0.3)
            ])
            .frame(height: 240)
            .chartXAxis {
                 AxisMarks(preset: .aligned, values: .stride(by: .day, count: 5)) { value in
                     if let date = value.as(Date.self) {
                         let day = Calendar.current.component(.day, from: date)
                         let isFirstOrLast = day == 1 || day == Calendar.current.component(.day, from: xAxisDomain[1])
                         
                         AxisValueLabel {
                             Text(date, format: .dateTime.day())
                                 .font(.system(.caption2, design: .rounded))
                         }
                         AxisTick()
                     }
                 }
             }
             .chartYAxis(.hidden)
             .chartXScale(domain: xAxisDomain)
             .chartYScale(domain: 0...(NSDecimalNumber(decimal: maxAmount).doubleValue * 1.1))
             .chartLegend(.hidden)
             .padding(.vertical, 8)
             .animation(.spring(response: 0.4, dampingFraction: 0.95), value: currentMonthExpenses.count)
             .animation(.spring(response: 0.4, dampingFraction: 0.95), value: previousMonthExpenses.count)
        }
        .onAppear {
            fetchPreviousMonthExpenses()
        }
        .onChange(of: selectedDate) { _, _ in
            fetchPreviousMonthExpenses()
        }
    }
    
    // Normalize previous month data to match current month's range
    private func normalizeToCurrentMonth(_ data: [(date: Date, amount: Decimal)]) -> [(date: Date, amount: Decimal)] {
        let calendar = Calendar.current
        let currentMonthStart = calendar.startOfMonth(for: selectedDate)
        let daysInCurrentMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        let daysInPrevMonth = calendar.range(of: .day, in: .month, for: data.first?.date ?? selectedDate)?.count ?? 30
        
        // Create a mapping function based on day proportion
        func mapDay(_ prevMonthDay: Int) -> Date {
            let dayProportion = Double(prevMonthDay) / Double(daysInPrevMonth)
            let currentMonthDay = Int(dayProportion * Double(daysInCurrentMonth))
            let mappedDay = max(1, min(currentMonthDay, daysInCurrentMonth))
            
            var dateComponents = calendar.dateComponents([.year, .month], from: currentMonthStart)
            dateComponents.day = mappedDay
            return calendar.date(from: dateComponents) ?? currentMonthStart
        }
        
        // Map previous month data points to current month
        var normalizedData: [(date: Date, amount: Decimal)] = []
        
        for dataPoint in data {
            let day = calendar.component(.day, from: dataPoint.date)
            let normalizedDate = mapDay(day)
            normalizedData.append((normalizedDate, dataPoint.amount))
        }
        
        // Ensure data is sorted by date
        normalizedData.sort { $0.date < $1.date }
        
        // Ensure we don't exceed the current month's range
        return normalizedData.filter { dataPoint in
            let day = calendar.component(.day, from: dataPoint.date)
            return day <= daysInCurrentMonth
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

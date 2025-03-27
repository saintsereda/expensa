import SwiftUI
import Charts
import CoreData

// Helper extension for more efficient date handling
private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        guard let startOfNextMonth = self.date(byAdding: DateComponents(month: 1), to: startOfMonth(for: date)) else {
            return date
        }
        return self.date(byAdding: DateComponents(day: -1), to: startOfNextMonth) ?? date
    }
}

struct MonthlyComparisonChart: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    @Environment(\.managedObjectContext) private var viewContext
    
    // The two separate data sources
    let currentMonthExpenses: [Expense]
    let selectedDate: Date
    
    @State private var previousMonthExpenses: [Expense] = []
    @State private var isLoadingPreviousMonth = false
    
    private var calendar: Calendar { Calendar.current }
    
    private var daysInMonth: Range<Int> {
        (calendar.range(of: .day, in: .month, for: selectedDate)?.lowerBound ?? 1)..<(calendar.range(of: .day, in: .month, for: selectedDate)?.upperBound ?? 31)
    }
    
    private var today: Date {
        calendar.startOfDay(for: Date())
    }
    
    private var xAxisLabels: [Int] {
        let lastDay = calendar.range(of: .day, in: .month, for: selectedDate)?.last ?? 28
        let isFebruary = calendar.component(.month, from: selectedDate) == 2
        
        return isFebruary
            ? [1, 6, 11, 16, 21, lastDay]
            : [1, 6, 11, 16, 21, 26, lastDay]
    }
    
    private var dateRange: ClosedRange<Date> {
        let startOfMonth = calendar.startOfMonth(for: selectedDate)
        let endOfMonth = calendar.endOfMonth(for: selectedDate)
        return startOfMonth...endOfMonth
    }
    
    // Memoized calculation to improve performance
    private func cumulativeDailyTotals(from expenses: [Expense], for monthDate: Date, limitToToday: Bool) -> [(date: Date, total: Decimal)] {
        // Use a dictionary for faster lookups
        var dailyTotals: [Int: Decimal] = [:]
        let startOfMonth = calendar.startOfMonth(for: monthDate)
        
        // First pass - sum up all expenses by day
        for expense in expenses {
            guard let date = expense.date else { continue }
            let day = calendar.component(.day, from: date)
            let amount = expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0
            dailyTotals[day, default: 0] += amount
        }
        
        // Second pass - calculate running total for each day
        var result: [(date: Date, total: Decimal)] = []
        var runningTotal: Decimal = 0
        
        for day in daysInMonth {
            guard let date = calendar.date(bySetting: .day, value: day, of: startOfMonth) else { continue }
            
            // If limiting to today and we've passed today, stop
            if limitToToday && date > today {
                break
            }
            
            runningTotal += dailyTotals[day] ?? 0
            result.append((date: date, total: runningTotal))
        }
        
        return result
    }
    
    private var previousMonthTotalsAligned: [(date: Date, total: Decimal)] {
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) else {
            return []
        }
        
        let raw = cumulativeDailyTotals(from: previousMonthExpenses, for: previousMonthDate, limitToToday: false)
        
        // Align previous month data to current month for comparison
        return raw.enumerated().compactMap { index, item in
            guard index < daysInMonth.count,
                  let alignedDate = calendar.date(bySetting: .day, value: index + 1, of: calendar.startOfMonth(for: selectedDate)) else {
                return nil
            }
            return (date: alignedDate, total: item.total)
        }
    }
    
    private var currentMonthTotals: [(date: Date, total: Decimal)] {
        cumulativeDailyTotals(from: currentMonthExpenses, for: selectedDate, limitToToday: true)
    }
    
    // Optimized fetch for previous month expenses
    private func fetchPreviousMonthExpenses() {
        // Prevent multiple concurrent fetches
        if isLoadingPreviousMonth {
            return
        }
        
        isLoadingPreviousMonth = true
        
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) else {
            isLoadingPreviousMonth = false
            return
        }
        
        let startOfPreviousMonth = calendar.startOfMonth(for: previousMonthDate)
        let endOfPreviousMonth = calendar.endOfMonth(for: previousMonthDate)
        
        // Use the end of day for the end date to include all expenses
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfPreviousMonth) ?? endOfPreviousMonth
        
        let fetchRequest = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@",
                                           startOfPreviousMonth as NSDate,
                                           endOfDay as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]
        
        // Use background task to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Perform fetch on background thread
                let context = viewContext
                let results = try context.performAndWait {
                    try fetchRequest.execute()
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    previousMonthExpenses = results
                    isLoadingPreviousMonth = false
                }
            } catch {
                print("Error fetching previous month expenses: \(error)")
                DispatchQueue.main.async {
                    isLoadingPreviousMonth = false
                }
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            Chart {
                // 🔹 Previous month line
                if !previousMonthExpenses.isEmpty {
                    ForEach(previousMonthTotalsAligned.indices, id: \.self) { index in
                        let item = previousMonthTotalsAligned[index]
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Total", NSDecimalNumber(decimal: item.total).doubleValue),
                            series: .value("Series", "Previous")
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(.white.opacity(0.25))
                    }
                }
                
                // ⚪️ Current month line
                ForEach(currentMonthTotals.indices, id: \.self) { index in
                    let item = currentMonthTotals[index]
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Total", NSDecimalNumber(decimal: item.total).doubleValue),
                        series: .value("Series", "Current")
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(.white)
                }
                
                // 🎯 End dot
                if let last = currentMonthTotals.last {
                    PointMark(
                        x: .value("Date", last.date),
                        y: .value("Total", NSDecimalNumber(decimal: last.total).doubleValue)
                    )
                    .symbolSize(32)
                    .foregroundStyle(.white)
                }
            }
            .frame(width: geometry.size.width)
            .chartXScale(domain: dateRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        let day = calendar.component(.day, from: date)
                        
                        if xAxisLabels.contains(day) {
                            AxisValueLabel {
                                Text("\(day)")
                                    .foregroundColor(.white)
                                    .font(.system(size: 8))
                                    .fixedSize()
                            }
                        }
                        
                        if calendar.isDate(date, inSameDayAs: today) {
                            AxisGridLine()
                                .foregroundStyle(.white.opacity(0.2))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .background(Color.clear)
        }
        .animation(.easeInOut, value: currentMonthTotals.count)
        .padding(.horizontal, 16)
        .frame(height: 200)
        .onAppear {
            fetchPreviousMonthExpenses()
        }
        .onChange(of: selectedDate) { _, _ in
            fetchPreviousMonthExpenses()
        }
    }
}

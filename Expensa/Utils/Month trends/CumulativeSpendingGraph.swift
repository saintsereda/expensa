import SwiftUI
import Charts
import CoreData

struct MonthlyComparisonChart: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    @Environment(\.managedObjectContext) private var viewContext
    
    // The two separate data sources
    let currentMonthExpenses: [Expense]
    let selectedDate: Date
    
    @State private var previousMonthExpenses: [Expense] = []
    
    private var calendar: Calendar { Calendar.current }
    
    private var daysInMonth: Range<Int> {
        (calendar.range(of: .day, in: .month, for: selectedDate)?.lowerBound ?? 1)..<(calendar.range(of: .day, in: .month, for: selectedDate)?.upperBound ?? 31)
    }
    
    private var currentInterval: DateInterval {
        ExpenseFilterManager().dateInterval(for: selectedDate)
    }
    
    private var previousInterval: DateInterval {
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        return ExpenseFilterManager().dateInterval(for: prevMonth)
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
        currentInterval.start...currentInterval.end
    }
    
    // Get the number of days in each month for x-axis
    private var daysInMonths: (current: Int, previous: Int) {
        let currentDays = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 31
        
        if let prevDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            let prevDays = calendar.range(of: .day, in: .month, for: prevDate)?.count ?? 31
            return (currentDays, prevDays)
        }
        
        return (currentDays, 0)
    }
    
    // Calculate cumulative totals for a specific collection of expenses - now with tuples
    private func cumulativeDailyTotals(from expenses: [Expense], in interval: DateInterval, limitToToday: Bool) -> [(date: Date, total: Decimal)] {
        var grouped: [Date: Decimal] = [:]
        for expense in expenses {
            guard let date = expense.date else { continue }
            let day = calendar.startOfDay(for: date)
            let amount = expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0
            grouped[day, default: 0] += amount
        }
        
        var result: [(date: Date, total: Decimal)] = []
        var runningTotal: Decimal = 0
        
        for day in daysInMonth {
            guard let date = calendar.date(bySetting: .day, value: day, of: interval.start),
                  !limitToToday || date <= today else { break }
            
            let amount = grouped[calendar.startOfDay(for: date)] ?? 0
            runningTotal += amount
            result.append((date: date, total: runningTotal))
        }
        return result
    }
    
    private var previousMonthTotalsAligned: [(date: Date, total: Decimal)] {
        let raw = cumulativeDailyTotals(from: previousMonthExpenses, in: previousInterval, limitToToday: false)
        return raw.enumerated().compactMap { index, item in
            guard let alignedDate = calendar.date(bySetting: .day, value: index + 1, of: currentInterval.start) else { return nil }
            return (date: alignedDate, total: item.total)
        }
    }
    
    private var currentMonthTotals: [(date: Date, total: Decimal)] {
        cumulativeDailyTotals(from: currentMonthExpenses, in: currentInterval, limitToToday: true)
    }
    
    // Fetch previous month's expenses
    private func fetchPreviousMonthExpenses() {
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            previousInterval.start as NSDate,
            previousInterval.end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]
        
        do {
            previousMonthExpenses = try viewContext.fetch(request)
        } catch {
            print("Error fetching previous month expenses: \(error)")
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
        .animation(.easeInOut, value: previousMonthTotalsAligned.count)
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

import SwiftUI
import Charts
import CoreData
import Combine

// ViewModel to handle data processing outside the View
class MonthlyComparisonViewModel: ObservableObject {
    @Published var currentMonthTotals: [(date: Date, total: Decimal)] = []
    @Published var previousMonthTotals: [(date: Date, total: Decimal)] = []
    @Published var selectedDate: Date
    @Published var dateRange: ClosedRange<Date>?
    @Published var xAxisLabels: [Int] = []
    
    private var currentMonthExpenses: [Expense] = []
    private var previousMonthExpenses: [Expense] = []
    private var cancellables = Set<AnyCancellable>()
    private let context: NSManagedObjectContext
    private let calendar = Calendar.current
    
    init(context: NSManagedObjectContext, initialDate: Date, initialExpenses: [Expense] = []) {
        self.context = context
        self.selectedDate = initialDate
        self.currentMonthExpenses = initialExpenses
        
        // Calculate date range and x-axis labels immediately
        updateDateRange()
        updateXAxisLabels()
        
        // Process initial expenses
        processCurrentMonthExpenses(initialExpenses)
        
        // Fetch previous month expenses
        Task {
            await fetchPreviousMonthExpenses()
        }
    }
    
    func updateCurrentMonthExpenses(_ expenses: [Expense]) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.currentMonthExpenses = expenses
            self.processCurrentMonthExpenses(expenses)
        }
    }
    
    func updateSelectedDate(_ date: Date) {
        self.selectedDate = date
        updateDateRange()
        updateXAxisLabels()
        
        // Fetch previous month's data with the new date
        Task {
            await fetchPreviousMonthExpenses()
        }
    }
    
    private func updateDateRange() {
        let interval = ExpenseFilterManager().dateInterval(for: selectedDate)
        DispatchQueue.main.async { [weak self] in
            self?.dateRange = interval.start...interval.end
        }
    }
    
    private func updateXAxisLabels() {
        let lastDay = calendar.range(of: .day, in: .month, for: selectedDate)?.last ?? 28
        
        // Create evenly spaced labels - divide the month into equal segments
        let numberOfLabels = 6 // Including first and last day
        let stepSize = max(1, lastDay / (numberOfLabels - 1))
        
        var labels: [Int] = []
        for i in 0..<numberOfLabels {
            let day = min(1 + (i * stepSize), lastDay)
            labels.append(day)
        }
        
        // Ensure first and last day are included
        if !labels.contains(1) {
            labels.insert(1, at: 0)
        }
        if !labels.contains(lastDay) {
            labels.append(lastDay)
        }
        
        // Add today if it's in the current month and not already included
        let today = calendar.startOfDay(for: Date())
        let isCurrentMonth = calendar.isDate(today, equalTo: selectedDate, toGranularity: .month)
        
        if isCurrentMonth {
            let todayDay = calendar.component(.day, from: today)
            // Only add today if it's not the first or last day (which are already shown)
            if todayDay != 1 && todayDay != lastDay && !labels.contains(todayDay) {
                labels.append(todayDay)
            }
        }
        
        // Sort and remove duplicates
        labels = Array(Set(labels)).sorted()
        
        DispatchQueue.main.async { [weak self] in
            self?.xAxisLabels = labels
        }
    }
    
    private func processCurrentMonthExpenses(_ expenses: [Expense]) {
        let currentInterval = ExpenseFilterManager().dateInterval(for: selectedDate)
        let today = calendar.startOfDay(for: Date())
        
        let totals = calculateCumulativeTotals(from: expenses, in: currentInterval, limitToToday: true, today: today)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentMonthTotals = totals
        }
    }
    
    func processPreviousMonthExpenses(_ expenses: [Expense]) {
        // If there are no expenses, set empty array and return early
        guard !expenses.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.previousMonthTotals = []
            }
            return
        }
        
        let currentInterval = ExpenseFilterManager().dateInterval(for: selectedDate)
        let previousInterval = getPreviousMonthInterval()
        
        // Calculate raw previous month totals
        let rawTotals = calculateCumulativeTotals(from: expenses, in: previousInterval, limitToToday: false, today: Date())
        
        // Check if we have any actual spending (non-zero totals)
        let hasPreviousSpending = rawTotals.contains { NSDecimalNumber(decimal: $0.total).doubleValue > 0 }
        
        if hasPreviousSpending {
            // Align to current month days
            let alignedTotals = alignPreviousMonthTotals(rawTotals, currentInterval: currentInterval)
            
            DispatchQueue.main.async { [weak self] in
                self?.previousMonthTotals = alignedTotals
            }
        } else {
            // If no actual spending, set empty array
            DispatchQueue.main.async { [weak self] in
                self?.previousMonthTotals = []
            }
        }
    }
    
    private func getPreviousMonthInterval() -> DateInterval {
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        return ExpenseFilterManager().dateInterval(for: prevMonth)
    }
    
    private func alignPreviousMonthTotals(_ totals: [(date: Date, total: Decimal)], currentInterval: DateInterval) -> [(date: Date, total: Decimal)] {
        return totals.enumerated().compactMap { index, item in
            guard let alignedDate = calendar.date(bySetting: .day, value: index + 1, of: currentInterval.start) else { return nil }
            return (date: alignedDate, total: item.total)
        }
    }
    
    private func calculateCumulativeTotals(from expenses: [Expense], in interval: DateInterval, limitToToday: Bool, today: Date) -> [(date: Date, total: Decimal)] {
        let daysInMonth = (calendar.range(of: .day, in: .month, for: interval.start)?.lowerBound ?? 1)..<(calendar.range(of: .day, in: .month, for: interval.start)?.upperBound ?? 31)
        
        // Group expenses by day and sum amounts
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
    
    @MainActor
    func fetchPreviousMonthExpenses() async {
        let previousInterval = getPreviousMonthInterval()
        
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            previousInterval.start as NSDate,
            previousInterval.end as NSDate
        )
        
        do {
            let expenses = try context.fetch(request)
            self.previousMonthExpenses = expenses
            processPreviousMonthExpenses(expenses)
        } catch {
            print("Error fetching previous month expenses: \(error)")
        }
    }
}

struct MonthlyComparisonChart: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var viewModel: MonthlyComparisonViewModel
    
    // Input state from parent
    let currentMonthExpenses: [Expense]
    let selectedDate: Date
    
    // MARK: - Initialization with dependency injection
    init(currentMonthExpenses: [Expense], selectedDate: Date) {
        self.currentMonthExpenses = currentMonthExpenses
        self.selectedDate = selectedDate
        
        // Create the view model with initial data
        _viewModel = StateObject(wrappedValue: MonthlyComparisonViewModel(
            context: CoreDataStack.shared.context,
            initialDate: selectedDate,
            initialExpenses: currentMonthExpenses
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            if let dateRange = viewModel.dateRange {
                Chart {
                    // Today's vertical reference line
                    if Calendar.current.isDate(Date(), equalTo: selectedDate, toGranularity: .month) {
                        let today = Calendar.current.startOfDay(for: Date())
                        RuleMark(x: .value("Today", today))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    
                    // 🔹 Previous month line - only show if there are values
                    if !viewModel.previousMonthTotals.isEmpty {
                        ForEach(viewModel.previousMonthTotals.indices, id: \.self) { index in
                            let item = viewModel.previousMonthTotals[index]
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
                    
                    // ⚪️ Current month line with area gradient
                    ForEach(viewModel.currentMonthTotals.indices, id: \.self) { index in
                        let item = viewModel.currentMonthTotals[index]
                        
                        // Area gradient under the line
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Total", NSDecimalNumber(decimal: item.total).doubleValue)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            .linearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Main line
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
                    if let last = viewModel.currentMonthTotals.last {
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
                    // Only show today's date if in current month
                    if Calendar.current.isDate(Date(), equalTo: selectedDate, toGranularity: .month) {
                        let todayDate = Calendar.current.startOfDay(for: Date())
                        let today = Calendar.current.component(.day, from: Date())
                        
                        AxisMarks(values: [todayDate]) { _ in
                            AxisValueLabel {
                                Text("\(today)")
                                    .foregroundColor(.white)
                                    .font(.system(size: 10))
                                    .fixedSize()
                            }
                            
                            AxisTick(stroke: StrokeStyle(lineWidth: 1))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            AxisGridLine()
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    } else {
                        // If not viewing current month, hide all axis labels
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                                .foregroundStyle(.clear)
                            AxisTick()
                                .foregroundStyle(.clear)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .background(Color.clear)
            } else {
                // Placeholder view while loading
                ProgressView()
                    .frame(width: geometry.size.width, height: 200)
            }
        }
        .frame(height: 164)
        .padding(.horizontal, 16)
        .onChange(of: currentMonthExpenses) { _, newExpenses in
            viewModel.updateCurrentMonthExpenses(newExpenses)
        }
        .onChange(of: selectedDate) { _, newDate in
            viewModel.updateSelectedDate(newDate)
        }
    }
}

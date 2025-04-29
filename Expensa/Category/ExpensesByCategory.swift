//
//  ExpensesByCategory.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import SwiftUI
import CoreData

enum ExpenseSorting: String, CaseIterable {
    case dateNewest, dateOldest, amountHighest, amountLowest
    
    var description: String {
        switch self {
        case .dateNewest: return "Newest first"
        case .dateOldest: return "Oldest first"
        case .amountHighest: return "Highest amount"
        case .amountLowest: return "Lowest amount"
        }
    }
}

struct MonthlyTrendView: View {
    let data: [(Date, Decimal)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthlyTrendChart(data: data)
                .frame(height: 200)
                .padding(.horizontal, 8) // Add side padding for the chart
        }
        .padding(.vertical)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

struct ExpensesByCategoryView: View {
    // MARK: - Environment & StateObjects
    @EnvironmentObject private var currencyManager: CurrencyManager
    @StateObject private var filterManager: ExpenseFilterManager
    @State private var showingDatePicker = false
    
    // MARK: - State
    @State private var selectedSorting: ExpenseSorting = .dateNewest
    @State private var selectedExpense: Expense?
    
    // MARK: - Properties
    let category: Category
    private let analytics = ExpenseAnalytics.shared
    
    // MARK: - Fetch Request for category expenses
    @FetchRequest private var expenses: FetchedResults<Expense>
    
    // MARK: - Computed Properties
    // Get 6 months of data regardless of selected period
    private var monthlyData: [(Date, Decimal)] {
        // Get all expenses for this category for the past 6 months
        let calendar = Calendar.current
        let today = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -5, to: calendar.startOfMonth(for: today))!
        
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.predicate = NSPredicate(
            format: "category == %@ AND date >= %@",
            category,
            sixMonthsAgo as NSDate
        )
        
        do {
            let allExpenses = try CoreDataStack.shared.context.fetch(request)
            return analytics.calculateMonthlyTrend(for: allExpenses)
        } catch {
            print("Error fetching 6-month expenses: \(error.localizedDescription)")
            return []
        }
    }
    
    private var maxExpenseDay: (date: Date, amount: Decimal)? {
        analytics.findPeakSpendingDay(for: Array(expenses))
    }
    
    private var sortedExpenses: [Expense] {
        Array(expenses).sorted { first, second in
            switch selectedSorting {
            case .dateNewest:
                return (first.date ?? Date()) > (second.date ?? Date())
            case .dateOldest:
                return (first.date ?? Date()) < (second.date ?? Date())
            case .amountHighest:
                let firstAmount = first.convertedAmount?.decimalValue ?? first.amount?.decimalValue ?? 0
                let secondAmount = second.convertedAmount?.decimalValue ?? second.amount?.decimalValue ?? 0
                return firstAmount > secondAmount
            case .amountLowest:
                let firstAmount = first.convertedAmount?.decimalValue ?? first.amount?.decimalValue ?? 0
                let secondAmount = second.convertedAmount?.decimalValue ?? second.amount?.decimalValue ?? 0
                return firstAmount < secondAmount
            }
        }
    }
    
    private var totalAmountForPeriod: Decimal {
        analytics.calculateTotalSpent(for: Array(expenses))
    }
    
    // MARK: - Initialization
    init(category: Category, selectedDate: Date = Date(), filterManager: ExpenseFilterManager? = nil) {
        self.category = category
        
        // Create or use filterManager
        let fm = filterManager ?? {
            let newFM = ExpenseFilterManager()
            newFM.selectedDate = selectedDate
            return newFM
        }()
        
        self._filterManager = StateObject(wrappedValue: fm)
        
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        
        // Get date interval based on filter manager
        let interval = fm.currentPeriodInterval()
        
        // Filter by both category and date range
        request.predicate = NSPredicate(
            format: "category == %@ AND date >= %@ AND date <= %@",
            category,
            interval.start as NSDate,
            interval.end as NSDate
        )
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        _expenses = FetchRequest(fetchRequest: request)
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                categoryHeader
                VStack(spacing: 16) {
                    MonthlyTrendView(data: monthlyData)
                    
                    if !sortedExpenses.isEmpty {
                        expensesList
                    } else {
                        noExpensesView
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(item: $selectedExpense) { _ in
            ExpenseDetailView(
                expense: $selectedExpense,
                onDelete: {
                    if let expense = selectedExpense {
                        ExpenseDataManager.shared.deleteExpense(expense)
                        selectedExpense = nil
                    }
                }
            )
            .environmentObject(currencyManager)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: filterManager.selectedDate) { _, _ in
            updateFetchRequestPredicate()
        }
        .onChange(of: filterManager.endDate) { _, _ in
            updateFetchRequestPredicate()
        }
        .onChange(of: filterManager.isRangeMode) { _, _ in
            updateFetchRequestPredicate()
        }
    }
    
    // MARK: - View Components
    private var categoryHeader: some View {
        ZStack {
            let fontSize: CGFloat = 30
            let iconPositions: [(x: CGFloat, y: CGFloat, rotation: Double, scale: CGFloat, opacity: Double)] = [
                (UIScreen.main.bounds.width * 0.5, 0, 15, 1.3, 0.5),
                (UIScreen.main.bounds.width - (fontSize / 1.5), 15, -58.9, 1.5, 0.2),
                (-(fontSize / 2.5), 25, 30, 1.2, 0.5),
                (UIScreen.main.bounds.width * 0.2, 65, -64, 1, 0.2),
                (UIScreen.main.bounds.width * 0.7, 70, 80, 1, 0.2)
            ]
            
            ForEach(Array(iconPositions.enumerated()), id: \.offset) { index, position in
                Text(category.icon ?? "❓")
                    .font(.system(size: fontSize))
                    .opacity(position.opacity)
                    .rotationEffect(.degrees(position.rotation))
                    .scaleEffect(position.scale)
                    .position(x: position.x, y: position.y)
            }
            
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemGray6))
                        .frame(width: 60, height: 60)
                    
                    Text(category.icon ?? "❓")
                        .font(.system(size: 30))
                }
                
                Text(category.name ?? "Unknown Category")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Spent in \(filterManager.formattedPeriod())")
                    .font(.body)

                if let defaultCurrency = currencyManager.defaultCurrency {
                    Text(currencyManager.currencyConverter.formatAmount(
                        totalAmountForPeriod,
                        currency: defaultCurrency
                    ))
                    .font(.title3)
                    .foregroundColor(.secondary)
                    
                    if let maxDay = maxExpenseDay {
                        HStack(spacing: 4) {
                            Text("Peak day:")
                                .foregroundColor(.secondary)
                            Text(maxDay.date.formatted(.relative))
                                .foregroundColor(.secondary)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(currencyManager.currencyConverter.formatAmount(
                                maxDay.amount,
                                currency: defaultCurrency
                            ))
                            .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .padding(.vertical)
        }
        .frame(height: 250)
    }
    
    private var expensesList: some View {
        VStack(alignment: .leading, spacing: 8) {            
            GroupedExpensesView(
                expenses: sortedExpenses,
                onExpenseSelected: { expense in
                    selectedExpense = expense
                }
            )
        }
    }
    
    private var noExpensesView: some View {
        VStack(spacing: 16) {
            Text("No expenses in this period")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("There are no expenses recorded for this category in the selected period. You can see the trend from previous months in the chart above.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding(.top, 32)
    }
    
    // MARK: - Helper Methods
    private func updateFetchRequestPredicate() {
        let interval = filterManager.currentPeriodInterval()
        expenses.nsPredicate = NSPredicate(
            format: "category == %@ AND date >= %@ AND date <= %@",
            category,
            interval.start as NSDate,
            interval.end as NSDate
        )
    }
}

// Helper extension
private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

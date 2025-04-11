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
        }
        .padding(.vertical)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

struct ExpensesByCategoryView: View {
    // MARK: - Environment & StateObjects
    @EnvironmentObject private var currencyManager: CurrencyManager
    @StateObject private var filterManager = ExpenseFilterManager()
    
    // MARK: - State
    @State private var selectedSorting: ExpenseSorting = .dateNewest
    @State private var selectedExpense: Expense?
    
    // MARK: - Properties
    let category: Category
    let selectedDate: Date
    private let analytics = ExpenseAnalytics.shared
    
    // MARK: - Fetch Request
    @FetchRequest private var expenses: FetchedResults<Expense>
    
    // MARK: - Computed Properties
    private var monthlyData: [(Date, Decimal)] {
        analytics.calculateMonthlyTrend(for: Array(expenses))
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
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: filterManager.selectedDate)
    }
    
    // MARK: - Initialization
    init(category: Category, selectedDate: Date = Date()) {
        self.category = category
        self.selectedDate = selectedDate
        
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        
        // Create date range for the selected month
        let calendar = Calendar.current
        let interval = DateInterval(
            start: calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!,
            end: calendar.date(byAdding: .month, value: 1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!)!.addingTimeInterval(-1)
        )
        
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
                    //                sortingMenu
                    expensesList
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
                
                Text("Spent in \(monthName)")
                    .font(.body)

                if let defaultCurrency = currencyManager.defaultCurrency {
                    Text(currencyManager.currencyConverter.formatAmount(
                        analytics.calculateTotalSpent(for: Array(expenses)),
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
    
    private var sortingMenu: some View {
        Menu {
            ForEach(ExpenseSorting.allCases, id: \.self) { sorting in
                Button(action: { selectedSorting = sorting }) {
                    if sorting == selectedSorting {
                        Label(sorting.description, systemImage: "checkmark")
                    } else {
                        Text(sorting.description)
                    }
                }
            }
        } label: {
            HStack {
                Text("Sort: \(selectedSorting.description)")
                Image(systemName: "chevron.up.chevron.down")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var expensesList: some View {
        GroupedExpensesView(
            expenses: sortedExpenses,
            onExpenseSelected: { expense in
                selectedExpense = expense
            }
        )
    }
}

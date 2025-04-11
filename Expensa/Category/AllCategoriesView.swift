//
//  AllCategoriesView.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import Foundation
import SwiftUI
import CoreData
import UIKit

// UIViewRepresentable wrapper for UIDatePicker in yearAndMonth mode
struct MonthYearPickerView: UIViewRepresentable {
    @Binding var selectedDate: Date
    
    func makeUIView(context: Context) -> UIDatePicker {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        
        datePicker.maximumDate = Date()
        
        // Using exactly the provided implementation
        datePicker.datePickerMode = .yearAndMonth
        datePicker.preferredDatePickerStyle = .wheels
        
        datePicker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        return datePicker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = selectedDate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: MonthYearPickerView
        
        init(_ parent: MonthYearPickerView) {
            self.parent = parent
        }
        
        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.selectedDate = sender.date
        }
    }
}

struct GroupedExpenseRow: View {
    let category: Category
    let expenses: [Expense]
    let budget: CategoryBudget?
    let totalSpent: Decimal
    let selectedDate: Date
    
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        NavigationLink(destination: ExpensesByCategoryView(
            category: category,
            selectedDate: selectedDate
            )
            .toolbar(.hidden, for: .tabBar)) {
            
            HStack(alignment: .center, spacing: 12) {
                // Left side with circular progress/icon
                CategoryIconView(
                    category: category,
                    budget: budget,
                    spent: totalSpent
                )
                
                // Category info
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name ?? "Unknown")
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(expenses.count) expense\(expenses.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.64))
                }
                
                Spacer()
                
                // Right side - amount info
                CategoryAmountView(
                    category: category,
                    budget: budget,
                    spent: totalSpent
                )
            }
            .padding(12)
        }
    }
}

// Extract the icon/progress circle to its own component
struct CategoryIconView: View {
    let category: Category
    let budget: CategoryBudget?
    let spent: Decimal
    
    private var hasLimit: Bool {
        budget?.budgetAmount?.decimalValue != nil
    }
    
    var body: some View {
        ZStack {
            if hasLimit, let limit = budget?.budgetAmount?.decimalValue {
                // Only show circular progress if this category has a budget limit
                let percentage = Double(truncating: (spent / limit) as NSDecimalNumber)
                CircularProgressView(
                    progress: percentage,
                    isOverBudget: spent > limit
                )
                
                CategoryCircleIcon(
                    icon: category.icon ?? "❓",
                    size: 40,  // Smaller size when there's a progress circle
                    iconSize: 20,
                    color: Color.primary.opacity(0.08)
                )
            } else {
                // Larger icon when no budget limit is set
                CategoryCircleIcon(
                    icon: category.icon ?? "❓",
                    size: 48,  // Larger size (48px) when no progress circle
                    iconSize: 20,
                    color: Color.primary.opacity(0.08)
                )
            }
        }
    }
}

// Extract the amount display to its own component
struct CategoryAmountView: View {
    let category: Category
    let budget: CategoryBudget?
    let spent: Decimal
    
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    private var hasLimit: Bool {
        budget?.budgetAmount?.decimalValue != nil
    }
    
    var body: some View {
        if let currency = budget?.budgetCurrency ?? currencyManager.defaultCurrency {
            VStack(alignment: .trailing, spacing: 4) {
                // Total spent
                Text(currencyManager.currencyConverter.formatAmount(
                    spent,
                    currency: currency
                ))
                .font(.body)
                .foregroundColor(.primary)
                
                // Remaining amount or "Limit is not set"
                if hasLimit, let limit = budget?.budgetAmount?.decimalValue {
                     let remaining = limit - spent
                     
                     if remaining < 0 {
                         // Over budget - don't show minus sign
                         Text("\(currencyManager.currencyConverter.formatAmount(abs(remaining), currency: currency)) over")
                             .font(.subheadline)
                             .foregroundColor(.red)
                     } else {
                         // Under budget
                         Text("\(currencyManager.currencyConverter.formatAmount(remaining, currency: currency)) left")
                             .font(.subheadline)
                             .foregroundColor(.secondary)
                     }
                 } else {
                     Text("Limit is not set")
                         .font(.subheadline)
                         .foregroundColor(.secondary)
                 }
             }
        } else if let defaultCurrency = currencyManager.defaultCurrency {
            // Fallback for when no budget is available
            Text(currencyManager.currencyConverter.formatAmount(
                spent,
                currency: defaultCurrency
            ))
            .font(.body)
            .foregroundColor(.primary)
        }
    }
}

// Month selector component to maintain the same functionality from the pie chart
struct MonthSelectorView: View {
    let monthDisplay: String
    let onMonthChange: (Bool) -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        HStack {
            Button(action: { onMonthChange(false) }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            
            Spacer()
            
            Text(monthDisplay)
                .font(.headline)
                .foregroundColor(.primary)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            isDragging = true
                            let maxDrag: CGFloat = 110
                            dragOffset = max(-maxDrag, min(maxDrag, gesture.translation.width))
                        }
                        .onEnded { gesture in
                            let threshold: CGFloat = 80
                            
                            if dragOffset > threshold {
                                onMonthChange(false)
                            } else if dragOffset < -threshold {
                                onMonthChange(true)
                            }
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isDragging = false
                            }
                        }
                )
            
            Spacer()
            
            Button(action: { onMonthChange(true) }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 8)
    }
}

struct AllCategoriesView: View {
    // Environment
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // State
    @StateObject private var filterManager = ExpenseFilterManager()
    @State private var showingDatePicker = false
    @State private var pickerDate: Date
    @State private var currentBudget: Budget?
    
    // Fetch Request
    @FetchRequest private var fetchedExpenses: FetchedResults<Expense>
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: filterManager.selectedDate)
    }
    
    // Computed property for categorized expenses
    private var categorizedExpenses: [(Category, [Expense])] {
        guard !fetchedExpenses.isEmpty else {
            return []
        }
        
        let categories = Set(fetchedExpenses.compactMap { $0.category })
        let categoryTuples = categories.map { category in
            (
                category,
                fetchedExpenses.filter { $0.category == category }
            )
        }
        return categoryTuples.sorted { first, second in
            let firstAmount = ExpenseDataManager.shared.calculateTotalAmount(for: first.1)
            let secondAmount = ExpenseDataManager.shared.calculateTotalAmount(for: second.1)
            
            // First sort by amount spent (descending)
            if firstAmount != secondAmount {
                return firstAmount > secondAmount
            }
            
            // If amounts are equal, sort by category name (ascending)
            return (first.0.name ?? "") < (second.0.name ?? "")
        }
    }
    
    // Total expenses amount directly from ExpenseDataManager
    private var totalExpensesAmount: Decimal {
        ExpenseDataManager.shared.calculateTotalAmount(for: Array(fetchedExpenses))
    }
    
    // Initialization with custom fetch request
    init() {
        // Initialize picker date state
        _pickerDate = State(initialValue: Date())
        
        // Create and configure fetch request
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Expense.createdAt, ascending: false)
        ]
        
        // Initialize date filtering
        let filterManager = ExpenseFilterManager()
        let initialInterval = filterManager.dateInterval(for: Date())
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            initialInterval.start as NSDate,
            initialInterval.end as NSDate
        )
        
        // Initialize the fetch request with animation
        self._fetchedExpenses = FetchRequest(
            fetchRequest: request
        )
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spent in \(monthName)")
                        .font(.body)
                        .foregroundColor(.primary).opacity(0.64)
                    // Total Amount Display
                    if let defaultCurrency = currencyManager.defaultCurrency {
                        Text(CurrencyConverter.shared.formatAmount(
                            totalExpensesAmount,
                            currency: defaultCurrency
                        ))
                        .font(.system(size: 32, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                // Pie Chart or Empty State
//                CategoryPieChartView(
//                    categorizedExpenses: categorizedExpenses,
//                    totalExpenses: totalExpensesAmount,
//                    monthDisplay: monthName,
//                    onMonthChange: { isNextMonth in
//                        changeMonth(isNextMonth: isNextMonth)
//                    }
//                )
                SegmentedLineChartView(
                    categorizedExpenses: categorizedExpenses,
                    totalExpenses: totalExpensesAmount,
                    height: 32,
                    segmentSpacing: 2
                )
                .padding(.horizontal, 16)
                
                // Categories list using the reusable rows
                if !categorizedExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(spacing: 4) {
                            ForEach(categorizedExpenses, id: \.0.id) { categoryData in
                                let category = categoryData.0
                                let expenses = categoryData.1
                                
                                // Get the CategoryBudget if available
                                let categoryBudget = currentBudget?.categoryBudgets?
                                    .compactMap { $0 as? CategoryBudget }
                                    .first { $0.category == category }
                                
                                // Calculate total spent
                                let spent = expenses.reduce(Decimal(0)) { sum, expense in
                                    sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
                                }
                                
                                GroupedExpenseRow(
                                    category: category,
                                    expenses: expenses,
                                    budget: categoryBudget,
                                    totalSpent: spent,
                                    selectedDate: filterManager.selectedDate
                                )
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
        .navigationTitle("All categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Add the calendar button to the toolbar
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Set picker date to current selected date
                    pickerDate = filterManager.selectedDate
                    showingDatePicker = true
                }) {
                    Image("calendar")
                        .renderingMode(.template)
                        .foregroundColor(.primary)
                }
            }
        }
        // This is already implemented in your code
        .onChange(of: filterManager.selectedDate) { _, newDate in
            updateFetchRequestPredicate(for: newDate)
            
            // Update budget for the selected month
            Task {
                currentBudget = await BudgetManager.shared.getBudgetFor(month: newDate)
            }
        }
        
        // Initial loading
        .onAppear {
            Task {
                // Initially load the budget for the selected month
                currentBudget = await BudgetManager.shared.getBudgetFor(month: filterManager.selectedDate)
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            // Month/Year picker sheet
            NavigationStack {
                VStack {
                    // Use the MonthYearPickerView for date selection
                    MonthYearPickerView(selectedDate: $pickerDate)
                        .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingDatePicker = false
                        }
                        .foregroundColor(.primary)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Show") {
                            // Apply the date from the picker
                            filterManager.selectedDate = pickerDate
                            showingDatePicker = false
                        }
                        .foregroundColor(.primary)
                    }
                }
                .navigationTitle("Select month")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.height(300)])
        }
    }
    
    // Helper methods
    private func updateFetchRequestPredicate(for date: Date) {
        let interval = filterManager.dateInterval(for: date)
        fetchedExpenses.nsPredicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            interval.start as NSDate,
            interval.end as NSDate
        )
    }
    
    // New function to change the month based on drag gesture
    private func changeMonth(isNextMonth: Bool) {
        let calendar = Calendar.current
        
        // Create a date one month before or after the current selected date
        if let newDate = calendar.date(
            byAdding: .month,
            value: isNextMonth ? 1 : -1,
            to: filterManager.selectedDate
        ) {
            // Provide haptic feedback for every month change attempt
            let generator = UINotificationFeedbackGenerator()
            
            // Make sure we don't go past the current date
            if !isNextMonth || newDate <= Date() {
                withAnimation {
                    filterManager.selectedDate = newDate
                    generator.notificationOccurred(.success)
                }
            } else {
                // If trying to go to a future month, provide warning haptic feedback
                generator.notificationOccurred(.warning)
            }
        }
    }
    
    // Date formatter for displaying month and year
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
}

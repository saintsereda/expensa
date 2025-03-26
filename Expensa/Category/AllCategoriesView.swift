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

struct AllCategoriesView: View {
    // Environment
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // State
    @StateObject private var filterManager = ExpenseFilterManager()
    @State private var showingDatePicker = false
    @State private var pickerDate: Date
    
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
            VStack(spacing: 16) {
                // Pie Chart or Empty State
                CategoryPieChartView(
                    categorizedExpenses: categorizedExpenses,
                    totalExpenses: totalExpensesAmount,
                    monthDisplay: monthName,
                    onMonthChange: { isNextMonth in
                        changeMonth(isNextMonth: isNextMonth)
                    }
                )
                
                // Categories list or empty state
                if !categorizedExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(categorizedExpenses.enumerated()), id: \.element.0) { index, categoryData in
                            CategoryExpensesRow(
                                category: categoryData.0,
                                expenses: categoryData.1,
                                totalExpenses: totalExpensesAmount
                            )
                            .padding(12)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
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
                    Image(systemName: "calendar")
                }
            }
        }
        .onChange(of: filterManager.selectedDate) { _, newDate in
            updateFetchRequestPredicate(for: newDate)
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
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Show") {
                            // Apply the date from the picker
                            filterManager.selectedDate = pickerDate
                            showingDatePicker = false
                        }
                    }
                }
                .navigationTitle("Select Month")
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

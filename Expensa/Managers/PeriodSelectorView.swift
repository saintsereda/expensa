//
//  PeriodPickerView.swift (Modified)
//  Expensa
//
//  Created by Andrew Sereda on 02.05.2025.
//fffff

import Foundation
import SwiftUI

// MARK: - Period Picker Sheet with Callback
struct PeriodPickerView: View {
    // We'll keep filterManager for initial state, but not modify it directly
    let filterManager: ExpenseFilterManager
    @Binding var showingDatePicker: Bool
    
    // New callback for period selection
    var onPeriodSelected: (Date, Date, Bool) -> Void
    
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedMode: DateRangeMode = .singleMonth
    
    enum DateRangeMode: String, CaseIterable, Identifiable {
        case singleMonth = "Month"
        case customRange = "Range"
        case presets = "Presets"
        
        var id: String { self.rawValue }
    }
    
    init(
        filterManager: ExpenseFilterManager,
        showingDatePicker: Binding<Bool>,
        onPeriodSelected: @escaping (Date, Date, Bool) -> Void
    ) {
        self.filterManager = filterManager
        self._showingDatePicker = showingDatePicker
        self.onPeriodSelected = onPeriodSelected
        self._startDate = State(initialValue: filterManager.selectedDate)
        self._endDate = State(initialValue: filterManager.endDate)
        self._selectedMode = State(initialValue: filterManager.isRangeMode ? .customRange : .singleMonth)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Mode selector
                Picker("Mode", selection: $selectedMode) {
                    ForEach(DateRangeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Different picker views based on mode
                if selectedMode == .singleMonth {
                    // Month Year picker
                    MonthYearPickerView(selectedDate: $startDate)
                }
                else if selectedMode == .presets {
                    // Preset periods
                    PeriodPresetsView(startDate: $startDate, endDate: $endDate)
                }
                else {
                    // Custom date range picker
                    DateRangePickerView(startDate: $startDate, endDate: $endDate)
                }
                
                Spacer()
            }
            .padding(.top, 16)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedback.play()
                        showingDatePicker = false
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        HapticFeedback.play()
                        
                        // Instead of directly updating filterManager,
                        // call the callback with the selected period
                        let isRangeMode = selectedMode != .singleMonth
                        onPeriodSelected(startDate, endDate, isRangeMode)
                        
                        showingDatePicker = false
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Period")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(400)])
    }
}

// MARK: - Period Selector View
struct PeriodSelectorView: View {
    // Now takes a callback instead of directly modifying filterManager
    var formattedPeriod: String
    var onPreviousPeriod: () -> Void
    var onNextPeriod: () -> Void
    var onSelectPeriod: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        HStack {
            // Previous period button
            Button(action: onPreviousPeriod) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            
            Spacer()
            
            // Period text - tap to open date picker
            Button(action: onSelectPeriod) {
                Text(formattedPeriod)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
            }
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
                            onPreviousPeriod()
                        } else if dragOffset < -threshold {
                            onNextPeriod()
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
            
            // Next period button
            Button(action: onNextPeriod) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Month Year Picker

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

// MARK: - Date Range Picker
struct DateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("From:")
                    .font(.headline)
                Spacer()
                
                DatePicker("", selection: $startDate, in: ...Date(), displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(width: 150)
                    .onChange(of: startDate) { _, newDate in
                        // Ensure end date isn't before start date
                        if endDate < newDate {
                            endDate = newDate
                        }
                    }
            }
            .padding(.horizontal)
            
            HStack {
                Text("To:")
                    .font(.headline)
                Spacer()
                
                DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(width: 150)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Period Presets View
struct PeriodPresetsView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    // Track the currently selected preset
    @State private var selectedPreset: PeriodPreset = .none
    
    let calendar = Calendar.current
    
    // Enum to track preset types
    enum PeriodPreset {
        case none
        case thisMonth
        case lastMonth
        case last3Months
        case last6Months
        case yearToDate
        case lastYear
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    presetButton("This Month", preset: .thisMonth) {
                        setThisMonth()
                        selectedPreset = .thisMonth
                    }
                    
                    presetButton("Last Month", preset: .lastMonth) {
                        setLastMonth()
                        selectedPreset = .lastMonth
                    }
                    
                    presetButton("Last 3 Months", preset: .last3Months) {
                        setLastNMonths(3)
                        selectedPreset = .last3Months
                    }
                    
                    presetButton("Last 6 Months", preset: .last6Months) {
                        setLastNMonths(6)
                        selectedPreset = .last6Months
                    }
                    
                    presetButton("Year to Date", preset: .yearToDate) {
                        setYearToDate()
                        selectedPreset = .yearToDate
                    }
                    
                    presetButton("Last Year", preset: .lastYear) {
                        setLastYear()
                        selectedPreset = .lastYear
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            // Determine which preset matches the current date range
            detectCurrentPreset()
        }
    }
    
    private func presetButton(_ title: String, preset: PeriodPreset, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                
                Spacer()
                
                // Show a checkmark for the selected preset
                if selectedPreset == preset {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Function to detect which preset matches the current date range
    private func detectCurrentPreset() {
        let today = Date()
        let thisYear = calendar.component(.year, from: today)
        
        // Get current month components
        let thisMonthComponents = calendar.dateComponents([.year, .month], from: today)
        if let thisMonthStart = calendar.date(from: thisMonthComponents),
           let thisMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: thisMonthStart) {
            
            // Check if it's "This Month"
            let thisMonthEndWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: thisMonthEnd) ?? thisMonthEnd
            if calendar.isDate(startDate, inSameDayAs: thisMonthStart) && calendar.isDate(endDate, inSameDayAs: thisMonthEndWithTime) {
                selectedPreset = .thisMonth
                return
            }
        }
        
        // Check for other presets
        // Last Month
        if let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: today) {
            let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonthDate)
            if let lastMonthStart = calendar.date(from: lastMonthComponents),
               let lastMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: lastMonthStart) {
                
                let lastMonthEndWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastMonthEnd) ?? lastMonthEnd
                if calendar.isDate(startDate, inSameDayAs: lastMonthStart) && calendar.isDate(endDate, inSameDayAs: lastMonthEndWithTime) {
                    selectedPreset = .lastMonth
                    return
                }
            }
        }
        
        // Year to Date
        let yearStartComponents = DateComponents(year: thisYear, month: 1, day: 1)
        if let yearStart = calendar.date(from: yearStartComponents) {
            let todayEndWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? today
            if calendar.isDate(startDate, inSameDayAs: yearStart) && calendar.isDate(endDate, inSameDayAs: todayEndWithTime) {
                selectedPreset = .yearToDate
                return
            }
        }
        
        // Last Year
        let lastYearComponents = DateComponents(year: thisYear - 1, month: 1, day: 1)
        let lastYearEndComponents = DateComponents(year: thisYear - 1, month: 12, day: 31)
        if let lastYearStart = calendar.date(from: lastYearComponents),
           let lastYearEnd = calendar.date(from: lastYearEndComponents) {
            
            let lastYearEndWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastYearEnd) ?? lastYearEnd
            if calendar.isDate(startDate, inSameDayAs: lastYearStart) && calendar.isDate(endDate, inSameDayAs: lastYearEndWithTime) {
                selectedPreset = .lastYear
                return
            }
        }
        
        // Check Last 3 Months
        if let threeMonthsAgo = calendar.date(byAdding: .month, value: -2, to: today) {
            let threeMonthsComponents = calendar.dateComponents([.year, .month], from: threeMonthsAgo)
            if let threeMonthsStart = calendar.date(from: threeMonthsComponents) {
                let todayEndWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? today
                
                if calendar.isDate(startDate, inSameDayAs: threeMonthsStart) && calendar.isDate(endDate, inSameDayAs: todayEndWithTime) {
                    selectedPreset = .last3Months
                    return
                }
            }
        }
        
        // Check Last 6 Months
        if let sixMonthsAgo = calendar.date(byAdding: .month, value: -5, to: today) {
            let sixMonthsComponents = calendar.dateComponents([.year, .month], from: sixMonthsAgo)
            if let sixMonthsStart = calendar.date(from: sixMonthsComponents) {
                let todayEndWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? today
                
                if calendar.isDate(startDate, inSameDayAs: sixMonthsStart) && calendar.isDate(endDate, inSameDayAs: todayEndWithTime) {
                    selectedPreset = .last6Months
                    return
                }
            }
        }
        
        // If none of the above, it's a custom range
        selectedPreset = .none
    }
    
    // Date preset functions
    private func setThisMonth() {
        let today = Date()
        let components = calendar.dateComponents([.year, .month], from: today)
        if let firstDay = calendar.date(from: components),
           let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) {
            startDate = firstDay
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
        }
    }
    
    private func setLastMonth() {
        let today = Date()
        var components = calendar.dateComponents([.year, .month], from: today)
        components.month = components.month! - 1
        if let firstDay = calendar.date(from: components),
           let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) {
            startDate = firstDay
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
        }
    }
    
    private func setLastNMonths(_ months: Int) {
        let today = Date()
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? today
        
        if let nMonthsAgo = calendar.date(byAdding: .month, value: -(months-1), to: today) {
            let components = calendar.dateComponents([.year, .month], from: nMonthsAgo)
            if let firstDay = calendar.date(from: components) {
                startDate = firstDay
                endDate = endOfToday
            }
        }
    }
    
    private func setYearToDate() {
        let today = Date()
        var components = calendar.dateComponents([.year], from: today)
        components.month = 1
        components.day = 1
        
        if let firstDay = calendar.date(from: components) {
            startDate = firstDay
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? today
        }
    }
    
    private func setLastYear() {
        let today = Date()
        var components = calendar.dateComponents([.year], from: today)
        components.year = components.year! - 1
        components.month = 1
        components.day = 1
        
        if let firstDay = calendar.date(from: components) {
            var endComponents = DateComponents()
            endComponents.year = components.year
            endComponents.month = 12
            endComponents.day = 31
            
            if let lastDay = calendar.date(from: endComponents) {
                startDate = firstDay
                endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
            }
        }
    }
}

//
//  CalendarView.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.11.2024.
//

import SwiftUI
import UIKit

struct CalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    @Binding var isRecurring: Bool
    @Binding var recurringFrequency: String
    let onDateSelected: (Date) -> Void
    
    @State private var tempDate: Date
    @State private var tempIsRecurring: Bool
    @State private var tempFrequency: String
    
    private let frequencyOptions = ["Daily", "Weekly", "Monthly", "Yearly"]
    
    init(selectedDate: Binding<Date>, isRecurring: Binding<Bool>, recurringFrequency: Binding<String>, onDateSelected: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self._isRecurring = isRecurring
        self._recurringFrequency = recurringFrequency
        self.onDateSelected = onDateSelected
        
        // Initialize temporary state
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
        self._tempIsRecurring = State(initialValue: isRecurring.wrappedValue)
        self._tempFrequency = State(initialValue: recurringFrequency.wrappedValue)
    }
    
    private var availableDateRange: DateInterval {
        let today = Calendar.current.startOfDay(for: Date())
        
        // By default (not recurring), only allow past and today's dates
        if !tempIsRecurring {
            return DateInterval(start: .distantPast, end: today)
        }
        
        // If recurring options selected, allow today and future dates
        return DateInterval(start: today, end: .distantFuture)
    }
    
    private var canConfigureRecurrence: Bool {
        let selectedDate = Calendar.current.startOfDay(for: tempDate)
        let today = Calendar.current.startOfDay(for: Date())
        
        // Recurrence dropdown is disabled if a past date is selected
        return selectedDate >= today
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CalendarViewWrapper(
                    selectedDate: $tempDate,
                    availableDateRange: availableDateRange
                ) { _ in }
                .frame(height: 360)
                .padding(.top, 16)
                .padding(.horizontal)
                
                Divider()
                HStack {
                    Text("Recurring")
                        .foregroundColor(canConfigureRecurrence ? .primary : .gray)
                    
                    Spacer()
                    Menu {
                        ForEach(frequencyOptions, id: \.self) { frequency in
                            if let nextDate = RecurringExpenseManager.shared.calculateNextDate(
                                from: tempDate,
                                frequency: frequency
                            ) {
                                Button(action: {
                                    tempIsRecurring = true
                                    tempFrequency = frequency
                                }) {
                                    Text("\(frequency)\n")
                                        .font(.body) +
                                    Text("Next \(nextDate.formatted(.custom("d MMM")))")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            tempIsRecurring = false
                            tempFrequency = "Not recurring"
                        }) {
                            Text("Not recurring")
                        }
                    } label: {
                        HStack {
                            Text(tempIsRecurring ? tempFrequency : "Not recurring")
                                .foregroundColor(canConfigureRecurrence ? .primary : .gray)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(canConfigureRecurrence ? .gray : .gray.opacity(0.5))
                        }
                    }
                    .disabled(!canConfigureRecurrence)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .opacity(canConfigureRecurrence ? 1 : 0.5)
                
                // Save button section
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        SaveButton(isEnabled: true) {
                            // Apply changes
                            selectedDate = tempDate
                            isRecurring = tempIsRecurring
                            recurringFrequency = tempFrequency
                            onDateSelected(tempDate)
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(Color(uiColor: .systemGray6))
            }
        }
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
    }
}

// Update CalendarViewWrapper to accept a custom date range
struct CalendarViewWrapper: UIViewRepresentable {
    @Binding var selectedDate: Date
    let availableDateRange: DateInterval
    let onDateSelected: (Date) -> Void

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.locale = .current
        calendarView.fontDesign = .rounded
        calendarView.delegate = context.coordinator

        // Set the available date range dynamically
        calendarView.availableDateRange = availableDateRange

        // Configure the selection behavior
        let dateSelection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        dateSelection.setSelected(components, animated: true)
        calendarView.selectionBehavior = dateSelection

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // Update available date range
        uiView.availableDateRange = availableDateRange

        if let selectionBehavior = uiView.selectionBehavior as? UICalendarSelectionSingleDate {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
            selectionBehavior.setSelected(components, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarViewWrapper

        init(parent: CalendarViewWrapper) {
            self.parent = parent
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents = dateComponents,
                  let date = Calendar.current.date(from: dateComponents) else { return }
            parent.selectedDate = date
        }
    }
}

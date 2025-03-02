//
//  BudgetView.swift
//  Expensa
//
//  Created by Andrew Sereda on 15.11.2024.
//  Shows empty state or set budgets

import Foundation
import SwiftUI

// MARK: - Updated Budget View
struct BudgetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedDate = Date()
    @State private var showAddBudget = false
    @State private var showEditBudget = false
    @State private var showDeleteAlert = false
    @State private var budgetToDelete: Budget?
    @State private var budgetToEdit: Budget?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    private let budgetManager = BudgetManager.shared
    
    // Simple fetch request for all budgets, sorted by date
    @FetchRequest(
        entity: Budget.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Budget.startDate, ascending: true)]
    ) private var allBudgets: FetchedResults<Budget>
    
    // Computed property to get budget for selected month
    private var selectedMonthBudget: Budget? {
        let calendar = Calendar.current
        return allBudgets.first { budget in
            guard let budgetDate = budget.startDate else { return false }
            return calendar.isDate(budgetDate, equalTo: selectedDate, toGranularity: .month)
        }
    }
    
    private var monthSwitcherView: some View {
        Menu {
            // Current month option
            Button("Current Month") {
                withAnimation {
                    selectedDate = Date()
                }
            }
            

            
            // Next months section
            Section("Next Months") {
                ForEach(1...6, id: \.self) { monthOffset in
                    let date = Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
                    Button(date.formatted(.dateTime.month(.wide).year())) {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                }
            }
            Divider()
            // Previous months section
            Section("Previous Months") {
                ForEach(1...6, id: \.self) { monthOffset in
                    let date = Calendar.current.date(byAdding: .month, value: -monthOffset, to: Date()) ?? Date()
                    Button(date.formatted(.dateTime.month(.wide).year())) {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                }
            }
        } label: {
            RoundButton(
                leftIcon: "calendar",
                label: selectedDate.formatted(.dateTime.month(.wide).year()),
                rightIcon: "chevron.down",
                action: {} // Menu takes care of the action, so this can be empty
            )
        }
    }
    
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                monthSwitcherView
                    .padding(.vertical)
                
                if let budget = selectedMonthBudget {
                    budgetListView(budget)
                } else {
                    emptyStateView
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showAddBudget) {
            BudgetForm()
        }
        .sheet(item: $budgetToEdit) { budget in
            BudgetForm(budget: budget)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Budget", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                guard let budget = budgetToDelete else { return }
                Task {
                    await deleteBudget(budget)
                }
            }
        } message: {
            Text("Are you sure you want to delete this budget? This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
        .disabled(isProcessing)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                )
            
            VStack(spacing: 12) {
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("No Budget Set")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start managing your finances by setting up your monthly budget")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if isCurrentMonth {
                Button(action: { showAddBudget = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Budget")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func budgetListView(_ budget: Budget) -> some View {
        VStack(spacing: 16) {
            BudgetRow(
                budget: budget,
                onEdit: {
                    budgetToEdit = budget
                    showEditBudget = true
                },
                onDelete: {
                    budgetToDelete = budget
                    showDeleteAlert = true
                }
            )
            .transition(.opacity)
        }
        .padding(.horizontal, 16)
    }
    
    private func deleteBudget(_ budget: Budget) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await budgetManager.deleteBudget(budget)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

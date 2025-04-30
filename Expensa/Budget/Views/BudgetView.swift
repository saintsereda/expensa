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
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = BudgetViewModel()
    
    private var monthSwitcherView: some View {
        Menu {
            // Current month option
            Button("Current Month") {
                withAnimation {
                    viewModel.dateChanged(to: Date())
                }
            }
            
            // Next months section
            Section("Next Months") {
                ForEach(1...6, id: \.self) { monthOffset in
                    let date = Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
                    Button(date.formatted(.dateTime.month(.wide).year())) {
                        withAnimation {
                            viewModel.dateChanged(to: date)
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
                            viewModel.dateChanged(to: date)
                        }
                    }
                }
            }
        } label: {
            RoundButton(
                leftIcon: "calendar",
                label: viewModel.selectedDate.formatted(.dateTime.month(.wide).year()),
                rightIcon: "chevron.down",
                action: {} // Menu takes care of the action, so this can be empty
            )
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                //                monthSwitcherView
                //                    .padding(.vertical)
                
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let budgetData = viewModel.currentBudget {
                    budgetContentView(budgetData)
                } else {
                    EmptyBudgetView(
                        selectedDate: viewModel.selectedDate,
                        isCurrentMonth: viewModel.isCurrentMonth,
                        onAddBudget: { viewModel.showAddBudget = true }
                    )
                    .transition(.opacity)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $viewModel.showAddBudget) {
            BudgetForm()
                .presentationCornerRadius(32)
                .onDisappear {
                    Task {
                        await viewModel.fetchCurrentBudget()
                    }
                }
        }
        .sheet(item: $viewModel.budgetToEdit) { editData in
            BudgetForm(budget: editData.budget)
                .presentationCornerRadius(32)
                .onDisappear {
                    Task {
                        await viewModel.fetchCurrentBudget()
                    }
                }
        }
        .alert("Delete Budget", isPresented: $viewModel.showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                viewModel.dismissAlerts()
            }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteBudget()
                }
            }
        } message: {
            Text("Are you sure you want to delete this budget? This action cannot be undone.")
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.dismissAlerts()
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            } else {
                Text("An error occurred")
            }
        }
        .disabled(viewModel.isLoading)
    }
    
    private func budgetContentView(_ budgetData: BudgetDisplayData) -> some View {
        VStack(spacing: 16) {
            // Monthly budget section
            monthlyBudgetSection(budgetData)
            
            // Category budgets section
            if !budgetData.categoryBudgets.isEmpty {
                categoryBudgetsSection(budgetData.categoryBudgets)
            }
            
            // Action buttons for current month
            if viewModel.isCurrentMonth {
                actionButtonsView()
            }
        }
        .padding(.horizontal, 16)
        .transition(.opacity)
    }
    
    private func monthlyBudgetSection(_ budgetData: BudgetDisplayData) -> some View {
        VStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Text("🗓️")
                    .font(.system(size: 20))
            }
            Text("Monthly budget")
                .font(.body)
                .foregroundColor(.gray)
            
            Text(budgetData.amountFormatted)
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.95), value: budgetData.amountFormatted)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text(budgetData.spentFormatted)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text("\(budgetData.monthlyPercentageFormatted) spent")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            //
            //                // Progress bar
            //                ProgressBar(percentage: budgetData.monthlyPercentage)
            
            SecondarySmallButton(
                isEnabled: true,
                label: "Adjust limits",
                action: { viewModel.editCurrentBudget() }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(colorScheme == .dark ? Color(UIColor.systemGray5).opacity(0.5) : Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func categoryBudgetsSection(_ categories: [CategoryBudgetDisplayData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Category limits")
                    .font(.body)
            }
            
            VStack(spacing: 8) {
                ForEach(categories) { categoryData in
                    CategoryBudgetRowView(categoryData: categoryData)
                }
            }
        }
    }
    
    private func actionButtonsView() -> some View {
        HStack(spacing: 12) {
            SecondarySmallButton(
                isEnabled: true,
                label: "Delete budget",
                action: { viewModel.showDeleteAlert = true }
            )
        }
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let percentage: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                    .cornerRadius(4)
                Rectangle()
                    .fill(percentage >= 100 ? Color.red :
                          percentage >= 90 ? Color.orange : Color.blue)
                    .frame(width: min(geometry.size.width * CGFloat(percentage / 100), geometry.size.width), height: 8)
                    .cornerRadius(4)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Category Budget Row View
struct CategoryBudgetRowView: View {
    let categoryData: CategoryBudgetDisplayData
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            // Category icon circle
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 48, height: 48)
                Text(categoryData.category.icon ?? "🔹")
                    .font(.system(size: 20))
            }
            
            // Category name
            Text(categoryData.category.name ?? "")
                .font(.body)
                .lineLimit(1)
            
            Spacer()
            
            // Limit amount
            Text(categoryData.amountFormatted)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize()
        }
        .padding(12)
        .background(colorScheme == .dark ? Color(UIColor.systemGray5).opacity(0.5) : Color(UIColor.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color(UIColor.systemGray4), lineWidth: 1))
        .cornerRadius(16)
    }
}

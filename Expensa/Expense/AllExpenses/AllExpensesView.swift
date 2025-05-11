//
//  AllExpensesView.swift
//  Expensa
//
//  Created on 11.05.2025.
//

import SwiftUI
import CoreData

struct AllExpensesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = AllExpensesViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search and filter section
                VStack(alignment: .leading, spacing: 8) {
                    SearchBar(text: $viewModel.searchText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterButton(
                                label: viewModel.categoryButtonLabel,
                                isSelected: !viewModel.selectedCategories.isEmpty,
                                action: viewModel.toggleCategoryFilter
                            )
                            
                            // Only show tags filter button if there are tags
                            if viewModel.hasTags {
                                FilterButton(
                                    label: viewModel.tagButtonLabel,
                                    isSelected: !viewModel.selectedTags.isEmpty,
                                    action: viewModel.toggleTagFilter
                                )
                            }
                            
                            // Date filter button
                            FilterButton(
                                label: viewModel.dateButtonLabel,
                                isSelected: viewModel.isDateFilterActive,
                                action: viewModel.toggleDateFilter
                            )
                        }
                        .padding(.bottom, 4)
                    }
                }
                .padding(.horizontal)
                
                // Main content
                if viewModel.filteredExpenses.isEmpty {
                    EmptyStateView(
                        type: determineEmptyStateType()
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        GroupedExpensesView(
                            expenses: viewModel.filteredExpenses,
                            onExpenseSelected: viewModel.selectExpense
                        )
                        .padding(.horizontal)
                        
                        // Load more indicator
                        if viewModel.hasMoreData {
                            HStack {
                                Spacer()
                                
                                if viewModel.isLoading {
                                    ProgressView()
                                        .padding()
                                } else {
                                    Button("Load More") {
                                        viewModel.loadMoreExpenses()
                                    }
                                    .padding()
                                }
                                
                                Spacer()
                            }
                            .onAppear {
                                // Load more when this view appears
                                viewModel.loadMoreExpenses()
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.top, 16)
        }
        .coordinateSpace(name: "scroll")
        .navigationTitle("All expenses")
        .onAppear {
            viewModel.resetFilters()
        }
        .sheet(item: $viewModel.selectedExpense) { _ in
            if let expense = viewModel.selectedExpense {
                ExpenseDetailView(
                    expense: Binding(
                        get: { viewModel.selectedExpense },
                        set: { viewModel.selectedExpense = $0 }
                    ),
                    onDelete: {
                        viewModel.deleteExpense(expense)
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showingCategoryFilter) {
            viewModel.handleCategoryFilterDismiss()
        } content: {
            CategorySheet(selectedCategories: $viewModel.selectedCategories)
        }
        .sheet(isPresented: $viewModel.showingTagFilter) {
            viewModel.handleTagFilterDismiss()
        } content: {
            TagSheet(selectedTags: $viewModel.selectedTags)
        }
        .sheet(isPresented: $viewModel.showingDateFilter) {
            PeriodPickerView(
                filterManager: viewModel.filterManager,
                showingDatePicker: $viewModel.showingDateFilter,
                onPeriodSelected: { startDate, endDate, isRangeMode in
                    viewModel.setDateFilter(
                        startDate: startDate,
                        endDate: endDate,
                        isRangeMode: isRangeMode
                    )
                }
            )
        }
    }
    
    private func determineEmptyStateType() -> EmptyStateView.EmptyStateType {
        if !viewModel.searchText.isEmpty {
            return .search
        } else if !viewModel.selectedCategories.isEmpty {
            return .category
        } else if !viewModel.selectedTags.isEmpty {
            return .search  // Using search type for tags as well
        } else {
            return .search
        }
    }
}

// MARK: - Supporting Views

struct EmptyStateView: View {
    enum EmptyStateType {
        case search
        case category
        
        var icon: String {
            switch self {
            case .search: return "magnifyingglass"
            case .category: return "tag"
            }
        }
        
        var title: String {
            switch self {
            case .search: return "No matching expenses found"
            case .category: return "No expenses in selected categories"
            }
        }
        
        var message: String {
            switch self {
            case .search: return "Try adjusting your search terms"
            case .category: return "Try selecting different categories"
            }
        }
    }
    
    let type: EmptyStateType
    
    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: type.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                )
            
            Text(type.title)
                .font(.headline)
            
            Text(type.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct FilterButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.95), value: label)
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40, alignment: .center)
            .background(isSelected ? Color(uiColor: .systemGray5) : Color(uiColor: .secondarySystemBackground))
            .foregroundColor(isSelected ? .primary : .secondary)
            .cornerRadius(999)
        }
    }
}

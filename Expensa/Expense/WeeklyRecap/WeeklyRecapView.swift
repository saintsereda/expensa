//
//  WeeklyRecapView.swift
//  Expensa
//
//  Created on 12.05.2025.
//

import SwiftUI
import CoreData

struct WeeklyRecapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    @StateObject private var viewModel = WeeklyRecapViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                weekRangeHeader
                
                if viewModel.isLoading {
                    loadingView
                } else {
                    // Weekly summary card
                    weeklySummaryCard
                    
                    // Spending insights
                    spendingInsightsCard
                }
                
                Spacer()
                    .frame(height: 16)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Weekly Recap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
            }
        }
        .onAppear {
            viewModel.loadWeeklyRecap()
        }
    }
    
    // MARK: - Component Views
    
    private var weekRangeHeader: some View {
        VStack(spacing: 8) {
            Text("Last Week")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(viewModel.formattedWeekRange)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading your weekly summary...")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }
    
    private var weeklySummaryCard: some View {
        VStack(spacing: 16) {
            // Total spent
            VStack(spacing: 4) {
                Text("Total Spent")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary.opacity(0.64))
                
                Text(viewModel.formattedTotalAmount)
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                // Week-over-week comparison
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isSpendingIncrease ? "arrow.up" : "arrow.down")
                        .foregroundColor(viewModel.isSpendingIncrease ? .red : .green)
                        .opacity(viewModel.formattedComparisonText.contains("Same") ||
                                viewModel.formattedComparisonText.contains("No spending") ? 0 : 1)
                    
                    Text(viewModel.formattedComparisonText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    if !viewModel.formattedPercentageChange.isEmpty &&
                       !viewModel.formattedComparisonText.contains("No spending") &&
                       !viewModel.formattedComparisonText.contains("Same") {
                        Text("(\(viewModel.formattedPercentageChange)%)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(viewModel.isSpendingIncrease ? .red : .green)
                    }
                }
            }
            .padding(.bottom, 8)
            
            // Transaction count
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.secondary)
                
                Text(viewModel.getFormattedTransactionCount())
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var spendingInsightsCard: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Spending Insights")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 4)
                
                // Highest spending day
                VStack(alignment: .leading, spacing: 8) {
                    Text("Highest Spending Day")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary.opacity(0.64))
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.formattedHighestDay)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(viewModel.getHighestDayDescription())
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(viewModel.formattedHighestAmount)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                    .background(Color.primary.opacity(0.1))
                
                // Lowest spending day
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lowest Spending Day")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary.opacity(0.64))
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.formattedLowestDay)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(viewModel.getLowestDayDescription())
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(viewModel.formattedLowestAmount)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 8)
                
                // Only show biggest expense section if we have data
                if viewModel.hasBiggestExpense {
                    Divider()
                        .background(Color.primary.opacity(0.1))
                    
                    // Biggest expense
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Biggest \(viewModel.biggestExpenseCategoryName) expense")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.primary.opacity(0.64))
                        
                        HStack(alignment: .center) {
                            Text("\(viewModel.formattedBiggestExpenseAmount) – \(viewModel.formattedBiggestExpenseDate)")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
        }
}

// MARK: - Preview
struct WeeklyRecapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WeeklyRecapView()
                .environment(\.managedObjectContext, CoreDataStack.shared.context)
                .environmentObject(CurrencyManager.shared)
        }
    }
}

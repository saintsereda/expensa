//
//  WeeklyRecapViewModel.swift
//  Expensa
//
//  Created on 12.05.2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine

class WeeklyRecapViewModel: ObservableObject {
    private let context: NSManagedObjectContext
    private let analytics = ExpenseAnalytics.shared
    private let currencyManager = CurrencyManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var isLoading = true
    @Published private(set) var recapData: WeeklyRecapData?
    @Published private(set) var formattedWeekRange = ""
    @Published private(set) var formattedTotalAmount = ""
    @Published private(set) var formattedHighestDay = ""
    @Published private(set) var formattedHighestAmount = ""
    @Published private(set) var formattedLowestDay = ""
    @Published private(set) var formattedLowestAmount = ""
    @Published private(set) var formattedComparisonText = ""
    @Published private(set) var isSpendingIncrease = false
    @Published private(set) var formattedPercentageChange = ""
    
    // Biggest expense data
    @Published private(set) var hasBiggestExpense = false
    @Published private(set) var biggestExpenseCategoryName = ""
    @Published private(set) var formattedBiggestExpenseAmount = ""
    @Published private(set) var formattedBiggestExpenseDate = ""
    
    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
        
        // Listen for currency changes to update formatting
        NotificationCenter.default.publisher(for: Notification.Name("DefaultCurrencyChanged"))
            .sink { [weak self] _ in
                self?.formatRecapData()
            }
            .store(in: &cancellables)
    }
    
    func loadWeeklyRecap() {
        isLoading = true
        
        Task {
            // Fetch expenses on background thread
            let expenses = await fetchExpenses()
            
            // Calculate recap data
            let recap = analytics.getWeeklyRecapData(for: expenses)
            
            // Update UI on main thread
            await MainActor.run {
                self.recapData = recap
                self.formatRecapData()
                self.isLoading = false
            }
        }
    }
    
    private func fetchExpenses() async -> [Expense] {
        return await context.perform {
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
            
            // Get date intervals for both weeks
            let lastWeekInterval = self.analytics.getLastWeekDateInterval()
            let weekBeforeLastInterval = self.analytics.getWeekBeforeLastInterval()
            
            // Combine into a single date range to fetch all expenses at once
            let startDate = min(lastWeekInterval.start, weekBeforeLastInterval.start)
            let endDate = max(lastWeekInterval.end, weekBeforeLastInterval.end)
            
            // Fetch expenses within the combined two-week range
            fetchRequest.predicate = NSPredicate(
                format: "date >= %@ AND date <= %@",
                startDate as NSDate,
                endDate as NSDate
            )
            
            do {
                let result = try self.context.fetch(fetchRequest)
                print("Fetched \(result.count) expenses for the two-week period")
                return result
            } catch {
                print("❌ Error fetching expenses for weekly recap: \(error)")
                return []
            }
        }
    }
    
    private func formatRecapData() {
        guard let recap = recapData,
              let defaultCurrency = currencyManager.defaultCurrency else {
            return
        }
        
        // Format week range
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let startDateString = dateFormatter.string(from: recap.weekInterval.start)
        let endDateString = dateFormatter.string(from: recap.weekInterval.end)
        formattedWeekRange = "\(startDateString) - \(endDateString)"
        
        // Format total amount
        formattedTotalAmount = currencyManager.currencyConverter.formatAmount(
            recap.totalSpent,
            currency: defaultCurrency
        )
        
        // Format highest spending day
        if let highestDay = recap.highestSpendingDay {
            dateFormatter.dateFormat = "EEEE"  // Full day name (e.g., "Monday")
            formattedHighestDay = dateFormatter.string(from: highestDay.date)
            
            formattedHighestAmount = currencyManager.currencyConverter.formatAmount(
                highestDay.amount,
                currency: defaultCurrency
            )
        } else {
            formattedHighestDay = "No data"
            formattedHighestAmount = currencyManager.currencyConverter.formatAmount(0, currency: defaultCurrency)
        }
        
        // Format lowest spending day
        if let lowestDay = recap.lowestSpendingDay {
            dateFormatter.dateFormat = "EEEE"  // Full day name (e.g., "Monday")
            formattedLowestDay = dateFormatter.string(from: lowestDay.date)
            
            formattedLowestAmount = currencyManager.currencyConverter.formatAmount(
                lowestDay.amount,
                currency: defaultCurrency
            )
        } else {
            formattedLowestDay = "No data"
            formattedLowestAmount = currencyManager.currencyConverter.formatAmount(0, currency: defaultCurrency)
        }
        
        // Format comparison data
        let comparison = recap.comparisonWithPreviousWeek
        isSpendingIncrease = comparison.isIncrease
        
        // Format the difference amount
        let formattedDifference = currencyManager.currencyConverter.formatAmount(
            abs(comparison.difference),
            currency: defaultCurrency
        )
        
        // Format percentage change
        let absPercentage = abs(comparison.percentageChange)
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 1
        numberFormatter.minimumFractionDigits = 0
        formattedPercentageChange = numberFormatter.string(from: NSNumber(value: absPercentage)) ?? "0"
        
        // Create the comparison text
        if comparison.previousWeekSpent == 0 && recap.totalSpent == 0 {
            formattedComparisonText = "No spending in the last two weeks"
        } else if comparison.previousWeekSpent == 0 {
            formattedComparisonText = "No spending in previous week"
        } else if comparison.difference == 0 {
            formattedComparisonText = "Same as previous week"
        } else {
            let direction = comparison.isIncrease ? "more than" : "less than"
            formattedComparisonText = "\(formattedDifference) \(direction) previous week"
        }
        
        // Format biggest expense
        if let biggestExpense = recap.biggestExpense {
            hasBiggestExpense = true
            biggestExpenseCategoryName = biggestExpense.category
            
            formattedBiggestExpenseAmount = currencyManager.currencyConverter.formatAmount(
                biggestExpense.amount,
                currency: defaultCurrency
            )
            
            // Format the date (May 10)
            dateFormatter.dateFormat = "MMM d"
            formattedBiggestExpenseDate = dateFormatter.string(from: biggestExpense.date)
        } else {
            hasBiggestExpense = false
            biggestExpenseCategoryName = "None"
            formattedBiggestExpenseAmount = ""
            formattedBiggestExpenseDate = ""
        }
    }
    
    // Helper methods for UI
    func getFormattedTransactionCount() -> String {
        guard let count = recapData?.transactionCount else { return "0 transactions" }
        return "\(count) transaction\(count == 1 ? "" : "s")"
    }
    
    func getHighestDayDescription() -> String {
        guard let highest = recapData?.highestSpendingDay, highest.expenseCount > 0 else {
            return "No transactions"
        }
        
        return "\(highest.expenseCount) transaction\(highest.expenseCount == 1 ? "" : "s")"
    }
    
    func getLowestDayDescription() -> String {
        guard let lowest = recapData?.lowestSpendingDay else { return "No transactions" }
        
        return lowest.expenseCount > 0
            ? "\(lowest.expenseCount) transaction\(lowest.expenseCount == 1 ? "" : "s")"
            : "No transactions"
    }
}

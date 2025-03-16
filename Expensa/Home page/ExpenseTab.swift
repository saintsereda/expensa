//
//  ExpensesTab.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI
import CoreData

struct EmptyExpenseTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("💰")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No expenses yet")
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Start tracking your spending by adding your first expense")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct ExpensesTab: View {
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // MARK: - Fetch Request
    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\RecurringExpense.nextDueDate, order: .forward)
        ],
        predicate: NSPredicate(format: "status == %@", "Active"),
        animation: .default
    ) private var recurringExpenses: FetchedResults<RecurringExpense>
    
    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\Expense.date, order: .reverse)
        ],
        animation: .default
    ) private var allExpensesEver: FetchedResults<Expense>
    
    // MARK: - State Objects
    @ObservedObject private var budgetManager = BudgetManager.shared
    @ObservedObject private var expenseManager = ExpenseDataManager.shared
    
    // MARK: - Properties
    @Binding var isPresentingExpenseEntry: Bool
    @Binding var selectedExpense: Expense?
    @State private var refreshBudget: Bool = false
    let fetchedExpenses: FetchedResults<Expense>
    let categorizedExpenses: [(Category, [Expense])]
    let filterManager: ExpenseFilterManager
    @Binding var currentBudget: Budget?
    
    private var shouldShowEmptyState: Bool {
        allExpensesEver.isEmpty && currentBudget == nil
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if shouldShowEmptyState {
                        EmptyExpenseTab()
                            .padding(.top, 60)
                    } else {
                        VStack(spacing: 16) {
                            TotalSpentRow(
                                expenses: fetchedExpenses,
                                selectedDate: filterManager.selectedDate
                            )
                            .padding(.horizontal, 16)
                            
//                            DailySpendingProgressGraph(
//                                expenses: Array(fetchedExpenses),
//                                selectedDate: filterManager.selectedDate
//                            )
                        }
                        .padding(.bottom, 16)
                        
                        VStack(spacing: 16) {
                            UncategorizedExpensesView(context: viewContext)
                                .environmentObject(currencyManager)
                            
                            //                        if let budget = currentBudget {
                            //                            CategoryLimitsSection(
                            //                                budget: budget,
                            //                                budgetManager: budgetManager,
                            //                                expenseManager: expenseManager
                            //                            )
                            //                        } else {
                            
//                            TopCategoriesSection(
//                                categorizedExpenses: categorizedExpenses,
//                                fetchedExpenses: fetchedExpenses,
//                                budget: currentBudget,
//                                budgetManager: budgetManager,
//                                expenseManager: expenseManager
//                            )
                            
                            CategorySpendingSection(
                                categorizedExpenses: categorizedExpenses,
                                fetchedExpenses: fetchedExpenses
                            )
                            //                        }
                            
                            if !recurringExpenses.isEmpty {
                                SubscriptionsSection(
                                    recurringExpenses: recurringExpenses
                                )
                            }
                            
                            RecentExpensesSection(
                                fetchedExpenses: fetchedExpenses,
                                selectedExpense: $selectedExpense
                            )
                        }
                        .padding(.horizontal, 16)
                    }
                    Spacer()
                    .frame(height: 80)
                }
                .padding(.top, 32)
            }
            
            VStack {
                Spacer()
                FloatingActionButton(
                    title: nil,
                    icon: "plus"
                ) {
                    isPresentingExpenseEntry = true
                }
            }
        }
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .allExpenses:
                AllExpenses()
                    .toolbar(.hidden, for: .tabBar)
            case .allCategories:
                AllCategoriesView(
                    categorizedExpenses: categorizedExpenses,
                    fetchedExpenses: fetchedExpenses
                )
            case .allSubscriptions:
                RecurrenceListView()
                    .toolbar(.hidden, for: .tabBar)
            case .budgetview:
                BudgetView()
                    .toolbar(.hidden, for: .tabBar)
            case .uncategorizedExpenses:
                UncategorizedExpensesListView()
                    .toolbar(.hidden, for: .tabBar)
                    .environmentObject(currencyManager)
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
            .fullScreenCover(isPresented: $isPresentingExpenseEntry) {
            ExpenseEntryView(
                isPresented: $isPresentingExpenseEntry,
                expense: nil
            )

            .environment(\.managedObjectContext, viewContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BudgetUpdated"))) { _ in
            Task {
                // Refresh the current budget asynchronously
                currentBudget = await BudgetManager.shared.getCurrentMonthBudget()
                refreshBudget.toggle() // Toggle to force view refresh
            }
        }
        // Make the view depend on refreshBudget to trigger updates
        .id(refreshBudget)
    }
}

// NavigationDestination.swift
enum NavigationDestination {
    case allExpenses
    case allCategories
    case allSubscriptions
    case budgetview
    case uncategorizedExpenses
}

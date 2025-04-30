//
//  ExpensesTab.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//  HomePage.swift

import SwiftUI
import CoreData

struct EmptyHomePage: View {
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

struct HomePage: View {
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
                        EmptyHomePage()
                            .padding(.top, 60)
                    } else {
                        VStack(spacing: 16) {
                            Spacer()
                            TotalSpentRow(
                                expenses: fetchedExpenses,
                                selectedDate: filterManager.selectedDate
                            )
                            .padding(.horizontal, 12)
                            //
                            //                            DailySpendingProgressGraph(
                            //                                expenses: Array(fetchedExpenses),
                            //                                selectedDate: filterManager.selectedDate
                            //                            )
                            
                            //                            SpendingProgressGraph(
                            //                                expenses: Array(fetchedExpenses),
                            //                                selectedDate: filterManager.selectedDate
                            //                            )
                            //                            CumulativeSpendingGraph(
                            //                                expenses: Array(fetchedExpenses),
                            //                                selectedDate: filterManager.selectedDate
                            //                                )
                            MonthlyComparisonChart(
                                currentMonthExpenses: Array(fetchedExpenses),
                                selectedDate: filterManager.selectedDate
                            )
                            
                        }

                        VStack(spacing: 16) {
                            UncategorizedExpensesView(context: viewContext)
                                .padding(.horizontal, 12)
                                .environmentObject(currencyManager)
                            
                            //                        if let budget = currentBudget {
                            //                            CategoryLimitsSection(
                            //                                budget: budget,
                            //                                budgetManager: budgetManager,
                            //                                expenseManager: expenseManager
                            //                            )
                            //                        } else {
                            
                            TopCategoriesSection(
                                categorizedExpenses: categorizedExpenses,
                                fetchedExpenses: fetchedExpenses,
                                budget: currentBudget,
                                budgetManager: budgetManager,
                                expenseManager: expenseManager
                            )
                            .padding(.horizontal, 12)
                            
                            //                            CategorySpendingSection(
                            //                                categorizedExpenses: categorizedExpenses,
                            //                                fetchedExpenses: fetchedExpenses
                            //                            )
                            //                        }
                            
                            if !recurringExpenses.isEmpty {
                                SubscriptionsSection(
                                    recurringExpenses: recurringExpenses
                                )
                                .padding(.horizontal, 12)
                            }
                            
                            RecentExpensesSection(
                                fetchedExpenses: fetchedExpenses,
                                selectedExpense: $selectedExpense
                            )
                            .padding(.horizontal, 12)
                        }
                        .padding(.top, 32)
                        .background(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color(UIColor.systemBackground).opacity(0), location: 0.0),   // 0%
                                    .init(color: Color(UIColor.systemBackground), location: 0.12),   // 60%
                                    .init(color: Color(UIColor.systemBackground), location: 1.0)  // 80%
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )
                    }
                    Spacer()
                    .frame(height: 80)
                }
                .padding(.top, 16)
            }
            
            VStack {
                Spacer()
                FloatingActionButton(
                    icon: "plus"
                ) {
                    HapticFeedback.play()
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
                AllCategoriesView()
                    .toolbar(.hidden, for: .tabBar)
                    .environmentObject(currencyManager)
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

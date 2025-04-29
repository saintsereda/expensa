//
//  UncategorizedExpensesView.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.02.2025.
//

import Foundation
import SwiftUI
import CoreData
import Lottie

struct UncategorizedExpensesView: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    
    // Direct fetch request for uncategorized expenses (with nil category OR "No Category")
    @FetchRequest private var uncategorizedExpenses: FetchedResults<Expense>
    
    // Computed property for total amount
    private var categoryAmount: Decimal {
        uncategorizedExpenses.reduce(Decimal(0)) { sum, expense in
            sum + (expense.convertedAmount?.decimalValue ?? expense.amount?.decimalValue ?? 0)
        }
    }
    
    // Initialize with a dedicated fetch request for uncategorized expenses
    init(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        
        // Only fetch expenses with nil category
        fetchRequest.predicate = NSPredicate(format: "category == nil")
        
        // Optional: Add sorting if needed
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        // Create the fetch request
        _uncategorizedExpenses = FetchRequest(fetchRequest: fetchRequest, animation: .default)
    }
    
    var body: some View {
        if !uncategorizedExpenses.isEmpty {
            NavigationLink(value: NavigationDestination.uncategorizedExpenses) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 48, height: 48)
                        
                        // Replace emoji with Lottie animation
                        LottieView(name: "eyes-animation", loopCount: 2, delay: 10.0)
                            .frame(width: 24, height: 24) // Adjust size as needed
                    }
                    VStack(alignment: .leading)  {
                        if let defaultCurrency = currencyManager.defaultCurrency {
                            Text(currencyManager.currencyConverter.formatAmount(
                                categoryAmount,
                                currency: defaultCurrency
                            ) + " uncategorized")
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        }
                        
                        Text("\(uncategorizedExpenses.count) expense\(uncategorizedExpenses.count == 1 ? "" : "s") needs attention")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.16))
                .cornerRadius(16)
                .contentTransition(.numericText())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// Add this SwiftUI wrapper for Lottie animations
struct LottieView: UIViewRepresentable {
    var name: String
    var loopCount: Int = 2
    var delay: TimeInterval = 3.0

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: name)
        animationView.contentMode = .scaleAspectFit
        view.addSubview(animationView)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        context.coordinator.setupAnimation(animationView, loopCount: loopCount, delay: delay)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        func setupAnimation(_ animationView: LottieAnimationView, loopCount: Int, delay: TimeInterval) {
            playAnimation(animationView, loopCount: loopCount, delay: delay)
        }

        private func playAnimation(_ animationView: LottieAnimationView, loopCount: Int, delay: TimeInterval) {
            animationView.play { [weak self] finished in
                if finished {
                    if loopCount > 1 {
                        self?.playAnimation(animationView, loopCount: loopCount - 1, delay: delay)
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self?.playAnimation(animationView, loopCount: loopCount, delay: delay)
                        }
                    }
                }
            }
        }
    }
}


//
//  UncategorizedExpensesListView.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.02.2025.
//

import SwiftUI
import CoreData

struct UncategorizedExpensesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var currencyManager: CurrencyManager
    @State private var selectedExpense: Expense?
    
    @FetchRequest private var uncategorizedExpenses: FetchedResults<Expense>
    
    init() {
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "category == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        _uncategorizedExpenses = FetchRequest(fetchRequest: fetchRequest, animation: .default)
    }
    
    var body: some View {
        List {
            ForEach(uncategorizedExpenses) { expense in
                ExpenseRow(expense: expense)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedExpense = expense
                    }
            }
        }
        .navigationTitle("Uncategorized Expenses")
        .listStyle(PlainListStyle())
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
    }
}

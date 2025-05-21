//
//  DefaultCurrency.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI
import CoreData

struct DefaultCurrencyView: View {
    @EnvironmentObject private var currencyManager: CurrencyManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var showingActionSheet = false
    @State private var selectedCurrency: Currency?
    @State private var hasExpenses: Bool = false
    @State private var isLoading: Bool = true
    
    private let preferredCurrencyCodes = ["EUR", "USD", "PLN", "UAH"]
    private let restrictedSearchTerms = ["russian", "russia", "ruble", "rub"]
    
    private var isSearchingRestrictedCurrency: Bool {
        let searchLowercased = searchText.lowercased()
        return !searchText.isEmpty && restrictedSearchTerms.contains { term in
            searchLowercased.contains(term)
        }
    }
    
    private var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return currencyManager.availableCurrencies
        }
        
        if isSearchingRestrictedCurrency {
            return []
        }
        
        return currencyManager.availableCurrencies.filter { currency in
            let searchTextLowercased = searchText.lowercased()
            return (currency.code?.lowercased().contains(searchTextLowercased) ?? false) ||
                   (currency.name?.lowercased().contains(searchTextLowercased) ?? false)
        }
    }
    
    private var preferredCurrencies: [Currency] {
        currencyManager.availableCurrencies.filter { currency in
            preferredCurrencyCodes.contains(currency.code ?? "")
        }
    }
    
    private var nonPreferredCurrencies: [Currency] {
        if searchText.isEmpty {
            return currencyManager.availableCurrencies.filter { currency in
                !preferredCurrencyCodes.contains(currency.code ?? "")
            }
        }
        return filteredCurrencies
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search currency", text: $searchText)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray5))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private var notSupportedView: some View {
        VStack(spacing: 16) {
            Text("🚫")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("404 country currency is not supported")
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func currencyRow(_ currency: Currency) -> some View {
        HStack {
            HStack(alignment: .top) {
                Text(currency.flag ?? "🌐")
                    .font(.body)
                    .foregroundColor(.gray)
                VStack(alignment: .leading) {
                    Text(currency.code ?? "")
                        .font(.body)
                        .foregroundColor(.primary)
                    HStack(alignment: .center) {
                        Text(currency.symbol ?? "")
                            .font(.body)
                            .foregroundColor(.gray)
                        Text(currency.name ?? "")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            if currency == currencyManager.defaultCurrency {
                Text("Default")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if currency != currencyManager.defaultCurrency {
                selectedCurrency = currency
                // Only show confirmation if there are expenses
                if hasExpenses {
                    showingActionSheet = true
                } else {
                    // Directly change currency without confirmation
                    Task {
                        await currencyManager.handleDefaultCurrencyChange(to: currency)
                    }
                }
            }
        }
    }
    
    // Function to check if there are any expenses in CoreData
    private func checkForExistingExpenses() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Expense")
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: fetchRequest)
            hasExpenses = count > 0
        } catch {
            print("Error checking for expenses: \(error.localizedDescription)")
            hasExpenses = false
        }
    }
    
    var body: some View {
        VStack {
            searchBar
            
            if isLoading {
                VStack {
                    ProgressView()
                        .padding()
                    Text("Loading currencies...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearchingRestrictedCurrency {
                notSupportedView
            } else {
                List {
                    if searchText.isEmpty {
                        Section(header: Text("Suggested")) {
                            ForEach(preferredCurrencies) { currency in
                                currencyRow(currency)
                            }
                        }
                    }
                    
                    Section(header: Text(searchText.isEmpty ? "All currencies" : "Search results")) {
                        ForEach(nonPreferredCurrencies) { currency in
                            currencyRow(currency)
                        }
                    }
                }
            }
        }
        .navigationTitle("Default currency")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Change default currency",
                      isPresented: $showingActionSheet,
                      presenting: selectedCurrency) { currency in
            Button("Change default currency", role: .destructive) {
                Task {
                    await currencyManager.handleDefaultCurrencyChange(to: currency)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { currency in
            Text("Changing your default currency to \(currency.code ?? "") will convert all existing expenses to the new currency.")
        }
        .task {
            // Ensure currencies are initialized before showing the view
            await currencyManager.ensureInitialized()
            checkForExistingExpenses()
            isLoading = false
        }
    }
}

// Preview provider for SwiftUI preview
struct DefaultCurrencyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DefaultCurrencyView()
                .environmentObject(CurrencyManager.shared)
                .environment(\.managedObjectContext, CoreDataStack.shared.context)
        }
    }
}

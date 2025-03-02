//
//  CurrencyListView.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI
import CoreData
import Combine

struct CurrencyListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var currencyManager: CurrencyManager
    @Binding var selectedCurrency: Currency?
    @State private var searchText = ""
    
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
    
    private func currencyRow(_ currency: Currency) -> some View {
        HStack {

            HStack (alignment: .top){
                Text(currency.flag ?? "🌐")
                    .font(.body)
                    .foregroundColor(.gray)
                VStack (alignment: .leading) {
                    Text(currency.code ?? "")
                        .font(.body)
                        .foregroundColor(.primary)
                    HStack (alignment: .center) {
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
            
            if currency == selectedCurrency {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCurrency = currency
            dismiss()
        }

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
    
    var body: some View {
        NavigationView {
            VStack {
                searchBar
                
                if isSearchingRestrictedCurrency {
                    notSupportedView
                } else {
                    List {
                        if searchText.isEmpty {
                            LastUpdatedBanner()
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
            .navigationTitle("Select currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

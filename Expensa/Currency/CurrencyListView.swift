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
    
    // State variables
    @State private var searchText = ""
    @State private var isKeyboardVisible = false
    
    // Move constants to static properties to reduce memory allocations
    private static let preferredCurrencyCodes = ["EUR", "USD", "PLN", "UAH"]
    private static let restrictedSearchTerms = ["russian", "russia", "ruble", "rub"]
    
    // Use computed properties only when needed, with proper caching
    private var isSearchingRestrictedCurrency: Bool {
        guard !searchText.isEmpty else { return false }
        let searchLowercased = searchText.lowercased()
        return CurrencyListView.restrictedSearchTerms.contains { searchLowercased.contains($0) }
    }
    
    // Cache filtered results to avoid recalculating on every view update
    @State private var filteredCurrencies: [Currency] = []
    @State private var preferredCurrencies: [Currency] = []
    @State private var nonPreferredCurrencies: [Currency] = []
    
    // Use onAppear to initialize the currencies once
    private func updateFilteredLists() {
        if searchText.isEmpty {
            preferredCurrencies = currencyManager.availableCurrencies.filter { currency in
                CurrencyListView.preferredCurrencyCodes.contains(currency.code ?? "")
            }
            nonPreferredCurrencies = currencyManager.availableCurrencies.filter { currency in
                !CurrencyListView.preferredCurrencyCodes.contains(currency.code ?? "")
            }
            filteredCurrencies = currencyManager.availableCurrencies
        } else if isSearchingRestrictedCurrency {
            filteredCurrencies = []
            nonPreferredCurrencies = []
        } else {
            let searchTextLowercased = searchText.lowercased()
            filteredCurrencies = currencyManager.availableCurrencies.filter { currency in
                (currency.code?.lowercased().contains(searchTextLowercased) ?? false) ||
                (currency.name?.lowercased().contains(searchTextLowercased) ?? false)
            }
            nonPreferredCurrencies = filteredCurrencies
        }
    }
    
    // More efficient keyboard handling using ViewModifier instead of Combine
    private struct KeyboardAwareModifier: ViewModifier {
        @Binding var isVisible: Bool
        
        func body(content: Content) -> some View {
            content
                .onAppear {
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                                          object: nil,
                                                          queue: .main) { _ in
                        isVisible = true
                    }
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                                          object: nil,
                                                          queue: .main) { _ in
                        isVisible = false
                    }
                }
                .onDisappear {
                    NotificationCenter.default.removeObserver(self)
                }
        }
    }
    
    // Optimize row rendering with ViewBuilder and explicit frame sizes
    @ViewBuilder
    private func currencyRow(_ currency: Currency) -> some View {
        HStack {
            // Flag in circle, similar to category icon
            ZStack {
                Circle()
                    .fill(currency == selectedCurrency ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Text(currency.flag ?? "🌐")
                    .font(.system(size: 24))
            }
            .overlay(
                Group {
                    if currency == selectedCurrency {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 48, height: 48)
                    }
                }
            )
            
            // Currency details
            VStack(alignment: .leading, spacing: 4) {
                Text(currency.code ?? "")
                    .font(.body)
                    .foregroundColor(currency == selectedCurrency ? .blue : .primary)
                
                HStack(alignment: .center, spacing: 4) {
                    Text(currency.symbol ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(currency.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 8)
            
            Spacer()
            
            // Status indicators
            if currency == currencyManager.defaultCurrency {
                Text("Default")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCurrency = currency
            HapticFeedback.play()
            dismiss()
        }
        .frame(height: 48) // Fixed height improves list performance
    }
    
    // Extract to separate view to prevent rebuilding when not needed
    private struct NotSupportedView: View {
        var body: some View {
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
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                VStack {
                    if isSearchingRestrictedCurrency {
                        NotSupportedView()
                    } else if !searchText.isEmpty && nonPreferredCurrencies.isEmpty {
                        // Empty state for no search results
                        VStack(spacing: 16) {
                            Spacer()
                            
                            Text("No currencies found")
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Spacer()
                        }
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        // Use LazyVStack instead of ScrollView+VStack for better memory usage
                        ScrollView(showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                if searchText.isEmpty {
                                    Text("Suggested")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                        .padding(.top)

                                    // Use LazyVStack for better performance with dynamic content
                                    LazyVStack(spacing: 16) {
                                        ForEach(preferredCurrencies) { currency in
                                            currencyRow(currency)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 32)
                                    
                                    Text("All currencies")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                }
                                
                                LazyVStack(spacing: 16) {
                                    ForEach(nonPreferredCurrencies) { currency in
                                        currencyRow(currency)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            // Add bottom padding to avoid content being hidden by search bar
                            .padding(.bottom, 104)
                        }
                    }
                }
                
                // Floating search bar at the bottom
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Gradient background behind the search bar
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 48)
                    .allowsHitTesting(true) // Let touches pass through
                    
                    FloatingSearchBar(text: $searchText, isKeyboardVisible: $isKeyboardVisible, placeholder: "Search currency")
                        .padding(.horizontal)
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
            .foregroundColor(.primary)
            .modifier(KeyboardAwareModifier(isVisible: $isKeyboardVisible))
            .onChange(of: searchText) { _, _ in
                updateFilteredLists()
            }
            .onAppear {
                updateFilteredLists()
            }
        }
    }
}

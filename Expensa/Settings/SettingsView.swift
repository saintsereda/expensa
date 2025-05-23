//
//  SettingsView.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import Foundation
import SwiftUI
import CoreData

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var accentColorManager = AccentColorManager.shared
    @State private var showingDebug = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    // New state variable for Apple Pay import sheet
    @State private var showingApplePayImport = false
    
    // Cache these values to avoid repeated fetches
    @State private var categoryCount: Int = 0
    @State private var tagCount: Int = 0
    @State private var defaultCurrencyCode: String = "Not set"
    
    var body: some View {
        List {
            preferencesSection
            manageSection
            importSection // New import section
            supportSection
            feedbackSection
            legalSection
            connectSection
        }
        .scrollIndicators(.hidden)
        .listStyle(InsetGroupedListStyle())
        .sheet(isPresented: $showingDebug) {
            NavigationView {
                RateDebugView()
            }
        }
        .sheet(isPresented: $showingApplePayImport) {
            ImportFromApplePaySheet()
        }
        .onAppear {
            // Update cached values on view appear
            updateCachedValues()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CategoriesUpdated"))) { _ in
            categoryCount = CategoryManager.shared.categories.count
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TagsUpdated"))) { _ in
            tagCount = TagManager.shared.tags.count
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DefaultCurrencyChanged"))) { _ in
            defaultCurrencyCode = CurrencyManager.shared.defaultCurrency?.code ?? "Not set"
        }
    }
    
    // Update all cached values in a single function
    private func updateCachedValues() {
        // Fetch category count once
        categoryCount = CategoryManager.shared.categories.count

        // Get tag count (assuming this is a similar expensive operation)
        tagCount = TagManager.shared.tags.count
        
        // Cache the default currency code
        defaultCurrencyCode = CurrencyManager.shared.defaultCurrency?.code ?? "Not set"
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        Section {
            // In your SettingsView.swift, modify your appearance picker section:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                    Text("Appearance")
                        .font(.body)
                    Spacer()
                    
                    // Implement the menu directly like in your CalendarSheet
                    Menu {
                        ForEach(ColorScheme.allCases, id: \.self) { theme in
                            Button(action: {
                                themeManager.setTheme(theme)
                            }) {
                                Text(theme.rawValue)
                            }
                        }
                    } label: {
                        HStack {
                            Text(themeManager.selectedTheme.rawValue)
                                .frame(width: 65, alignment: .trailing)
                                .foregroundColor(.primary) // Use .primary instead of default blue
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            
            // New Accent Color picker
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentColorManager.selectedAccentColor.color)
                    Text("Accent Color")
                        .font(.body)
                    Spacer()
                    
                    Menu {
                        ForEach(AccentColorOption.allCases) { colorOption in
                            Button(action: {
                                accentColorManager.selectedAccentColor = colorOption
                            }) {
                                HStack {
                                    Circle()
                                        .fill(colorOption.color)
                                        .frame(width: 16, height: 16)
                                    Text(colorOption.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(accentColorManager.selectedAccentColor.rawValue)
                                .frame(width: 65, alignment: .trailing)
                                .foregroundColor(.primary) // Use .primary instead of default blue
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            
            NavigationLink(destination: NotificationsView(context: managedObjectContext).toolbar(.hidden, for: .tabBar)) {                NavigationRow(
                    title: "Notifications",
                    icon: "bell.fill",
                    color: .orange
                )
            }
            
            NavigationLink(destination: SecurityPageView().toolbar(.hidden, for: .tabBar)) {
                NavigationRow(
                    title: "Security",
                    icon: "lock.fill",
                    color: .purple
                )
            }
            
            NavigationLink(destination: iCloudSyncView().toolbar(.hidden, for: .tabBar)) {
                NavigationRow(
                    title: "iCloud Sync",
                    icon: "icloud.fill",
                    color: .blue,
                    showChevron: false
                )
            }
            
            NavigationLink(destination: DataAndStorageView().toolbar(.hidden, for: .tabBar)) {
                NavigationRow(
                    title: "Data and Storage",
                    icon: "externaldrive.fill",
                    color: .accentColor
                )
            }
            
            NavigationRow(
                title: "Language",
                subtitle: "Coming soon",
                icon: "globe",
                color: .green
            ) {
                showLanguageOptions()
            }
        } header: {
        }
    }
    
    // MARK: - Manage Section
    private var manageSection: some View {
        Section {
            NavigationLink(
                destination: CategoryListView().toolbar(.hidden, for: .tabBar)) {
                NavigationRow(
                    title: "Categories",
                    subtitle: (categoryCount == 0 ? "No categories" : "\(categoryCount) categories"),
                    icon: "folder.fill",
                    color: .purple
                )
            }
            NavigationLink(destination: TagListView().toolbar(.hidden, for: .tabBar)) {
                NavigationRow(
                    title: "Tags",
                    subtitle: (tagCount == 0 ? "No tags" : "\(tagCount) tags"),
                    icon: "tag.fill",
                    color: .indigo
                )
            }
            
            NavigationLink(destination: RecurrenceListView().toolbar(.hidden, for: .tabBar)) {
                NavigationRow(
                    title: "Recurring expenses",
                    icon: "repeat.circle.fill",
                    color: .blue,
                    showChevron: false // Don't show NavigationRow's chevron
                )
            }
            
            NavigationLink(destination: DefaultCurrencyView().toolbar(.hidden, for: .tabBar)) {
                NavigationRow(
                    title: "Default currency",
                    subtitle: defaultCurrencyCode,
                    icon: "creditcard.fill",
                    color: .green
                )
            }
        } header: {
            SectionHeader(text: "Manage")
        }
    }
    
    // MARK: - Import Section (New)
    private var importSection: some View {
        Section {
            Button(action: {
                showingApplePayImport = true
            }) {
                NavigationRow(
                    title: "Import from Apple Pay",
                    subtitle: "Sync your Apple Pay transactions",
                    icon: "apple.logo",
                    color: .black
                )
            }
        } header: {
            SectionHeader(text: "Import")
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        Section {
            NavigationRow(
                title: "Report Bug",
                subtitle: "Help us improve",
                icon: "ant.fill",
                color: .red
            ) {
                reportBug()
            }
            
            NavigationRow(
                title: "Request a Feature",
                subtitle: "Share your ideas",
                icon: "star.fill",
                color: .yellow
            ) {
                requestFeature()
            }
        } header: {
            SectionHeader(text: "Support")
        }
    }
    
    // MARK: - Feedback Section
    private var feedbackSection: some View {
        Section {
            NavigationRow(
                title: "Rate on App Store",
                subtitle: "Love the app? Let us know!",
                icon: "star.fill",
                color: .pink
            ) {
                rateApp()
            }
            
            NavigationRow(
                title: "Share with Friends",
                subtitle: "Spread the word",
                icon: "square.and.arrow.up.fill",
                color: .blue
            ) {
                shareApp()
            }
        } header: {
            SectionHeader(text: "Feedback")
        }
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        Section {
            NavigationRow(
                title: "Privacy Policy",
                icon: "shield.fill",
                color: .gray
            ) {
                showPrivacyPolicy()
            }
            
            NavigationRow(
                title: "Terms of Use",
                icon: "doc.text.fill",
                color: .gray
            ) {
                showTermsOfUse()
            }
        } header: {
            SectionHeader(text: "Legal")
        }
    }
    
    // MARK: - Connect Section
    private var connectSection: some View {
        Section {
            Link(destination: URL(string: "https://x.com/andrew_sereda")!) {
                NavigationRow(
                    title: "Follow Developer on X",
                    subtitle: "@andrew_sereda",
                    icon: "person.fill",
                    color: .cyan
                )
            }
            
            // NEW: Tip Jar Navigation Link
            NavigationLink(destination: TipJarView().toolbar(.hidden, for: .tabBar)) {
                NavigationRow(
                    title: "Tip Jar",
                    subtitle: "Support development with a tip",
                    icon: "cup.and.saucer.fill",
                    color: .pink
                )
            }
        } header: {
            SectionHeader(text: "Connect")
        }
    }
    
    // MARK: - Actions
    private func showCurrentPlan() {}
    private func showNotificationsOptions() {}
    private func showSecurityOptions() {}
    private func showICloudSyncOptions() {}
    private func showDataStorageOptions() {}
    private func showLanguageOptions() {}
    private func showCategoriesOptions() {}
    private func showTagsOptions() {}
    private func reportBug() {}
    private func requestFeature() {}
    private func rateApp() {}
    private func shareApp() {}
    private func showPrivacyPolicy() {}
    private func showTermsOfUse() {}
    private func showDonateOptions() {}
}

// MARK: - Supporting Views
struct NavigationRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    var action: (() -> Void)? = nil
    var showChevron: Bool = false // Add this parameter
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Only show chevron if explicitly requested
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct DaySelectorPill: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(day) day\(day > 1 ? "s" : "")")
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(UIColor.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct SectionHeader: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .textCase(nil)
    }
}

// MARK: - View Modifier
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

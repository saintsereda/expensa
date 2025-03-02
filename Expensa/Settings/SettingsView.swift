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
    @StateObject private var themeManager = ThemeManager()
    @State private var showingDebug = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    // Cache these values to avoid repeated fetches
    @State private var categoryCount: Int = 0
    @State private var tagCount: Int = 0
    @State private var defaultCurrencyCode: String = "Not set"
    
    var body: some View {
        List {
          //  profileSection
            preferencesSection
            manageSection
            supportSection
            feedbackSection
            legalSection
            connectSection
        }
        .listStyle(InsetGroupedListStyle())
        .sheet(isPresented: $showingDebug) {
            NavigationView {
                RateDebugView()
            }
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
    
    // MARK: - Profile Section
    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free Plan")
                        .font(.headline)
                    Text("Upgrade for more features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                showCurrentPlan()
            }
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                    Text("Appearance")
                        .font(.body)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { themeManager.selectedTheme },
                        set: { themeManager.setTheme($0) }
                    )) {
                        ForEach(ColorScheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.vertical, 4)
            // NavigationLink(destination: RateDebugView().toolbar(.hidden, for: .tabBar)) {
            //     NavigationRow(
            //         title: "Debug rates",
            //         icon: "ladybug.fill",
            //         color: .gray
            //     ) {
            //         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //             showingDebug = true
            //         }
            //     }
            // }
            
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
            SectionHeader(text: "Preferences")
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
            
            NavigationRow(
                title: "Support Development",
                subtitle: "Help keep Expensa free",
                icon: "heart.fill",
                color: .red
            ) {
                showDonateOptions()
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

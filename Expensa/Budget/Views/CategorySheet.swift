//
//  CategorySheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 18.11.2024.
//  Updated on 20.03.2025.
//

import SwiftUI
import CoreData
import Combine

// Protocol for multi-select category selection behavior
protocol MultiCategorySelectionBehavior {
    func onCategorySelected(_ category: Category)
    func isSelected(_ category: Category) -> Bool
}

struct StandardMultiSelectionBehavior: MultiCategorySelectionBehavior {
    @Binding var selectedCategories: Set<Category>
    
    func onCategorySelected(_ category: Category) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    func isSelected(_ category: Category) -> Bool {
        return selectedCategories.contains(category)
    }
}

struct CategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var categoryManager: CategoryManager
    
    private let selectionBehavior: MultiCategorySelectionBehavior
    @State private var searchText = ""
    @State private var categories: [Category] = []
    @State private var hasLoaded: Bool = false
    @State private var navigateToNewCategory: Bool = false
    
    private var filteredCategories: [Category] {
        searchText.isEmpty ? categories : categories.filter { category in
            (category.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Initialize for standard multi-selection
    init(selectedCategories: Binding<Set<Category>>) {
        self.selectionBehavior = StandardMultiSelectionBehavior(selectedCategories: selectedCategories)
    }
    
    // Function to update categories based on search text
    private func updateCategories() {
        categories = categoryManager.getCategories()
    }
    
    // Function to load all necessary data
    private func loadData() {
        // Skip if already loaded
        if hasLoaded { return }
        
        // Load all categories
        updateCategories()
        
        hasLoaded = true
    }
    
    var body: some View {
        List {
            // Header section
            Section {
                Text("Select categories to set individual spending limits for each")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Categories section
            Section {
                if filteredCategories.isEmpty {
                    Text("No categories found")
                        .foregroundColor(.gray)
                } else {
                    ForEach(filteredCategories, id: \.self) { category in
                        CategoryRow(
                            category: category,
                            isSelected: selectionBehavior.isSelected(category)
                        )
                        .onTapGesture {
                            selectionBehavior.onCategorySelected(category)
                            categoryManager.incrementUsage(for: category)
                            HapticFeedback.play()
                        }
                    }
                }
            }
            
            // Add new category section
            Section {
                Button(action: {
                    navigateToNewCategory = true
                    HapticFeedback.play()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add new category")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Select Categories")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search categories")
        .navigationBarBackButtonHidden(false)
        .task {
            // Use .task instead of .onAppear for better SwiftUI lifecycle integration
            loadData()
        }
        .onChange(of: searchText) { _, _ in
            // We don't need to call updateCategories here since filteredCategories is computed
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CategoriesUpdated"))) { _ in
            // Update categories when we receive a notification that categories have been updated
            updateCategories()
        }
        .navigationDestination(isPresented: $navigateToNewCategory) {
            CategoryFormView(showCancelButton: false)
                .environmentObject(categoryManager)
        }
    }
}

private struct CategoryRow: View {
    let category: Category
    let isSelected: Bool
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Text(category.icon ?? "🔹")
                    .font(.system(size: 18))
            }
            
            Text(category.name ?? "Unnamed Category")
                .font(.body)
                .padding(.leading, 8)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

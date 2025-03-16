//
//  CategorySelectorView.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import SwiftUI
import CoreData
import Combine

import SwiftUI
import CoreData
import Combine

struct CategorySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var categoryManager: CategoryManager
    
    // Binding to the selected category
    @Binding var selectedCategory: Category?
    
    // State variables
    @State private var searchText = ""
    @State private var categories: [Category] = []
    @State private var hasLoaded: Bool = false
    @State private var navigateToNewCategory: Bool = false
    @State private var isKeyboardVisible = false
    
    private let lastSelectedCategoryKey = "lastSelectedCategoryID"
    
    init(selectedCategory: Binding<Category?>) {
        self._selectedCategory = selectedCategory
    }
    
    // Function to update categories based on search text
    private func updateCategories() {
        let allCategories = categoryManager.getCategories()
        
        if searchText.isEmpty {
            // Show all categories when search is empty
            categories = allCategories
        } else {
            // Filter by search text
            categories = allCategories.filter { category in
                (category.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Function to load all necessary data
    private func loadData() {
        // Skip if already loaded
        if hasLoaded { return }
        
        // Load all categories
        updateCategories()
        
        hasLoaded = true
    }
    
    private func handleCategorySelection(_ category: Category) {
        selectedCategory = category
        saveLastSelectedCategory(category)
        categoryManager.incrementUsage(for: category)
        dismiss()
    }
    
    private func saveLastSelectedCategory(_ category: Category) {
        guard let categoryId = category.id?.uuidString else { return }
        UserDefaults.standard.set(categoryId, forKey: lastSelectedCategoryKey)
    }
    
    private func getLastSelectedCategory() -> Category? {
        guard let savedCategoryId = UserDefaults.standard.string(forKey: lastSelectedCategoryKey),
              let uuid = UUID(uuidString: savedCategoryId) else {
            return nil
        }
        
        return categoryManager.categories.first { category in
            category.id == uuid
        }
    }
    
    private func setupKeyboardObservers() {
        let keyboardWillShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
        
        let keyboardWillHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }
        
        _ = Publishers.Merge(keyboardWillShow, keyboardWillHide)
            .subscribe(on: RunLoop.main)
            .assign(to: \.isKeyboardVisible, on: self)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Main content - either all categories or search results
                        if categories.isEmpty {
                            emptyCategoriesView
                        } else {
                            categoriesGridView
                        }
                    }
                    // Add bottom padding to prevent content from being hidden by the floating search bar
                    .padding(.bottom, 104)
                }
                
                // Floating search bar with background
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
                    
                    FloatingSearchBar(text: $searchText, isKeyboardVisible: $isKeyboardVisible, placeholder: "Search categories")
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Select category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .foregroundColor(.primary)
            .task {
                // Use .task instead of .onAppear for better SwiftUI lifecycle integration
                loadData()
                setupKeyboardObservers()
            }
            .onChange(of: searchText) { _, _ in
                updateCategories()
            }
            .onChange(of: navigateToNewCategory) { oldValue, newValue in
                // When returning from the CategoryFormView
                if oldValue == true && newValue == false {
                    // Clear the search text to reset the view
                    searchText = ""
                    
                    // Refresh the categories list with a slight delay to ensure CoreData is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Reload data
                        updateCategories()
                        
                        // Get the most recently added category
                        let allCategories = categoryManager.getCategories()
                        if let newCategory = allCategories.last {
                            // Select the newly added category
                            selectedCategory = newCategory
                            saveLastSelectedCategory(newCategory)
                            categoryManager.incrementUsage(for: newCategory)
                        }
                    }
                }
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
    
    // MARK: - Extracted View Components
    
    private var emptyCategoriesView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("No categories found.\nYou can create your own category")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: { navigateToNewCategory = true }) {
                AddCategoryItem()
            }
            .frame(width: 120)
            
            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var categoriesGridView: some View {
        Group {
            // Calculate how many items we have (categories + add button)
            let totalItems = categories.count + 1
            let rowCount = (totalItems + 2) / 3 // Calculate number of rows needed for 3 items per row
            
            VStack(alignment: .leading, spacing: 24) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { colIndex in
                            let index = rowIndex * 3 + colIndex
                            
                            if index < categories.count {
                                // Regular category
                                CategoryItemView(
                                    category: categories[index],
                                    isSelected: selectedCategory != nil && categories[index] == selectedCategory
                                )
                                .onTapGesture {
                                    handleCategorySelection(categories[index])
                                    HapticFeedback.play()
                                }
                                .frame(maxWidth: .infinity)
                            } else if index == categories.count {
                                // Add category button (exactly after all categories)
                                Button(action: {
                                    HapticFeedback.play()
                                    navigateToNewCategory = true
                                }) {
                                    AddCategoryItem()
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                // Empty space
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 24)
    }
}

// Separate view for the Add Category button
struct AddCategoryItem: View {
    var body: some View {
        VStack(spacing: 12) {
            // Circle with + icon
            ZStack {
                Circle()
                    .stroke(Color(UIColor.systemGray5), lineWidth: 2)
                    .frame(width: 80, height: 80)

                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
            }
            
            // Text label
            Text("Add category")
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

struct CategoryItemView: View {
    let category: Category
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Emoji container - 48px circle with 24px emoji
            ZStack {
                Circle()
                    .fill(isSelected ? Color(UIColor.systemGray5) : Color.clear)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                    .stroke(Color(UIColor.systemGray5), lineWidth: 2)
                    )
                
                Text(category.icon ?? "🔹")
                    .font(.system(size: 32))
            }
            
            // Category name
            Text(category.name ?? "Unnamed")
                .font(.system(size: 15))
                .foregroundColor(Color.primary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

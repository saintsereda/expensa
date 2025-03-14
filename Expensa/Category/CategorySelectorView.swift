//
//  CategorySelectorView.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

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
    @State private var filteredCategories: [Category] = []
    @State private var frequentCategories: [Category] = []
    @State private var hasLoaded: Bool = false
    @State private var navigateToNewCategory: Bool = false
    @State private var isKeyboardVisible = false
    
    private let lastSelectedCategoryKey = "lastSelectedCategoryID"
    
    init(selectedCategory: Binding<Category?>) {
        self._selectedCategory = selectedCategory
    }
    
    // Function to update filtered categories based on search text
    private func updateFilteredCategories() {
        let allCategories = categoryManager.getCategories()
        
        if searchText.isEmpty {
            // When showing frequently used categories, remove them from the main list
            filteredCategories = allCategories.filter { category in
                !frequentCategories.contains(category)
            }
        } else {
            // Filter by search text
            filteredCategories = allCategories.filter { category in
                (category.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Function to load all necessary data
    private func loadData() {
        // Skip if already loaded
        if hasLoaded { return }
        
        // Load frequent categories
        frequentCategories = categoryManager.getMostUsedCategories()
        
        // Load and filter all categories
        updateFilteredCategories()
        
        // The key change: Don't modify selectedCategory if it's explicitly nil
        // This preserves the nil state when editing an expense with no category
        
        hasLoaded = true
    }
    
    // Chunk the array of categories into arrays of 3 for grid layout
    private func chunkedCategories(_ categories: [Category]) -> [[Category]] {
        var result: [[Category]] = []
        var currentChunk: [Category] = []
        
        for category in categories {
            currentChunk.append(category)
            if currentChunk.count == 4 {
                result.append(currentChunk)
                currentChunk = []
            }
        }
        
        if !currentChunk.isEmpty {
            result.append(currentChunk)
        }
        
        return result
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
                    VStack(alignment: .leading, spacing: 0) {
                        // MARK: - Main View Content
                        if searchText.isEmpty {
                            frequentCategoriesSection
                            allCategoriesSection
                        } else {
                            searchResultsSection
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
                updateFilteredCategories()
            }
            .onChange(of: navigateToNewCategory) { oldValue, newValue in
                // When returning from the CategoryFormView
                if oldValue == true && newValue == false {
                    // Clear the search text to reset the view
                    searchText = ""
                    
                    // Refresh the categories list with a slight delay to ensure CoreData is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Reload data including frequently used categories
                        frequentCategories = categoryManager.getMostUsedCategories()
                        updateFilteredCategories()
                        
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
                updateFilteredCategories()
            }
            .navigationDestination(isPresented: $navigateToNewCategory) {
                CategoryFormView(showCancelButton: false)
                    .environmentObject(categoryManager)
            }
        }
    }
    
    // MARK: - Extracted View Components
    
    private var frequentCategoriesSection: some View {
        Group {
            if !frequentCategories.isEmpty {
                Text("Frequently used")
                    .font(.subheadline)
                    .padding(.horizontal)
                    .padding(.top)
                    .foregroundColor(.gray)
                
                ForEach(chunkedCategories(frequentCategories), id: \.self) { row in
                    categoryRow(for: row)
                }
            }
        }
    }
    
    private var allCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All categories")
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.top)
                .foregroundColor(.gray)
            
            if filteredCategories.isEmpty {
                emptyCategoriesView
            } else {
                categoriesGridView
            }
        }
    }
    
    private var emptyCategoriesView: some View {
        VStack {
            HStack(spacing: 8) {
                Spacer().frame(maxWidth: .infinity)
                
                Button(action: { navigateToNewCategory = true }) {
                    AddCategoryItem()
                }
                .frame(maxWidth: .infinity)
                
                
                Spacer().frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            Text("No categories found")
                .foregroundColor(.gray)
                .padding(.horizontal)
        }
    }
    
    private var categoriesGridView: some View {
        Group {
            // Calculate how many items we have (categories + add button)
            let totalItems = filteredCategories.count + 1
            let rowCount = (totalItems + 3) / 4 // Calculate number of rows needed
            
            VStack(alignment: .leading, spacing: 24) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { colIndex in
                            let index = rowIndex * 4 + colIndex
                            
                            if index < filteredCategories.count {
                                // Regular category
                                CategoryItemView(
                                    category: filteredCategories[index],
                                    isSelected: selectedCategory != nil && filteredCategories[index] == selectedCategory
                                )
                                .onTapGesture {
                                    handleCategorySelection(filteredCategories[index])
                                    HapticFeedback.play()
                                }
                                .frame(maxWidth: .infinity)
                            } else if index == filteredCategories.count {
                                // Add category button (exactly after all categories)
                                // IMPORTANT: Remove the nested onTapGesture
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
    }
    
    private var categoryRows: some View {
        Group {
            if !filteredCategories.isEmpty {
                let rowCount = (filteredCategories.count + 3) / 4 // Calculate number of rows needed
                
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { colIndex in
                            let index = rowIndex * 4 + colIndex
                            
                            if index < filteredCategories.count {
                                CategoryItemView(
                                    category: filteredCategories[index],
                                    isSelected: selectedCategory != nil && filteredCategories[index] == selectedCategory
                                )
                                .onTapGesture {
                                    handleCategorySelection(filteredCategories[index])
                                    HapticFeedback.play()
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var searchResultsSection: some View {
        Group {
            if filteredCategories.isEmpty {
                // Center aligned content for empty search results
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
            } else {
                searchResultsGrid
            }
        }
    }
    
    private var searchResultsGrid: some View {
        Group {
            // Calculate how many items we have (categories + add button)
            let totalItems = filteredCategories.count + 1
            let rowCount = (totalItems + 3) / 4
            
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { colIndex in
                        let index = rowIndex * 4 + colIndex
                        
                        if index < filteredCategories.count {
                            // Regular category
                            CategoryItemView(
                                category: filteredCategories[index],
                                isSelected: selectedCategory != nil && filteredCategories[index] == selectedCategory
                            )
                            .onTapGesture {
                                handleCategorySelection(filteredCategories[index])
                                HapticFeedback.play()
                            }
                            .frame(maxWidth: .infinity)
                        } else if index == filteredCategories.count {
                            // Add category button (exactly after all categories)
                            // IMPORTANT: Remove the nested onTapGesture
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
    
    private func categoryRow(for row: [Category]) -> some View {
        HStack(spacing: 8) {
            ForEach(row, id: \.self) { category in
                CategoryItemView(
                    category: category,
                    isSelected: selectedCategory != nil && category == selectedCategory
                )
                .onTapGesture {
                    handleCategorySelection(category)
                    HapticFeedback.play()
                }
                .frame(maxWidth: .infinity)
            }
            
            // Fill empty slots with spacers
            if row.count < 4 {
                ForEach(0..<(4 - row.count), id: \.self) { _ in
                    Spacer().frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var addCategoryRow: some View {
        HStack {
            Spacer()
            
            Button(action: { navigateToNewCategory = true }) {
                AddCategoryItem()
                    .onTapGesture {
                        HapticFeedback.play()
                    }
            }
            .frame(width: 100)
            
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
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
                    .frame(width: 64, height: 64)

                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
            }
            
            // Text label
            Text("Add category")
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(height: 104)
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
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Text(category.icon ?? "🔹")
                    .font(.system(size: 20))
            }
            .overlay(
                isSelected ?
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 64, height: 64) : nil
            )
            
            // Category name
            Text(category.name ?? "Unnamed")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .blue : .primary)
                .lineLimit(1)
        }
        .frame(height: 104)
        .contentShape(Rectangle())
    }
}

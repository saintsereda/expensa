//
//  CategorySelectorView.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import SwiftUI
import CoreData

// Protocol for different category selection behaviors remains the same
protocol CategorySelectionBehavior {
    func onCategorySelected(_ category: Category)
    func isSelected(_ category: Category) -> Bool
    var shouldSaveLastSelected: Bool { get }
}

struct ExpenseSelectionBehavior: CategorySelectionBehavior {
    @Binding var selectedCategory: Category?
    
    func onCategorySelected(_ category: Category) {
        selectedCategory = category
    }
    
    func isSelected(_ category: Category) -> Bool {
        return category == selectedCategory
    }
    
    var shouldSaveLastSelected: Bool { true }
}

struct BudgetSelectionBehavior: CategorySelectionBehavior {
    var categoryBudgets: [Category: Decimal]
    var onSelect: (Category) -> Void
    
    func onCategorySelected(_ category: Category) {
        onSelect(category)
    }
    
    func isSelected(_ category: Category) -> Bool {
        return categoryBudgets.keys.contains(category)
    }
    
    var shouldSaveLastSelected: Bool { false }
}

struct CategorySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var categoryManager: CategoryManager

    private let selectionBehavior: CategorySelectionBehavior
    @State private var searchText = ""
    
    private let lastSelectedCategoryKey = "lastSelectedCategoryID"
    
    private var filteredCategories: [Category] {
        let allCategories = categoryManager.getCategories()
        let filtered = searchText.isEmpty ? allCategories : allCategories.filter { category in
            (category.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
        
        // When showing frequently used categories, remove them from the main list
        if searchText.isEmpty && !frequentlyUsedCategories.isEmpty {
            return filtered.filter { category in
                !frequentlyUsedCategories.contains(category)
            }
        }
        
        return filtered
    }
    
    // Initialize for expense selection
    init(selectedCategory: Binding<Category?>) {
        self.selectionBehavior = ExpenseSelectionBehavior(selectedCategory: selectedCategory)
    }
    
    // Initialize for budget selection
    init(categoryBudgets: [Category: Decimal], onSelect: @escaping (Category) -> Void) {
        self.selectionBehavior = BudgetSelectionBehavior(categoryBudgets: categoryBudgets, onSelect: onSelect)
    }
    
    private var frequentlyUsedCategories: [Category] {
        guard selectionBehavior is ExpenseSelectionBehavior else { return [] }
        return categoryManager.getMostUsedCategories()
    }
    
    var body: some View {
        NavigationView {
            List {
                if searchText.isEmpty {
                    // Frequently Used section for expense creation only
                    if !frequentlyUsedCategories.isEmpty {
                        Section(header: Text("Frequently Used")) {
                            ForEach(frequentlyUsedCategories, id: \.self) { category in
                                CategoryRow(
                                    category: category,
                                    isSelected: selectionBehavior.isSelected(category)
                                )
                                .onTapGesture {
                                    selectionBehavior.onCategorySelected(category)
                                    if selectionBehavior.shouldSaveLastSelected {
                                        saveLastSelectedCategory(category)
                                    }
                                    categoryManager.incrementUsage(for: category)
                                    dismiss()
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("All Categories")) {
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
                                    if selectionBehavior.shouldSaveLastSelected {
                                        saveLastSelectedCategory(category)
                                    }
                                    if selectionBehavior is ExpenseSelectionBehavior {
                                        categoryManager.incrementUsage(for: category)
                                    }
                                    dismiss()
                                }
                            }
                        }
                    }
                } else {
                    // Search results without sections
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
                                if selectionBehavior.shouldSaveLastSelected {
                                    saveLastSelectedCategory(category)
                                }
                                if selectionBehavior is ExpenseSelectionBehavior {
                                    categoryManager.incrementUsage(for: category)
                                }
                                dismiss()
                            }
                        }
                    }
                }
            }
           .navigationTitle("Select category")
           .navigationBarTitleDisplayMode(.inline)
           .searchable(text: $searchText, prompt: "Search categories")
           .toolbar {
               ToolbarItem(placement: .navigationBarLeading) {
                   Button("Cancel") {
                       dismiss()
                   }
               }
           }
           .onAppear {
               // Ensure categories are loaded
               if categoryManager.categories.isEmpty {
                   categoryManager.reloadCategories()
               }
               
               // Handle last selected category
               if let expenseBehavior = selectionBehavior as? ExpenseSelectionBehavior,
                  expenseBehavior.selectedCategory == nil {
                   if let lastCategory = getLastSelectedCategory() {
                       expenseBehavior.selectedCategory = lastCategory
                   }
               }
           }
       }
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
}

private struct CategoryRow: View {
    let category: Category
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(category.icon ?? "🔹")
            Text(category.name ?? "Unnamed Category")
                .font(.body)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
    }
}

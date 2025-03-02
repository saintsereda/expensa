//
//  CategorySheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 18.11.2024.
//

import SwiftUI
import CoreData

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
    
    private var filteredCategories: [Category] {
        let allCategories = categoryManager.getCategories()
        let filtered = searchText.isEmpty ? allCategories : allCategories.filter { category in
            (category.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
        
        return filtered
    }
    
    // Initialize for standard multi-selection
    init(selectedCategories: Binding<Set<Category>>) {
        self.selectionBehavior = StandardMultiSelectionBehavior(selectedCategories: selectedCategories)
    }
    

    
    var body: some View {
        NavigationView {
            List {
                if searchText.isEmpty {
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
                                categoryManager.incrementUsage(for: category)
                            }
                        }
                    }
                }
            }
           .navigationTitle("Select Categories")
           .navigationBarTitleDisplayMode(.inline)
           .searchable(text: $searchText, prompt: "Search categories")
           .toolbar {
               ToolbarItem(placement: .navigationBarLeading) {
                   Button("Cancel") {
                       dismiss()
                   }
               }
               ToolbarItem(placement: .navigationBarTrailing) {
                   Button("Done") {
                       dismiss()
                   }
               }
           }
           .onAppear {
               // Ensure categories are loaded
               if categoryManager.categories.isEmpty {
                   categoryManager.reloadCategories()
               }
           }
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

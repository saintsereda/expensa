//
//  DataCategorySelection.swift
//  Expensa
//
//  Created by Andrew Sereda on 14.02.2025.
//

import Foundation
import SwiftUI
import CoreData

struct DataCategorySelection: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedCategories: Set<Category>
    @State private var selectAll = false
    @State private var searchText = ""
    
    var categories: [Category]
    
    private var sortedCategories: [Category] {
        let filtered = searchText.isEmpty ? categories : categories.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.icon ?? "").contains(searchText)
        }
        return filtered.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search categories...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
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
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                List {
                    // Select All Row
                    HStack {
                        Text("All categories")
                        
                        Spacer()
                        
                        Image(systemName: selectAll ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectAll ? .blue : .gray)
                            .font(.system(size: 20))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectAll.toggle()
                        if selectAll {
                            selectedCategories = Set(categories)
                        } else {
                            selectedCategories.removeAll()
                        }
                    }
                    
                    // Category Rows
                    ForEach(sortedCategories, id: \.self) { category in
                        HStack {
                            Text(category.icon ?? "🔹")
                            
                            Text(category.name ?? "Unnamed Category")
                            
                            Spacer()
                            
                            Image(systemName: selectedCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedCategories.contains(category) ? .blue : .gray)
                                .font(.system(size: 20))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                            selectAll = selectedCategories.count == categories.count
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    dismiss()
                }
            )
            .onAppear {
                // Initialize selection state
                if selectedCategories.isEmpty {
                    selectedCategories = Set(categories)
                }
                selectAll = selectedCategories.count == categories.count
            }
        }
    }
}

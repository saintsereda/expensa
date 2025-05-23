//
//  TagDetailSheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 23.05.2025.
//

import SwiftUI
import CoreData

struct TagDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tagManager: TagManager
    let tag: Tag
    
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showExpensesList = false
    @State private var expenseCount: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tag header
                VStack(spacing: 16) {
                    // Tag display
                    Text("#\(tag.name ?? "unknown")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .padding(.top, 20)
                    
                    // Expense count
                    Text(expenseCountText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray6))
                
                // Options list
                VStack(spacing: 0) {
                    // Show transactions / No expenses option
                    Button(action: {
                        if expenseCount > 0 {
                            showExpensesList = true
                        }
                    }) {
                        HStack {
                            Image(systemName: expenseCount > 0 ? "list.bullet.rectangle" : "tray")
                                .foregroundColor(expenseCount > 0 ? .blue : .gray)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expenseCount > 0 ? "Show Transactions" : "No Expenses")
                                    .foregroundColor(expenseCount > 0 ? .primary : .gray)
                                    .font(.body)
                                
                                if expenseCount > 0 {
                                    Text("View all expenses with this tag")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if expenseCount > 0 {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                    }
                    .disabled(expenseCount == 0)
                    
                    Divider()
                        .padding(.leading, 64)
                    
                    // Edit tag option
                    Button(action: {
                        showEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Edit Tag")
                                    .foregroundColor(.primary)
                                    .font(.body)
                                
                                Text("Change tag name or color")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                    }
                    
                    Divider()
                        .padding(.leading, 64)
                    
                    // Remove tag option
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remove Tag")
                                    .foregroundColor(.red)
                                    .font(.body)
                                
                                Text(expenseCount > 0 ? "Remove from all expenses" : "Delete this tag")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Tag Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            updateExpenseCount()
        }
        .sheet(isPresented: $showEditSheet) {
            TagEditSheet(tag: tag)
                .environmentObject(tagManager)
        }
        .sheet(isPresented: $showExpensesList) {
            NavigationView {
                AllExpensesView(preselectedTag: tag)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showExpensesList = false
                            }
                        }
                    }
            }
            .presentationCornerRadius(32)
        }
        .alert("Remove Tag", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                deleteTag()
            }
        } message: {
            Text(expenseCount > 0 ?
                 "This tag will be removed from \(expenseCount) expense\(expenseCount == 1 ? "" : "s"). This action cannot be undone." :
                 "This tag will be permanently deleted.")
        }
        .presentationCornerRadius(32)
    }
    
    private var expenseCountText: String {
        if expenseCount == 0 {
            return "No expenses with this tag"
        } else if expenseCount == 1 {
            return "1 expense with this tag"
        } else {
            return "\(expenseCount) expenses with this tag"
        }
    }
    
    private func updateExpenseCount() {
        expenseCount = tag.expenses?.count ?? 0
    }
    
    private func deleteTag() {
        tagManager.deleteTag(tag)
        HapticFeedback.playSuccess()
        dismiss()
    }
}

// MARK: - Tag Edit Sheet
struct TagEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tagManager: TagManager
    let tag: Tag
    
    @State private var tagName: String = ""
    @State private var selectedColor: String = ""
    @State private var showValidationError = false
    
    private let availableColors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
        "#FFEEAD", "#D4A5A5", "#9B59B6", "#3498DB",
        "#E74C3C", "#2ECC71", "#F39C12", "#8E44AD"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Tag name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("#")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                        
                        TextField("Enter tag name", text: $tagName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    if showValidationError {
                        Text("Tag name cannot be empty")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Color selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == colorHex ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedColor = colorHex
                                    HapticFeedback.play()
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
        .onAppear {
            tagName = tag.name ?? ""
            selectedColor = tag.color ?? availableColors.first!
        }
        .presentationCornerRadius(32)
    }
    
    private func saveChanges() {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            showValidationError = true
            HapticFeedback.playError()
            return
        }
        
        // Check if another tag already has this name
        if let existingTag = tagManager.findTag(name: trimmedName),
           existingTag != tag {
            showValidationError = true
            HapticFeedback.playError()
            return
        }
        
        // Update the tag
        tag.name = trimmedName.lowercased()
        tag.color = selectedColor
        
        // Save to Core Data
        do {
            try CoreDataStack.shared.context.save()
            tagManager.fetchAllTags()
            HapticFeedback.playSuccess()
            dismiss()
        } catch {
            print("Error saving tag changes: \(error)")
            HapticFeedback.playError()
        }
    }
}

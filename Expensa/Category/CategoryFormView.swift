//
//  AddCategory.swift
//  Expensa
//
//  Created by Andrew Sereda on 28.10.2024.
//

import SwiftUI
import UIKit
import ConfettiSwiftUI

// Custom UITextField that defaults to emoji keyboard
class EmojiTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        return UITextInputMode.activeInputModes.first(where: { $0.primaryLanguage == "emoji" })
    }
}

// SwiftUI wrapper for EmojiTextField
struct EmojiTextFieldRepresentable: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> EmojiTextField {
        let textField = EmojiTextField()
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.font = .systemFont(ofSize: 72)
        textField.tintColor = .clear
        
        return textField
    }
    
    func updateUIView(_ uiView: EmojiTextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Get the new text after the change
            if let text = textField.text,
               let textRange = Range(range, in: text) {
                let updatedText = text.replacingCharacters(in: textRange, with: string)
                // Only allow one emoji
                if updatedText.count > 1 {
                    DispatchQueue.main.async {
                        self.text = string.isEmpty ? "" : string
                    }
                    return false
                }
            }
            return true
        }
    }
}

struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var categoryName: String = ""
    @State private var selectedEmoji: String
    @State private var isValid = false
    @State private var showAnimation = false
    @State private var showDeleteConfirmation = false
    @FocusState private var isNameFieldFocused: Bool
    @State private var showConfetti = false
    @State private var confettiCounter = 0
    
    private let editingCategory: Category?
    private let isEditing: Bool
    
    var onSave: ((String) -> Void)?
    
    private static let placeholderEmojis = [
        "🛒", "🏠", "🚗", "🍔", "💰", "🎮", "📱", "🎬", "💄", "🏋️",
        "📚", "✈️", "🎵", "🏥", "🎁", "👕", "🐶", "🎨", "💼", "🏦"
    ]
    
    init() {
        let randomEmoji = Self.placeholderEmojis.randomElement() ?? "😀"
        _selectedEmoji = State(initialValue: randomEmoji)
        self.editingCategory = nil
        self.isEditing = false
    }
    
    init(category: Category) {
        _selectedEmoji = State(initialValue: category.icon ?? "😀")
        _categoryName = State(initialValue: category.name ?? "")
        self.editingCategory = category
        self.isEditing = true
    }
    
    init(onSave: @escaping (String) -> Void) {
        let randomEmoji = Self.placeholderEmojis.randomElement() ?? "😀"
        _selectedEmoji = State(initialValue: randomEmoji)
        self.editingCategory = nil
        self.isEditing = false
        self.onSave = onSave
    }
    
    var body: some View {
            VStack(spacing: 24) {
                // Emoji input
                ZStack {
                    EmojiTextFieldRepresentable(text: $selectedEmoji)
                        .onChange(of: selectedEmoji) { _, newValue in
                            if !newValue.isEmpty {
                                showAnimation = false
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    selectedEmoji = String(newValue.suffix(1))
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showAnimation = true
                                    }
                                }
                            }
                        }
                        .blurAnimation(isAnimating: showAnimation)
                        .onAppear {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showAnimation = true
                            }
                        }
                }
                .frame(width: 120, height: 120)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(60)
                
                // Category name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    TextField("", text: $categoryName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            isNameFieldFocused ?
                                            Color.accentColor.opacity(0.5) :
                                            Color(UIColor.systemGray4),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .focused($isNameFieldFocused)
                        .onChange(of: categoryName) {
                            validateInput()
                        }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                Spacer()
                
                // Delete button (only shown when editing)
                if isEditing {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Text("Delete Category")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .padding(.top, 32)
            .navigationTitle(isEditing ? "Edit category" : "New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Save") {
                        saveCategory()
                    }
                    .disabled(!isValid)
                }
            }
            .ignoresSafeArea(.keyboard)
            .onAppear {
                validateInput()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimation = true
                }
                // Set focus to the name field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFieldFocused = true
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside of text fields
                isNameFieldFocused = false
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete category?"),
                    message: Text("All related transactions will remain uncategorized."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteCategory()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    
    private func validateInput() {
        isValid = !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedEmoji.isEmpty
    }
    
    private func saveCategory() {
        isNameFieldFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let category = editingCategory {
                // Update existing category
                CategoryManager.shared.updateCategory(
                    category,
                    name: trimmedName,
                    icon: selectedEmoji
                )
            } else {
                // Add new category
                CategoryManager.shared.addCustomCategory(
                    name: trimmedName,
                    icon: selectedEmoji
                )
                print("DEBUG: Calling onSave with emoji: \(selectedEmoji)")
                onSave?(selectedEmoji)
            }
            
            dismiss()
        }
    }
    
    private func deleteCategory() {
        if let category = editingCategory {
            CategoryManager.shared.deleteCategory(category)
        }
        dismiss()
    }
}

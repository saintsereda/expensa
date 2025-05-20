//
//  CategoryListView.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI
import CoreData
import Foundation
import ConfettiSwiftUI

struct CategoryListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) var categories: FetchedResults<Category>
    
    @State private var isEditing = false
    @State private var selectedCategories = Set<Category>()
    @State private var firstSelection: Category? = nil
    @State private var secondSelection: Category? = nil
    @State private var thirdSelection: Category? = nil  // Add this new state variable
    @State private var showAnimations = [false, false, false, false]  // Expand animations array
    
    @State private var showDeleteConfirmation = false
    @State private var isPresented = false
    @State private var selectedCategoryForEdit: Category?
    
    @State private var showConfetti = false
    @State private var confettiCounter = 0
    @State private var confettiEmoji = "🎉"
    @State private var isAddingNewCategory = false
    
    @State private var showSuccessSheet = false
    @State private var isProcessingDeletion = false
    @State private var deletionCount = 0
    
    var filteredCategories: [Category] {
        if searchText.isEmpty {
            return Array(categories)
        } else {
            return categories.filter { category in
                (category.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                (category.icon ?? "").contains(searchText)
            }
        }
    }
    
    var body: some View {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Search bar
                        SearchBar(text: $searchText)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        if filteredCategories.isEmpty {
                            emptyStateView
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredCategories, id: \.self) { category in
                                    HStack {
                                        Text(category.icon ?? "🔹")
                                        Text(category.name ?? "Unnamed Category")
                                            .font(.body)
                                        
                                        Spacer()
                                        
                                        if isEditing {
                                            Image(systemName: selectedCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(.blue)
                                                .onTapGesture {
                                                    toggleSelection(of: category)
                                                }
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isEditing {
                                            toggleSelection(of: category)
                                        } else {
                                            selectedCategoryForEdit = category
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    
                                    if category != filteredCategories.last {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, isEditing ? 60 : 0)
                }
                
                if isEditing {
                    VStack {
                        Spacer()
                        bottomSheet
                            .opacity(showSuccessSheet ? 0 : 1)
                            .animation(.easeOut(duration: 0.2), value: showSuccessSheet)
                    }
                }
                
                ZStack(alignment: .bottom) {
                    Spacer()
                    ConfettiCannon(
                        trigger: $confettiCounter,
                        num: 50,
                        confettis: [.text(confettiEmoji)],
                        colors: [.red, .blue, .green],
                        confettiSize: 20,
                        rainHeight: 800,
                        radius: 500,
                        repetitions: 1,
                        repetitionInterval: 0.5
                    )
                    .id(confettiEmoji)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: 50)
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            isEditing.toggle()
                            if !isEditing {
                                selectedCategories.removeAll()
                                firstSelection = nil
                                secondSelection = nil
                                thirdSelection = nil  // Clear third selection
                                showAnimations = [false, false, false, false]  // Reset all animations
                            }
                        }) {
                            Text(isEditing ? "Done" : "Edit")
                        }
                        
                        if !isEditing {
                            Button(action: {
                                isAddingNewCategory = true
                                isPresented = true
                            }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedCategoryForEdit) { category in
                NavigationStack {
                    CategoryFormView(category: category)
                }
            }
            .ignoresSafeArea(.keyboard)
            .sheet(isPresented: $isPresented, onDismiss: {
                isAddingNewCategory = false
            }) {
                NavigationStack {
                    CategoryFormView(onSave: { emoji in
                        print("DEBUG: Received emoji in callback: \(emoji)")
                        confettiEmoji = emoji  // Set the emoji first
                        // Small delay to ensure the View updates with new emoji before triggering
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                confettiCounter += 1  // Then trigger the animation
                            }
                            showConfetti = true
                        }
                    })
                }
            }
            .sheet(isPresented: $showSuccessSheet, onDismiss: {
                // This will be called whether the sheet is dismissed automatically or manually
                
                resetUIAfterCategoryDeletion()
            }) {
                SuccessSheet(
                    isLoading: $isProcessingDeletion,
                    message: "\(deletionCount) \(deletionCount == 1 ? "category" : "categories") removed",
                    loadingMessage: "Removing categories...",
                    iconName: "checkmark.circle.fill"
                )
                .presentationBackground(.clear)
                .presentationBackgroundInteraction(.enabled)
                .presentationCompactAdaptation(.none)
                .presentationDetents([.height(200)])
            }
            .ignoresSafeArea(.keyboard)
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Remove categories?"),
                    message: Text("All related transactions will remain uncategorized."),
                    primaryButton: .destructive(Text("Remove")) {
                        deleteSelectedCategoriesWithSuccessSheet()
                    },
                    secondaryButton: .cancel()
                )
            }
            .ignoresSafeArea(.keyboard)
    }
    
    private func resetUIAfterCategoryDeletion() {
        // Only reset if we're not still in the loading state
        if !isProcessingDeletion {
            selectedCategories.removeAll()
            firstSelection = nil
            secondSelection = nil
            thirdSelection = nil  // If you added this
            isEditing = false
            showAnimations = [false, false, false, false]  // Or however many you have now
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            Image(systemName: "square.grid.2x2.slash")
                .font(.system(size: 48))
                .foregroundColor(Color(UIColor.systemGray4))
                .padding(.bottom, 16)
            
            Text("No categories found")
                .font(.headline)
                .foregroundColor(.gray)
            
            if !searchText.isEmpty {
                Text("Try a different search")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.systemGray))
            } else {
                Text("Add a category to get started")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.systemGray))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    struct SearchBar: View {
        @Binding var text: String
        
        var body: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search categories...", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(10)
        }
    }
    
    // First, let's create the CategorySquare component
    struct CategorySquare: View {
        let content: String
        let bgColor: Color
        let rotation: Double
        let isCounter: Bool
        let isAnimating: Bool
        
        var body: some View {
            Text(content)
                .font(.system(size: isCounter ? 14 : 16))
                .foregroundColor(.secondary)
                .frame(width: 30, height: 30)
                .background(
                    ZStack {
                        // Apply blur effect first
                        BlurView(style: .systemThinMaterial)
                            .cornerRadius(8)
                        
                        // Then overlay with semi-transparent color
                        bgColor.opacity(0.3)
                            .cornerRadius(8)
                    }
                )
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 0)
                .rotationEffect(Angle(degrees: rotation))
                .frame(width: 38, height: 38)
                .blurAnimation(isAnimating: isAnimating)
        }
    }
    
    // Next, create the SquaresGroup component
    struct SquaresGroup: View {
        let selectedItems: Set<Category>
        let firstSelection: Category?
        let secondSelection: Category?
        let thirdSelection: Category?
        let showAnimations: [Bool]
        
        private let squareFrameSize: CGFloat = 38
        private let spacing: CGFloat = -20
        
        private var totalWidth: CGFloat {
            guard !selectedItems.isEmpty else { return 0 }
            return squareFrameSize + (CGFloat(min(selectedItems.count - 1, 2)) * (squareFrameSize + spacing))
        }
        
        var body: some View {
            HStack(spacing: spacing) {
                // First selection
                if let first = firstSelection {
                    CategorySquare(
                        content: first.icon ?? "🔹",
                        bgColor: Color(UIColor.systemBackground).opacity(0.3),
                        rotation: -18,
                        isCounter: false,
                        isAnimating: showAnimations[0]
                    )
                    .offset(y: -2)
                }
                
                // Second selection
                if let second = secondSelection {
                    CategorySquare(
                        content: second.icon ?? "🔹",
                        bgColor: Color(UIColor.systemBackground).opacity(0.3),
                        rotation: 17,
                        isCounter: false,
                        isAnimating: showAnimations[1]
                    )
                    .offset(y: 2)
                }
                
                // Third selection OR counter
                if selectedItems.count >= 3 {
                    if selectedItems.count > 3 {
                        // Show counter for 4+ selections
                        CategorySquare(
                            content: "+\(selectedItems.count - 2)",
                            bgColor: Color(UIColor.systemBackground).opacity(0.3),
                            rotation: -12,
                            isCounter: true,
                            isAnimating: showAnimations[2]
                        )
                        .offset(y: 0)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: selectedItems.count)
                    } else if let third = thirdSelection {
                        // Show third emoji
                        CategorySquare(
                            content: third.icon ?? "🔹",
                            bgColor: Color(UIColor.systemBackground).opacity(0.3),
                            rotation: -12,
                            isCounter: false,
                            isAnimating: showAnimations[2]
                        )
                        .offset(y: 0)
                    }
                }
            }
            .frame(width: totalWidth, height: squareFrameSize)
        }
    }
    
    // Now update the bottomSheet in CategoryListView to use the new component
    private var bottomSheet: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    SquaresGroup(
                        selectedItems: selectedCategories,
                        firstSelection: firstSelection,
                        secondSelection: secondSelection,
                        thirdSelection: thirdSelection,
                        showAnimations: showAnimations
                    )
                    
                    Text(selectedCategories.isEmpty ? "Select categories" : "\(selectedCategories.count) selected")
                        .foregroundColor(.gray)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: selectedCategories.count)
                    
                }
                Spacer()
                
                
                Button(action: { showDeleteConfirmation = true }) {
                    Text("Remove")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(99)
                }
                .disabled(selectedCategories.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .background(
                ZStack {
                    // Add the top divider
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color(UIColor.separator))
                        Spacer()
                    }
                    
                    // Add the blur effect
                    BlurView(style: .regular)
                }
            )
        }
        .edgesIgnoringSafeArea(.bottom)
        .transition(.move(edge: .bottom))
    }
    
    
    struct BlurView: UIViewRepresentable {
        var style: UIBlurEffect.Style
        
        func makeUIView(context: Context) -> UIVisualEffectView {
            return UIVisualEffectView(effect: UIBlurEffect(style: style))
        }
        
        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
            uiView.effect = UIBlurEffect(style: style)
        }
    }
    
    private func toggleSelection(of category: Category) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
            
            // Reset appropriate selection if removed
            if category == firstSelection {
                firstSelection = nil
            } else if category == secondSelection {
                secondSelection = nil
            } else if category == thirdSelection {
                thirdSelection = nil
            }
            
        } else {
            selectedCategories.insert(category)
            
            // Set first, second, or third selection if not yet set
            if firstSelection == nil {
                firstSelection = category
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimations[0] = true
                }
            } else if secondSelection == nil {
                secondSelection = category
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimations[1] = true
                }
            } else if thirdSelection == nil {
                thirdSelection = category
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimations[2] = true
                }
            } else if selectedCategories.count > 3 {
                // Animate counter for selections beyond the third
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimations[3] = true
                }
            }
        }
    }
    
    private func deleteSelectedCategoriesWithSuccessSheet() {
        // Store the count for the success message
        deletionCount = selectedCategories.count
        isEditing = false
        // Show loading state
        isProcessingDeletion = true
        showSuccessSheet = true
        
        // Simulate a brief processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Perform the actual deletion
            for category in selectedCategories {
                CategoryManager.shared.deleteCategory(category)
            }
            
            // Update UI state
            isProcessingDeletion = false
        }
    }
}

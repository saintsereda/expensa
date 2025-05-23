//
//  TagsListView.swift
//  Expensa
//
//  Created by Andrew Sereda on 30.10.2024.
//

import Foundation
import SwiftUI
import Combine
import CoreData
import ConfettiSwiftUI

struct TagListView: View {
    @EnvironmentObject private var tagManager: TagManager
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var selectedTags = Set<Tag>()
    @State private var showDeleteConfirmation = false
    @State private var firstSelection: Tag? = nil
    @State private var secondSelection: Tag? = nil
    @State private var thirdSelection: Tag? = nil
    @State private var showAnimations = [false, false, false, false]
    
    // New states for success sheet and confetti
    @State private var showSuccessSheet = false
    @State private var isProcessingDeletion = false
    @State private var deletionCount = 0
    @State private var showConfetti = false
    @State private var confettiCounter = 0
    @State private var confettiEmoji = "#️⃣"
    @State private var isPresented = false
    @State private var selectedTagForEdit: Tag? = nil
    @State private var showNewTagSheet = false
    
    var filteredTags: [Tag] {
        if searchText.isEmpty {
            return tagManager.tags
        } else {
            return tagManager.tags.filter { tag in
                (tag.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
            ZStack {
                VStack(spacing: 0) {
                    // Search bar - always visible when there are tags in the system
                    if !tagManager.tags.isEmpty {
                        SearchBar(text: $searchText)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                    }
                    
                    // Content area
                    if filteredTags.isEmpty {
                        // Empty state
                        if searchText.isEmpty {
                            VStack(spacing: 20) {
                                ContentUnavailableView("No tags found",
                                                      systemImage: "tag.slash",
                                                      description: Text("Add a tag to get started"))
                                
                                Button(action: {
                                    showNewTagSheet = true
                                }) {
                                    Label("Add Your First Tag", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.accentColor)
                                        .cornerRadius(12)
                                }
                            }
                        } else {
                            ContentUnavailableView.search(text: searchText)
                        }
                    } else {
                        // Tag list
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredTags, id: \.self) { tag in
                                    HStack {
                                        Text("#\(tag.name ?? "unknown")")
                                            .foregroundColor(.accentColor)
                                        
                                        Spacer()
                                        
                                        if isEditing {
                                            Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(.blue)
                                                .onTapGesture {
                                                    toggleSelection(of: tag)
                                                }
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isEditing {
                                            toggleSelection(of: tag)
                                        } else {
                                            selectedTagForEdit = tag
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    
                                    if tag != filteredTags.last {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, isEditing ? 60 : 0)
                
                // Bottom edit sheet
                if isEditing {
                    VStack {
                        Spacer()
                        bottomSheet
                            .opacity(showSuccessSheet ? 0 : 1)
                            .animation(.easeOut(duration: 0.2), value: showSuccessSheet)
                    }
                }
            }
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Add button - always visible
                        Button(action: {
                            showNewTagSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                        
                        // Edit button - only visible when there are tags
                        if !filteredTags.isEmpty {
                            Button(action: {
                                isEditing.toggle()
                                if !isEditing {
                                    resetSelections()
                                }
                            }) {
                                Text(isEditing ? "Done" : "Edit")
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedTagForEdit) { tag in
                TagDetailSheet(tag: tag)
                    .presentationDetents([.medium])
                    .environmentObject(tagManager)
            }
            .sheet(isPresented: $showNewTagSheet) {
                NewTagSheet()
                    .environmentObject(tagManager)
            }
            .ignoresSafeArea(.keyboard)
            // Success sheet
            .sheet(isPresented: $showSuccessSheet, onDismiss: {
                resetSelections()
                resetUIAfterTagDeletion()
            }) {
                SuccessSheet(
                    isLoading: $isProcessingDeletion,
                    message: "\(deletionCount) \(deletionCount == 1 ? "tag" : "tags") removed",
                    loadingMessage: "Removing tags...",
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
                    title: Text("Remove tags?"),
                    message: Text("Selected tags will be removed from all expenses."),
                    primaryButton: .destructive(Text("Remove")) {
                        deleteSelectedTagsWithSuccessSheet()
                    },
                    secondaryButton: .cancel()
                )
            }
            .ignoresSafeArea(.keyboard)
    }
    
    // TagSquare Component
    struct TagSquare: View {
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
    
    // SquaresGroup Component
    struct SquaresGroup: View {
        let selectedItems: Set<Tag>
        let firstSelection: Tag?
        let secondSelection: Tag?
        let thirdSelection: Tag?
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
                if firstSelection != nil {
                    TagSquare(
                        content: "#",
                        bgColor: Color(UIColor.systemBackground).opacity(0.3),
                        rotation: -18,
                        isCounter: false,
                        isAnimating: showAnimations[0]
                    )
                    .offset(y: -2)
                }
                
                // Second selection
                if secondSelection != nil {
                    TagSquare(
                        content: "#",
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
                        TagSquare(
                            content: "+\(selectedItems.count - 2)",
                            bgColor: Color(UIColor.systemBackground).opacity(0.3),
                            rotation: -12,
                            isCounter: true,
                            isAnimating: showAnimations[2]
                        )
                        .offset(y: 0)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: selectedItems.count)
                    } else if thirdSelection != nil {
                        // Show third tag
                        TagSquare(
                            content: "#",
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
    
    private var bottomSheet: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    SquaresGroup(
                        selectedItems: selectedTags,
                        firstSelection: firstSelection,
                        secondSelection: secondSelection,
                        thirdSelection: thirdSelection,
                        showAnimations: showAnimations
                    )
                    
                    Text(selectedTags.isEmpty ? "Select tags" : "\(selectedTags.count) selected")
                        .foregroundColor(.gray)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: selectedTags.count)
                    
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
                .disabled(selectedTags.isEmpty)
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
    
    // Update the toggle selection function
    private func toggleSelection(of tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
            
            // Reset appropriate selection if removed
            if tag == firstSelection {
                firstSelection = nil
            } else if tag == secondSelection {
                secondSelection = nil
            } else if tag == thirdSelection {
                thirdSelection = nil
            }
            
        } else {
            selectedTags.insert(tag)
            
            // Set first, second, or third selection if not yet set
            if firstSelection == nil {
                firstSelection = tag
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimations[0] = true
                }
            } else if secondSelection == nil {
                secondSelection = tag
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimations[1] = true
                }
            } else if thirdSelection == nil {
                thirdSelection = tag
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimations[2] = true
                }
            } else if selectedTags.count > 3 {
                // Animate counter for selections beyond the third
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAnimations[3] = true
                }
            }
        }
    }
    
    // Reset selections
    private func resetSelections() {
        selectedTags.removeAll()
        firstSelection = nil
        secondSelection = nil
        thirdSelection = nil
        showAnimations = [false, false, false, false]
    }
    
    // Reset UI after tag deletion
    private func resetUIAfterTagDeletion() {
        // Only reset if we're not still in the loading state
        if !isProcessingDeletion {
            resetSelections()
            isEditing = false
        }
    }
    
    // Delete with success sheet
    private func deleteSelectedTagsWithSuccessSheet() {
        // Store the count for the success message
        deletionCount = selectedTags.count
        isEditing = false
        // Show loading state
        isProcessingDeletion = true
        showSuccessSheet = true
        
        // Simulate a brief processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Perform the actual deletion
            for tag in selectedTags {
                tagManager.deleteTag(tag)
            }
            
            // Update UI state
            isProcessingDeletion = false
        }
    }
}

struct SearchBar: View {
   @Binding var text: String
   
   var body: some View {
       HStack {
           Image(systemName: "magnifyingglass")
               .foregroundColor(.gray)
           
           TextField("Search", text: $text)
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

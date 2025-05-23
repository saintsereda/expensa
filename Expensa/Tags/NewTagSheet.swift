//
//  NewTagSheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 23.05.2025.
//

import SwiftUI
import HighlightedTextEditor
import CoreData
import UIKit

struct NewTagSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var tagManager: TagManager
    @State private var tagInput: String = ""
    @FocusState private var isFocused: Bool
    
    // Store a reference to the UITextView for direct manipulation
    @State private var textView: UITextView?
    
    // Regex pattern for highlighting hashtags in the editor
    private static let hashtagPattern = try! NSRegularExpression(pattern: "#\\w+", options: [])
    
    // Complete hashtag extraction pattern for saving
    private static let completeTagPattern = try! NSRegularExpression(
        pattern: "#(\\w+)(?=\\s|[.,;:!?)]|$)",
        options: []
    )
    
    // Highlighting rules
    private let highlightRules: [HighlightRule] = [
        HighlightRule(
            pattern: NewTagSheet.hashtagPattern,
            formattingRules: [
                TextFormattingRule(key: .foregroundColor, value: UIColor.systemBlue)
            ]
        )
    ]
    
    // Callback to get access to the text view
    private var introspectCallback: IntrospectCallback {
        return { editor in
            self.textView = editor.textView
        }
    }
    
    // Extract and create tags from input text
    private func extractAndCreateTags() {
        let text = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = NewTagSheet.completeTagPattern.matches(in: text, options: [], range: range)
        
        var createdTags: [String] = []
        
        // Process each hashtag match
        for match in matches {
            if match.numberOfRanges >= 2,
               let tagNameRange = Range(match.range(at: 1), in: text) {
                
                let tagName = String(text[tagNameRange]).lowercased()
                
                // Skip empty tags
                guard !tagName.isEmpty else { continue }
                
                // Check if tag already exists
                if tagManager.findTag(name: tagName) == nil {
                    // Create new tag
                    if let _ = tagManager.createTag(name: tagName) {
                        createdTags.append(tagName)
                    }
                }
            }
        }
        
        // Reload tags to reflect changes
        tagManager.fetchAllTags()
        
        // Show feedback if tags were created
        if !createdTags.isEmpty {
            HapticFeedback.play()
        }
    }
    
    private func insertHashtagPrefix() {
        let hashtagText = "#"
        
        if let textView = textView {
            // Get the current cursor position
            let currentPosition = textView.selectedRange
            
            // If there's a valid cursor position
            if currentPosition.location != NSNotFound {
                // Create an NSString from our current text
                let nsString = tagInput as NSString
                
                // Insert the hashtag at the cursor position
                let newText = nsString.replacingCharacters(in: currentPosition, with: hashtagText)
                tagInput = newText
                
                // Calculate new cursor position
                let newPosition = currentPosition.location + hashtagText.count
                
                // Wait a tiny bit for the text view to update before setting cursor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    textView.selectedRange = NSRange(location: newPosition, length: 0)
                    textView.becomeFirstResponder()
                }
            } else {
                // Fallback: append to the end
                tagInput = tagInput + hashtagText
                
                // Set cursor to the end
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let endPosition = tagInput.count
                    textView.selectedRange = NSRange(location: endPosition, length: 0)
                    textView.becomeFirstResponder()
                }
            }
        } else {
            // Fallback if textView reference isn't available
            tagInput = tagInput + hashtagText
            isFocused = true
        }
        
        // Add haptic feedback
        HapticFeedback.play()
    }
    
    private var hasValidTags: Bool {
        let text = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = NewTagSheet.completeTagPattern.matches(in: text, options: [], range: range)
        
        return !matches.isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text("Type hashtags separated by spaces")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text("Example: #food #restaurant #dinner")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Text input area
                VStack(spacing: 0) {
                    HStack {
                        Text("Tags:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: insertHashtagPrefix) {
                            Image(systemName: "number")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Highlighted text editor
                    HighlightedTextEditor(text: $tagInput, highlightRules: highlightRules)
                        .introspect(callback: introspectCallback)
                        .focused($isFocused)
                        .padding(.horizontal)
                        .frame(minHeight: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                .padding(.horizontal)
                        )
                }
                .padding(.bottom, 20)
                
                Spacer()
                
                // Example tags section
                if !tagManager.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Existing tags:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(tagManager.tags.prefix(10)), id: \.self) { tag in
                                    Text("#\(tag.name ?? "unknown")")
                                        .font(.system(size: 14))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(uiColor: .systemGray5))
                                        .foregroundColor(.secondary)
                                        .cornerRadius(999)
                                }
                                
                                if tagManager.tags.count > 10 {
                                    Text("+\(tagManager.tags.count - 10) more")
                                        .font(.system(size: 14))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(uiColor: .systemGray6))
                                        .foregroundColor(.secondary)
                                        .cornerRadius(999)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Add Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        extractAndCreateTags()
                        dismiss()
                    }
                    .disabled(!hasValidTags)
                }
            }
            .onAppear {
                // Focus the text editor with a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
        .presentationCornerRadius(32)
    }
}

#Preview {
    NewTagSheet()
        .environmentObject(TagManager.shared)
}

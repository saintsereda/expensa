import SwiftUI
import HighlightedTextEditor
import CoreData
import UIKit

struct NotesModalView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var tagManager: TagManager
    @Binding var notes: String
    @Binding var tempTags: Set<Tag>
    @State private var tempNotes: String
    @FocusState private var isFocused: Bool
    
    // Store a reference to the UITextView for direct manipulation
    @State private var textView: UITextView?
    
    // Regex pattern for highlighting hashtags in the editor
    private static let hashtagPattern = try! NSRegularExpression(pattern: "#\\w+", options: [])
    
    // Complete hashtag extraction pattern for when saving
    private static let completeTagPattern = try! NSRegularExpression(
        pattern: "#(\\w+)(?=\\s|[.,;:!?)]|$)",
        options: []
    )
    
    // Highlighting rules
    private let highlightRules: [HighlightRule] = [
        HighlightRule(
            pattern: NotesModalView.hashtagPattern,
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
    
    init(notes: Binding<String>, tempTags: Binding<Set<Tag>>) {
        self._notes = notes
        self._tempTags = tempTags
        self._tempNotes = State(initialValue: notes.wrappedValue)
    }
    
    // Extract tags only when saving
    private func extractFinalTags() {
        let text = tempNotes
        let range = NSRange(location: 0, length: text.utf16.count)
        
        // Use the complete tag pattern to find only properly formed hashtags
        let matches = NotesModalView.completeTagPattern.matches(in: text, options: [], range: range)
        
        // Clear existing temp tags
        tempTags.removeAll()
        
        // Process each match
        for match in matches {
            // The first capture group contains just the tag name without the #
            if match.numberOfRanges >= 2,
               let tagNameRange = Range(match.range(at: 1), in: text) {
                
                let tagName = String(text[tagNameRange])
                
                // Skip empty tags
                guard !tagName.isEmpty else { continue }
                
                // Try to find existing tag first
                if let existingTag = tagManager.findTag(name: tagName) {
                    tempTags.insert(existingTag)
                } else {
                    // Create temporary tag without saving to CoreData
                    let tempTag = tagManager.createTemporaryTag(name: tagName)
                    tempTags.insert(tempTag)
                }
            }
        }
    }
    
    private func insertTag(_ tag: Tag) {
        guard let tagName = tag.name else { return }
        let tagText = "#\(tagName) "
        
        if let textView = textView {
            // Get the current cursor position
            let currentPosition = textView.selectedRange
            
            // If there's a valid cursor position
            if currentPosition.location != NSNotFound {
                // Create an NSString from our current text
                let nsString = tempNotes as NSString
                
                // Insert the tag at the cursor position
                let newText = nsString.replacingCharacters(in: currentPosition, with: tagText)
                tempNotes = newText
                
                // Calculate new cursor position
                let newPosition = currentPosition.location + tagText.count
                
                // Important: Wait a tiny bit for the text view to update before setting cursor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // Set the cursor position after the inserted tag
                    textView.selectedRange = NSRange(location: newPosition, length: 0)
                    
                    // Make sure textView has focus
                    textView.becomeFirstResponder()
                }
            } else {
                // Fallback: append to the end
                tempNotes = tempNotes + tagText
                
                // Set cursor to the end
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let endPosition = tempNotes.count
                    textView.selectedRange = NSRange(location: endPosition, length: 0)
                    textView.becomeFirstResponder()
                }
            }
        } else {
            // Fallback if textView reference isn't available
            tempNotes = tempNotes + tagText
            isFocused = true
        }
        
        // Add haptic feedback
        HapticFeedback.play()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Use HighlightedTextEditor with the introspect callback
                HighlightedTextEditor(text: $tempNotes, highlightRules: highlightRules)
                    .introspect(callback: introspectCallback)
                    .focused($isFocused)
                    .padding()
                
                // Bottom tag selection section
                VStack(spacing: 0) {
                    Divider()
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tagManager.tags, id: \.self) { tag in
                                TagChip(tag: tag, isSelected: tempTags.contains(tag))
                                    .onTapGesture {
                                        insertTag(tag)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(
                        VStack(spacing: 0) {
                            Divider()
                            Spacer()
                        }
                    )
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Only extract tags when saving
                        extractFinalTags()
                        notes = tempNotes
                        HapticFeedback.play()
                        dismiss()
                    }
                }
            }
            .foregroundColor(.primary)
            .onAppear {
                // Focus the text editor with a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }
}

// Tag chip component
struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    
    var body: some View {
        Text("#\(tag.name ?? "unknown")")
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(uiColor: .systemGray5))
            .foregroundColor(.secondary)
            .cornerRadius(999)
    }
}

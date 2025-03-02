import SwiftUI
import HighlightedTextEditor
import CoreData

struct NotesModalView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var tagManager: TagManager
    @Binding var notes: String
    @Binding var tempTags: Set<Tag>  // Add this binding
    @State private var tempNotes: String
    @FocusState private var isFocused: Bool
    
    // Regular expression to match hashtags
    private let hashtagPattern = try! NSRegularExpression(pattern: "#\\w+", options: [])
    
    // Highlighting rule for hashtags
    private var highlightRules: [HighlightRule] {
        [
            HighlightRule(
                pattern: hashtagPattern,
                formattingRules: [
                    TextFormattingRule(key: .foregroundColor, value: UIColor.systemBlue)
                ]
            )
        ]
    }
    
    init(notes: Binding<String>, tempTags: Binding<Set<Tag>>) {
        self._notes = notes
        self._tempTags = tempTags
        self._tempNotes = State(initialValue: notes.wrappedValue)
    }
    
    private func extractTempTags() {
        // Extract all hashtags from the text
        let range = NSRange(location: 0, length: tempNotes.utf16.count)
        let matches = hashtagPattern.matches(in: tempNotes, options: [], range: range)
        
        // Clear existing temp tags
        tempTags.removeAll()
        
        // Create temporary tags
        for match in matches {
            if let range = Range(match.range, in: tempNotes) {
                let tagText = String(tempNotes[range])
                let tagName = String(tagText.dropFirst()) // Remove # from the beginning
                
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
        // Insert tag at cursor position or end of text
        guard let tagName = tag.name else { return }
        let tagText = "#\(tagName) "
        
        // Add the tag to the text
        tempNotes.append(tagText)
        
        // Add to temp tags
        if !tempTags.contains(tag) {
            tempTags.insert(tag)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Text editor
                HighlightedTextEditor(text: $tempNotes, highlightRules: highlightRules)
                    .focused($isFocused)
                    .padding()
                
                // Bottom tag scroll section
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
                        ZStack {
                            // Add the top divider
                            VStack(spacing: 0) {
                                Divider()
                                
                                Spacer()
                            }
//                            
//                            // Add the blur effect
//                            BlurView(style: .regular)
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
                        notes = tempNotes
                        extractTempTags()
                        dismiss()
                    }
                }
            }
            .foregroundColor(.primary)
        }
        .onAppear {
            isFocused = true
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

// BlurView from TagListView
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

//
//  TagSheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 24.02.2025.
//

import Foundation
import SwiftUI
import CoreData

struct TagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tagManager: TagManager
    @Binding var selectedTags: Set<Tag>
    @State private var tempSelection: Set<Tag> = []
    @State private var searchText = ""
    
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
        NavigationView {
            VStack {
                if tagManager.tags.isEmpty {
                    // Empty state view
                    VStack {
                        Spacer()
                        
                        Image(systemName: "tag.slash")
                            .font(.system(size: 48))
                            .foregroundColor(Color(UIColor.systemGray4))
                            .padding(.bottom, 16)
                        
                        Text("No tags found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Add a tag to an expense first")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.systemGray))
                        
                        Spacer()
                    }
                } else {
                    // Search bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    // Tag list
                    List(filteredTags, id: \.self) { tag in
                        HStack {
                            Text("#\(tag.name ?? "unknown")")
                                .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            if tempSelection.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempSelection.contains(tag) {
                                tempSelection.remove(tag)
                            } else {
                                tempSelection.insert(tag)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedTags = tempSelection
                        dismiss()
                    }
                }
            }
            .onAppear {
                tempSelection = selectedTags
            }
        }
        .presentationCornerRadius(32)
        .environmentObject(TagManager.shared)
    }
}

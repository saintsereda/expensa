//
//  ExportSheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 14.02.2025.
//

import Foundation
import SwiftUI
import CoreData

struct CategorySquare: View {
    let content: String
    let bgColor: Color
    let rotation: Double
    let isCounter: Bool
    
    var body: some View {
        Text(content)
            .font(.system(size: isCounter ? 14 : 16))
            .foregroundColor(.primary)
            .frame(width: 30, height: 30)
            .background(bgColor)
            .cornerRadius(8)
            .rotationEffect(Angle(degrees: rotation))
            .frame(width: 38, height: 38)
    }
}

struct SquaresGroup: View {
    let selectedCategories: Set<Category>
    
    private let squareFrameSize: CGFloat = 38
    private let spacing: CGFloat = -20
    
    // Subtle background colors
    private let bgColors: [Color] = [
        Color(red: 0.95, green: 0.88, blue: 0.88), // Soft pink
        Color(red: 0.88, green: 0.95, blue: 0.88), // Soft green
        Color(red: 0.88, green: 0.88, blue: 0.95), // Soft blue
        Color(red: 0.95, green: 0.95, blue: 0.88), // Soft yellow
        Color(red: 0.95, green: 0.88, blue: 0.95), // Soft purple
        Color(red: 0.88, green: 0.95, blue: 0.95), // Soft cyan
        Color(red: 0.92, green: 0.90, blue: 0.87), // Soft beige
        Color(red: 0.90, green: 0.87, blue: 0.92), // Soft lavender
        Color(red: 0.87, green: 0.92, blue: 0.90)  // Soft mint
    ]
    
    private func getColorForCategory(_ category: Category) -> Color {
        // Use category's UUID or name hash to consistently assign a color
        let hash = (category.id?.uuidString ?? category.name ?? "").hashValue
        let index = abs(hash) % bgColors.count
        return bgColors[index]
    }
    
    private var totalWidth: CGFloat {
        guard !selectedCategories.isEmpty else { return 0 }
        return squareFrameSize + (CGFloat(min(selectedCategories.count - 1, 2)) * (squareFrameSize + spacing))
    }
    
    private var thirdSquareContent: String {
        if selectedCategories.count > 3 {
            return "+\(selectedCategories.count - 2)"
        } else if let thirdCategory = Array(selectedCategories)[safe: 2] {
            return thirdCategory.icon ?? "🔹"
        }
        return ""
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            if let first = Array(selectedCategories).first {
                CategorySquare(
                    content: first.icon ?? "🔹",
                    bgColor: getColorForCategory(first),
                    rotation: -18.38,
                    isCounter: false
                )
            }
            
            if selectedCategories.count > 1,
               let second = Array(selectedCategories)[safe: 1] {
                CategorySquare(
                    content: second.icon ?? "🔹",
                    bgColor: getColorForCategory(second),
                    rotation: 17.12,
                    isCounter: false
                )
            }
            
            if selectedCategories.count > 2 {
                if selectedCategories.count > 3 {
                    // Counter square
                    CategorySquare(
                        content: thirdSquareContent,
                        bgColor: Color(uiColor: .systemGray5),
                        rotation: -12.54,
                        isCounter: true
                    )
                } else if let third = Array(selectedCategories)[safe: 2] {
                    // Third category square
                    CategorySquare(
                        content: third.icon ?? "🔹",
                        bgColor: getColorForCategory(third),
                        rotation: -12.54,
                        isCounter: false
                    )
                }
            }
        }
        .frame(width: totalWidth, height: squareFrameSize)
    }
}

struct SelectedCategoriesView: View {
    let selectedCategories: Set<Category>
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("\(selectedCategories.count)")
                    .foregroundColor(.gray)
                    .fixedSize()
                
                Text(" selected")
                    .foregroundColor(.gray)
                    .fixedSize()
            }
            .lineLimit(1)
            
            Spacer()
                .frame(width: 8)
            
            SquaresGroup(selectedCategories: selectedCategories)
                .frame(maxHeight: .infinity)
            
            Spacer()
                .frame(width: 8)
        }
    }
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedCategories: Set<Category>
    @State private var showingCategorySelection = false
    @State private var isLoading = false
    let categories: [Category]
    
    init(categories: [Category]) {
        self.categories = categories
        _selectedCategories = State(initialValue: Set(categories))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // White background
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Extra space after navigation title
                 //   Color.clear.frame(height: 16)
                    
                    // Dropdowns section
                    VStack(spacing: 8) { // Added 8px spacing between rows
                        // Categories Menu
                        Button {
                            showingCategorySelection = true
                        } label: {
                            HStack {
                                Text("Categories")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedCategories.isEmpty || selectedCategories.count == categories.count {
                                    Text("All categories")
                                        .foregroundColor(.gray)
                                } else {
                                    SelectedCategoriesView(selectedCategories: selectedCategories)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(16)
                        }
                        
                        // Time Period Menu (disabled)
                        HStack {
                            Text("Time Period")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("Soon")
                                .foregroundColor(.gray)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(uiColor: .tertiaryLabel))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(16)
                        .opacity(0.5)
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Export button section
                    VStack(spacing: 0) {
                        Button(action: {
                            isLoading = true
                            
                            // Start the export process
                            exportData(context: viewContext, categories: Array(selectedCategories)) { success in
                                // Update loading state on the main thread
                                DispatchQueue.main.async {
                                    isLoading = false
                                    if success {
                                        // First dismiss this sheet
                                        dismiss()
                                        
                                        // After dismissal, present the share sheet
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                            presentShareSheetAfterDismissal()
                                        }
                                    }
                                }
                            }
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(999)
                            } else {
                                Text("Export")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(selectedCategories.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                                    .cornerRadius(999)
                            }
                        }
                        .disabled(selectedCategories.isEmpty || isLoading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .padding(.bottom, 24) // Additional bottom padding to make total 40px
                    }
                }
            }
            .navigationTitle("Export data")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .sheet(isPresented: $showingCategorySelection) {
            DataCategorySelection(
                selectedCategories: $selectedCategories,
                categories: categories
            )
        }
    }
    
    private var categorySelectionText: String {
        if selectedCategories.isEmpty {
            return "All categories"
        } else if selectedCategories.count == categories.count {
            return "All categories"
        } else if selectedCategories.count == 1 {
            return selectedCategories.first?.name ?? "1 category"
        } else {
            return "\(selectedCategories.count) categories"
        }
    }
}

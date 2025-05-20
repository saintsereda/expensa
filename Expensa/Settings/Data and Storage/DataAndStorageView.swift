//
//  DataAndStorageView.swift - Updated with ImportSheet
//  Expensa
//
//  Created by Andrew Sereda on 02.11.2024.
//  Updated on 16.05.2025.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ImportResult {
    var success: Bool
    var message: String
    var count: Int
    
    // Default initializer with empty state
    static func empty() -> ImportResult {
        return ImportResult(success: true, message: "", count: 0)
    }
}

struct DataAndStorageView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingCategorySelection = false
    @State private var showingExportSheet = false
    @State private var selectedCategories: Set<Category> = []
    
    @State private var showingEraseActionMenu = false
    @State private var showingSuccessSheet = false
    @State private var showingImportSuccessSheet = false
    @State private var showingExportSuccess = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showingImportSheet = false  // New state for Import Sheet
    @State private var isErasing = false
    @State private var importResult = ImportResult(success: true, message: "", count: 0)
    
    // Add this computed property inside DataAndStorageView
    private var categories: [Category] {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.bottom, 8)
                        
                        Text("Data management")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Manage your app data and storage settings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 20)
                    
                    // Actions Card
                    VStack(spacing: 20) {
                        // Export Data Button
                        Button(action: {
                            showingExportSheet = true  // Add this state variable
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    if isExporting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 20))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Export data")
                                        .font(.headline)
                                    
                                    Text(isExporting ? "Generating CSV file..." : "Export selected categories as CSV")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if !isExporting {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(ActionButtonStyle())
                        .disabled(isExporting)
                        .sheet(isPresented: $showingExportSheet) {
                            ExportSheet(categories: Array(categories))
                                .presentationDetents([.height(280)]) // Set your desired height
                                .presentationBackground(.clear) // Important: use clear background
                        }
                        
                        // Import Data Button - Updated to show ImportSheet
                        Button(action: {
                            showingImportSheet = true // Show the new import sheet instead
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Import data")
                                        .font(.headline)
                                    
                                    Text("Load CSV file to restore data")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(ActionButtonStyle())
                        .sheet(isPresented: $showingImportSheet) {
                            ImportSheet()
                        }
                        
                        Divider()
                            .padding(.horizontal, -20)
                        
                        // Erase Data Button
                        Button(action: { showingEraseActionMenu = true }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    if isErasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .tint(.red)
                                    } else {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Erase all data")
                                        .font(.headline)
                                    
                                    Text(isErasing ? "Erasing data..." : "Permanently delete all data")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if !isErasing {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(ActionButtonStyle())
                        .disabled(isErasing)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        InfoRow(
                            icon: "exclamationmark.triangle.fill",
                            text: "Erasing data cannot be undone",
                            color: .orange
                        )
                        
                        InfoRow(
                            icon: "arrow.up.doc.fill",
                            text: "Export your data before erasing",
                            color: .accentColor
                        )
                    }
                    .padding(.horizontal, 36)
                }
                .padding(.bottom, 32)
            }
            
            // No separate loading overlay needed since we're
            // now using the loading state in the success sheet
        }
        .confirmationDialog(
            "Erase all data",
            isPresented: $showingEraseActionMenu,
            titleVisibility: .visible
        ) {
            Button("Erase all data", role: .destructive) {
                isErasing = true
                showingSuccessSheet = true
                eraseAllData(context: viewContext) { success in
                    isErasing = false
                }
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action will delete all expenses, categories, budgets, and recurring expenses. This cannot be undone.")
        }
        .sheet(isPresented: $showingSuccessSheet) {
            SuccessSheet(
                isLoading: $isErasing,
                message: "Your action was completed successfully.",
                loadingMessage: "Processing...",
                iconName: "checkmark.circle.fill",
                isError: false
            )
            .presentationBackground(.clear)
            .presentationBackgroundInteraction(.enabled)
            .presentationCompactAdaptation(.none)
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showingImportSuccessSheet) {
            SuccessSheet(
                isLoading: Binding<Bool>(
                    get: { importResult.message.isEmpty },
                    set: { _ in }
                ),
                message: importResult.message,
                loadingMessage: "Importing data...",
                iconName: "square.and.arrow.down.fill",
                isError: !importResult.success
            )
            .presentationBackground(.clear)
            .presentationBackgroundInteraction(.enabled)
            .presentationCompactAdaptation(.none)
            .presentationDetents([.height(200)])
        }
    }
    
    private func exportDataWithLoading() async {
        // Simulate export delay and show loading state
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay for demo
            await MainActor.run {
                exportData(context: viewContext, categories: Array(selectedCategories))
                isExporting = false
                withAnimation {
                    showingExportSuccess = true
                }
            }
        } catch {
            await MainActor.run {
                isExporting = false
            }
        }
    }
}

// MARK: - Supporting Views

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16, weight: .semibold))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// Wrapper for UIDocumentPickerViewController
struct DocumentPickerView: UIViewControllerRepresentable {
    var onFilePicked: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFilePicked: onFilePicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText], asCopy: true)
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onFilePicked: (URL?) -> Void

        init(onFilePicked: @escaping (URL?) -> Void) {
            self.onFilePicked = onFilePicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFilePicked(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFilePicked(nil)
        }
    }
}

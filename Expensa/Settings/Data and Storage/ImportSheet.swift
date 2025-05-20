//
//  ImportSheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.05.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var isGeneratingTemplate = false
    @State private var showingImportSuccessSheet = false
    @State private var showTemplateSaveError = false
    @State private var importResult = ImportResult.empty()
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            ZStack {
                // White background
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "tablecells")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 24)
                    
                    // Title and Description
                    VStack(spacing: 8) {
                        Text("Import Data from CSV")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Expensa supports importing expenses from CSV files. Use our template for the best results.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // CSV Format Information
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CSV Format Requirements:")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        FormatRequirementRow(text: "Date (YYYY-MM-DD)")
                        FormatRequirementRow(text: "Category name")
                        FormatRequirementRow(text: "Amount (numeric)")
                        FormatRequirementRow(text: "Currency code (e.g., USD)")
                        FormatRequirementRow(text: "Notes (optional)")
                        FormatRequirementRow(text: "Tags (optional, separated by ;)")
                        
                        Text("*Your CSV file must include a header row with these column names.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            isGeneratingTemplate = true
                            generateAndShareTemplate()
                        }) {
                            HStack {
                                if isGeneratingTemplate {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .tint(.blue)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                }
                                Text("Get Template")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isGeneratingTemplate)
                        
                        Button(action: {
                            isImporting = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Import Data")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isGeneratingTemplate)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isImporting) {
                DocumentPickerView { url in
                    if let url = url {
                        // Show loading sheet
                        isImporting = false
                        showingImportSuccessSheet = true
                        
                        // Import data with completion handler
                        importData(from: url, context: viewContext) { success, count in
                            if success {
                                importResult = ImportResult(
                                    success: true,
                                    message: "\(count) expenses imported successfully",
                                    count: count
                                )
                            } else {
                                importResult = ImportResult(
                                    success: false,
                                    message: "Failed to import data. Please check the file format.",
                                    count: 0
                                )
                            }
                        }
                    }
                }
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func generateAndShareTemplate() {
        // Create template CSV content
        let templateContent = """
        Date,Category,Amount,Currency,Note,Tags
        2025-05-16,Groceries,55.50,USD,Weekly shopping,Food;Essential
        """
        
        // Get the document directory - more reliable than temp directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Could not access documents directory")
            self.isGeneratingTemplate = false
            self.showTemplateSaveError = true
            return
        }
        
        // Create a file path
        let fileName = "Expensa_Template.csv"
        let path = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            // Write to the file
            try templateContent.write(to: path, atomically: true, encoding: .utf8)
            
            // Verify file exists
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: path.path) {
                // Use a small delay to ensure UI has updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.shareFile(url: path)
                }
            } else {
                print("Error: Template file was not created properly")
                self.isGeneratingTemplate = false
                self.showTemplateSaveError = true
            }
        } catch {
            print("Error creating template file: \(error)")
            self.isGeneratingTemplate = false
            self.showTemplateSaveError = true
        }
    }
    
    // Function to share a file using UIActivityViewController
    private func shareFile(url: URL) {
        // Verify file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            print("File does not exist at path: \(url.path)")
            self.isGeneratingTemplate = false
            self.showTemplateSaveError = true
            return
        }
        
        // Get UIApplication key window
        guard let keyWindow = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
            print("No key window found")
            self.isGeneratingTemplate = false
            return
        }
        
        // Store current state for closure
        let updateLoadingState = {
            DispatchQueue.main.async {
                self.isGeneratingTemplate = false
            }
        }
        
        // Use UIActivityViewController for sharing
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Add completion handler to reset button state
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            updateLoadingState()
        }
        
        // Handle iPad presentation
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = keyWindow
            popoverController.sourceRect = CGRect(
                x: keyWindow.bounds.midX,
                y: keyWindow.bounds.midY,
                width: 0, height: 0
            )
            popoverController.permittedArrowDirections = []
        }
        
        // Find the top-most view controller
        var topController = keyWindow.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        // Present the share sheet
        topController?.present(activityVC, animated: true) {
            // If presentation was successful, we'll let the completion handler reset the state
            // But if something goes wrong, we need to reset the state here as a fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                updateLoadingState()
            }
        }
    }
}

struct FormatRequirementRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

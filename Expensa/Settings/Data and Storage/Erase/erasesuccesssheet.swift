//
//  SuccessSheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 25.02.2025.
//

import SwiftUI

struct SuccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isLoading: Bool
    let message: String
    let loadingMessage: String
    let iconName: String
    let isError: Bool
    
    // Animation states
    @State private var progress: CGFloat = 0
    @State private var shouldDismiss: Bool = false
    
    init(
        isLoading: Binding<Bool>,
        message: String,
        loadingMessage: String = "Processing...",
        iconName: String = "checkmark.circle.fill",
        isError: Bool = false
    ) {
        self._isLoading = isLoading
        self.message = message
        self.loadingMessage = loadingMessage
        self.iconName = iconName
        self.isError = isError
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clear background
                Color.clear
                
                // Sheet content
                VStack (alignment: .leading) {
                    // The actual sheet with 8px padding on all sides
                    SuccessSheetContent()
                        .frame(width: max(geometry.size.width - 16, 10), height: 200) // Reduced height from 280 to 200
                        .background(
                            RoundedRectangle(cornerRadius: 52)
                                .fill(Color(UIColor.systemBackground))
                        )
                        .padding(.horizontal, 8) // Side padding
                        .padding(.bottom, 8)     // Bottom padding
                }
                .transition(.move(edge: .bottom))
                .edgesIgnoringSafeArea(.all)
            }
        }
        .interactiveDismissDisabled(isLoading) // Prevent dismissal while loading
        .onChange(of: shouldDismiss) {_, newValue in
            if newValue {
                dismiss()
            }
        }
        .onAppear {
            // Start animation when not in loading state and sheet appears
            if !isLoading {
                startProgressAnimation()
            }
        }
        .onChange(of: isLoading) {_, newValue in
            // When loading completes, start the progress animation
            if !newValue {
                startProgressAnimation()
            }
        }
    }
    
    private func startProgressAnimation() {
        // Reset progress
        progress = 0
        
        // Animate progress to 100% over 2 seconds
        withAnimation(.linear(duration: 2.0)) {
            progress = 1.0
        }
        
        // Schedule dismissal after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.shouldDismiss = true
        }
    }
    
    // Content of the success sheet
    @ViewBuilder
    private func SuccessSheetContent() -> some View {
        VStack(spacing: 0) {
            // Progress loader (replaces drag indicator)
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2.5)
                    .frame(width: 40, height: 5)
                    .foregroundColor(.gray.opacity(0.3))
                
                // Animated progress bar
                RoundedRectangle(cornerRadius: 2.5)
                    .frame(width: 40 * progress, height: 5)
                    .foregroundColor(isError ? .red : .primary)
            }
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Icon and message - with precise padding control
            VStack(spacing: 24) {
                if isLoading {
                    // Loading state
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(2.0)
                    
                    Text(loadingMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .foregroundColor(.primary)
                } else {
                    // Success or error state
                    Image(systemName: isError ? "xmark.circle.fill" : iconName)
                        .font(.system(size: 36)) // Increased size from 24 to 36
                        .foregroundColor(isError ? .red : .green)
                    
                    Text(message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 20) // Explicit top padding
            .padding(.bottom, 20) // Explicit bottom padding
            .animation(.easeInOut, value: isLoading)
        }
    }
}

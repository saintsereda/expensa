//
//  ImportFromApplePaySheet.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.05.2025.
//

import SwiftUI

struct ImportFromApplePaySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // White background
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Icon
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "apple.logo")
                                .font(.system(size: 36))
                                .foregroundColor(.black)
                        }
                        .padding(.top, 24)
                        
                        // Title and Description
                        VStack(spacing: 8) {
                            Text("Import from Apple Pay")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Automatically import your Apple Wallet transactions using the Shortcuts app.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        // Setup Instructions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Setup Instructions")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            SetupStepRow(
                                number: "1",
                                title: "Open Apple Shortcuts app",
                                description: "Go to the \"Automation\" tab and tap the \"+\" button"
                            )
                            
                            SetupStepRow(
                                number: "2",
                                title: "Create transaction trigger",
                                description: "Select \"Transaction\" and set up \"When I tap\" a card"
                            )
                            
                            SetupStepRow(
                                number: "3",
                                title: "Create blank automation",
                                description: "Tap \"Next\" and select \"New Blank Automation\""
                            )
                            
                            SetupStepRow(
                                number: "4",
                                title: "Add \"Import transaction\" action",
                                description: "Select this action from Expensa app"
                            )
                            
                            SetupStepRow(
                                number: "5",
                                title: "Configure transaction details",
                                description: "Add \"Shortcut Input\" → \"Amount\" to the Amount field"
                            )
                            
                            SetupStepRow(
                                number: "6",
                                title: "Add merchant info (optional)",
                                description: "Add \"Shortcut Input\" → \"Merchant\" to the Notes field"
                            )
                            
                            SetupStepRow(
                                number: "7",
                                title: "Complete setup",
                                description: "Tap \"Done\" to save your automation"
                            )
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        // Benefits Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Benefits")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            BenefitRow(
                                icon: "clock.fill",
                                title: "Save Time",
                                description: "Add transactions as you pay with your cards"
                            )
                            
                            BenefitRow(
                                icon: "checkmark.circle.fill",
                                title: "Ensure Accuracy",
                                description: "Exact amounts are imported automatically"
                            )
                            
                            BenefitRow(
                                icon: "lock.fill",
                                title: "Secure & Private",
                                description: "Uses Apple's secure Shortcuts system"
                            )
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        // Visual Guide
                        VStack(spacing: 12) {
                            Text("Visual Guide")
                                .font(.headline)
                            
                            HStack(spacing: 16) {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "creditcard")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "app.connected.to.app.below.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "dollarsign.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.vertical, 16)
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        // Support section
                        VStack(spacing: 8) {
                            Text("Still have questions?")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("We're here to help — get in touch and we'll get back to you shortly.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 16)
                        
                        Spacer()
                        
                        // Action button
                        Button(action: {
                            if let shortcutsURL = URL(string: "shortcuts://") {
                                UIApplication.shared.open(shortcutsURL)
                            }
                        }) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                Text("Open Shortcuts App")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
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
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct SetupStepRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 28, height: 28)
                
                Text(number)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ImportFromApplePaySheet_Previews: PreviewProvider {
    static var previews: some View {
        ImportFromApplePaySheet()
    }
}

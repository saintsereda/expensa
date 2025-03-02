//
//  SecurityPageView.swift
//  Expensa
//
//  Created by Andrew Sereda on 03.11.2024.
//

import SwiftUI

struct SecurityPageView: View {
    @State private var showingPasscodeSetup = false
    @State private var showingPasscodeManagement = false
    @State private var isPasscodeSet = KeychainHelper.shared.getPasscode() != nil
    @State private var useFaceID = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "lock.shield.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(spacing: 8) {
                            Text("App Security")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Keep your data secure with a passcode and Face ID")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Security Status Card
                    VStack(spacing: 20) {
                        SecurityStatusRow(
                            title: "Passcode",
                            icon: "lock.circle.fill",
                            isEnabled: isPasscodeSet,
                            action: {
                                if isPasscodeSet {
                                    showingPasscodeManagement = true
                                } else {
                                    showingPasscodeSetup = true
                                }
                            }
                        )
                        
                        if isPasscodeSet {
                            Divider()
                            
                            SecurityStatusRow(
                                title: "Face ID",
                                icon: "faceid",
                                isEnabled: useFaceID,
                                action: {
                                    // Toggle Face ID
                                    useFaceID.toggle()
                                }
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                    
                    // Main Action Button
//                    if !isPasscodeSet {
//                        Button(action: {
//                            showingPasscodeSetup = true
//                        }) {
//                            HStack {
//                                Image(systemName: "lock.fill")
//                                Text("Set Up Passcode")
//                            }
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .frame(height: 56)
//                            .background(
//                                RoundedRectangle(cornerRadius: 16)
//                                    .fill(Color.accentColor)
//                            )
//                        }
//                        .padding(.horizontal)
//                        .padding(.top, 16)
//                    }
                    
                    // Security Info
                    if isPasscodeSet {
                        VStack(alignment: .leading, spacing: 12) {
                            SecurityInfoRow(
                                icon: "checkmark.shield.fill",
                                text: "Your data is encrypted",
                                color: .green
                            )
                            SecurityInfoRow(
                                icon: "key.fill",
                                text: "Change passcode anytime",
                                color: .orange
                            )
                            SecurityInfoRow(
                                icon: "faceid",
                                text: "Quick access with Face ID",
                                color: .blue
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingPasscodeSetup) {
            PasscodeSetupView(isPasscodeSet: $isPasscodeSet)
        }
        .sheet(isPresented: $showingPasscodeManagement) {
            PasscodeManagementView(isPasscodeSet: $isPasscodeSet)
        }
    }
}

// MARK: - Supporting Views

struct SecurityStatusRow: View {
    let title: String
    let icon: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 32)
                
                Text(title)
                    .font(.body)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(isEnabled ? "On" : "Off")
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .foregroundColor(.primary)
    }
}

struct SecurityInfoRow: View {
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

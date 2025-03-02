//
//  PasscodeManagementView.swift
//  Expensa
//
//  Created by Andrew Sereda on 03.11.2024.
//

import SwiftUI

struct PasscodeManagementView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isPasscodeSet: Bool
    @State private var showingVerification = false
    @State private var showingChangePasscode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                        }
                        
                        Text("Manage Passcode")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Change or remove your device passcode")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        ActionButton(
                            title: "Change Passcode",
                            icon: "key.fill",
                            action: { showingChangePasscode = true },
                            style: .primary
                        )
                        
                        ActionButton(
                            title: "Turn Off Passcode",
                            icon: "lock.open.fill",
                            action: { showingVerification = true },
                            style: .destructive
                        )
                    }
                    .padding(.horizontal)
                    
                    // Security Info
                    VStack(alignment: .leading, spacing: 16) {
                        SecurityNote(
                            icon: "exclamationmark.triangle.fill",
                            text: "Turning off passcode will make your data less secure",
                            color: .orange
                        )
                        
                        SecurityNote(
                            icon: "key.fill",
                            text: "Make sure to remember your new passcode",
                            color: .secondary
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingVerification) {
            PasscodeVerificationView(
                isPresented: $showingVerification,
                isPasscodeSet: $isPasscodeSet,
                mode: .turnOff
            ) {
                // Completion handler - will be called after successful verification
                isPasscodeSet = false
                showingVerification = false
                dismiss() // Dismiss PasscodeManagementView
            }
        }
        .sheet(isPresented: $showingChangePasscode) {
            PasscodeVerificationView(
                isPresented: $showingChangePasscode,
                isPasscodeSet: $isPasscodeSet,
                mode: .change
            ) {
                // Here we would typically show PasscodeSetupView, but since we want to
                // return to SecurityPageView, we'll just dismiss everything
                showingChangePasscode = false
                dismiss() // Dismiss PasscodeManagementView
            }
        }
    }
    
    private func turnOffPasscode() {
        let deleted = KeychainHelper.shared.deletePasscode()
        if deleted {
            isPasscodeSet = false
            dismiss()
        }
    }
    
    private func changePasscode() {
        dismiss()
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return .accentColor
            case .destructive:
                return .red
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(style.backgroundColor)
            )
        }
    }
}

struct SecurityNote: View {
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
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

struct PasscodeVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool
    @Binding var isPasscodeSet: Bool
    @State private var enteredPasscode = ""
    @State private var showError = false
    @State private var shake = false
    @State private var dots: [Bool] = Array(repeating: false, count: 4)
    
    let mode: VerificationMode
    let onSuccess: () -> Void
    
    enum VerificationMode {
        case turnOff
        case change
        
        var title: String {
            switch self {
            case .turnOff:
                return "Verify Passcode"
            case .change:
                return "Enter Current Passcode"
            }
        }
        
        var subtitle: String {
            switch self {
            case .turnOff:
                return "Enter your current passcode to turn it off"
            case .change:
                return "Enter your current passcode to change it"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: mode == .turnOff ? "lock.open.fill" : "key.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.bottom, 8)
                        
                        Text(mode.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(mode.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Passcode dots
                    HStack(spacing: 20) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(getDotColor(for: index))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(.gray.opacity(0.3), lineWidth: 2)
                                )
                        }
                    }
                    .modifier(ShakeEffect(animatableData: CGFloat(shake ? 1 : 0)))
                    
                    // Hidden text field for input
                    SecureField("", text: $enteredPasscode)
                        .keyboardType(.numberPad)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        .onChange(of: enteredPasscode) { _, newValue in
                            handleInput(newValue)
                        }
                    
                    if showError {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Incorrect passcode")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                        .transition(.opacity)
                    }
                    
                    // Number pad
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                        ForEach(1...9, id: \.self) { number in
                            NumberButton(number: String(number)) {
                                handleNumberInput(String(number))
                            }
                        }
                        NumberButton(number: "←") {
                            handleDelete()
                        }
                        NumberButton(number: "0") {
                            handleNumberInput("0")
                        }
                        NumberButton(number: "✓") {
                            verifyPasscode()
                        }
                        .disabled(enteredPasscode.count < 4)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getDotColor(for index: Int) -> Color {
        return index < enteredPasscode.count ? .accentColor : .clear
    }
    
    private func handleInput(_ newValue: String) {
        if newValue.count > 4 {
            enteredPasscode = String(newValue.prefix(4))
        }
        updateDots()
        if enteredPasscode.count == 4 {
            verifyPasscode()
        }
    }
    
    private func handleNumberInput(_ number: String) {
        if enteredPasscode.count < 4 {
            enteredPasscode += number
            updateDots()
            if enteredPasscode.count == 4 {
                verifyPasscode()
            }
        }
    }
    
    private func handleDelete() {
        enteredPasscode = String(enteredPasscode.dropLast())
        updateDots()
    }
    
    private func updateDots() {
        for i in 0..<4 {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                dots[i] = i < enteredPasscode.count
            }
        }
    }
    
    private func verifyPasscode() {
        if KeychainHelper.shared.getPasscode() == enteredPasscode {
            switch mode {
            case .turnOff:
                let deleted = KeychainHelper.shared.deletePasscode()
                if deleted {
                    onSuccess()
                }
            case .change:
                onSuccess()
            }
        } else {
            withAnimation {
                showError = true
            }
            enteredPasscode = ""
            updateDots()
            triggerShake()
        }
    }
    
    private func triggerShake() {
        withAnimation(.default) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shake = false
            withAnimation {
                showError = false
            }
        }
    }
}

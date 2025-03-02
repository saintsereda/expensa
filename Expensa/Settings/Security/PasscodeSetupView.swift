//
//  PasscodeSetupView.swift
//  Expensa
//
//  Created by Andrew Sereda on 03.11.2024.
//

import SwiftUI

struct PasscodeSetupView: View {
    @Environment(\.dismiss) var dismiss
    @State private var firstPasscode = ""
    @State private var confirmPasscode = ""
    @State private var isConfirming = false
    @Binding var isPasscodeSet: Bool
    @State private var showError = false
    @State private var shake = false
    @State private var dots: [Bool] = Array(repeating: false, count: 4)
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 16)
                    
                    Text(isConfirming ? "Confirm Your Passcode" : "Create Passcode")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(isConfirming ? "Please enter the same passcode again" : "Enter a 4-digit code to secure your data")
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
                SecureField("", text: isConfirming ? $confirmPasscode : $firstPasscode)
                    .keyboardType(.numberPad)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .onChange(of: isConfirming ? confirmPasscode : firstPasscode) { _, newValue in
                        handleInput(newValue)
                    }
                
                if showError {
                    Text("Passcodes don't match")
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .transition(.opacity)
                }
                
                // Custom number pad
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
                    NumberButton(number: isConfirming ? "✓" : "→") {
                        handleNext()
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    private func getDotColor(for index: Int) -> Color {
        let currentPasscode = isConfirming ? confirmPasscode : firstPasscode
        return index < currentPasscode.count ? .accentColor : .clear
    }
    
    private func handleInput(_ newValue: String) {
        if newValue.count > 4 {
            if isConfirming {
                confirmPasscode = String(newValue.prefix(4))
            } else {
                firstPasscode = String(newValue.prefix(4))
            }
        }
        checkAndProceed()
    }
    
    private func handleNumberInput(_ number: String) {
        let currentPasscode = isConfirming ? confirmPasscode : firstPasscode
        if currentPasscode.count < 4 {
            if isConfirming {
                confirmPasscode += number
            } else {
                firstPasscode += number
            }
            updateDots()
            checkAndProceed()
        }
    }
    
    private func checkAndProceed() {
        // If first passcode is complete, proceed to confirmation
        if !isConfirming && firstPasscode.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showError = false
                    isConfirming = true
                }
            }
        }
        // If confirmation is complete, verify and save
        else if isConfirming && confirmPasscode.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if firstPasscode == confirmPasscode {
                    let saved = KeychainHelper.shared.savePasscode(firstPasscode)
                    if saved {
                        withAnimation {
                            isPasscodeSet = true
                        }
                        dismiss()
                    } else {
                        showError = true
                        confirmPasscode = ""
                        triggerShake()
                    }
                } else {
                    withAnimation {
                        showError = true
                    }
                    confirmPasscode = ""
                    triggerShake()
                }
            }
        }
    }
    
    private func handleDelete() {
        if isConfirming {
            confirmPasscode = String(confirmPasscode.dropLast())
        } else {
            firstPasscode = String(firstPasscode.dropLast())
        }
        updateDots()
    }
    
    private func updateDots() {
        let currentPasscode = isConfirming ? confirmPasscode : firstPasscode
        for i in 0..<4 {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                dots[i] = i < currentPasscode.count
            }
        }
    }
    
    private func handleNext() {
        if isConfirming {
            if firstPasscode == confirmPasscode {
                let saved = KeychainHelper.shared.savePasscode(firstPasscode)
                if saved {
                    withAnimation {
                        isPasscodeSet = true
                    }
                    dismiss()
                } else {
                    showError = true
                    confirmPasscode = ""
                    triggerShake()
                }
            } else {
                withAnimation {
                    showError = true
                }
                confirmPasscode = ""
                triggerShake()
            }
        } else {
            withAnimation {
                showError = false
                isConfirming = true
            }
        }
    }
    
    private func triggerShake() {
        withAnimation(.default) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shake = false
        }
    }
}

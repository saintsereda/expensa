//
//  PasscodeEntryView.swift
//  Expensa
//
//  Created by Andrew Sereda on 03.11.2024.
//

import SwiftUI

struct PasscodeEntryView: View {
    @Binding var isPasscodeEntered: Bool
    @State private var enteredPasscode = ""
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
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.bottom, 8)
                    
                    Text("Enter Passcode")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your passcode to unlock the app")
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
                    NumberButton(number: "✓") {
                        verifyPasscode()
                    }
                    .disabled(enteredPasscode.count < 4)
                }
                .padding(.horizontal)
            }
            .padding()
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
            withAnimation {
                isPasscodeEntered = true
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

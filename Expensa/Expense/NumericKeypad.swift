//
//  NumericKeypad.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI

struct NumericKeypad: View {
    let onNumberTap: (String) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate responsive spacing and button size based on screen width
            let availableWidth = geometry.size.width
            let buttonCount = 3 // 3 buttons per row
            let minSpacing: CGFloat = 16 // Minimum spacing between buttons
            let maxButtonWidth: CGFloat = 96 // Maximum button width
            
            // Calculate the ideal button width based on available space
            let calculatedButtonWidth = min(maxButtonWidth,
                                           (availableWidth - (minSpacing * (CGFloat(buttonCount) - 1))) / CGFloat(buttonCount))
            
            // Calculate the actual spacing to use
            let actualSpacing = (availableWidth - (calculatedButtonWidth * CGFloat(buttonCount))) / (CGFloat(buttonCount) - 1)
            
            VStack(spacing: 8) {
                // First row: 1-3
                HStack(spacing: actualSpacing) {
                    ForEach(1...3, id: \.self) { number in
                        numberButton("\(number)", width: calculatedButtonWidth)
                    }
                }
                
                // Second row: 4-6
                HStack(spacing: actualSpacing) {
                    ForEach(4...6, id: \.self) { number in
                        numberButton("\(number)", width: calculatedButtonWidth)
                    }
                }
                
                // Third row: 7-9
                HStack(spacing: actualSpacing) {
                    ForEach(7...9, id: \.self) { number in
                        numberButton("\(number)", width: calculatedButtonWidth)
                    }
                }
                
                // Fourth row: comma, 0, delete
                HStack(spacing: actualSpacing) {
                    numberButton(",", width: calculatedButtonWidth)
                    numberButton("0", width: calculatedButtonWidth)
                    deleteButton(width: calculatedButtonWidth)
                }
            }
            .frame(maxWidth: .infinity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(height: 280) // Provide a fixed height for the keypad
    }
    
    private func numberButton(_ value: String, width: CGFloat) -> some View {
        Button(action: {
            onNumberTap(value)
        }) {
            Text(value)
                .font(.system(size: 32, weight: .regular, design: .rounded))
                .frame(width: width, height: 60)
                .foregroundColor(Color(uiColor: .label))
        }
    }
    
    private func deleteButton(width: CGFloat) -> some View {
        Button(action: onDelete) {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 20, design: .rounded))
                .frame(width: width, height: 60)
                .foregroundColor(Color(uiColor: .label))
        }
    }
}

// MARK: - Preview Provider
struct NumericKeypad_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            NumericKeypad(
                onNumberTap: { _ in },
                onDelete: {}
            )
        }
    }
}

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
        VStack(spacing: 8) {
            // First row: 1-3
            HStack(spacing: 32) {
                ForEach(1...3, id: \.self) { number in
                    numberButton("\(number)")
                }
            }
            
            // Second row: 4-6
            HStack(spacing: 32) {
                ForEach(4...6, id: \.self) { number in
                    numberButton("\(number)")
                }
            }
            
            // Third row: 7-9
            HStack(spacing: 32) {
                ForEach(7...9, id: \.self) { number in
                    numberButton("\(number)")
                }
            }
            
            // Fourth row: comma, 0, delete
            HStack(spacing: 32) {
                numberButton(",")
                numberButton("0")
                deleteButton
            }
        }
    }
    
    private func numberButton(_ value: String) -> some View {
        Button(action: {
            onNumberTap(value)
        }) {
            Text(value)
                .font(.system(size: 32, weight: .regular, design: .rounded))
                .frame(width: 96, height: 60)
                .foregroundColor(Color(uiColor: .label))
        }
    }
    
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 24, design: .rounded))
                .frame(width: 96, height: 60)
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

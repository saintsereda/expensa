//
//  FloatingSearchBar.swift
//  Expensa
//
//  Created by Andrew Sereda on 13.03.2025.
//

import Foundation
import SwiftUI
import Combine

struct FloatingSearchBar: View {
    @Binding var text: String
    @Binding var isKeyboardVisible: Bool
    @FocusState private var isFocused: Bool
    
    var placeholder: String
    
    init(text: Binding<String>, isKeyboardVisible: Binding<Bool>, placeholder: String = "Search...") {
        self._text = text
        self._isKeyboardVisible = isKeyboardVisible
        self.placeholder = placeholder
    }
    
    var body: some View {
        VStack {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 12)
                    
                    TextField(placeholder, text: $text)
                        .padding(.vertical, 10)
                        .focused($isFocused)
                    
                    if !text.isEmpty {
                        Button(action: {
                            text = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 8)
                        }
                    }
                }
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 99)
                        .fill(Color(.systemGray5))
                        .edgesIgnoringSafeArea(.bottom)
                )
                .onChange(of: isFocused) { _, newValue in
                    isKeyboardVisible = newValue
                }
            }
            Spacer()
                .frame(height: isKeyboardVisible ? 16 : 24)
        }
        .background(
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
}

//
//  SettingsRow.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import SwiftUI

struct SettingsRow: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .padding(8)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            Text(title)
                .foregroundColor(.primary)
                .padding(.leading, 8)
        }
    }
}

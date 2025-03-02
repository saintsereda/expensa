//
//  MonthSelector.swift
//  Expensa
//
//  Created by Andrew Sereda on 31.10.2024.
//

import Foundation
import SwiftUI

struct MonthSelector: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        HStack {
//            Button(action: { moveMonth(by: -1) }) {
//                Image(systemName: "chevron.left")
//                    .imageScale(.large)
//                    .foregroundColor(.blue)
//            }
//            .padding()
//            
//            Text(selectedDate.formatted(.dateTime.month(.wide).year()))
//                .font(.headline)
//            
//            Button(action: { moveMonth(by: 1) }) {
//                Image(systemName: "chevron.right")
//                    .imageScale(.large)
//                    .foregroundColor(.blue)
//            }
//            .padding()
            }
    }
    
    private func moveMonth(by value: Int) {
        if let newDate = Calendar.current.date(
            byAdding: .month,
            value: value,
            to: selectedDate
        ) {
            selectedDate = newDate
        }
    }
}

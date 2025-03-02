//
//  LastUpdatedBanner.swift
//  Expensa
//
//  Created by Andrew Sereda on 16.11.2024.
//

import Foundation
import SwiftUI

struct LastUpdatedBanner: View {
    @ObservedObject private var rateManager = HistoricalRateManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lastUpdateText)
                    .font(.body)
                
                Text("Currency rates update daily.")
                    .foregroundColor(.gray)
            }
        }
        .cornerRadius(12)
    }
    
    private var lastUpdateText: String {
        if let lastUpdate = UserDefaults.standard.object(forKey: rateManager.lastUpdateKey) as? Date {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "Rates updated: \(formatter.localizedString(for: lastUpdate, relativeTo: Date()))"
        } else {
            return "Rates not yet updated"
        }
    }
}

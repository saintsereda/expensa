// Create an InsightsSection.swift file to add to the HomePage

//
//  InsightsSection.swift
//  Expensa
//
//  Created on 12.05.2025.
//

import SwiftUI

struct InsightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.64))
            
            // Weekly Recap
            NavigationLink(value: NavigationDestination.weeklyRecap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Recap")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Text("See how you spent last week")
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.64))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.primary.opacity(0.4))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

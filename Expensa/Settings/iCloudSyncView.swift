//
//  iCloudSyncView.swift
//  Expensa
//
//  Created by Andrew Sereda on 05.01.2025.
//

import SwiftUI
import CloudKit
import CoreData

struct iCloudSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // Add the AppStorage property to persist the user’s iCloud sync preference
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true
    
    @State private var fetchedCategories: [Category] = []
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        List {
            Section(header: Text("iCloud Sync Settings")) {
                Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                    .toggleStyle(SwitchToggleStyle())
            }
            
            Section(header: Text("iCloud Sync")) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cloud")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text("iCloud Sync")
                                .font(.headline)
                        }
                        
                        Text("Data is automatically synced across your devices when signed into iCloud")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("iCloud Sync")
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func errorRow(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var simulatorInfoRow: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            Text("Running in Simulator")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

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
    
    // Add the AppStorage property to persist the user's iCloud sync preference
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true
    
    @State private var iCloudStatus: String = "Checking..."
    @State private var isCheckingStatus: Bool = true
    @State private var lastSyncDate: Date? = nil
    @State private var showDiagnosticInfo: Bool = false
    @State private var entityCounts: [String: Int] = [:]
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    // Timer for refreshing status
    @State private var timer: Timer? = nil
    
    var body: some View {
        List {
            Section(header: Text("iCloud Sync Settings")) {
                Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: iCloudSyncEnabled) { newValue in
                        if newValue {
                            // Re-check status when enabled
                            checkiCloudStatus()
                        }
                    }
            }
            
            Section(header: Text("Status")) {
                HStack {
                    Image(systemName: isCheckingStatus ? "arrow.triangle.2.circlepath" :
                          (iCloudStatus == "Available" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"))
                        .foregroundColor(isCheckingStatus ? .gray :
                                       (iCloudStatus == "Available" ? .green : .orange))
                        .imageScale(.large)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Account")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(isCheckingStatus ? "Checking..." : iCloudStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isCheckingStatus {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                if let lastSync = lastSyncDate {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Synced")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(lastSync, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(action: {
                    checkiCloudStatus()
                    refreshLastSyncDate()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Status")
                    }
                }
            }
            
            Section(header: Text("Information")) {
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
                
                #if targetEnvironment(simulator)
                simulatorInfoRow
                #endif
            }
            
            Section(header: Text("Diagnostic Information")) {
                DisclosureGroup("Show Details", isExpanded: $showDiagnosticInfo) {
                    ForEach(entityCounts.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .font(.subheadline)
                            Spacer()
                            Text("\(value)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        forceSync()
                    }) {
                        Label("Force Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        refreshEntityCounts()
                    }) {
                        Label("Refresh Data", systemImage: "arrow.clockwise")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("iCloud Sync")
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            checkiCloudStatus()
            refreshLastSyncDate()
            refreshEntityCounts()
            
            // Set up a timer to refresh status periodically
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                refreshLastSyncDate()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // Check iCloud account status
    private func checkiCloudStatus() {
        isCheckingStatus = true
        
        CKContainer(identifier: "iCloud.com.sereda.Expensa").accountStatus { status, error in
            DispatchQueue.main.async {
                isCheckingStatus = false
                
                switch status {
                case .available:
                    iCloudStatus = "Available"
                case .noAccount:
                    iCloudStatus = "No iCloud Account"
                case .restricted:
                    iCloudStatus = "Restricted"
                case .couldNotDetermine:
                    iCloudStatus = "Could Not Determine"
                case .temporarilyUnavailable:
                    iCloudStatus = "Temporarily Unavailable"
                @unknown default:
                    iCloudStatus = "Unknown Status"
                }
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    // Refresh last sync date
    private func refreshLastSyncDate() {
        lastSyncDate = CloudKitSyncMonitor.shared.lastSyncDate
    }
    
    // Refresh entity counts for diagnostic information
    private func refreshEntityCounts() {
        let context = CoreDataStack.shared.context
        let entities = ["Category", "Currency", "Expense", "Budget", "Tag", "ExchangeRateHistory"]
        
        var counts: [String: Int] = [:]
        
        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            fetchRequest.resultType = .countResultType
            
            do {
                let count = try context.count(for: fetchRequest)
                counts[entity] = count
            } catch {
                counts[entity] = -1 // Error indicator
            }
        }
        
        self.entityCounts = counts
    }
    
    // Force sync (for user-initiated sync)
    private func forceSync() {
        // Check if we have the CloudKitSyncManager implementation
        // This might need to be adjusted based on your actual implementation
        #if false
        CloudKitSyncManager.shared.forceSyncNow()
        #else
        // Alternative approach using CloudKitSyncMonitor
        // This will at least refresh the status
        CloudKitSyncMonitor.shared.waitForInitialSync { success in
            DispatchQueue.main.async {
                refreshLastSyncDate()
                refreshEntityCounts()
            }
        }
        #endif
    }
    
    // Error row view
    private func errorRow(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // Simulator information row
    private var simulatorInfoRow: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Running in Simulator")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("iCloud sync has limited functionality in the iOS Simulator")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Preview provider
struct iCloudSyncView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            iCloudSyncView()
        }
    }
}

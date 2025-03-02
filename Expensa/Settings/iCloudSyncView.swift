import SwiftUI
import CloudKit
import CoreData

struct iCloudSyncView: View {
    @EnvironmentObject private var cloudKitManager: CloudKitManager
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
            
            Section {
                statusRow
                
                if let error = cloudKitManager.error {
                    errorRow(error)
                }
                
                #if targetEnvironment(simulator)
                simulatorInfoRow
                #endif
            }
            
            Section(header: Text("Actions")) {
                Button(action: {
                    Task {
                        await cloudKitManager.getiCloudStatus()
                    }
                }) {
                    HStack {
                        Text("Check iCloud Status")
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                Button(action: {
                    cloudKitManager.requestPermission()
                }) {
                    HStack {
                        Text("Request Permission")
                        Spacer()
                        Image(systemName: "person.badge.key")
                    }
                }
            }
            
            Section(header: Text("Testing")) {
                Button(action: {
                    Task {
                        await testSaveCategory()
                    }
                }) {
                    HStack {
                        Text("Test Save Category")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                Button(action: {
                    Task {
                        await testSaveExpense()
                    }
                }) {
                    HStack {
                        Text("Test Save Expense")
                        Spacer()
                        Image(systemName: "dollarsign.circle")
                    }
                }
                
                Button(action: {
                    Task {
                        await testFetchCategories()
                    }
                }) {
                    HStack {
                        Text("Test Fetch Categories")
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                    }
                }
                
                if !fetchedCategories.isEmpty {
                    ForEach(fetchedCategories, id: \.id) { category in
                        VStack(alignment: .leading) {
                            Text(category.name ?? "Unnamed")
                                .font(.headline)
                            Text("Created: \(category.createdAt?.formatted() ?? "Unknown")")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("iCloud Sync")
        .task {
            await cloudKitManager.getiCloudStatus()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var statusRow: some View {
        HStack {
            Image(systemName: cloudKitManager.isSignedInToiCloud ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(cloudKitManager.isSignedInToiCloud ? .green : .red)
            
            VStack(alignment: .leading) {
                Text(cloudKitManager.isSignedInToiCloud ? "iCloud Connected" : "iCloud Not Connected")
                    .font(.headline)
                Text(cloudKitManager.isSignedInToiCloud ? "Your data will be synced" : "Sign in to enable sync")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
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

    // MARK: - Test Functions

    private func testSaveExpense() async {
        do {
            let newExpense = Expense(context: viewContext)
            newExpense.id = UUID()
            newExpense.amount = (99 as Decimal) as NSDecimalNumber
            newExpense.currency = "USD"
            newExpense.date = Date()
            newExpense.createdAt = Date()
            newExpense.updatedAt = Date()
            newExpense.notes = "Test expense"
            newExpense.isPaid = true
            newExpense.isRecurring = false
            
            print("Attempting to save expense: \(newExpense.amount ?? 0)")
            
            // Check the toggle before syncing
            if iCloudSyncEnabled {
                try await cloudKitManager.saveExpense(newExpense)
                print("Successfully saved to CloudKit")
            } else {
                print("iCloud Sync is disabled; expense will not be synced.")
            }
            
            try viewContext.save()
            print("Successfully saved to CoreData")
        } catch {
            print("Error saving expense: \(error.localizedDescription)")
            showError("Failed to save expense: \(error.localizedDescription)")
        }
    }
    
    private func testSaveCategory() async {
        do {
            let newCategory = Category(context: viewContext)
            newCategory.id = UUID()
            newCategory.name = "Test Category \(Date().formatted())"
            newCategory.icon = "🚧"
            newCategory.sortOrder = 0
            newCategory.createdAt = Date()
            print("Container Identifier: \(cloudKitManager.container.containerIdentifier ?? "None")")
            
            print("Attempting to save category: \(newCategory.name ?? "")")
            
            if iCloudSyncEnabled {
                try await cloudKitManager.saveCategory(newCategory)
                print("Successfully saved to CloudKit")
            } else {
                print("iCloud Sync is disabled; category will not be synced.")
            }
            
            try viewContext.save()
            print("Successfully saved to CoreData")
        } catch {
            print("Error saving category: \(error.localizedDescription)")
            showError("Failed to save category: \(error.localizedDescription)")
        }
    }
    
    private func testFetchCategories() async {
        do {
            fetchedCategories = try await cloudKitManager.fetchCategories()
        } catch {
            showError("Failed to fetch categories: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

//import SwiftUI
//import CloudKit
//import CoreData
//
//struct iCloudSyncView: View {
//   @EnvironmentObject private var cloudKitManager: CloudKitManager
//   @Environment(\.dismiss) private var dismiss
//   @Environment(\.managedObjectContext) private var viewContext
//   
//   @State private var fetchedCategories: [Category] = []
//   @State private var showingError: Bool = false
//   @State private var errorMessage: String = ""
//   
//   var body: some View {
//       List {
//           Section {
//               statusRow
//               
//               if let error = cloudKitManager.error {
//                   errorRow(error)
//               }
//               
//               #if targetEnvironment(simulator)
//               simulatorInfoRow
//               #endif
//           }
//           
//           Section {
//               Button(action: {
//                   Task {
//                       await cloudKitManager.getiCloudStatus()
//                   }
//               }) {
//                   HStack {
//                       Text("Check iCloud Status")
//                       Spacer()
//                       Image(systemName: "arrow.clockwise")
//                   }
//               }
//               
//               Button(action: {
//                   cloudKitManager.requestPermission()
//               }) {
//                   HStack {
//                       Text("Request Permission")
//                       Spacer()
//                       Image(systemName: "person.badge.key")
//                   }
//               }
//           } header: {
//               Text("Actions")
//           }
//           
//           Section {
//               Button(action: {
//                   Task {
//                       await testSaveCategory()
//                   }
//               }) {
//                   HStack {
//                       Text("Test Save Category")
//                       Spacer()
//                       Image(systemName: "square.and.arrow.up")
//                   }
//               }
//               
//               Button(action: {
//                   Task {
//                       await testSaveExpense()
//                   }
//               }) {
//                   HStack {
//                       Text("Test Save Expense")
//                       Spacer()
//                       Image(systemName: "dollarsign.circle")
//                   }
//               }
//               
//               Button(action: {
//                   Task {
//                       await testFetchCategories()
//                   }
//               }) {
//                   HStack {
//                       Text("Test Fetch Categories")
//                       Spacer()
//                       Image(systemName: "arrow.down.circle")
//                   }
//               }
//               
//               if !fetchedCategories.isEmpty {
//                   ForEach(fetchedCategories, id: \.id) { category in
//                       VStack(alignment: .leading) {
//                           Text(category.name ?? "Unnamed")
//                               .font(.headline)
//                           Text("Created: \(category.createdAt?.formatted() ?? "Unknown")")
//                               .font(.caption)
//                       }
//                   }
//               }
//           } header: {
//               Text("Testing")
//           }
//       }
//       .navigationTitle("iCloud Sync")
//       .task {
//           await cloudKitManager.getiCloudStatus()
//       }
//       .alert("Error", isPresented: $showingError) {
//           Button("OK", role: .cancel) { }
//       } message: {
//           Text(errorMessage)
//       }
//   }
//   
//   private var statusRow: some View {
//       HStack {
//           Image(systemName: cloudKitManager.isSignedInToiCloud ? "checkmark.circle.fill" : "xmark.circle.fill")
//               .foregroundColor(cloudKitManager.isSignedInToiCloud ? .green : .red)
//           
//           VStack(alignment: .leading) {
//               Text(cloudKitManager.isSignedInToiCloud ? "iCloud Connected" : "iCloud Not Connected")
//                   .font(.headline)
//               Text(cloudKitManager.isSignedInToiCloud ? "Your data will be synced" : "Sign in to enable sync")
//                   .font(.subheadline)
//                   .foregroundColor(.secondary)
//           }
//       }
//   }
//   
//   private func errorRow(_ error: String) -> some View {
//       HStack {
//           Image(systemName: "exclamationmark.triangle.fill")
//               .foregroundColor(.orange)
//           Text(error)
//               .font(.subheadline)
//               .foregroundColor(.secondary)
//       }
//   }
//   
//   private var simulatorInfoRow: some View {
//       HStack {
//           Image(systemName: "info.circle.fill")
//               .foregroundColor(.blue)
//           Text("Running in Simulator")
//               .font(.subheadline)
//               .foregroundColor(.secondary)
//       }
//   }
//
//    // Add the test function
//    private func testSaveExpense() async {
//        do {
//            let newExpense = Expense(context: viewContext)
//            newExpense.id = UUID()
//            newExpense.amount = (99 as Decimal) as NSDecimalNumber
//            newExpense.currency = "USD"
//            newExpense.date = Date()
//            newExpense.createdAt = Date()
//            newExpense.updatedAt = Date()
//            newExpense.notes = "Test expense"
//            newExpense.isPaid = true
//            newExpense.isRecurring = false
//            
//            print("Attempting to save expense: \(newExpense.amount ?? 0)")
//            try await cloudKitManager.saveExpense(newExpense)
//            print("Successfully saved to CloudKit")
//            try viewContext.save()
//            print("Successfully saved to CoreData")
//        } catch {
//            print("Error saving expense: \(error.localizedDescription)")
//            showError("Failed to save expense: \(error.localizedDescription)")
//        }
//    }
//   
//    private func testSaveCategory() async {
//        do {
//            let newCategory = Category(context: viewContext)
//            newCategory.id = UUID()
//            newCategory.name = "Test Category \(Date().formatted())"
//            newCategory.icon = "🚧"
//            newCategory.sortOrder = 0
//            newCategory.createdAt = Date()
//            print("Container Identifier: \(cloudKitManager.container.containerIdentifier ?? "None")")
//            
//            print("Attempting to save category: \(newCategory.name ?? "")")
//            try await cloudKitManager.saveCategory(newCategory)
//            print("Successfully saved to CloudKit")
//            try viewContext.save()
//            print("Successfully saved to CoreData")
//        } catch {
//            print("Error saving category: \(error.localizedDescription)")
//            showError("Failed to save category: \(error.localizedDescription)")
//        }
//    }
//    
//   private func testFetchCategories() async {
//       do {
//           fetchedCategories = try await cloudKitManager.fetchCategories()
//       } catch {
//           showError("Failed to fetch categories: \(error.localizedDescription)")
//       }
//   }
//   
//   private func showError(_ message: String) {
//       errorMessage = message
//       showingError = true
//   }
//}

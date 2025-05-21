////
////  CloudKitManager.swift
////  Expensa
////
////  Created by Andrew Sereda on 18.11.2024.
////
//import Foundation
//import CloudKit
//
//class CloudKitManager: ObservableObject {
//   let container: CKContainer
//   let publicDatabase: CKDatabase
//   let privateDatabase: CKDatabase
//   
//   @Published var isSignedInToiCloud: Bool = false
//   @Published var error: String?
//   @Published var permissionStatus: Bool = false
//   
//   init() {
//       self.container = CKContainer(identifier: "iCloud.com.sereda.Expensa")
//       self.publicDatabase = container.publicCloudDatabase
//       self.privateDatabase = container.database(with: .private)
//   }
//   
//    func saveRecord<T: CloudKitRecord>(_ item: T) async throws where T.RecordType == T {
//        let record = item.toCKRecord()
//        let savedRecord = try await privateDatabase.save(record)
//        print("✅ Saved record of type \(T.self) to CloudKit")
//        // Handle the saved record if needed
//    }
//
//    func fetchRecords<T: CloudKitRecord>(
//        recordType: String,
//        predicate: NSPredicate = NSPredicate(value: true)
//    ) async throws -> [T] where T.RecordType == T {
//        let query = CKQuery(recordType: recordType, predicate: predicate)
//        let result = try await privateDatabase.records(matching: query)
//        
//        // Handle each record's result
//        return try result.matchResults.compactMap { recordID, matchResult in
//            switch matchResult {
//            case .success(let record):
//                return try T.fromCKRecord(record) // Convert CKRecord to your model type
//            case .failure(let error):
//                throw error // You can handle errors here or propagate them
//            }
//        }
//    }
//    
//    func saveCategory(_ category: Category) async throws {
//        if category.id != nil {
//            try await modifyRecord(category)
//        } else {
//            try await saveRecord(category)
//        }
//    }
//    
//    func fetchCategories() async throws -> [Category] {
//        try await fetchRecords(recordType: "Category")
//    }
//    
//    func saveExpense(_ expense: Expense) async throws {
//        if expense.id != nil {
//            try await modifyRecord(expense)
//        } else {
//            try await saveRecord(expense)
//        }
//    }
//    
//    func saveRecurringExpense(_ recurringExpense: RecurringExpense) async throws {
//        if recurringExpense.id != nil {
//            try await modifyRecord(recurringExpense)
//        } else {
//            try await saveRecord(recurringExpense)
//        }
//    }
//    
//    func deleteRecord(withID recordID: CKRecord.ID) async throws {
//        do {
//            _ = try await privateDatabase.deleteRecord(withID: recordID)
//            print("✅ Successfully deleted record with ID: \(recordID.recordName)")
//        } catch {
//            print("❌ Failed to delete record: \(error)")
//            throw error
//        }
//    }
//
//    func deleteExpense(withID id: UUID) async throws {
//        let recordID = CKRecord.ID(recordName: id.uuidString)
//        try await deleteRecord(withID: recordID)
//    }
//
//    func deleteCategory(withID id: UUID) async throws {
//        let recordID = CKRecord.ID(recordName: id.uuidString)
//        try await deleteRecord(withID: recordID)
//    }
//
//    func deleteTag(withID id: UUID) async throws {
//        let recordID = CKRecord.ID(recordName: id.uuidString)
//        try await deleteRecord(withID: recordID)
//    }
//
//    func deleteRecurringExpense(withID id: UUID) async throws {
//        let recordID = CKRecord.ID(recordName: id.uuidString)
//        try await deleteRecord(withID: recordID)
//    }
//    
//    func fetchExpenses() async throws -> [Expense] {
//        try await fetchRecords(recordType: "Expense")
//    }
//    
//    // Optional: Fetch a specific category
//    func fetchCategory(withId id: String) async throws -> Category? {
//        let predicate = NSPredicate(format: "id == %@", id)
//        let categories: [Category] = try await fetchRecords(recordType: "Category", predicate: predicate)
//        return categories.first
//    }
//    
//    func saveTag(_ tag: Tag) async throws {
//        try await saveRecord(tag)
//    }
//    
//    func fetchTags() async throws -> [Tag] {
//        try await fetchRecords(recordType: "Tag")
//    }
//   
//   // iCloud status check
//   func getiCloudStatus() async {
//       #if targetEnvironment(simulator)
//       do {
//           let status = try await container.accountStatus()
//           DispatchQueue.main.async {
//               switch status {
//               case .available:
//                   self.isSignedInToiCloud = true
//                   self.error = nil
//               case .noAccount:
//                   self.isSignedInToiCloud = false
//                   self.error = "No iCloud account found. Please sign in to your iCloud account in Settings to use sync features."
//               case .restricted:
//                   self.isSignedInToiCloud = false
//                   self.error = "iCloud account is restricted."
//               case .couldNotDetermine:
//                   self.isSignedInToiCloud = false
//                   self.error = "Unable to determine iCloud account status."
//               case .temporarilyUnavailable:
//                   self.isSignedInToiCloud = false
//                   self.error = "iCloud account is temporarily unavailable."
//               @unknown default:
//                   self.isSignedInToiCloud = false
//                   self.error = "Unknown iCloud account status."
//               }
//           }
//       } catch {
//           DispatchQueue.main.async {
//               self.isSignedInToiCloud = false
//               self.error = error.localizedDescription
//           }
//       }
//       #else
//       do {
//           let status = try await container.accountStatus()
//           DispatchQueue.main.async {
//               self.isSignedInToiCloud = (status == .available)
//               self.error = nil
//           }
//       } catch {
//           DispatchQueue.main.async {
//               self.isSignedInToiCloud = false
//               self.error = error.localizedDescription
//           }
//       }
//       #endif
//   }
//    
//    func modifyRecord<T: CloudKitRecord>(_ item: T) async throws {
//        let recordID = CKRecord.ID(recordName: item.id?.uuidString ?? UUID().uuidString)
//        
//        // First try to fetch existing record
//        do {
//            let existingRecord = try await privateDatabase.record(for: recordID)
//            // Update existing record with new values
//            let record = item.toCKRecord()
//            existingRecord.setValuesForKeys(record.allKeys().reduce(into: [String: Any]()) { dict, key in
//                dict[key] = record.value(forKey: key)
//            })
//            
//            // Save the modified record
//            _ = try await privateDatabase.save(existingRecord)
//            print("✅ Modified record of type \(T.self) in CloudKit")
//        } catch {
//            // If record doesn't exist, create new one
//            let record = item.toCKRecord()
//            _ = try await privateDatabase.save(record)
//            print("✅ Created new record of type \(T.self) in CloudKit (during modify)")
//        }
//    }
//   
//   func requestPermission() {
//       container.requestApplicationPermission(.userDiscoverability) { [weak self] (status, error) in
//           DispatchQueue.main.async {
//               if status == .granted {
//                   self?.permissionStatus = true
//               } else {
//                   self?.permissionStatus = false
//               }
//           }
//       }
//   }
//}

//
//  CloudKitRecord.swift
//  Expensa
//
//  Created by Andrew Sereda on 22.11.2024.
//

import CloudKit
import CoreData
import Combine

enum CloudKitError: Error {
    case invalidData
}

protocol CloudKitRecord {
    associatedtype RecordType
    var id: UUID? { get }
    func toCKRecord() -> CKRecord
    static func fromCKRecord(_ record: CKRecord) throws -> RecordType
}

extension Category: CloudKitRecord {
    typealias RecordType = Category
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Category")
        record.setValue(id?.uuidString, forKey: "id")
        record.setValue(name, forKey: "name")
        record.setValue(icon, forKey: "icon")
        record.setValue(sortOrder, forKey: "sortOrder")
        if let limit = budgetLimit {
            record.setValue(limit as NSDecimalNumber, forKey: "budgetLimit")
        }
        record.setValue(createdAt, forKey: "createdAt")
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> Category {
        let category = Category(context: CoreDataStack.shared.context)
        
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString)
        else { throw CloudKitError.invalidData }
        
        category.id = id
        category.name = record["name"] as? String
        category.icon = record["icon"] as? String
        category.sortOrder = record["sortOrder"] as? Int64 ?? 0
        if let budgetLimitNumber = record["budgetLimit"] as? NSNumber {
            category.budgetLimit = NSDecimalNumber(decimal: budgetLimitNumber.decimalValue)
        }
        category.createdAt = record["createdAt"] as? Date
        
        return category
    }
}

extension Expense: CloudKitRecord {
    typealias RecordType = Expense
    
    func toCKRecord() -> CKRecord {
        // Create record with existing ID if available
        let recordID = CKRecord.ID(recordName: id?.uuidString ?? UUID().uuidString)
        let record = CKRecord(recordType: "Expense", recordID: recordID)
        
        record.setValue(id?.uuidString, forKey: "id")
        record.setValue(amount, forKey: "amount")
        record.setValue(conversionRate, forKey: "conversionRate")
        record.setValue(convertedAmount, forKey: "convertedAmount")
        record.setValue(currency, forKey: "currency")
        record.setValue(notes, forKey: "notes")
        record.setValue(isPaid ? 1 : 0, forKey: "isPaid")
        record.setValue(isRecurring ? 1 : 0, forKey: "isRecurring")
        record.setValue(recurrenceStatus, forKey: "recurrenceStatus")
        record.setValue(recurrenceType, forKey: "recurrenceType")
        record.setValue(createdAt, forKey: "createdAt")
        record.setValue(updatedAt, forKey: "updatedAt")
        record.setValue(date, forKey: "date")
        
        // Handle category reference
        if let category = category {
            let categoryReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: category.id?.uuidString ?? ""), action: .deleteSelf)
            record.setValue(categoryReference, forKey: "category")
        }
        
        // Handle tags references
        if let tags = tags {
            let tagReferences = tags.compactMap { tag -> CKRecord.Reference? in
                guard let tag = tag as? Tag, let tagId = tag.id?.uuidString else { return nil }
                return CKRecord.Reference(recordID: CKRecord.ID(recordName: tagId), action: .deleteSelf)
            }
            if !tagReferences.isEmpty {
                record.setValue(tagReferences, forKey: "tags")
            }
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> Expense {
        let expense = Expense(context: CoreDataStack.shared.context)
        
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString)
        else { throw CloudKitError.invalidData }
        
        expense.id = id
        if let amountNumber = record["amount"] as? NSNumber {
            expense.amount = (amountNumber.decimalValue) as NSDecimalNumber
        }
        if let conversionRateNumber = record["conversionRate"] as? NSNumber {
            expense.conversionRate = (conversionRateNumber.decimalValue) as NSDecimalNumber
        }
        if let convertedAmountNumber = record["convertedAmount"] as? NSNumber {
            expense.convertedAmount = (convertedAmountNumber.decimalValue) as NSDecimalNumber
        }
        expense.currency = record["currency"] as? String
        expense.notes = record["notes"] as? String
        expense.isPaid = (record["isPaid"] as? Int64 ?? 0) > 0
        expense.isRecurring = (record["isRecurring"] as? Int64 ?? 0) > 0
        expense.recurrenceStatus = record["recurrenceStatus"] as? String
        expense.recurrenceType = record["recurrenceType"] as? String
        expense.createdAt = record["createdAt"] as? Date
        expense.updatedAt = record["updatedAt"] as? Date
        expense.date = record["date"] as? Date
        
        return expense
    }
}

extension RecurringExpense: CloudKitRecord {
    typealias RecordType = RecurringExpense
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "RecurringExpense")
        record.setValue(id?.uuidString, forKey: "id")
        record.setValue(amount, forKey: "amount")
        record.setValue(convertedAmount, forKey: "convertedAmount")
        record.setValue(currency, forKey: "currency")
        record.setValue(frequency, forKey: "frequency")
        record.setValue(lastGeneratedDate, forKey: "lastGeneratedDate")
        record.setValue(notes, forKey: "notes")
        record.setValue(notificationEnabled ? 1 : 0, forKey: "notificationEnabled")
        record.setValue(status, forKey: "status")
        record.setValue(nextDueDate, forKey: "nextDueDate")
        record.setValue(createdAt, forKey: "createdAt")
        record.setValue(updatedAt, forKey: "updatedAt")
        
        // Handle category reference
        if let category = category {
            let categoryReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: category.id?.uuidString ?? ""), action: .deleteSelf)
            record.setValue(categoryReference, forKey: "category")
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> RecurringExpense {
        let recurringExpense = RecurringExpense(context: CoreDataStack.shared.context)
        
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString)
        else { throw CloudKitError.invalidData }
        
        recurringExpense.id = id
        recurringExpense.amount = record["amount"] as? NSDecimalNumber
        recurringExpense.convertedAmount = record["convertedAmount"] as? NSDecimalNumber
        recurringExpense.currency = record["currency"] as? String
        recurringExpense.frequency = record["frequency"] as? String
        recurringExpense.lastGeneratedDate = record["lastGeneratedDate"] as? Date
        recurringExpense.notes = record["notes"] as? String
        recurringExpense.notificationEnabled = (record["notificationEnabled"] as? Int64 ?? 0) > 0
        recurringExpense.status = record["status"] as? String
        recurringExpense.nextDueDate = record["nextDueDate"] as? Date
        recurringExpense.createdAt = record["createdAt"] as? Date
        recurringExpense.updatedAt = record["updatedAt"] as? Date
        
        return recurringExpense
    }
}

extension Tag: CloudKitRecord {
    typealias RecordType = Tag
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Tag")
        record.setValue(id?.uuidString, forKey: "id")
        record.setValue(name, forKey: "name")
        record.setValue(color, forKey: "color")
        record.setValue(createdAt, forKey: "createdAt")
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> Tag {
        let tag = Tag(context: CoreDataStack.shared.context)
        
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString)
        else { throw CloudKitError.invalidData }
        
        tag.id = id
        tag.name = record["name"] as? String
        tag.color = record["color"] as? String
        tag.createdAt = record["createdAt"] as? Date
        
        return tag
    }
}

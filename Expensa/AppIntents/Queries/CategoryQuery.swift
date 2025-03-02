//
//  CategoryQuery.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.11.2024.
//

import Foundation
import AppIntents
import CoreData

@available(iOS 16.0, *)
public struct CategoryQuery: EntityQuery {
    public init() {}
    
    public func entities(for identifiers: [String]) async throws -> [CategoryEntity] {
        return identifiers.compactMap { id in
            guard let uuid = UUID(uuidString: id),
                  let category = CategoryManager.shared.fetchCategory(withId: uuid) else {
                return nil
            }
            return CategoryEntity(
                id: id,
                displayString: "\(category.icon ?? "") \(category.name ?? "Unknown")"
            )
        }
    }
    
    public func suggestedEntities() async -> [CategoryEntity] {
        return CategoryManager.shared.categories.compactMap { category in
            guard let id = category.id?.uuidString else { return nil }
            return CategoryEntity(
                id: id,
                displayString: "\(category.icon ?? "") \(category.name ?? "Unknown")"
            )
        }
    }
}

//
//  CategoryEntity.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.11.2024.
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
public struct CategoryEntity: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    public static var defaultQuery = CategoryQuery()
    
    public let id: String
    public let displayString: String
    
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)"
        )
    }
    
    public init(id: String, displayString: String) {
        self.id = id
        self.displayString = displayString
    }
}

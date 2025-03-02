//
//  File.swift
//  Expensa
//
//  Created by Andrew Sereda on 11.11.2024.
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
public struct ExpenseShortcutsProvider: AppShortcutsProvider {
    public static var shortcutTileColor: ShortcutTileColor { .blue }
    
    public static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: ImportExpenseIntent(),
                phrases: [
                    "Import expense to \(.applicationName)",
                    "Import payment in \(.applicationName)",
                    "Import transaction in \(.applicationName)"
                ],
                shortTitle: "Import expense",
                systemImageName: "creditcard"
            ),
            AppShortcut(
                intent: QuickAddExpenseIntent(),
                phrases: [
                    "Add expense to \(.applicationName)",
                    "Quick add in \(.applicationName)",
                    "Add transaction in \(.applicationName)"
                ],
                shortTitle: "Add expense",
                systemImageName: "plus.circle"
            )
        ]
    }
}


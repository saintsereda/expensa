//
//  NotificationsView.swift
//  Expensa
//
//  Created by Andrew Sereda on 10.05.2025.
//

import SwiftUI
import CoreData

struct NotificationsView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var viewModel: NotificationViewModel
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: NotificationViewModel(context: context))
    }
    
    var body: some View {
        List {
            // Main toggle section
            Section {
                Toggle(isOn: $viewModel.isNotificationsEnabled) {
                    NavigationRow(
                        title: "Enable notifications",
                        subtitle: viewModel.isNotificationsEnabled ? "Notifications are enabled" : "Notifications are disabled",
                        icon: "bell.fill",
                        color: .orange
                    )
                }
                .onChange(of: viewModel.isNotificationsEnabled) { newValue in
                    if newValue {
                        viewModel.requestPermission()
                    } else {
                        viewModel.updateNotifications()
                    }
                }
            } header: {
                SectionHeader(text: "Notification settings")
            }
            
            if viewModel.isNotificationsEnabled {
                // Reminder times section
                Section {
                    ForEach(ReminderTime.allCases, id: \.self) { reminderTime in
                        VStack {
                            Toggle(isOn: Binding(
                                get: { viewModel.selectedTimes.contains(reminderTime) },
                                set: { isEnabled in
                                    if isEnabled {
                                        viewModel.selectedTimes.insert(reminderTime)
                                    } else {
                                        viewModel.selectedTimes.remove(reminderTime)
                                    }
                                    viewModel.updateNotifications()
                                }
                            )) {
                                Text(reminderTime.rawValue)
                            }
                            
                            if reminderTime == .custom && viewModel.selectedTimes.contains(.custom) {
                                DatePicker(
                                    "Select time",
                                    selection: $viewModel.customTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .onChange(of: viewModel.customTime) { _ in
                                    viewModel.updateNotifications()
                                }
                            }
                        }
                    }
                } header: {
                    SectionHeader(text: "Reminder Times")
                }
                
                // Test notification section
                Section {
                    Button(action: {
                        viewModel.sendTestNotification()
                    }) {
                        NavigationRow(
                            title: "Send Test Notification",
                            subtitle: "Will appear in 5 seconds",
                            icon: "paperplane.fill",
                            color: .blue
                        )
                    }
                } header: {
                    SectionHeader(text: "Test Notification")
                }
            }
        }
        .navigationTitle("Notifications")
        .listStyle(InsetGroupedListStyle())
    }
}

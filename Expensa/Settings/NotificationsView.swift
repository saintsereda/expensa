import SwiftUI
import UserNotifications
import CoreData

// Structure to hold notification preferences for encoding/decoding
struct NotificationPreferences: Codable {
    var isNotificationsEnabled: Bool
    var selectedTimes: Set<ReminderTime>
    var customTime: Date
}

enum ReminderTime: String, CaseIterable, Codable {
    case morning = "Morning (9:00 AM)"
    case evening = "Evening (9:00 PM)"
    case custom = "Custom Time"
    
    var hour: Int {
        switch self {
        case .morning: return 9
        case .evening: return 21
        case .custom: return 12
        }
    }
    
    var minute: Int {
        return 0
    }
}

class NotificationManager: ObservableObject {
    @Published var isNotificationsEnabled = false {
        didSet {
            saveSettings()
        }
    }
    
    @Published var selectedTimes: Set<ReminderTime> = [] {
        didSet {
            saveSettings()
        }
    }
    
    @Published var customTime = Date() {
        didSet {
            saveSettings()
        }
    }
    
    private let managedObjectContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
        loadSettings()
        checkNotificationStatus()
    }
    
    private func loadSettings() {
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let userSettings = try managedObjectContext.fetch(fetchRequest).first ?? createUserSettings()
            
            if let preferencesData = userSettings.notificationPreferences,
               let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: preferencesData) {
                isNotificationsEnabled = preferences.isNotificationsEnabled
                selectedTimes = preferences.selectedTimes
                customTime = preferences.customTime
                
                // Reschedule notifications if enabled
                if isNotificationsEnabled {
                    updateNotifications()
                }
            }
        } catch {
            print("Error loading notification settings: \(error)")
        }
    }
    
    private func createUserSettings() -> UserSettings {
        let userSettings = UserSettings(context: managedObjectContext)
        userSettings.id = UUID()
        userSettings.theme = "system"  // Default theme
        userSettings.timeZone = TimeZone.current.identifier  // Current time zone
        
        // Set initial notification preferences
        let initialPreferences = NotificationPreferences(
            isNotificationsEnabled: false,
            selectedTimes: [],
            customTime: Date()
        )
        userSettings.notificationPreferences = try? JSONEncoder().encode(initialPreferences)
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Error creating user settings: \(error)")
        }
        
        return userSettings
    }
    
    private func saveSettings() {
        let fetchRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let userSettings = try managedObjectContext.fetch(fetchRequest).first ?? createUserSettings()
            
            let preferences = NotificationPreferences(
                isNotificationsEnabled: isNotificationsEnabled,
                selectedTimes: selectedTimes,
                customTime: customTime
            )
            
            userSettings.notificationPreferences = try JSONEncoder().encode(preferences)
            
            try managedObjectContext.save()
        } catch {
            print("Error saving notification settings: \(error)")
        }
    }
    
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized
                self.saveSettings()
            }
        }
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = success
                self.saveSettings()
            }
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for reminderTime: ReminderTime) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminderTime.rawValue]
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Expense Reminder"
        content.body = reminderTime == .morning ?
            "Start your day by planning your expenses!" :
            "Don't forget to log today's expenses!"
        content.sound = .default
        
        var components = DateComponents()
        
        if reminderTime == .custom {
            let calendar = Calendar.current
            components = calendar.dateComponents([.hour, .minute], from: customTime)
        } else {
            components.hour = reminderTime.hour
            components.minute = reminderTime.minute
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: reminderTime.rawValue,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func updateNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        if isNotificationsEnabled {
            for reminderTime in selectedTimes {
                scheduleNotification(for: reminderTime)
            }
        }
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is how your expense reminder will look"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

struct NotificationsView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var notificationManager: NotificationManager
    
    init(context: NSManagedObjectContext) {
        _notificationManager = StateObject(wrappedValue: NotificationManager(context: context))
    }
    
    var body: some View {
        List {
            // Main toggle section
            Section {
                Toggle(isOn: $notificationManager.isNotificationsEnabled) {
                    NavigationRow(
                        title: "Enable Notifications",
                        subtitle: notificationManager.isNotificationsEnabled ? "Notifications are enabled" : "Notifications are disabled",
                        icon: "bell.fill",
                        color: .orange
                    )
                }
                .onChange(of: notificationManager.isNotificationsEnabled) { newValue in
                    if newValue {
                        notificationManager.requestPermission()
                    } else {
                        notificationManager.updateNotifications()
                    }
                }
            } header: {
                SectionHeader(text: "Notification Settings")
            }
            
            if notificationManager.isNotificationsEnabled {
                // Reminder times section
                Section {
                    ForEach(ReminderTime.allCases, id: \.self) { reminderTime in
                        VStack {
                            Toggle(isOn: Binding(
                                get: { notificationManager.selectedTimes.contains(reminderTime) },
                                set: { isEnabled in
                                    if isEnabled {
                                        notificationManager.selectedTimes.insert(reminderTime)
                                    } else {
                                        notificationManager.selectedTimes.remove(reminderTime)
                                    }
                                    notificationManager.updateNotifications()
                                }
                            )) {
                                Text(reminderTime.rawValue)
                            }
                            
                            if reminderTime == .custom && notificationManager.selectedTimes.contains(.custom) {
                                DatePicker(
                                    "Select time",
                                    selection: $notificationManager.customTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .onChange(of: notificationManager.customTime) { _ in
                                    notificationManager.updateNotifications()
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
                        notificationManager.sendTestNotification()
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

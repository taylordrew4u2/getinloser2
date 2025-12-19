import Foundation
import UserNotifications
import CoreLocation

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var notificationsEnabled = true
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override private init() {
        super.init()
        notificationCenter.delegate = self
        loadNotificationSettings()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.notificationsEnabled = granted
            }
            
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    // MARK: - Settings
    
    func loadNotificationSettings() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func toggleNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "notificationsEnabled")
    }
    
    // MARK: - Event Notifications
    
    func scheduleEventNotification(for event: ItineraryEvent) async {
        guard notificationsEnabled else { return }
        
        // Cancel existing notification for this event
        cancelEventNotification(eventID: event.id)
        
        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: event.date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: event.time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        guard let eventDateTime = calendar.date(from: combinedComponents) else { return }
        
        // Schedule notifications at different intervals
        let intervals: [TimeInterval] = [
            -3600,      // 1 hour before
            -1800,      // 30 minutes before
            -900        // 15 minutes before
        ]
        
        for (index, interval) in intervals.enumerated() {
            let triggerDate = eventDateTime.addingTimeInterval(interval)
            
            // Only schedule future notifications
            guard triggerDate > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Upcoming: \(event.name)"
            content.body = "Your event at \(event.location) is starting soon"
            content.sound = .default
            content.categoryIdentifier = "EVENT_REMINDER"
            content.userInfo = ["eventID": event.id, "tripID": event.tripID]
            
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "\(event.id)-\(index)",
                content: content,
                trigger: trigger
            )
            
            try? await notificationCenter.add(request)
        }
    }
    
    func cancelEventNotification(eventID: String) {
        let identifiers = (0..<3).map { "\(eventID)-\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Local Notifications
    
    func sendLocalNotification(title: String, body: String) async {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification tap
        if let eventID = userInfo["eventID"] as? String,
           let tripID = userInfo["tripID"] as? String {
            // Navigate to event detail
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenEvent"),
                object: nil,
                userInfo: ["eventID": eventID, "tripID": tripID]
            )
        }
        
        completionHandler()
    }
}

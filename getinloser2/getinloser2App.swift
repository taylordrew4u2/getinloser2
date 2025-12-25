//
//  getinloser2App.swift
//  getinloser2
//
//  Created by Taylor Drew on 12/16/25.
//

import SwiftUI
import UserNotifications
import FirebaseCore

@main
struct getinloser2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var firebaseManager = FirebaseStorageManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .environmentObject(firebaseManager)
                .environmentObject(notificationManager)
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh data when app becomes active
                    Task {
                        await firebaseManager.refreshAllData()
                    }
                }
        }
    }
}

// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions and register for remote notifications
        requestNotificationPermissions(application: application)
        
        return true
    }
    
    private func requestNotificationPermissions(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
    }
    
    // MARK: - Remote Notification Registration
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Successfully registered for remote notifications")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Handle Remote Notifications (Firebase)
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("Received remote notification: \(userInfo)")
        
        Task { @MainActor in
            await FirebaseStorageManager.shared.handleRemoteNotification(userInfo: userInfo)
            completionHandler(.newData)
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
        
        // Also refresh data
        Task { @MainActor in
            await FirebaseStorageManager.shared.refreshAllData()
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Refresh data when notification is tapped
        Task { @MainActor in
            await FirebaseStorageManager.shared.refreshAllData()
        }
        completionHandler()
    }
}

//
//  getinloser2App.swift
//  getinloser2
//
//  Created by Taylor Drew on 12/16/25.
//

import SwiftUI

@main
struct getinloser2App: App {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .environmentObject(cloudKitManager)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)
        }
    }
}

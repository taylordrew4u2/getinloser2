//
//  getinloser2App.swift
//  getinloser2
//
//  Created by Taylor Drew on 12/16/25.
//

import SwiftUI
import CoreData

@main
struct getinloser2App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

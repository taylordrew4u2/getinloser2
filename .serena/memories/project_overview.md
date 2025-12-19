# Project Overview
- Purpose: iOS SwiftUI app "getinloser2" for trip planning with CloudKit sync; manages trips, itinerary events, todos, notes, tickets, members, invite codes.
- Tech stack: Swift 5/SwiftUI, CloudKit, Combine, CoreLocation; Xcode project (getinloser2.xcodeproj) with models/managers/views structure.
- Data: Custom models (Trip, ItineraryEvent, TodoItem, TicketDocument, TripNote, TripMember); CloudKit records for syncing; local UserDefaults fallback.
- Architecture: ObservableObject managers (CloudKitManager, LocationManager, NotificationManager); SwiftUI views per feature tabs (Itinerary, Maps, Members, Notes, Tickets, Todo).
- Platforms: iOS (UIKit/SwiftUI).
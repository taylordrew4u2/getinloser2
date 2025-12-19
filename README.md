# Get In Loser - Travel Itinerary Planner

A shared travel itinerary planner app built with SwiftUI and CloudKit for iOS 17+.

## Features

### Core Functionality
- **Shared Trips**: Create and share trips with your travel group
- **Real-time Sync**: All changes sync instantly across all members via iCloud
- **Smart Notifications**: Get alerts for upcoming events and trip updates
- **GPS Navigation**: Built-in map integration with directions to destinations

### Main Features

#### 1. Trip Management
- Create trips with name, location (with map confirmation), and dates
- Share trips via secure links
- Add/remove members
- Delete trips

#### 2. Itinerary Tab
- View trip by day
- 24-hour timeline for each day
- Add events with:
  - Name
  - Time
  - Location (geocoded with map confirmation)
  - Notes
- Automatic notification scheduling (1 hour, 30 min, 15 min before events)

#### 3. Maps Tab
- View all event locations on Apple Maps
- See your current location
- Quick navigation to any destination
- "Open in Maps" for turn-by-turn directions

#### 4. Tickets Tab
- Upload photos and PDFs
- Store airline tickets, hotel confirmations, etc.
- Accessible to all trip members

#### 5. Notes Tab
- Shared notepad for the group
- Real-time collaborative editing
- Auto-save functionality
- Shows last editor and timestamp

#### 6. To-Do Tab
- Create shared tasks
- Each member must check off tasks individually
- Shows completion status per member
- Highlights pending members
- Task marked complete only when all members check it off

#### 7. Members Tab
- View all trip members
- Contact information with phone links
- Notification settings toggle
- Invite new members via share link
- Owner can remove members

## Technical Stack

### Technologies Used
- **SwiftUI**: Modern declarative UI framework
- **CloudKit**: Backend database and sync
- **Core Location**: GPS and geocoding
- **MapKit**: Maps and navigation
- **UserNotifications**: Local and push notifications
- **Combine**: Reactive programming

### Architecture
- **MVVM Pattern**: Clean separation of concerns
- **@MainActor**: Thread-safe UI updates
- **Async/Await**: Modern concurrency
- **ObservableObject**: State management

### Models
- `Trip`: Main trip data
- `ItineraryEvent`: Events with time and location
- `TodoItem`: Tasks with per-member completion
- `TicketDocument`: File uploads (images/PDFs)
- `TripNote`: Shared notes
- `TripMember`: User information

### Managers
- `CloudKitManager`: All CloudKit operations and syncing
- `NotificationManager`: Local and push notifications
- `LocationManager`: GPS, geocoding, and directions

## Setup Instructions

### Prerequisites
1. Xcode 15.0 or later
2. iOS 17.0 or later
3. Apple Developer Account (for CloudKit)

### Configuration Steps

1. **Open the project in Xcode**
   ```bash
   cd /Users/taylordrew/Documents/getinloser2
   open getinloser2.xcodeproj
   ```

2. **Configure Bundle Identifier**
   - Select the project in Xcode
   - Choose your target
   - Update Bundle Identifier to something unique (e.g., `com.yourname.getinloser2`)

3. **Enable Capabilities**
   - Go to Signing & Capabilities
   - Add the following capabilities:
     - iCloud (CloudKit)
     - Push Notifications
     - Background Modes (Remote notifications)

4. **Configure CloudKit**
   - The app automatically uses `CKContainer.default()`
   - CloudKit records will be created automatically on first use
   - Required record types:
     - Trip
     - ItineraryEvent
     - TodoItem
     - TicketDocument
     - TripNote
     - TripMember

5. **Configure Signing**
   - Select your development team
   - Xcode will automatically provision the app

### Testing
1. Build and run on a physical device (CloudKit requires a real device)
2. Sign in with your Apple ID on the device
3. Grant required permissions:
   - Location access
   - Notification permissions
   - Photo library access

## Color Scheme
- **Primary Background**: Black
- **Text**: White
- **Secondary Text**: Gray
- **Accent**: System Blue
- **Success**: Green
- **Error**: Red
- **Warning**: Orange

## Minimum Requirements
- iOS 17.0+
- iPhone or iPad
- Active internet connection (WiFi or cellular)
- iCloud account

## Key Features Implementation

### Real-time Syncing
- CloudKit subscriptions for automatic updates
- Pull-to-refresh on all views
- Automatic conflict resolution

### Notifications
- Scheduled notifications for events (1hr, 30min, 15min before)
- Push notifications for trip updates
- Toggle notifications per user
- Background notification support

### Sharing
- Generate secure CloudKit share links
- Anyone with the link can join (must have app installed)
- Full read/write access for all members
- Owner can remove members

### Data Persistence
- All data stored in CloudKit
- Automatic sync across devices
- Offline capability with local cache
- Automatic recovery on connection restore

## Known Limitations
1. CloudKit requires Apple ID
2. Must have app installed to accept invites
3. Requires iOS 17.0 minimum
4. Large files may take time to upload on slow connections

## Future Enhancements
- Expense splitting
- Weather integration
- Flight tracking
- Packing lists
- Photo albums
- Chat functionality

## Support
For issues or questions, please refer to the CloudKit documentation:
https://developer.apple.com/documentation/cloudkit/

---

Built with ❤️ using Swift and SwiftUI

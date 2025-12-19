# Setup Guide for Get In Loser

## Quick Start

### 1. Open the Project in Xcode
1. Open Xcode (version 15.0 or later)
2. Go to File > Open
3. Navigate to `/Users/taylordrew/Documents/getinloser2/`
4. Select `getinloser2.xcodeproj`

### 2. Configure Your Bundle Identifier
1. Select the project in the Project Navigator (left sidebar)
2. Select the `getinloser2` target
3. Go to the "Signing & Capabilities" tab
4. Change the Bundle Identifier to something unique:
   - Example: `com.yourname.getinloser2`
   - Or use your organization: `com.yourcompany.getinloser2`

### 3. Select Your Team
1. In the same "Signing & Capabilities" tab
2. Under "Team", select your Apple Developer team
3. If you don't have a team, you can use your personal Apple ID:
   - Click "Add Account" in the Team dropdown
   - Sign in with your Apple ID
   - Select your personal team

### 4. Enable Required Capabilities
The following capabilities are already configured in the project:
- ✅ iCloud (with CloudKit enabled)
- ✅ Push Notifications
- ✅ Background Modes (Remote notifications)

If they're not visible:
1. Click "+ Capability" button
2. Add "iCloud" and check "CloudKit"
3. Add "Push Notifications"
4. Add "Background Modes" and check "Remote notifications"

### 5. CloudKit Setup
CloudKit will automatically set up when you first run the app. The required record types are:
- Trip
- ItineraryEvent
- TodoItem
- TicketDocument
- TripNote
- TripMember

### 6. Build and Run
1. Connect a physical iOS device (iOS 17+) OR select an iOS Simulator
2. Click the Play button (▶️) or press Cmd+R
3. **Important**: For full CloudKit functionality, use a real device
4. Sign in with your iCloud account on the device

### 7. Grant Permissions
When the app launches, it will request:
- ✅ Location permissions (for maps and navigation)
- ✅ Notification permissions (for event reminders)
- ✅ Photo library access (when uploading tickets)

### 8. Test the App
1. **Create a Trip**:
   - Tap the + button on the home screen
   - Enter trip name, location, and dates
   - Confirm the location on the map

2. **Add Events**:
   - Open your trip
   - Go to the Itinerary tab
   - Tap on a day
   - Add events with time, location, and notes

3. **View on Map**:
   - Switch to the Maps tab
   - See all your event locations
   - Tap "Open in Maps" for directions

4. **Upload Tickets**:
   - Go to Tickets tab
   - Tap + button
   - Choose photo or PDF to upload

5. **Collaborate**:
   - Add notes in the Notes tab
   - Create tasks in the To-Do tab
   - Invite members in the Members tab

## Troubleshooting

### "No iCloud Account"
- Go to Settings > [Your Name] > iCloud
- Sign in with your Apple ID
- Enable iCloud Drive

### "CloudKit Not Available"
- Ensure you're signed into iCloud
- Check internet connection
- For simulator: make sure iCloud is configured in Settings app

### "Notifications Not Working"
- Go to Settings > Notifications > Get In Loser
- Enable "Allow Notifications"

### "Location Not Available"
- Go to Settings > Privacy & Security > Location Services
- Enable for "Get In Loser"
- Choose "While Using the App"

### Build Errors
1. Clean build folder: Product > Clean Build Folder (Shift+Cmd+K)
2. Quit and restart Xcode
3. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

## Project Structure

```
getinloser2/
├── getinloser2App.swift          # Main app entry point
├── Models/                        # Data models
│   ├── Trip.swift
│   ├── ItineraryEvent.swift
│   ├── TodoItem.swift
│   ├── TicketDocument.swift
│   ├── TripNote.swift
│   └── TripMember.swift
├── Managers/                      # Service managers
│   ├── CloudKitManager.swift     # CloudKit operations
│   ├── NotificationManager.swift # Push/local notifications
│   └── LocationManager.swift     # GPS & maps
├── Views/                         # UI components
│   ├── LaunchScreenView.swift
│   ├── HomeView.swift
│   ├── AddTripView.swift
│   ├── MapConfirmationView.swift
│   ├── TripDetailView.swift
│   ├── DayTimelineView.swift
│   ├── AddEventView.swift
│   ├── EventDetailView.swift
│   └── Tabs/
│       ├── ItineraryTabView.swift
│       ├── MapsTabView.swift
│       ├── TicketsTabView.swift
│       ├── NotesTabView.swift
│       ├── TodoTabView.swift
│       └── MembersTabView.swift
├── Assets.xcassets/              # Images and colors
├── Info.plist                    # App configuration
└── getinloser2.entitlements      # Capabilities

```

## Testing with Multiple Users

To test the sharing functionality:

1. **Method 1: Multiple Devices**
   - Install on 2+ devices with different Apple IDs
   - Create trip on device 1
   - Share link from Members tab
   - Open link on device 2

2. **Method 2: Simulator + Device**
   - Create trip on simulator
   - Share link
   - Open on physical device

## Production Deployment

Before submitting to App Store:

1. **Update Version Info**
   - Increment CFBundleVersion in Info.plist
   - Update CFBundleShortVersionString

2. **Configure Production CloudKit**
   - Go to CloudKit Dashboard
   - Deploy schema to production

3. **Update Entitlements**
   - Change `aps-environment` from `development` to `production`

4. **App Store Connect**
   - Create app record
   - Upload screenshots
   - Fill in app description and metadata
   - Submit for review

## Support Resources

- [Apple CloudKit Documentation](https://developer.apple.com/documentation/cloudkit/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

## Features Checklist

- ✅ Launch screen with animated icon
- ✅ Home page with trip list
- ✅ Add trip with location confirmation
- ✅ Trip detail with 6 tabs
- ✅ Itinerary with day-by-day timeline
- ✅ 24-hour timeline for each day
- ✅ Event creation with time, location, notes
- ✅ Maps view with all locations
- ✅ GPS navigation integration
- ✅ Ticket upload (photos & PDFs)
- ✅ Shared notes with auto-save
- ✅ To-do list with per-member completion
- ✅ Members list with contact info
- ✅ Real-time sync via CloudKit
- ✅ Push notifications for changes
- ✅ Event reminder notifications
- ✅ Share trips via secure link
- ✅ Black/white/gray/blue color scheme
- ✅ iOS 17+ minimum version

---

Need help? Check the README.md for detailed feature documentation.

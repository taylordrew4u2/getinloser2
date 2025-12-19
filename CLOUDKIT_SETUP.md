# Get In Loser - iCloud Kit Setup Guide

## Overview
This travel itinerary planner app uses **iCloud CloudKit** as its complete backend solution for:
- Real-time data synchronization across all user devices
- Secure sharing of trip data between multiple users
- Automatic conflict resolution and merge handling
- Photo/PDF document storage for tickets
- Push notifications for trip updates

---

## Prerequisites

### Apple Developer Account
1. **Required**: You need an Apple Developer account (free or paid)
   - Free account: Can test on personal devices but cannot distribute to App Store
   - Paid account ($99/year): Full capabilities including App Store distribution

2. **Sign in to Xcode**:
   - Open Xcode → Preferences (⌘,)
   - Go to "Accounts" tab
   - Click "+" and add your Apple ID
   - Wait for provisioning profiles to download

### iOS Device Requirements
- **Minimum iOS**: 17.0 or later
- **iCloud**: Device must be signed in to iCloud (Settings → [Your Name] → iCloud)
- **Internet**: Active WiFi or cellular connection for CloudKit sync
- **Storage**: Adequate iCloud storage for photos/documents

---

## Step-by-Step iCloud Kit Setup

### 1. Configure Project Signing & Capabilities

#### A. Set Bundle Identifier
1. Open `getinloser2.xcodeproj` in Xcode
2. Select the project in the navigator (blue icon at top)
3. Select the "getinloser2" target
4. Go to "Signing & Capabilities" tab
5. Set **Bundle Identifier** to something unique:
   ```
   com.yourname.getinloser2
   ```
   - Must be globally unique (no one else can have this ID)
   - Use reverse domain notation (com.yourcompany.appname)
   - Cannot contain spaces or special characters except dots and hyphens

#### B. Select Development Team
1. In the same "Signing & Capabilities" tab
2. Under "Team" dropdown, select your Apple ID/team
3. Xcode will automatically create provisioning profiles
4. Wait for "Signing Certificate" to show valid status

### 2. Enable iCloud Capability

#### A. Add iCloud Capability
1. Still in "Signing & Capabilities" tab
2. Click the **"+ Capability"** button (top left)
3. Scroll and select **"iCloud"**
4. This adds the capability to your project

#### B. Configure CloudKit Services
1. Under the new "iCloud" section, check these boxes:
   - ☑️ **CloudKit**
   - ☑️ **CloudKit Dashboard** (optional, for debugging)

2. Under "Containers" section:
   - Click the **"+"** button
   - Select **"Add Specific Container"**
   - Enter: `iCloud.com.yourname.getinloser2` (match your bundle ID)
   - OR click refresh and select the auto-generated container

3. Verify the container appears and is checked ☑️

#### C. Enable Background Modes (Important!)
1. Click **"+ Capability"** again
2. Add **"Background Modes"**
3. Check these boxes:
   - ☑️ **Remote notifications** (for CloudKit push notifications)
   - ☑️ **Background fetch** (for sync updates)

### 3. Configure Entitlements File

The file `getinloser2.entitlements` should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.yourname.getinloser2</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.yourname.getinloser2</string>
    </array>
</dict>
</plist>
```

**Update**: Replace `com.yourname.getinloser2` with your actual bundle identifier

### 4. Verify Info.plist Permissions

Ensure `Info.plist` includes these keys (already added):

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show you on the map and provide directions to trip destinations.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photos to attach tickets and travel documents to your trips.</string>

<key>NSCameraUsageDescription</key>
<string>Take photos of tickets and documents to add to your trip.</string>

<key>NSUserNotificationsUsageDescription</key>
<string>Get notified about upcoming events and trip updates from your travel group.</string>
```

---

## CloudKit Schema & Record Types

The app automatically creates these CloudKit record types on first use:

### Record Type: **Trip**
| Field Name | Type | Indexed |
|------------|------|---------|
| name | String | Yes |
| destination | String | Yes |
| startDate | Date/Time | Yes |
| endDate | Date/Time | Yes |
| latitude | Double | No |
| longitude | Double | No |
| ownerID | String | Yes |
| memberIDs | String List | No |
| shareRecord | Reference | No |

### Record Type: **ItineraryEvent**
| Field Name | Type | Indexed |
|------------|------|---------|
| tripID | Reference | Yes |
| name | String | Yes |
| eventDate | Date/Time | Yes |
| startTime | Date/Time | Yes |
| locationName | String | No |
| latitude | Double | No |
| longitude | Double | No |
| notes | String | No |

### Record Type: **TodoItem**
| Field Name | Type | Indexed |
|------------|------|---------|
| tripID | Reference | Yes |
| title | String | Yes |
| completedBy | String List | No |
| createdBy | String | Yes |

### Record Type: **TicketDocument**
| Field Name | Type | Indexed |
|------------|------|---------|
| tripID | Reference | Yes |
| fileName | String | Yes |
| fileType | String | No |
| imageAsset | Asset | No |
| uploadedBy | String | Yes |
| uploadDate | Date/Time | Yes |

### Record Type: **TripNote**
| Field Name | Type | Indexed |
|------------|------|---------|
| tripID | Reference | Yes |
| content | String | No |
| lastEditedBy | String | No |
| lastEditDate | Date/Time | Yes |

### Record Type: **TripMember**
| Field Name | Type | Indexed |
|------------|------|---------|
| tripID | Reference | Yes |
| userID | String | Yes |
| name | String | Yes |
| phoneNumber | String | No |
| notificationsEnabled | Int64 | No |

**Note**: CloudKit will auto-create these schemas when you first save records. No manual CloudKit Dashboard setup required!

---

## ⚠️ Important: Manual CloudKit Schema Setup

**If you see errors like**:
- `"Type is not marked indexable: Trip"`
- `"Field 'tripID' has a value type of REFERENCE and cannot be queried using filter value type STRING"`

**You need to manually configure the schema in CloudKit Dashboard:**

### Step 1: Access CloudKit Dashboard
1. Go to: https://icloud.developer.apple.com/
2. Sign in with your Apple Developer account
3. Select your container: `ICloud.TRAVEL.getinloser2`

### Step 2: Add Indexes to Trip Record Type
1. Click on **"Schema"** in the left sidebar
2. Click on **"Record Types"**
3. Select the **"Trip"** record type
4. Go to **"Indexes"** tab
5. Add these queryable indexes:
   - `memberIDs` (QUERYABLE) - **Required for fetching user's trips**
   - `inviteCode` (QUERYABLE) - Required for join by invite code
   - `startDate` (QUERYABLE, SORTABLE) - For sorting trips

### Step 3: Fix Reference Fields (tripID)
The `tripID` field in these record types must be a **REFERENCE** type, not STRING:

For each of these record types: **ItineraryEvent, TodoItem, TicketDocument, TripNote**
1. Select the record type in Schema → Record Types
2. Find the `tripID` field
3. Ensure it's set to type **REFERENCE** pointing to Trip record
4. Mark it as **QUERYABLE**

### Step 4: Deploy Schema to Development
1. After making changes, click **"Deploy Schema Changes..."**
2. Select **"Development"** environment
3. Click **"Deploy"**

### Step 5: Clear Existing Data (if corrupted)
If you had created records with wrong field types:
1. Go to **"Data"** → **"Records"**
2. Select **"Public Database"**
3. Delete any corrupted records
4. Re-run the app to create fresh records with correct schema

---

## Testing CloudKit Functionality

### 1. Build and Run on Device
```bash
# Must use REAL DEVICE for full CloudKit testing
# Simulator has limited CloudKit capabilities
```

1. Connect iPhone/iPad via USB
2. Select your device in Xcode toolbar
3. Click ▶️ Run (⌘R)
4. Grant permissions when prompted:
   - Notifications: "Allow"
   - Location: "Allow While Using App"
   - Photos: "Allow"

### 2. Verify iCloud Connection
1. Open the app
2. Create a test trip
3. Check Xcode console for:
   ```
   ✅ Successfully saved trip to CloudKit
   ✅ Subscribed to CloudKit changes
   ```
4. If errors appear, see Troubleshooting section below

### 3. Test Multi-Device Sync
1. Install app on second device (signed into SAME iCloud account)
2. Share trip from device 1
3. Accept share on device 2
4. Add event on device 2 → should appear on device 1 within seconds

### 4. Test Sharing with Another User
1. Have friend/tester sign in with DIFFERENT iCloud account
2. They must install the app (via TestFlight or Xcode)
3. Share trip via the "Share Trip" button
4. They receive iCloud share notification
5. Both users can now edit and sync the trip

---

## CloudKit Dashboard (Optional)

### Access the Dashboard
1. Go to: https://icloud.developer.apple.com/
2. Sign in with your Apple Developer account
3. Select your app: "getinloser2"
4. Select container: `iCloud.com.yourname.getinloser2`

### Useful Dashboard Features
- **Data**: Browse all records, manually edit/delete
- **Schema**: View record types and fields
- **Logs**: See CloudKit API calls and errors
- **Telemetry**: Monitor usage and performance
- **Subscriptions**: View active push notification subscriptions

### Monitoring in Dashboard
1. Go to "Data" → "Records"
2. Select "Public Database" (for shared trips)
3. Select "Private Database" (for user-specific data)
4. View all Trip, Event, TodoItem records

---

## CloudKit Environments

### Development Environment
- **Used for**: Testing during development
- **Data**: Separate from production, can be wiped
- **Access**: Only devices running from Xcode
- **Current**: You're using this by default

### Production Environment
- **Used for**: App Store builds
- **Data**: Real user data, permanent
- **Access**: All App Store users
- **Deploy**: Xcode → Product → Archive → Distribute

**Important**: Data does NOT sync between development and production!

---

## Common Issues & Troubleshooting

### Error: "Account Temporarily Unavailable"
**Cause**: Not signed into iCloud on device
**Fix**: 
1. Settings → [Your Name]
2. Sign in to iCloud
3. Enable iCloud Drive

### Error: "Request Failed with HTTP Status Code 503"
**Cause**: CloudKit service temporarily down
**Fix**: Wait 5-10 minutes and retry

### Error: "CKErrorZoneNotFound"
**Cause**: First-time setup, zone needs creation
**Fix**: App automatically creates zone, retry operation

### Error: "CKErrorServerRecordChanged"
**Cause**: Record was modified by another user
**Fix**: App automatically re-fetches and merges, user sees latest data

### App Not Syncing Between Devices
**Check**:
1. ✅ Both devices signed into SAME iCloud account?
2. ✅ Both devices have internet connection?
3. ✅ iCloud Drive enabled in Settings?
4. ✅ App has "Background App Refresh" enabled?
5. ✅ Check Xcode console for CloudKit errors

### Sharing Not Working
**Check**:
1. ✅ Recipient has the app installed?
2. ✅ Recipient signed into iCloud?
3. ✅ Share link not expired? (links can expire)
4. ✅ Check CloudKit Dashboard → Sharing section

### Notifications Not Appearing
**Check**:
1. ✅ Notifications enabled in device Settings?
2. ✅ App has notification permission?
3. ✅ User has notifications enabled in Members tab?
4. ✅ Background Modes capability added?

---

## Performance & Quotas

### CloudKit Free Tier Limits (Per App)
- **Requests**: 40 requests/second
- **Database Storage**: 10GB of asset storage
- **Data Transfer**: 2GB/day for free users
- **Asset Storage**: 1GB/user for free users

**For this app**: Free tier is MORE than sufficient for typical travel groups (5-20 people)

### Best Practices for Performance
1. **Batch Operations**: CloudKit manager batches saves/fetches
2. **Subscriptions**: Uses push notifications instead of polling
3. **Query Optimization**: Only fetches data for current trip
4. **Asset Compression**: Images auto-compressed before upload
5. **Caching**: Loaded data cached locally for offline viewing

---

## Security & Privacy

### Data Security
- ✅ **Encrypted**: All CloudKit data encrypted at rest and in transit
- ✅ **Private by Default**: Each user's private database is isolated
- ✅ **Shared Access**: Only users with share link can access trip data
- ✅ **Revocable**: Trip owner can remove members anytime

### User Privacy
- ✅ **No Third-Party Servers**: All data stored in Apple's iCloud
- ✅ **No Analytics**: App does not track user behavior
- ✅ **Local Storage**: Device caches data for offline access
- ✅ **User Control**: Users can delete trips and all associated data

### Sharing Security
- Share links are cryptographically secure
- Only users with the exact link can access
- Links can be revoked by trip owner
- Members must be authenticated via iCloud

---

## Production Deployment

### Preparing for App Store
1. **Test Thoroughly**: Use TestFlight beta testing
2. **Deploy Schema**: Use CloudKit Dashboard to deploy schema to production
3. **Archive Build**: Xcode → Product → Archive
4. **Submit**: Distribute to App Store Connect
5. **Review**: Wait for Apple review (1-3 days typical)

### Post-Launch Monitoring
1. Check CloudKit Dashboard regularly for errors
2. Monitor user reviews for CloudKit issues
3. Track crash reports in Xcode Organizer
4. Update app as needed for iOS updates

---

## Additional Resources

### Apple Documentation
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Quick Start](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/)
- [Sharing CloudKit Data](https://developer.apple.com/documentation/cloudkit/shared_records)

### Xcode Help
- CloudKit Console: https://icloud.developer.apple.com/
- WWDC Sessions: Search "CloudKit" on developer.apple.com
- Forums: https://developer.apple.com/forums/tags/cloudkit

### Support
- Apple Developer Forums
- Stack Overflow: Tag `cloudkit` and `swift`
- Xcode → Help → Developer Documentation

---

## Quick Reference Commands

### View CloudKit Logs in Xcode
```
# Filter console for CloudKit messages
Product → Scheme → Edit Scheme → Run → Arguments
Add: -com.apple.CoreData.CloudKitDebug 3
```

### Reset CloudKit Development Data
```
CloudKit Dashboard → Data → Reset Development Environment
⚠️ WARNING: This deletes ALL development data!
```

### Check iCloud Status Programmatically
```swift
CKContainer.default().accountStatus { status, error in
    print("iCloud Status: \(status.rawValue)")
}
```

---

## Summary Checklist

Before releasing your app, ensure:

- ☑️ Bundle Identifier is unique and configured
- ☑️ Development Team selected in Signing & Capabilities
- ☑️ iCloud capability added with CloudKit enabled
- ☑️ Background Modes capability added (Remote notifications)
- ☑️ Entitlements file contains correct container identifiers
- ☑️ Info.plist has all required permission descriptions
- ☑️ Tested on real device (not just simulator)
- ☑️ Tested multi-device sync with same iCloud account
- ☑️ Tested sharing between different iCloud accounts
- ☑️ Notifications working and delivering properly
- ☑️ CloudKit Dashboard deployed to production environment

---

**App**: Get In Loser - Travel Itinerary Planner
**Version**: 1.0
**Last Updated**: December 2025
**Minimum iOS**: 17.0
**Backend**: iCloud CloudKit
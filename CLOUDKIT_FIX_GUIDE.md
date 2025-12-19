# CloudKit Schema Fix Guide - Get In Loser App

## Overview

Your app is experiencing CloudKit errors because the schema in CloudKit Dashboard doesn't match what your code expects. This guide will walk you through **exactly** how to fix it.

---

## Current Errors You're Seeing

```
Error fetching events: "Field 'tripID' has a value type of REFERENCE and cannot be queried using filter value type STRING"
Error fetching todos: "Field 'tripID' has a value type of REFERENCE and cannot be queried using filter value type STRING"
Error fetching note: "Field 'tripID' has a value type of REFERENCE and cannot be queried using filter value type STRING"
Error fetching tickets: "Field 'tripID' has a value type of REFERENCE and cannot be queried using filter value type STRING"
CloudKit note save failed: "invalid attempt to set value type STRING for field 'tripID' for type 'TripNote', defined to be: REFERENCE"
```

**What this means**: CloudKit has `tripID` defined as a `REFERENCE` field (a pointer to another record), but there are old records saved with `tripID` as a plain `STRING`. The code has been fixed, but the old data needs to be cleaned up.

---

## Step-by-Step Fix Instructions

### Step 1: Open CloudKit Dashboard

1. Open Safari or Chrome
2. Go to: **https://icloud.developer.apple.com/**
3. Sign in with your Apple ID (the one linked to your Apple Developer account)
4. You'll see a list of your CloudKit containers

### Step 2: Select Your Container

1. Look for your container in the list. It should be named:
   ```
   iCloud.TRAVEL.getinloser2
   ```
2. Click on it to open the container dashboard
3. Make sure you're in the **Development** environment (check the dropdown at the top - it should say "Development" not "Production")

### Step 3: Delete Corrupted Records

The old records have `tripID` saved as a STRING instead of REFERENCE. You need to delete them.

#### 3a. Delete TripNote Records

1. In the left sidebar, click **"Data"**
2. Click **"Records"**
3. In the **"Database"** dropdown, select **"Public Database"**
4. In the **"Zone"** dropdown, select **"_defaultZone"**
5. In the **"Type"** dropdown, select **"TripNote"**
6. You'll see a list of all TripNote records
7. **For each record**:
   - Click on the record to select it
   - Click the **"Delete"** button (trash icon) in the toolbar
   - Confirm the deletion
8. Repeat until all TripNote records are deleted

#### 3b. Delete ItineraryEvent Records

1. In the **"Type"** dropdown, select **"ItineraryEvent"**
2. Delete all ItineraryEvent records (same process as above)

#### 3c. Delete TodoItem Records

1. In the **"Type"** dropdown, select **"TodoItem"**
2. Delete all TodoItem records

#### 3d. Delete TicketDocument Records

1. In the **"Type"** dropdown, select **"TicketDocument"**
2. Delete all TicketDocument records

#### 3e. (Optional) Delete Trip Records

If you want a completely fresh start:
1. In the **"Type"** dropdown, select **"Trip"**
2. Delete all Trip records

> **Note**: You can also use the "Delete All Records" option if available, but be careful as this deletes everything.

### Step 4: Verify Schema Fields

Now let's make sure the schema is set up correctly.

#### 4a. Check the Schema

1. In the left sidebar, click **"Schema"**
2. Click **"Record Types"**

#### 4b. Verify Trip Record Type

1. Click on **"Trip"** in the list
2. You should see these fields:
   | Field Name | Type |
   |------------|------|
   | name | String |
   | location | String |
   | startDate | Date/Time |
   | endDate | Date/Time |
   | coordinate | Location |
   | ownerID | String |
   | memberIDs | List of Strings |
   | inviteCode | String |

3. If `memberIDs` doesn't have an index, add one:
   - Click the **"Indexes"** tab
   - Click **"Add Index"**
   - Select `memberIDs` as QUERYABLE
   - Click **"Save"**

#### 4c. Verify ItineraryEvent Record Type

1. Click on **"ItineraryEvent"** in the list
2. Verify `tripID` is type **REFERENCE** pointing to **Trip**
3. If it says STRING, you need to delete the field and recreate it:
   - Click the trash icon next to `tripID`
   - Click **"Add Field"**
   - Name: `tripID`
   - Type: **Reference**
   - Reference Record Type: **Trip**
   - Click **"Save"**

4. Required fields:
   | Field Name | Type |
   |------------|------|
   | tripID | Reference → Trip |
   | name | String |
   | date | Date/Time |
   | time | Date/Time |
   | location | String |
   | coordinate | Location |
   | notes | String |
   | createdBy | String |

#### 4d. Verify TodoItem Record Type

1. Click on **"TodoItem"** in the list
2. Verify these fields:
   | Field Name | Type |
   |------------|------|
   | tripID | Reference → Trip |
   | title | String |
   | completedBy | Bytes |
   | createdBy | String |

#### 4e. Verify TicketDocument Record Type

1. Click on **"TicketDocument"** in the list
2. Verify these fields:
   | Field Name | Type |
   |------------|------|
   | tripID | Reference → Trip |
   | fileName | String |
   | fileType | String |
   | fileAsset | Asset |
   | uploadedBy | String |
   | uploadDate | Date/Time |

#### 4f. Verify TripNote Record Type

1. Click on **"TripNote"** in the list
2. Verify these fields:
   | Field Name | Type |
   |------------|------|
   | tripID | Reference → Trip |
   | content | String |
   | lastModifiedBy | String |
   | lastModifiedDate | Date/Time |

### Step 5: Add Required Indexes

Indexes are required for querying. Without them, you'll get "Type is not marked indexable" errors.

1. Go to **Schema** → **Indexes**
2. Add these indexes if they don't exist:

| Record Type | Field(s) | Type |
|-------------|----------|------|
| Trip | memberIDs | QUERYABLE |
| Trip | inviteCode | QUERYABLE |
| Trip | startDate | QUERYABLE, SORTABLE |
| ItineraryEvent | tripID | QUERYABLE |
| ItineraryEvent | date | QUERYABLE, SORTABLE |
| TodoItem | tripID | QUERYABLE |
| TicketDocument | tripID | QUERYABLE |
| TicketDocument | uploadDate | SORTABLE |
| TripNote | tripID | QUERYABLE |

**To add an index:**
1. Click **"Add Index"**
2. Select the Record Type
3. Select the Field
4. Check QUERYABLE and/or SORTABLE as needed
5. Click **"Save"**

### Step 6: Deploy Schema Changes

After making changes to the schema, you need to deploy them:

1. Click the **"Deploy Schema Changes..."** button (usually at the top right)
2. Select **"Development"** environment
3. Click **"Deploy"**
4. Wait for the deployment to complete

### Step 7: Clean Build in Xcode

After fixing CloudKit:

1. In Xcode, go to **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. Delete the app from your device/simulator
3. Build and run the app again (Cmd+R)

---

## Verification Checklist

After completing the steps above, verify:

- [ ] All old records with STRING tripID have been deleted
- [ ] All record types have tripID as REFERENCE type (except Trip itself)
- [ ] Trip record type has memberIDs and inviteCode as QUERYABLE
- [ ] Schema changes have been deployed
- [ ] App has been clean built and reinstalled

---

## Testing the Fix

1. Run the app
2. Create a new trip
3. Go into the trip and:
   - Add an event to the itinerary
   - Add a todo item
   - Add a note
   - Check the Members tab
4. Check Xcode console - you should NOT see the "REFERENCE/STRING" errors anymore

---

## If You Still See Errors

### Error: "Type is not marked indexable: Trip"

This means the Trip record type needs a queryable index on the field being queried.

**Fix**: Go to Schema → Indexes and add a QUERYABLE index for `memberIDs` on the Trip record type.

### Error: "Field 'tripID' has a value type of REFERENCE..."

This means there are still old records with STRING values.

**Fix**: Go to Data → Records and delete ALL records of that type, then recreate them through the app.

### Error: "No ObservableObject of type NotificationManager found"

This is a code issue, not CloudKit. The app code has already been fixed for this.

**Fix**: Make sure you're running the latest code with NotificationManager added to the environment.

---

## Quick Reference: CloudKit Dashboard Navigation

```
CloudKit Dashboard (https://icloud.developer.apple.com/)
│
├── [Select Container: iCloud.TRAVEL.getinloser2]
│
├── Data
│   └── Records ← Delete corrupted records here
│       ├── Database: Public Database
│       ├── Zone: _defaultZone
│       └── Type: [Select record type]
│
├── Schema
│   ├── Record Types ← View/edit field definitions
│   │   ├── Trip
│   │   ├── ItineraryEvent
│   │   ├── TodoItem
│   │   ├── TicketDocument
│   │   └── TripNote
│   │
│   └── Indexes ← Add queryable/sortable indexes
│
└── Deploy Schema Changes... ← Deploy after making changes
```

---

## Contact/Support

If you continue to have issues after following this guide:

1. Check Xcode console for specific error messages
2. Verify you're in the Development environment (not Production)
3. Make sure your device is signed into the correct iCloud account
4. Try resetting the Development environment entirely (this deletes ALL data):
   - Go to CloudKit Dashboard → Data → "Reset Development Environment"

---

**Last Updated**: December 24, 2025
**App Version**: Get In Loser 1.0
**Container**: iCloud.TRAVEL.getinloser2

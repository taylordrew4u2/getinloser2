# CloudKit Schema Import Guide

## Overview
This guide explains how to import the pre-defined CloudKit schema (`CloudKitSchema.json`) into your iCloud container using the CloudKit Dashboard. This allows you to set up all record types, fields, and indexes in advance rather than having them created automatically by the app.

---

## Why Import a Schema?

### Benefits:
1. **Consistency**: Ensures all environments use the same schema
2. **Control**: Define exact field types, indexes, and permissions upfront
3. **Validation**: Catch schema issues before app deployment
4. **Documentation**: Schema file serves as documentation
5. **Migration**: Easier to version and migrate schemas

### When to Import:
- **Before First App Run**: Best practice for new projects
- **Development Environment First**: Test schema before production
- **After Schema Changes**: Update schema as app evolves

---

## Prerequisites

### Required:
1. ✅ Apple Developer Account (free or paid)
2. ✅ App configured in Xcode with Bundle Identifier
3. ✅ iCloud capability enabled with CloudKit
4. ✅ CloudKit container created (automatic when capability enabled)
5. ✅ Schema file: `CloudKitSchema.json` (included in project)

### Access:
- CloudKit Dashboard: https://icloud.developer.apple.com/

---

## Step-by-Step Import Instructions

### Step 1: Access CloudKit Dashboard

1. Open your web browser
2. Navigate to: **https://icloud.developer.apple.com/**
3. Sign in with your Apple Developer credentials
4. Wait for the dashboard to load

### Step 2: Select Your Container

1. In the dashboard, you'll see "CloudKit Database"
2. Click the **container dropdown** at the top
3. Select your app's container:
   - Should be: `iCloud.com.yourname.getinloser2`
   - Or whatever Bundle ID you configured

4. Select **"Development"** environment (dropdown next to container)
   - Always test in Development first!
   - Production should only be updated after thorough testing

### Step 3: Navigate to Schema Section

1. In the left sidebar, click **"Schema"**
2. You'll see tabs:
   - Record Types
   - Security Roles
   - Subscription Types
   - Indexes

### Step 4: Import Schema (Automatic Method)

⚠️ **Note**: CloudKit Dashboard does NOT have a direct JSON import feature. You have two options:

#### Option A: Manual Creation (Recommended for First-Time Setup)
Follow the manual setup steps below to create each record type.

#### Option B: Use CloudKit Console API (Advanced)
Use Apple's CloudKit console API with the schema file. This requires programming knowledge.

---

## Manual Schema Setup (Recommended)

Since CloudKit Dashboard doesn't support direct JSON import, follow these steps to manually create the schema:

### Record Type 1: **Trip**

1. Click **"Record Types"** tab
2. Click **"+"** button (top right)
3. Enter Record Type Name: `Trip`
4. Click **"Create"**
5. Add fields by clicking **"Add Field"**:

| Field Name | Type | Queryable | Sortable |
|------------|------|-----------|----------|
| name | String | ✓ | ✓ |
| destination | String | ✓ | ✓ |
| startDate | Date/Time | ✓ | ✓ |
| endDate | Date/Time | ✓ | ✓ |
| latitude | Double | ✗ | ✗ |
| longitude | Double | ✗ | ✗ |
| ownerID | String | ✓ | ✗ |
| memberIDs | String List | ✗ | ✗ |
| shareRecord | Reference | ✗ | ✗ |

6. Click **"Save"** when done

### Record Type 2: **ItineraryEvent**

1. Click **"+"** to create new record type
2. Name: `ItineraryEvent`
3. Add fields:

| Field Name | Type | Queryable | Sortable |
|------------|------|-----------|----------|
| tripID | Reference | ✓ | ✗ |
| name | String | ✓ | ✓ |
| eventDate | Date/Time | ✓ | ✓ |
| startTime | Date/Time | ✓ | ✓ |
| locationName | String | ✗ | ✗ |
| latitude | Double | ✗ | ✗ |
| longitude | Double | ✗ | ✗ |
| notes | String | ✗ | ✗ |

4. For `tripID` reference field:
   - Type: Reference
   - Reference Type: `Trip`
   - Action: `Delete Self` (when Trip is deleted, delete events)

5. Click **"Save"**

### Record Type 3: **TodoItem**

1. Create new record type: `TodoItem`
2. Add fields:

| Field Name | Type | Queryable | Sortable |
|------------|------|-----------|----------|
| tripID | Reference | ✓ | ✗ |
| title | String | ✓ | ✓ |
| completedBy | String List | ✗ | ✗ |
| createdBy | String | ✓ | ✗ |
| createdDate | Date/Time | ✓ | ✓ |

3. `tripID` reference → `Trip` with `Delete Self` action
4. Click **"Save"**

### Record Type 4: **TicketDocument**

1. Create new record type: `TicketDocument`
2. Add fields:

| Field Name | Type | Queryable | Sortable |
|------------|------|-----------|----------|
| tripID | Reference | ✓ | ✗ |
| fileName | String | ✓ | ✓ |
| fileType | String | ✗ | ✗ |
| imageAsset | Asset | ✗ | ✗ |
| uploadedBy | String | ✓ | ✗ |
| uploadDate | Date/Time | ✓ | ✓ |

3. `tripID` reference → `Trip` with `Delete Self` action
4. Click **"Save"**

### Record Type 5: **TripNote**

1. Create new record type: `TripNote`
2. Add fields:

| Field Name | Type | Queryable | Sortable |
|------------|------|-----------|----------|
| tripID | Reference | ✓ | ✗ |
| content | String | ✗ | ✗ |
| lastEditedBy | String | ✗ | ✗ |
| lastEditDate | Date/Time | ✓ | ✓ |

3. `tripID` reference → `Trip` with `Delete Self` action
4. Click **"Save"**

### Record Type 6: **TripMember**

1. Create new record type: `TripMember`
2. Add fields:

| Field Name | Type | Queryable | Sortable |
|------------|------|-----------|----------|
| tripID | Reference | ✓ | ✗ |
| userID | String | ✓ | ✗ |
| name | String | ✓ | ✓ |
| phoneNumber | String | ✗ | ✗ |
| notificationsEnabled | Int(64) | ✗ | ✗ |
| joinedDate | Date/Time | ✓ | ✓ |

3. `tripID` reference → `Trip` with `Delete Self` action
4. Click **"Save"**

---

## Configure Indexes (Performance Optimization)

Indexes make queries faster. Add these for optimal performance:

### Navigate to Indexes Tab

1. Click **"Indexes"** in the Schema section
2. For each record type, add recommended indexes:

### Trip Indexes
- **Index 1**: `startDate` (ascending)

### ItineraryEvent Indexes
- **Index 1**: `tripID` (ascending), `eventDate` (ascending)
- **Index 2**: `eventDate` (ascending)

### TodoItem Indexes
- **Index 1**: `tripID` (ascending), `createdDate` (ascending)

### TicketDocument Indexes
- **Index 1**: `tripID` (ascending), `uploadDate` (ascending)

### TripNote Indexes
- **Index 1**: `tripID` (ascending)

### TripMember Indexes
- **Index 1**: `tripID` (ascending), `userID` (ascending)

### How to Add an Index:
1. Select the Record Type
2. Click **"Add Index"**
3. Select field(s) to index
4. Choose sort order (ascending/descending)
5. Click **"Save"**

---

## Configure Security Roles

### Default Security Roles

CloudKit provides these by default:
- **World**: Unauthenticated users (public read)
- **Authenticated**: Any signed-in iCloud user
- **Creator**: User who created the record

### Recommended Permissions for This App

#### For "World" Role:
- All record types: **Read only** (allow public sharing)
- No create or write permissions

#### For "Authenticated" Role:
- All record types: **Full access** (read, write, create)
- Users must be signed into iCloud

#### For "Creator" Role:
- All record types: **Full access**
- User can always modify their own records

### How to Configure:
1. Go to **"Security Roles"** tab
2. Click on each role (World, Authenticated, Creator)
3. For each record type, set permissions:
   - Read: ✓
   - Write: ✓ (for Authenticated/Creator only)
   - Create: ✓ (for Authenticated/Creator only)
4. Click **"Save"**

---

## Verify Schema Setup

### Check Each Record Type:

1. Go to **"Schema"** → **"Record Types"**
2. Click on each record type (Trip, ItineraryEvent, etc.)
3. Verify all fields are present with correct types
4. Check that Reference fields point to correct record types

### Test with Sample Data:

1. Go to **"Data"** section (left sidebar)
2. Click **"+"** to create a test record
3. Select `Trip` record type
4. Fill in fields:
   - name: "Test Trip"
   - destination: "Paris"
   - startDate: [choose a date]
   - endDate: [choose a date]
   - ownerID: "test-user"
5. Click **"Save"**
6. Verify record appears in the list

### Test App with Schema:

1. Build and run your app in Xcode
2. Create a trip in the app
3. Go back to CloudKit Dashboard → Data
4. Refresh and verify the trip appears
5. Check that all fields populated correctly

---

## Deploy to Production

⚠️ **IMPORTANT**: Only deploy after thorough testing!

### Prerequisites:
1. ✅ Schema tested extensively in Development
2. ✅ App tested with real users via TestFlight
3. ✅ No schema errors or issues
4. ✅ Ready for App Store release

### Deployment Steps:

1. In CloudKit Dashboard, ensure you're in **Development** environment
2. Click your name/menu (top right)
3. Select **"Deploy Schema Changes"**
4. Choose **"To Production"**
5. Review changes carefully
6. Click **"Deploy"**
7. Wait for deployment to complete (can take several minutes)

### ⚠️ Production Warning:
- Production schema changes are **permanent**
- Cannot be undone
- Affects all App Store users
- Plan carefully before deploying

---

## Alternative: Programmatic Schema Creation

The app is already configured to create schema automatically via `CloudKitManager.swift`. The schema will be created when:

1. First trip is created
2. First event is added
3. First todo item is added
4. Etc.

### Automatic Schema Creation Advantages:
- ✅ No manual setup required
- ✅ Schema stays in sync with code
- ✅ Faster development iteration

### Manual Schema Creation Advantages:
- ✅ Better control and validation
- ✅ Can add custom indexes
- ✅ Can configure advanced security
- ✅ Can test schema independently

**Recommendation**: For this app, automatic creation works well. Manual setup is optional but provides more control.

---

## Schema File Reference

The `CloudKitSchema.json` file contains the complete schema definition. Use it as reference when manually creating record types.

### File Location:
```
/Users/taylordrew/Documents/getinloser2/CloudKitSchema.json
```

### File Contents:
- **Record Types**: All 6 record types with fields
- **Indexes**: Performance optimization indexes
- **Security Roles**: Permission configurations

### Using the Schema File:

While CloudKit Dashboard doesn't support direct import, you can:

1. **Reference Guide**: Use as a checklist when manually creating
2. **Version Control**: Track schema changes over time
3. **Documentation**: Share with team members
4. **API Import**: Use with CloudKit server-side APIs (advanced)

---

## Troubleshooting Schema Issues

### Error: "Record type not found"
**Cause**: Schema not created yet
**Fix**: 
- Create record type manually in dashboard, OR
- Let app create it automatically on first use

### Error: "Field type mismatch"
**Cause**: Field type in code doesn't match dashboard
**Fix**: 
- Update dashboard field type, OR
- Update Swift model to match dashboard

### Error: "Cannot modify production schema"
**Cause**: Production schema is locked after deployment
**Fix**: 
- Test in Development first
- Plan schema changes carefully
- Some changes require new fields (can't modify existing)

### Records Not Appearing
**Check**:
1. ✅ Correct environment selected (Development vs Production)?
2. ✅ Correct container selected?
3. ✅ Filters applied in Data view?
4. ✅ App actually saved records (check console logs)?

### Slow Queries
**Fix**: 
- Add indexes for frequently queried fields
- Use indexed fields in query predicates
- Limit result sets with pagination

---

## Best Practices

### Schema Design:
1. ✅ Keep field names consistent and descriptive
2. ✅ Use References for relationships (not string IDs)
3. ✅ Mark frequently queried fields as Queryable
4. ✅ Mark frequently sorted fields as Sortable
5. ✅ Use appropriate field types (String, Int, Double, etc.)

### Development Workflow:
1. ✅ Always test in Development environment first
2. ✅ Use version control for schema JSON file
3. ✅ Document schema changes in commit messages
4. ✅ Test schema migrations before production deploy
5. ✅ Keep Development and Production schemas in sync

### Performance:
1. ✅ Add indexes for common queries
2. ✅ Use compound indexes for multi-field queries
3. ✅ Avoid indexing large text fields
4. ✅ Monitor query performance in CloudKit Dashboard

### Security:
1. ✅ Review security roles carefully
2. ✅ Limit world-readable data
3. ✅ Use authenticated role for user data
4. ✅ Test permissions with different user accounts

---

## Quick Command Reference

### View Development Schema:
1. CloudKit Dashboard → Select Container
2. Select "Development" environment
3. Schema → Record Types

### View Production Schema:
1. CloudKit Dashboard → Select Container
2. Select "Production" environment
3. Schema → Record Types

### Reset Development Database:
1. CloudKit Dashboard → Development environment
2. Data → Reset Development Environment
3. ⚠️ **WARNING**: Deletes ALL development data!

### Export Schema (Manual):
Unfortunately, CloudKit doesn't provide direct export. You must:
1. Manually document schema in JSON (like we did)
2. Or use CloudKit server APIs

---

## Summary Checklist

Before launching your app:

- ☑️ All 6 record types created in Development
- ☑️ All fields configured with correct types
- ☑️ Reference fields set up with proper cascading deletes
- ☑️ Indexes added for performance optimization
- ☑️ Security roles configured appropriately
- ☑️ Test records created and verified
- ☑️ App tested with Development schema
- ☑️ Schema deployed to Production (after testing)
- ☑️ Production tested before App Store release

---

## Additional Resources

### Apple Documentation:
- [CloudKit Schema Management](https://developer.apple.com/documentation/cloudkit/managing_cloudkit_schema)
- [CloudKit Dashboard Guide](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/EnablingiCloudandConfiguringCloudKit/EnablingiCloudandConfiguringCloudKit.html)
- [Record Types and Fields](https://developer.apple.com/documentation/cloudkit/ckrecord)

### Tools:
- CloudKit Dashboard: https://icloud.developer.apple.com/
- CloudKit Console (Terminal): Part of Server-to-Server API

### Support:
- Apple Developer Forums: https://developer.apple.com/forums/
- Stack Overflow: Tag `cloudkit`

---

**App**: Get In Loser - Travel Itinerary Planner  
**Schema Version**: 1.0  
**Last Updated**: December 2025  
**CloudKit Container**: `iCloud.com.yourname.getinloser2`

---

## Notes

The schema file (`CloudKitSchema.json`) is provided as a reference and documentation tool. While CloudKit Dashboard doesn't support direct JSON import, the file serves as:

1. **Documentation**: Complete schema definition
2. **Version Control**: Track changes over time
3. **Team Reference**: Share schema with developers
4. **Manual Setup Guide**: Step-by-step field creation

The app will automatically create the schema if you prefer not to set it up manually. Both approaches work equally well for this application.

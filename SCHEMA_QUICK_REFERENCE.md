id # CloudKit Schema Quick Reference

## Record Types Summary

This is a quick reference for manually setting up CloudKit schema in the dashboard.

---

## 1. Trip
**Purpose**: Main travel trip container

| Field Name | Type | Queryable | Sortable | Notes |
|------------|------|-----------|----------|-------|
| name | String | ✓ | ✓ | Trip name/title |
| destination | String | ✓ | ✓ | Destination city/location |
| startDate | Date/Time | ✓ | ✓ | Trip start date |
| endDate | Date/Time | ✓ | ✓ | Trip end date |
| latitude | Double | ✗ | ✗ | Destination latitude |
| longitude | Double | ✗ | ✗ | Destination longitude |
| ownerID | String | ✓ | ✗ | Creator's iCloud user ID |
| memberIDs | String List | ✗ | ✗ | All member user IDs |
| shareRecord | Reference | ✗ | ✗ | CloudKit share reference |

**Index**: `startDate` (ascending)

---

## 2. ItineraryEvent
**Purpose**: Scheduled activities/events in trip

| Field Name | Type | Queryable | Sortable | Notes |
|------------|------|-----------|----------|-------|
| tripID | Reference → Trip | ✓ | ✗ | Parent trip (DELETE SELF) |
| name | String | ✓ | ✓ | Event name/title |
| eventDate | Date/Time | ✓ | ✓ | Date of event |
| startTime | Date/Time | ✓ | ✓ | Event start time |
| locationName | String | ✗ | ✗ | Location description |
| latitude | Double | ✗ | ✗ | Event latitude |
| longitude | Double | ✗ | ✗ | Event longitude |
| notes | String | ✗ | ✗ | Event notes/details |

**Indexes**: 
- `tripID` + `eventDate` (ascending)
- `eventDate` (ascending)

---

## 3. TodoItem
**Purpose**: Shared checklist tasks

| Field Name | Type | Queryable | Sortable | Notes |
|------------|------|-----------|----------|-------|
| tripID | Reference → Trip | ✓ | ✗ | Parent trip (DELETE SELF) |
| title | String | ✓ | ✓ | Task description |
| completedBy | String List | ✗ | ✗ | User IDs who completed |
| createdBy | String | ✓ | ✗ | Creator user ID |
| createdDate | Date/Time | ✓ | ✓ | When task was created |

**Index**: `tripID` + `createdDate` (ascending)

---

## 4. TicketDocument
**Purpose**: Photos/PDFs of tickets and documents

| Field Name | Type | Queryable | Sortable | Notes |
|------------|------|-----------|----------|-------|
| tripID | Reference → Trip | ✓ | ✗ | Parent trip (DELETE SELF) |
| fileName | String | ✓ | ✓ | Document filename |
| fileType | String | ✗ | ✗ | MIME type (image/pdf) |
| imageAsset | Asset | ✗ | ✗ | File data |
| uploadedBy | String | ✓ | ✗ | Uploader user ID |
| uploadDate | Date/Time | ✓ | ✓ | Upload timestamp |

**Index**: `tripID` + `uploadDate` (ascending)

---

## 5. TripNote
**Purpose**: Shared collaborative notes

| Field Name | Type | Queryable | Sortable | Notes |
|------------|------|-----------|----------|-------|
| tripID | Reference → Trip | ✓ | ✗ | Parent trip (DELETE SELF) |
| content | String | ✗ | ✗ | Note content (large text) |
| lastEditedBy | String | ✗ | ✗ | Last editor user ID |
| lastEditDate | Date/Time | ✓ | ✓ | Last edit timestamp |

**Index**: `tripID` (ascending)

---

## 6. TripMember
**Purpose**: Trip participant information

| Field Name | Type | Queryable | Sortable | Notes |
|------------|------|-----------|----------|-------|
| tripID | Reference → Trip | ✓ | ✗ | Parent trip (DELETE SELF) |
| userID | String | ✓ | ✗ | iCloud user ID |
| name | String | ✓ | ✓ | Display name |
| phoneNumber | String | ✗ | ✗ | Contact phone |
| notificationsEnabled | Int(64) | ✗ | ✗ | 1=on, 0=off |
| joinedDate | Date/Time | ✓ | ✓ | When user joined trip |

**Index**: `tripID` + `userID` (ascending)

---

## Security Roles Configuration

### World (Unauthenticated)
- All record types: **Read only**
- Create: ✗
- Write: ✗

### Authenticated (iCloud signed in)
- All record types: **Full access**
- Create: ✓
- Write: ✓
- Read: ✓

### Creator (Record owner)
- All record types: **Full access**
- Always can modify own records

---

## Reference Field Configuration

All child record types have a `tripID` reference field:

**Settings**:
- Reference Type: `Trip`
- Delete Action: **Delete Self**
  - When Trip is deleted, all child records are deleted automatically

**Child Records**:
- ItineraryEvent
- TodoItem
- TicketDocument
- TripNote
- TripMember

---

## Field Type Guide

| CloudKit Type | Swift Type | Use For |
|--------------|------------|---------|
| String | String | Text, IDs, names |
| String List | [String] | Multiple values |
| Int(64) | Int | Numbers, counts, flags |
| Double | Double | Coordinates, decimals |
| Date/Time | Date | Timestamps, dates |
| Asset | CKAsset | Files, images, PDFs |
| Reference | CKRecord.Reference | Relationships |

---

## Setup Checklist

In CloudKit Dashboard (Development):

1. **Record Types**
   - ☑️ Trip
   - ☑️ ItineraryEvent
   - ☑️ TodoItem
   - ☑️ TicketDocument
   - ☑️ TripNote
   - ☑️ TripMember

2. **All Fields Added**
   - ☑️ Correct types
   - ☑️ Queryable/Sortable set
   - ☑️ Reference fields configured

3. **Indexes Created**
   - ☑️ Trip: startDate
   - ☑️ ItineraryEvent: tripID+eventDate, eventDate
   - ☑️ TodoItem: tripID+createdDate
   - ☑️ TicketDocument: tripID+uploadDate
   - ☑️ TripNote: tripID
   - ☑️ TripMember: tripID+userID

4. **Security Roles**
   - ☑️ World: Read only
   - ☑️ Authenticated: Full access
   - ☑️ Creator: Full access

5. **Testing**
   - ☑️ Create test Trip record
   - ☑️ Verify in Data section
   - ☑️ Test with app
   - ☑️ Test multi-device sync

6. **Production**
   - ☑️ Thorough testing in Development
   - ☑️ Schema deployed to Production
   - ☑️ Verified in Production environment

---

## Common Field Patterns

### User Identification
```
ownerID: String (creator's iCloud user ID)
userID: String (member's iCloud user ID)
createdBy: String (who created the record)
```

### Timestamps
```
createdDate: Date/Time
lastEditDate: Date/Time
uploadDate: Date/Time
joinedDate: Date/Time
```

### Location Data
```
latitude: Double
longitude: Double
locationName: String (human-readable)
```

### References
```
tripID: Reference → Trip (with DELETE SELF)
shareRecord: Reference (for CloudKit sharing)
```

---

## Dashboard URL
https://icloud.developer.apple.com/

**Container Format**: `iCloud.com.yourname.getinloser2`

Replace `yourname` with your Bundle Identifier prefix.

---

For detailed setup instructions, see:
- `CLOUDKIT_SCHEMA_IMPORT_GUIDE.md` - Full setup guide
- `CLOUDKIT_SETUP.md` - General CloudKit configuration
- `CloudKitSchema.json` - Complete schema definition

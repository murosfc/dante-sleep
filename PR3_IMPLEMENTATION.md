# PR 3: Sleep Entries Migration to Firestore - IMPLEMENTATION COMPLETE

## What was implemented

### 1. **Updated SleepEntry Model** (lib/models/entry.dart)
- Added `firestoreId` to track Firestore document ID
- Added `syncStatus` field ('synced', 'pending', 'failed')
- Added `createdAt` and `updatedAt` timestamps
- Added `toFirestore()` method for sending to Firestore
- Added `fromFirestore()` factory method to deserialize from Firestore

### 2. **New SyncQueueItem Model** (lib/models/sync_queue_item.dart)
- Represents queued operations (create, update, delete)
- Stores operation status and data
- Persists to SharedPreferences for offline reliability
- Can be serialized/deserialized with toJson()/fromJson()

### 3. **Firebase Service Updates** (lib/services/firebase_service.dart)
**New collection structure:**
```
sleep_entries/{uid}/
  └─ entries/{entryId}  (subcollection with all user's cards)
```

**New methods:**
- `createSleepEntry(userId, entryData)` → Creates entry, returns docId
- `updateSleepEntry(userId, entryId, entryData)` → Updates existing entry
- `deleteSleepEntry(userId, entryId)` → Deletes entry
- `getSleepEntriesStream(userId)` → Returns real-time stream of entries
- `migrateSleepEntriesToFirestore(userId, entries)` → Batch migrate old entries

### 4. **AppProvider with Offline Sync** (lib/providers/app_provider.dart)

**New properties:**
- `_syncQueue: List<SyncQueueItem>` - stores pending operations
- `_isMigratingData: bool` - prevents concurrent migrations

**Updated methods:**
All CRUD operations now:
1. Update local state
2. Add to sync queue
3. Call `_syncToFirestore()` in background
4. Persist to SharedPreferences (backup)

Updated methods:
- `toggleButton()` - creates or updates entry with queue
- `toggleBottle()` - queues bottle update
- `editBottleTime()` - queues time update
- `editSlept()` / `editWokeUp()` - queue time edits
- `updateEntryPeriod()` / `updateSelectedPeriod()` - queue period changes
- `updateSelectedBottle()` - queue bottle toggle
- `deleteEntry()` - queues deletion

**New methods:**
- `_addToSyncQueue(operation, entry)` - adds item to queue
- `_syncToFirestore()` - attempts to sync all pending items
  - Handles create/update/delete for each operation
  - Updates local `firestoreId` after successful create
  - Removes synced items from queue
  - Saves queue to SharedPreferences
  - Marks entries as synced
- `_loadSyncQueue()` - loads queue from SharedPreferences on startup
- `_saveSyncQueue()` - persists queue after modifications
- `_migrateOldEntriesToFirestore()` - migrates old entries on first auth
  - Reads from `entries` in SharedPreferences
  - Batch uploads to Firestore
  - Marks migration as done to prevent re-runs

**Updated `loadData()`:**
- Loads sync queue from SharedPreferences
- Calls migration after settings loaded
- Triggers sync of pending operations

**Updated `loadSettingsFromCurrentUser()`:**
- Called after login (email/Google)
- Triggers migration
- Syncs pending operations immediately

## Behavior Flow

### On App Startup (no auth):
1. Load local entries from SharedPreferences
2. Load sync queue from SharedPreferences
3. Display entries from local storage

### After User Login:
1. `loadSettingsFromCurrentUser()` is called
2. Check if migration needed (`entries_migrated_${uid}` flag)
3. If yes: batch upload all old SharedPreferences entries to Firestore
4. Sync any pending operations in queue
5. Entries now sync bidirectionally

### When User Creates/Edits/Deletes Entry:
1. Update local list immediately (optimistic UI)
2. Add operation to sync queue
3. Save updated entries to SharedPreferences
4. Start background sync via `_syncToFirestore()`
5. If online: sync to Firestore, update entry status to 'synced'
6. If offline: operations stay in queue, will sync when connection returns

### Sync Queue Persistence:
- Queue stored in SharedPreferences as JSON
- Each item has status: pending → syncing → synced/failed
- Failed items stay in queue for retry
- Synced items removed from queue after successful upload

## Data Structure in Firestore

```
sleep_entries/
  {uid}/
    entries/
      {entryId1}
        createdAt: "2026-04-24T10:30:00Z"
        updatedAt: "2026-04-24T11:00:00Z"
        wokeUp: "2026-04-24T11:00:00Z"
        slept: "2026-04-24T10:30:00Z"
        isDay: true
        bottle: true
        bottleTime: "2026-04-24T10:45:00Z"
      {entryId2}
        ...
```

## Offline-First Architecture

1. **Local-first writes**: All operations succeed locally immediately
2. **Background sync**: Async upload to Firestore
3. **Queue persistence**: Failed syncs survive app restart
4. **Automatic retry**: `_syncToFirestore()` called after every change
5. **Fallback**: SharedPreferences always has latest local state

## Security Rules (Firebase Console)

Before publishing, set these rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /sleep_entries/{userId}/entries/{entryId} {
      allow read, write, delete: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Testing Checklist

- [ ] Create entry → verify `syncStatus: 'pending'` → verify sync to Firestore
- [ ] Edit entry (time, bottle, period) → verify queue → verify sync
- [ ] Delete entry → verify queue → verify deletion in Firestore
- [ ] Go offline → create entry → verify queue → go online → verify sync
- [ ] Restart app with pending entries → verify sync continues
- [ ] Old entries migrated on first login → check Firestore console

## Next Steps (Optional Future PRs)

1. **Real-time sync UI**: Add StreamBuilder to MainScreen to listen directly to Firestore changes
2. **Sync status indicator**: Show pending/syncing/synced/failed status per entry in UI
3. **Conflict resolution**: Handle same entry edited on multiple devices
4. **Batch operations**: Use WriteBatch for larger migrations
5. **Data export**: Include Firestore entries in CSV export

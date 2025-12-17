# Fixing Firestore Timeout - Index Creation Guide

## Problem
Firestore queries are timing out after 15 seconds when fetching trades.

## Root Cause
The query in `TradeSyncService.fetchTrades()` uses:
```dart
_tradesCollection(userId)
    .orderBy('entryDate', descending: true)
    .limit(limitCount)
```

This query on a subcollection (`users/{userId}/trades`) requires a **composite index**.

## Solution

### Option 1: Create Index via Firebase Console (Recommended)

1. Open the [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `trading-app-68902`
3. Go to **Firestore Database** → **Indexes** tab
4. Click **Create Index**
5. Configure:
   - **Collection ID**: `trades`
   - **Query scope**: `Collection group`
   - **Fields to index**:
     - Field: `entryDate`, Order: `Descending`
   - Click **Create Index**

6. Wait for index to build (can take 5-10 minutes for existing data)

### Option 2: Create Index via CLI

```bash
firebase firestore:indexes
```

This will show you existing indexes and suggest missing ones.

### Option 3: Let Firestore Auto-Generate

When you run a query that needs an index, Firestore logs a console error with a direct link:

1. Open browser DevTools (F12)
2. Look for console error: `The query requires an index. You can create it here: https://console.firebase.google.com/...`
3. Click the link to auto-create the index

## Index Configuration

```json
{
  "indexes": [
    {
      "collectionGroup": "trades",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {
          "fieldPath": "entryDate",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

## Verification

After creating the index:

1. Clear browser cache
2. Logout and login again
3. Watch DevTools Console for Firestore timing logs:

**Expected**:
```
🔥 [FIRESTORE] FETCH_START | collection: users/xxx/trades
🔥 [FIRESTORE] FETCH_SUCCESS | docs: 15
⏱️ [DEBUG] BackgroundSync END (500ms) | 15 trades synced
```

**Time should be < 2 seconds** ✅

## Firestore Security Rules

Also verify your security rules allow reads:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own trades
    match /users/{userId}/trades/{tradeId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Alternative: Single Collection Design

If subcollections are problematic, consider migrating to a single `trades` collection:

```
trades/{tradeId}
  - userId: string
  - symbol: string
  - entryDate: timestamp
  - ...
```

Query:
```dart
_firestore.collection('trades')
  .where('userId', isEqualTo: userId)
  .orderBy('entryDate', descending: true)
  .limit(100)
```

This requires only a single-field index on `entryDate` (automatically created).

## Current Mitigation

The app now uses **local-first loading**, so the timeout doesn't block the UI:
- Local cache loads in < 200ms
- Background sync runs without blocking
- If sync fails, user still has local data

This makes the timeout **low priority** but still worth fixing for:
- Cross-device sync
- New device first-time load
- Fresh data after other user edits


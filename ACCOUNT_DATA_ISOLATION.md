# Account Data Isolation & Cross-Device Sync

This document explains how trade/journal data is stored, scoped by user, and synced across devices.

---

## Architecture Overview

The trading journal uses a **hybrid storage architecture**:

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Cloud (Source of Truth)** | Firebase Firestore | Cross-device sync, data persistence |
| **Local Cache** | Hive | Offline access, fast reads |

---

## Data Isolation (Multi-User)

### How Trades Are Scoped

1. **Every trade has a `userId` field** - set to the Firebase Auth UID of the user who created it
2. **Strict filtering** - when loading trades, only trades matching the current user's UID are returned
3. **No leakage** - trades without a userId (legacy) are NOT returned to logged-in users

### Relevant Code

**Trade Model** (`lib/models/trade.dart`):
```dart
@HiveField(16)
final String? userId;  // Firebase Auth UID
```

**Repository Filter** (`lib/services/trade_repository.dart`):
```dart
List<Trade> getAllTrades({String? userId}) {
  if (userId != null) {
    // STRICT: Only return trades belonging to this user
    trades = trades.where((t) => t.userId == userId).toList();
  }
}
```

### Re-initialization on Auth Changes

**Problem solved**: Previously, if User A logged in, then logged out and User B logged in, User B would see User A's trades (still in memory).

**Solution** (`lib/main.dart` - `AppInitializer`):
```dart
@override
void didChangeDependencies() {
  // Watch for auth changes
  final currentUserId = authProvider.user?.uid;
  
  // If user changed, reinitialize all providers
  if (_isInitialized && currentUserId != _lastUserId) {
    _reinitializeForNewUser(currentUserId);
  }
}
```

---

## Cross-Device Sync

### How It Works

1. **On Login**: TradeProvider fetches trades from Firestore for the current user
2. **On Create/Update/Delete**: Trade is saved to both local Hive AND Firestore
3. **Firestore is source of truth**: If cloud has trades, they take precedence over local cache

### Sync Service (`lib/services/trade_sync_service.dart`)

```dart
// Fetch trades from cloud
Future<List<Trade>> fetchTrades(String userId)

// Save trade to cloud
Future<bool> saveTrade(Trade trade)

// Delete trade from cloud
Future<bool> deleteTrade(String tradeId, String userId)
```

### Firestore Structure

```
users/
  └── {userId}/
      └── trades/
          └── {tradeId}: {
              symbol: "AAPL",
              side: "long",
              entryPrice: 150.00,
              ...
          }
```

---

## Logout Behavior

When a user logs out:

1. **Auth state changes** → `AuthProvider` sets state to `unauthenticated`
2. **AppInitializer detects change** → calls `_reinitializeForNewUser(null)`
3. **TradeProvider.init(userId: null)** → clears `_trades` list, loads only trades without userId (none for logged-in users)
4. **UI rebuilds** → shows empty journal (or login screen)

---

## Testing Checklist

### Account Isolation (PC)
- [ ] Create trade as User A → appears in A's journal
- [ ] Log out, log in as User B → B sees empty journal (not A's trades)
- [ ] Log back in as User A → A sees only A's trades

### Cross-Device Sync
- [ ] Create trade on PC as User A
- [ ] Open app on phone, log in as User A → same trade appears
- [ ] Create trade on phone → appears on both PC and phone after refresh

### Edge Cases
- [ ] Offline mode: trades save locally, sync when online
- [ ] Restart app: trades persist correctly per user
- [ ] Fast login/logout switching: no data leakage

---

## Migration (Legacy Data)

### Old trades without userId

Trades created before this fix don't have a `userId` field. They are:

1. **NOT shown to logged-in users** (strict filtering)
2. **Only visible in offline/no-auth mode**

### To clear old data

Go to **Settings → Clear All Trades** to remove all local trades and start fresh.

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/main.dart` | Added auth change detection and provider reinitialization |
| `lib/state/trade_provider.dart` | Added sync service integration, strict userId filtering |
| `lib/services/trade_repository.dart` | Strict userId filtering (no more `|| userId == null`) |
| `lib/services/trade_sync_service.dart` | **NEW** - Firestore sync service |
| `lib/screens/settings_screen.dart` | Added "Clear All Trades" button |

---

## Troubleshooting

### "I see another user's trades"
- This should not happen after this fix
- Check: Is the app fully restarted? Try logout → restart app → login

### "Phone doesn't show trades from PC"
- Ensure both devices are online
- Check Firebase console for the trades collection
- Pull-to-refresh or restart the app

### "Trades disappear after restart"
- Check if userId is being set correctly (enable debug logs)
- Verify Firebase connection

---

_Last updated: December 2024_


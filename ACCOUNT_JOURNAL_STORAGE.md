# Account Journal Storage & Cross-Device Sync

## Overview

The Trading Journal uses a **Firestore-first architecture** for trade storage, ensuring:
- **Per-user isolation**: Each user only sees their own trades
- **Cross-device sync**: Same account shows same trades on any device
- **Offline support**: Local Hive cache for offline access

---

## Architecture

### Data Storage Locations

| Location | Purpose | Source of Truth |
|----------|---------|-----------------|
| **Firebase Firestore** | Remote database | ✅ YES |
| **Hive (IndexedDB on web)** | Local cache | No (mirrors Firestore) |

### Firestore Structure

```
users/
  {userId}/
    trades/
      {tradeId}/
        - symbol: String
        - side: "long" | "short"
        - quantity: Number
        - entryPrice: Number
        - exitPrice: Number?
        - entryDate: Timestamp
        - exitDate: Timestamp?
        - tags: String[]
        - notes: String?
        - stopLoss: Number?
        - takeProfit: Number?
        - userId: String (REQUIRED)
        - createdAt: Timestamp
        - updatedAt: Timestamp
```

---

## User Scoping

### How Trades Are Associated with Users

Every trade **MUST** have a `userId` field set. This is enforced at multiple levels:

1. **TradeProvider.addTrade()**: Rejects trades if `_userId` is null
2. **PaperTradingProvider._onTradeClosed()**: Rejects trades if `trade.userId` is null
3. **PaperTradingEngine**: Passes `userId` through to created trades

### How Trades Are Filtered

When loading trades:

```dart
// TradeProvider.init()
if (userId == null) {
  _trades = []; // Logged out - show nothing
} else {
  _trades = await _syncService.fetchTrades(userId); // Firestore source
}
```

---

## Cross-Device Sync

### On Login

1. User logs in → `AuthProvider.user` changes
2. `AppInitializer.didChangeDependencies()` detects change
3. `TradeProvider.init(userId: newUserId)` is called
4. Firestore fetch replaces local cache
5. UI shows user's trades

### On Trade Creation

1. Trade saved to local Hive cache
2. Trade saved to Firestore (synchronous for paper trades)
3. UI updates immediately

### On Logout

1. User logs out → `AuthProvider.user` becomes null
2. `TradeProvider.init(userId: null)` is called
3. In-memory trades list cleared
4. UI shows empty state

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/state/trade_provider.dart` | Trade state management, Firestore sync |
| `lib/services/trade_repository.dart` | Local Hive storage |
| `lib/services/trade_sync_service.dart` | Firestore CRUD operations |
| `lib/state/paper_trading_provider.dart` | Paper trading → journal integration |
| `lib/main.dart` | Auth change detection, provider reinit |

---

## Testing Checklist

### Account Isolation (Same Device)

- [ ] User A creates trade → A sees it
- [ ] User A logs out → Journal is empty
- [ ] User B logs in → B sees NO trades from A
- [ ] User A logs back in → A sees only A's trades

### Cross-Device Sync

- [ ] User A creates trade on Desktop Web
- [ ] User A logs in on Mobile Web → Same trades appear
- [ ] User A deletes trade on Mobile → Disappears on Desktop

### Persistence

- [ ] User creates trade → Refresh page → Trade still there
- [ ] User creates trade → Close browser → Reopen → Trade still there

### Edge Cases

- [ ] Creating trade while offline → Syncs when back online
- [ ] Orphan trades (no userId) don't appear for any user

---

## Migration

### Orphan Trades (Legacy)

Trades created before userId enforcement may not have a `userId`. These are:
- **NOT shown** to any logged-in user
- Can be migrated via `TradeProvider.migrateOrphanTrades()`
- Can be deleted via `TradeProvider.deleteOrphanTrades()`

### Migration Options

1. **Auto-migrate on login**: Add to `TradeProvider.init()`:
   ```dart
   await migrateOrphanTrades();
   ```

2. **Manual migration**: Add a button in Settings to migrate/delete orphan trades

---

## Troubleshooting

### Trades not showing

1. Check console for Firestore errors
2. Verify user is logged in (`AuthProvider.user != null`)
3. Check Firestore rules allow read for the user
4. Try `TradeProvider.fullSync()` to force refresh

### Trades leaking between accounts

1. Ensure all trades have `userId` set
2. Check `TradeProvider._userId` matches `AuthProvider.user.uid`
3. Run `deleteOrphanTrades()` to clean up legacy data

### Mobile web shows different trades than desktop

1. Both must be online for sync to work
2. Check network connectivity
3. Force refresh on both devices


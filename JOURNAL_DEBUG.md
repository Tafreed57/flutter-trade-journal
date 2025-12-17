# Journal Debug Guide

## Overview

This document explains how to debug trading journal issues including:
- Chart trades not saving
- Journal loading forever
- Account-specific loading issues

---

## Debug Instrumentation

The app includes comprehensive debug logging via `JournalDebug` class in `lib/core/debug_trace.dart`.

### Log Prefixes

| Prefix | Category |
|--------|----------|
| ⏱️ [DEBUG] | Timing/duration measurement |
| 🔐 [AUTH] | Authentication events |
| 📋 [JOURNAL] | Journal load/query events |
| 📊 [CHART_TRADE] | Chart-based trade events |
| ✏️ [MANUAL_TRADE] | Manual trade events |
| 🔥 [FIRESTORE] | Firestore operations |
| 🔄 [STATE] | State transitions |
| ⚠️ [DEBUG_WARN] | Warnings |
| ❌ [DEBUG_ERROR] | Errors |

---

## Expected Log Sequence

### Successful Chart Trade Close

```
📊 [CHART_TRADE] CLOSE_POSITION_START | posId: abc12345...
📊 [CHART_TRADE] POSITION_CLOSE_START | posId: abc12345..., symbol: BTCUSD, userId: xyz98765...
📊 [CHART_TRADE] CREATE_JOURNAL_ENTRY_START | symbol: BTCUSD, posId: abc12345...
📊 [CHART_TRADE] TRADE_OBJECT_CREATED | tradeId: def11111...
📊 [CHART_TRADE] CALLING_ON_TRADE_CLOSED | tradeId: def11111...
⏱️ [DEBUG] PaperTrading._onTradeClosed START
📊 [CHART_TRADE] CLOSE_CALLBACK_START | symbol: BTCUSD, tradeId: def11111..., userId: xyz98765...
📊 [CHART_TRADE] SAVING_TO_HIVE | tradeId: def11111...
📊 [CHART_TRADE] SAVED_TO_HIVE | tradeId: def11111...
⏱️ [DEBUG] Firestore.saveTrade START
🔥 [FIRESTORE] SAVE_START | collection: users/xyz98765.../trades, docId: def11111...
🔥 [FIRESTORE] SAVE_SUCCESS | docId: def11111...
⏱️ [DEBUG] Firestore.saveTrade END (234ms) | SUCCESS
📊 [CHART_TRADE] SAVED_TO_FIRESTORE | tradeId: def11111...
⏱️ [DEBUG] PaperTrading._onTradeClosed END (245ms) | SUCCESS
📊 [CHART_TRADE] ON_TRADE_CLOSED_COMPLETE | tradeId: def11111...
📊 [CHART_TRADE] POSITION_CLOSE_COMPLETE | posId: abc12345...
📊 [CHART_TRADE] CLOSE_POSITION_SUCCESS | posId: abc12345...
```

### Successful Journal Load

```
⏱️ [DEBUG] TradeProvider.init START
📋 [JOURNAL] INIT_START | userId: xyz98765...
📋 [JOURNAL] FETCHING_FROM_FIRESTORE | userId: xyz98765...
⏱️ [DEBUG] Firestore.fetchTrades START
🔥 [FIRESTORE] FETCH_START | collection: users/xyz98765.../trades
🔥 [FIRESTORE] FETCH_SUCCESS | collection: users/xyz98765.../trades, docs: 15
⏱️ [DEBUG] Firestore.fetchTrades END (523ms) | 15 trades
📋 [JOURNAL] FIRESTORE_FETCH_COMPLETE | userId: xyz98765..., trades: 15, source: Firestore
⏱️ [DEBUG] TradeProvider.init END (534ms) | 15 trades
📋 [JOURNAL] INIT_SUCCESS | userId: xyz98765..., trades: 15
```

---

## Common Failure Patterns

### 1. Chart Trade Not Saving (onTradeClosed is null)

```
⚠️ [DEBUG_WARN] onTradeClosed callback is null - trade will NOT be saved!
```

**Cause**: `PaperTradingEngine.onTradeClosed` callback not set.

**Fix**: Ensure `PaperTradingProvider` constructor sets `_engine.onTradeClosed = _onTradeClosed;`

### 2. Trade Missing userId

```
📊 [CHART_TRADE] CLOSE_REJECTED | symbol: BTCUSD, error: No userId on trade
```

**Cause**: Position was created without `userId` being passed through.

**Fix**: Check `PaperTradingProvider._userId` is set before trading.

### 3. Firestore Save Timeout

```
🔥 [FIRESTORE] SAVE_TIMEOUT | docId: def11111..., error: Timed out after 10 seconds
```

**Cause**: Network issues or Firestore is slow/unavailable.

**Fix**: Check network connection. Trade is still saved locally.

### 4. Journal Load Timeout

```
🔥 [FIRESTORE] FETCH_TIMEOUT | collection: users/xyz.../trades, error: Timed out after 15 seconds
```

**Cause**: Network issues or too many trades.

**Fix**: App will fallback to local cache. User can retry.

### 5. Firestore Permissions Error

```
🔥 [FIRESTORE] FETCH_ERROR | collection: users/xyz.../trades, error: permission-denied
```

**Cause**: Firestore security rules don't allow this user to read.

**Fix**: Check Firestore rules allow `users/{userId}/trades` read for authenticated users.

---

## Reproducing Issues

### Chart Trade Not Saving

1. Open browser DevTools (F12)
2. Go to Console tab
3. Open Chart screen
4. Place a position (Long/Short tool or Buy/Sell)
5. Close the position
6. Check logs for `CHART_TRADE` entries
7. Verify `ON_TRADE_CLOSED_COMPLETE` appears

### Journal Loading Forever

1. Open browser DevTools (F12)
2. Clear site data (Application > Storage > Clear site data)
3. Reload the page
4. Login to your account
5. Watch for `JOURNAL` logs
6. If `INIT_SUCCESS` never appears, check for errors

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/debug_trace.dart` | Debug instrumentation |
| `lib/state/trade_provider.dart` | Journal state management |
| `lib/state/paper_trading_provider.dart` | Paper trading state |
| `lib/services/paper_trading_engine.dart` | Position lifecycle |
| `lib/services/trade_sync_service.dart` | Firestore sync |
| `lib/services/trade_repository.dart` | Local Hive storage |

---

## Timeouts

| Operation | Timeout | Fallback |
|-----------|---------|----------|
| Firestore fetch trades | 15 seconds | Local cache |
| Firestore save trade | 10 seconds | Local only |

---

## Verification Checklist

### Chart Trade Saves

- [ ] Open position from chart tool
- [ ] Close position
- [ ] Journal shows trade immediately
- [ ] Refresh page → trade still there
- [ ] Check different account → trade NOT there

### Journal Loads

- [ ] Login → journal loads in <5 seconds
- [ ] New tab → journal loads reliably
- [ ] Empty account → shows "No trades yet" (not spinner)
- [ ] Network offline → shows error with retry

### Account Isolation

- [ ] User A trades not visible to User B
- [ ] Logout clears journal UI
- [ ] Login as different user → correct trades


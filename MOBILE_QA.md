# Mobile QA Checklist

This document provides a comprehensive checklist for manually testing the Trade Journal app on mobile devices after recent changes.

---

## 📱 Test Environments

### Target Devices
- [ ] Small phone (< 360dp width) - e.g., iPhone SE, Galaxy S20
- [ ] Medium phone (360-400dp width) - e.g., iPhone 13, Pixel 5
- [ ] Large phone (> 400dp width) - e.g., iPhone 14 Pro Max, Galaxy S23 Ultra
- [ ] Tablet (600dp+ width) - e.g., iPad Mini, Galaxy Tab

### Platforms
- [ ] Android (Chrome/WebView)
- [ ] iOS (Safari/WebView)
- [ ] Web (Chrome mobile emulator)
- [ ] Web (Firefox mobile emulator)

---

## 🔐 PHASE 1: Sign-Up/Sign-In Auto-Login

### New User Email Sign-Up
- [ ] Open app fresh (not logged in)
- [ ] Tap "Create Account" or navigate to sign-up screen
- [ ] Enter a new email and password
- [ ] Tap "Create Account" button
- [ ] After account creation, user should immediately land in the main app (authenticated)
- [ ] No "Sign in again" prompt should appear
- [ ] Loading indicator shows during the process
- [ ] User's email appears in settings/profile

### New User Google Sign-Up
- [ ] Open app fresh (not logged in)
- [ ] Tap "Sign in with Google"
- [ ] Select a Google account that has NEVER used this app
- [ ] After OAuth completes, user should immediately land in the app (authenticated)
- [ ] No "Sign in again" prompt should appear
- [ ] Loading indicator shows during the process
- [ ] User's email/name appears in settings/profile

### Returning User Email Sign-In
- [ ] Log out from an existing email-authenticated account
- [ ] Enter the same email and password
- [ ] User should immediately land in the app (authenticated)
- [ ] All previous data (trades, drawings) should persist

### Returning User Google Sign-In
- [ ] Log out from an existing Google-authenticated account
- [ ] Tap "Sign in with Google"
- [ ] Select the same Google account
- [ ] User should immediately land in the app (authenticated)
- [ ] All previous data (trades, drawings) should persist

### Error Scenarios
- [ ] Cancel Google OAuth mid-flow → returns to login screen gracefully
- [ ] Slow network → loading state persists, no crash
- [ ] Invalid/expired token → shows appropriate error message
- [ ] Email already exists → shows error message, user can tap "Sign In" link
- [ ] Wrong password → shows error message

---

## 📊 PHASE 2: Mobile Chart UI

### Header / Top Bar
- [ ] Symbol selector is visible and tappable
- [ ] Live/Demo indicator fits without overflow
- [ ] Drawing tools menu icon is visible (pencil icon)
- [ ] Chart settings gear icon is visible
- [ ] No buttons are clipped or overlapping

### Drawing Tools Menu (Mobile)
- [ ] Tap the drawing tools icon → popup menu appears
- [ ] All tools are listed: Trend Line, Horizontal Line, Rectangle, Fibonacci
- [ ] Position tools section: Long Position, Short Position
- [ ] Position Calculator option is available
- [ ] Clear All option appears when drawings exist
- [ ] Menu items are tappable (44px+ touch targets)
- [ ] Selected tool shows checkmark indicator

### Position Tool Settings Sheet
- [ ] Tap "Long Position" → settings sheet appears from bottom
- [ ] Tap "Short Position" → settings sheet appears from bottom
- [ ] Sheet shows: SL% presets (1%, 2%, 3%, 5%)
- [ ] Sheet shows: R:R presets (1:1, 1:1.5, 1:2, 1:3, 1:5)
- [ ] Sheet shows: Quantity presets
- [ ] Summary shows calculated SL%, TP%, and R:R
- [ ] "Place Long/Short Position" button works
- [ ] After confirming, tool is activated and ready for placement

### OHLC Stats Row
- [ ] Stats row (O/H/L/C, Vol, Change%) scrolls horizontally on small screens
- [ ] All values are readable
- [ ] No clipping or overflow

### Timeframe Buttons
- [ ] All timeframes are visible (may require horizontal scroll)
- [ ] Active timeframe is highlighted
- [ ] Tapping a timeframe changes the chart

### Chart Canvas
- [ ] Chart fills available space properly
- [ ] Candlesticks render correctly
- [ ] Touch gestures work: pan, pinch-to-zoom
- [ ] Drawing tools work with touch input
- [ ] Position tools can be placed with single tap

### Trading Panel (Bottom)
- [ ] Account bar shows Balance and Unrealized P&L
- [ ] Tabs (Order / Positions) are visible and switchable
- [ ] Quantity selector is usable
- [ ] SL% and TP% inputs are tappable
- [ ] BUY/SELL buttons are full-width and tappable

### Indicators Panel
- [ ] RSI toggle is accessible (via chart settings or menu)
- [ ] When enabled, RSI panel shows below main chart
- [ ] RSI values are readable

---

## 🎯 PHASE 3: Long/Short Position Tool

### RR Preset Before Placement
- [ ] Open position tool settings sheet
- [ ] Select a SL% preset (e.g., 2%)
- [ ] Select a R:R preset (e.g., 1:2)
- [ ] Confirm the tool
- [ ] Tap on chart to place position
- [ ] Verify: Entry = tap price
- [ ] Verify: SL is 2% away from entry
- [ ] Verify: TP is 4% away from entry (2% × 2 R:R)

### SL/TP Sync: Tool → Panel
- [ ] Place a position tool on chart
- [ ] Select/tap the position tool
- [ ] Check that SL% and TP% in the Order panel update to match the tool
- [ ] Drag the SL line on the chart → SL% in panel updates
- [ ] Drag the TP line on the chart → TP% in panel updates

### SL/TP Sync: Panel → Tool
- [ ] Select an existing position tool
- [ ] Change SL% in the Order panel
- [ ] Verify SL line on chart moves correspondingly
- [ ] Change TP% in the Order panel
- [ ] Verify TP line on chart moves correspondingly

### Position Tool Interactions
- [ ] Tool can be selected by tapping
- [ ] Tool shows visual selection state (highlighted)
- [ ] Deselect tool by tapping elsewhere
- [ ] Delete tool via clear option or delete button
- [ ] Tool persists after app restart

---

## 🖥️ Desktop/Web Regression

### Verify No Regressions
- [ ] All controls are visible and properly spaced on desktop
- [ ] Left sidebar (if present) shows all drawing tools
- [ ] Position tool settings sheet works on desktop too
- [ ] Chart interactions (mouse) work as expected
- [ ] Trading panel layout is unchanged

---

## 🔄 Persistence & State

- [ ] Create a trade → restart app → trade is still there
- [ ] Place a drawing → restart app → drawing is still there
- [ ] Place a position tool → restart app → position tool is still there
- [ ] Sign out → sign in → all data is restored

---

## 🚨 Error & Edge Cases

- [ ] No console errors during normal usage
- [ ] No visual glitches when rotating device (if applicable)
- [ ] Keyboard appears correctly when tapping input fields
- [ ] Bottom sheet dismisses correctly with swipe or tap outside

---

## ✅ Sign-Off

| Tester | Device | Date | Status |
|--------|--------|------|--------|
| | | | |
| | | | |

### Notes
_Add any issues found during testing here:_

1.
2.
3.

---

## 📌 Quick Verification Commands

### Run on Chrome Mobile Emulator
```bash
flutter run -d chrome --web-renderer html
```

### Run on Android Device
```bash
flutter run -d <device_id> --release
```

### Build Web for Testing
```bash
flutter build web --release
firebase serve --only hosting
```

---

_Last updated: December 2024_


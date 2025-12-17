# Video Presentation Script
## Flutter Trading Journal Application
### Duration: 20 Minutes Maximum

---

**Presenter:** [INSERT YOUR FULL NAME]  
**Student ID:** [INSERT STUDENT ID]  
**Solo Project**

---

# TIMELINE OVERVIEW

| Time | Section | Duration |
|------|---------|----------|
| 0:00 - 1:00 | Introduction | 1 min |
| 1:00 - 5:00 | Project Overview | 4 min |
| 5:00 - 12:00 | Live Demo | 7 min |
| 12:00 - 17:00 | Code Walkthrough | 5 min |
| 17:00 - 20:00 | Wrap-up | 3 min |

---

# SECTION 1: INTRODUCTION (0:00 - 1:00)

## On Screen
- Your face (webcam)
- Title slide with project name

## Script

> "Hello, my name is [YOUR FULL NAME], and my student ID is [YOUR ID]. 
>
> Today I'm presenting my solo project for [COURSE NAME]: a Flutter-based Trading Journal and Charting Application.
>
> I am the sole developer of this project, responsible for all design, implementation, and deployment.
>
> This application allows traders to visualize market data, practice trading with virtual money, and track their performance through a comprehensive journaling system.
>
> Let me start by explaining the project architecture, then I'll demonstrate the features live, walk through the key code, and conclude with challenges I faced and lessons learned."

---

# SECTION 2: PROJECT OVERVIEW (1:00 - 5:00)

## On Screen
- Architecture diagram (you can create one or use text/whiteboard)
- README.md visible in IDE

## Script

### 1:00 - 2:00 — Problem & Solution

> "The problem I'm solving is this: retail traders struggle to improve because they don't systematically track their trades. 
>
> Professional trading journals cost $100-300 per month, and they're fragmented—one tool for charts, another for journaling, another for analytics.
>
> My solution is an integrated, cross-platform application that combines:
> - Interactive candlestick charts
> - Paper trading simulator
> - Trade journaling
> - Performance analytics
>
> And it's completely free and open-source."

### 2:00 - 3:30 — Architecture

> "Let me explain the architecture. The application follows clean architecture principles with four distinct layers."

**[Show architecture diagram or explain verbally]**

> "At the top, we have the **Presentation Layer**—Flutter widgets and screens. These are purely for rendering UI.
>
> Below that, the **State Layer** uses Provider for state management. I have providers for market data, trades, drawings, and paper trading.
>
> The **Domain Layer** contains pure Dart services—no Flutter dependencies. This includes the market data engine, paper trading engine, and analytics service. These are fully unit-testable.
>
> Finally, the **Data Layer** handles persistence with Hive, which is a fast NoSQL database that works on all platforms including Web."

### 3:30 - 5:00 — Technology Choices

> "I chose Flutter because:
> 1. Single codebase targets Web, Android, Windows, macOS, and Linux
> 2. CustomPainter gives me full control over chart rendering
> 3. Hot reload accelerates development
>
> For the candlestick chart, I built it from scratch using CustomPainter rather than using a library. This was more work, but it gave me complete control over interactions like position tools with stop-loss and take-profit levels.
>
> For persistence, I use Hive. It's extremely fast, supports complex objects, and works on Web through IndexedDB.
>
> For state management, I use Provider. It's simple, performant, and officially recommended by Flutter.
>
> The app is deployed to Firebase Hosting for Web and builds signed APKs and AABs for Android."

---

# SECTION 3: LIVE DEMO (5:00 - 12:00)

## On Screen
- Running application (Chrome or Android emulator)
- Switch between features as you demonstrate

## Script

### 5:00 - 6:00 — App Launch & Chart

**[Open https://trading-app-68902.web.app in Chrome]**

> "Let me demonstrate the application live. I'll open the deployed web version.
>
> As you can see, the app loads with a candlestick chart. This is real candlestick data—or in this case, mock data that simulates real market behavior.
>
> The chart shows:
> - Green and red candles for up/down price movement
> - Volume bars at the bottom
> - The current price line on the right
> - Time axis at the bottom"

### 6:00 - 7:00 — Chart Interaction

**[Demonstrate zoom and pan]**

> "I can interact with the chart in several ways.
>
> **Zooming:** Using pinch gestures on touch or mouse wheel, I can zoom in to see more detail or zoom out to see more history.
>
> **Panning:** Dragging left and right scrolls through history. The chart loads more historical data as I scroll back.
>
> **Crosshair:** Long-pressing—or on desktop, hovering—shows a crosshair with the OHLC data: Open, High, Low, Close, and Volume for that candle."

### 7:00 - 8:00 — Timeframe Switching

**[Click through timeframes: 1m → 5m → 1H → 1D]**

> "I can switch timeframes using these buttons: 1-minute, 5-minute, 15-minute, 1-hour, and daily.
>
> Watch as I switch from 1-minute to 1-hour—the candles change completely. Each timeframe has its own data series, properly aggregated.
>
> This was actually one of the biggest technical challenges, which I'll discuss later."

### 8:00 - 9:30 — Position Tools

**[Select Long Position tool, place on chart]**

> "Now let me demonstrate the position tools. These are for planning trades with specific risk management.
>
> I'll select 'Long Position' and tap on the chart. This places a position tool at that price level.
>
> You can see:
> - The entry price in blue
> - The stop loss level in red below—this is where I'd exit if the trade goes against me
> - The take profit level in green above—my profit target
> - The risk-reward ratio displayed, which is automatically calculated
>
> I can drag the handles to adjust these levels. As I drag, the R:R ratio updates in real-time.
>
> There's also a 'Short Position' tool for bearish trades, which mirrors this but inverted."

### 9:30 - 10:30 — Paper Trading

**[Execute a paper trade]**

> "The app includes a paper trading simulator. I start with a virtual $10,000 balance.
>
> I'll click 'Buy' to open a long position. I can set the quantity, stop loss, and take profit.
>
> Once executed, the position appears in my positions list with real-time P&L.
>
> If I close the position, the trade is automatically logged to my journal—I don't have to manually enter it."

### 10:30 - 11:15 — Trade Journal

**[Navigate to Trades tab]**

> "Let me show the journaling system. This is where all trades are recorded.
>
> Each trade shows:
> - Symbol and direction
> - Entry and exit prices
> - Profit/loss with color coding
> - Tags for categorization
>
> I can tap on any trade to see details and add notes about why I took the trade and what I learned.
>
> There's also search and filtering—I can filter by symbol, outcome, or date range."

### 11:15 - 12:00 — Analytics

**[Navigate to Analytics tab]**

> "Finally, the analytics dashboard aggregates all my trading data.
>
> I can see:
> - Win rate percentage
> - Total P&L
> - Profit factor
> - Equity curve showing account growth over time
> - P&L breakdown by symbol
> - Calendar heatmap of trading activity
>
> This helps identify patterns—maybe I trade worse on Mondays, or I'm more successful with certain symbols."

---

# SECTION 4: CODE WALKTHROUGH (12:00 - 17:00)

## On Screen
- VS Code or Cursor IDE
- Specific files as mentioned

## Script

### 12:00 - 13:30 — Chart Engine

**[Open lib/widgets/charts/candlestick_chart.dart]**

> "Let me walk through the key code. First, the chart engine.
>
> Open `candlestick_chart.dart`. This file is over 2,400 lines—it's the heart of the application.
>
> The chart is a StatefulWidget that uses CustomPainter for rendering."

**[Scroll to the _CandlestickPainter class]**

> "Here's the painter. The `paint` method is called every frame. It draws in layers:
> - Grid lines first
> - Then candles
> - Volume bars
> - Indicators like EMAs
> - Current price line
> - Position tools
> - Crosshair on top
>
> Each candle is drawn as a rectangle for the body and a line for the wick. Green if close > open, red otherwise."

**[Show gesture handling code]**

> "Gesture handling is complex. I use GestureDetector with scale callbacks for simultaneous pan and zoom. Long press shows the crosshair. Taps can place drawing tools."

### 13:30 - 14:30 — Coordinate Conversion

**[Open lib/widgets/charts/chart_coordinate_converter.dart]**

> "One of the hardest parts was coordinate conversion. There are three coordinate systems:
> 1. Screen coordinates—pixels, Y increases downward
> 2. Chart coordinates—price/time, Y increases upward
> 3. Candle indices—discrete positions
>
> This `screenToChart` method converts a tap position to a price and time. Notice the Y-axis inversion—screen Y is subtracted because prices go up while screen coordinates go down."

### 14:30 - 15:30 — Trading Engine

**[Open lib/services/paper_trading_engine.dart]**

> "The paper trading engine is pure Dart—no Flutter dependencies. This makes it testable.
>
> Here's the `placeMarketOrder` method. It:
> 1. Validates the order
> 2. Creates or updates a position
> 3. Deducts from balance
> 4. Sets up stop loss and take profit triggers
>
> The `processPrice` method is called when prices update. It checks if any SL/TP levels are hit and closes positions automatically.
>
> When a position closes, it fires a callback that logs the trade to the journal—that's the integration I mentioned earlier."

### 15:30 - 16:30 — Persistence

**[Open lib/services/trade_repository.dart]**

> "Persistence uses Hive. Here's the trade repository.
>
> Trades are stored in a Hive box—essentially a typed key-value store. Hive generates type adapters from my model annotations.
>
> The `addTrade` method opens the box, puts the trade, and Hive handles serialization automatically.
>
> On Web, this uses IndexedDB. On mobile and desktop, it uses local files. Same code, all platforms."

### 16:30 - 17:00 — Deployment Config

**[Open firebase.json and android/app/build.gradle.kts]**

> "For deployment, `firebase.json` configures web hosting. It sets up CORS headers and caching.
>
> For Android, `build.gradle.kts` configures release signing. I load the keystore path and passwords from a `key.properties` file that's gitignored—secrets never go in version control.
>
> The app is live at `trading-app-68902.web.app` and the Android AAB is ready for Play Store upload."

---

# SECTION 5: WRAP-UP (17:00 - 20:00)

## On Screen
- Back to you (webcam)
- Can show slides with bullet points

## Script

### 17:00 - 18:30 — Technical Challenges

> "Let me discuss the main challenges I faced.
>
> **Challenge 1: Coordinate Systems**
> The chart has inverted Y coordinates—screen Y goes down, prices go up. This caused tools to appear at wrong positions. I solved it by building a dedicated coordinate converter class that handles all transformations.
>
> **Challenge 2: Timeframe Aggregation**
> Initially, I tried to aggregate higher timeframes from 1-minute data. This caused 'mega candles' and missing data issues. I solved it by storing each timeframe's data independently.
>
> **Challenge 3: Position Tool Interaction**
> Making the drag handles work required screen-space hit detection, not chart-space. The handles need to be a fixed pixel size regardless of zoom level.
>
> **Challenge 4: Persistence**
> Data wasn't saving correctly because Hive boxes weren't flushing before app termination. I added lifecycle observers to ensure data is saved."

### 18:30 - 19:30 — Lessons Learned

> "Here are my key takeaways:
>
> **Technical:**
> - Custom graphics give control but require understanding coordinate systems deeply
> - State management is crucial—Provider made complex state manageable
> - Offline-first design is worth the investment
>
> **Process:**
> - Iterative development works—build features incrementally
> - Comprehensive logging saves debugging time
> - Test with full app restart, not just hot reload
>
> **Personal Growth:**
> - I now have deep Flutter expertise, especially CustomPainter
> - I understand clean architecture principles practically
> - I can deploy to Web and Play Store end-to-end"

### 19:30 - 20:00 — Conclusion

> "To summarize:
>
> I built a complete trading journal application as a solo project. It features:
> - Professional candlestick charts with zoom, pan, and drawing tools
> - Paper trading simulator
> - Trade journaling with analytics
> - Cross-platform deployment to Web and Android
>
> The application is live at `trading-app-68902.web.app` and the code is on GitHub.
>
> Thank you for watching. I'm happy to answer any questions."

---

# APPENDIX: FILES TO SHOW DURING CODE WALKTHROUGH

| Timestamp | File | What to Show |
|-----------|------|--------------|
| 12:00 | `lib/widgets/charts/candlestick_chart.dart` | Line ~50: class definition, Line ~2200: painter class |
| 13:30 | `lib/widgets/charts/chart_coordinate_converter.dart` | `screenToChart` method |
| 14:30 | `lib/services/paper_trading_engine.dart` | `placeMarketOrder`, `processPrice` methods |
| 15:30 | `lib/services/trade_repository.dart` | `addTrade`, `getAllTrades` methods |
| 16:30 | `firebase.json`, `android/app/build.gradle.kts` | Deployment configuration |

---

# TIPS FOR RECORDING

1. **Test the demo before recording** — Make sure the web app is responsive
2. **Prepare the code files** — Have them open in tabs, ready to switch
3. **Practice transitions** — Smooth flow between sections
4. **Use screen recording** — OBS Studio or similar
5. **Show your face** — Intro and outro at minimum
6. **Speak clearly** — Not too fast, pause between sections
7. **Time yourself** — Practice to hit 18-19 minutes, leaving buffer

---

# SCREEN LAYOUT SUGGESTIONS

**During Demo:**
- Chrome browser with app fullscreen
- Occasionally show DevTools to prove no errors

**During Code Walkthrough:**
- IDE (Cursor/VS Code) with file explorer visible
- Code syntax highlighted
- Zoom in on relevant sections

**During Intro/Outro:**
- Webcam centered
- Simple background
- Good lighting

---

**END OF SCRIPT**


# 📊 Flutter Trading Journal

A professional-grade trading journal and analytics application built with Flutter. Track your trades, analyze performance, practice with paper trading, and visualize market data with interactive charts.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

## ✨ Features

### 📝 Trade Journal
- **Log trades** with symbol, side (long/short), quantity, entry/exit prices, dates
- **Add tags** for categorization (swing, scalp, earnings, etc.)
- **Notes field** for trade rationale and lessons learned
- **Edit/Delete** trades with confirmation
- **Search & Filter** by symbol, outcome, date range

### 📈 Analytics Dashboard
- **Win Rate** calculation with visual indicators
- **Total P&L** tracking
- **Profit Factor** and Risk-Reward ratio
- **Equity Curve** visualization
- **P&L by Symbol** breakdown
- **Calendar Heatmap** of trading activity

### 📉 Interactive Charts
- **TradingView-style** candlestick charts
- **Zoom** (pinch/mouse wheel) and **Pan** (drag)
- **Crosshair** with OHLC tooltip
- **EMA indicators** (9, 21, 50 period)
- **Volume bars**
- **Timeframe switching** (1m, 5m, 15m, 1H, 1D)
- **Symbol search** with popular stocks

### 💰 Paper Trading
- **Virtual $10,000** starting balance
- **Buy/Sell** orders with one-click execution
- **Stop Loss / Take Profit** with percentage inputs
- **Position tracking** with live P&L
- **Auto-logging** of closed trades to journal
- **Trade markers** displayed on chart

### 📤 Data Export
- **CSV export** for spreadsheets
- **JSON export** for backups
- **Share files** directly from app

## 🏗️ Architecture

```
lib/
├── core/              # Environment config, utilities
├── models/            # Data models (Trade, Candle, etc.)
├── screens/           # UI screens
├── services/          # Business logic (analytics, trading engine)
├── state/             # State management (Provider)
├── theme/             # App theming
└── widgets/           # Reusable UI components
```

### Key Design Decisions

- **Offline-first**: Local persistence with Hive
- **State Management**: Provider (simple, testable)
- **Clean Architecture**: Separated UI, state, and business logic
- **Testable**: Pure Dart services for unit testing
- **Mock Data Fallback**: Works without API key

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Dart 3.0+
- Android Studio / VS Code

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/trade_journal_app.git
cd trade_journal_app

# Install dependencies
flutter pub get

# Generate Hive adapters
flutter pub run build_runner build

# Run the app
flutter run
```

### Environment Setup (Optional)

For live market data, create a `.env` file:

```env
FINNHUB_API_KEY=your_api_key_here
```

Get a free API key at [finnhub.io](https://finnhub.io/).

> **Note**: The app works with mock data if no API key is provided.

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/analytics_service_test.dart
```

### Test Coverage

- ✅ Analytics calculations (win rate, P&L, profit factor)
- ✅ Paper trading engine (orders, positions, SL/TP)
- ✅ Trade model computations

## 📱 Screenshots

| Trades List | Analytics | Chart | Paper Trading |
|-------------|-----------|-------|---------------|
| Trade history with P&L | Performance metrics | Interactive candlesticks | Virtual trading |

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.10+ |
| Language | Dart 3.0+ |
| State Management | Provider |
| Local Storage | Hive |
| Charts | fl_chart, Custom Painters |
| HTTP | http, web_socket_channel |
| Environment | flutter_dotenv |

## 📦 Dependencies

```yaml
dependencies:
  provider: ^6.1.2          # State management
  hive: ^2.2.3              # Local database
  hive_flutter: ^1.1.0      # Flutter Hive integration
  fl_chart: ^0.69.0         # Charts
  intl: ^0.19.0             # Formatting
  uuid: ^4.5.1              # Unique IDs
  flutter_dotenv: ^5.2.1    # Environment variables
  web_socket_channel: ^3.0.1 # WebSocket for live data
  http: ^1.2.2              # HTTP client
  path_provider: ^2.1.4     # File system access
  share_plus: ^10.1.4       # Share files
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📋 Roadmap

- [ ] Cloud sync (Firebase)
- [ ] Trade screenshots/attachments
- [ ] Drawing tools (trendlines, horizontals)
- [ ] Push notifications for SL/TP
- [ ] Multi-account support
- [ ] Dark/Light theme toggle
- [ ] Portfolio tracking

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [TradingView](https://tradingview.com) - Chart interaction inspiration
- [Finnhub](https://finnhub.io) - Market data API
- [Flutter](https://flutter.dev) - Amazing cross-platform framework

---

<p align="center">
  Made with ❤️ and Flutter
</p>

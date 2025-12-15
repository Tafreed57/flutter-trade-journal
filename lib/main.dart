import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/env_config.dart';
import 'core/logger.dart';
import 'firebase_options.dart';
import 'models/paper_trading.dart';
import 'models/trade.dart';
import 'screens/auth/auth_gate.dart';
import 'services/trade_repository.dart';
import 'state/auth_provider.dart';
import 'state/chart_drawing_provider.dart';
import 'state/market_data_provider.dart';
import 'state/paper_trading_provider.dart';
import 'state/theme_provider.dart';
import 'state/trade_provider.dart';
import 'theme/app_theme.dart';

/// Whether Firebase was successfully initialized
/// Set to false until Firebase packages are enabled
bool _firebaseAvailable = false;

/// Check if Firebase is available
bool get isFirebaseAvailable => _firebaseAvailable;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseAvailable = true;
    Log.i('Firebase initialized successfully');
  } catch (e) {
    Log.w('Firebase initialization failed - running offline: $e');
    _firebaseAvailable = false;
  }

  // Load environment variables (API keys, etc.)
  await EnvConfig.load();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Register Hive type adapters - Trade models
  Hive.registerAdapter(TradeSideAdapter());
  Hive.registerAdapter(TradeOutcomeAdapter());
  Hive.registerAdapter(TradeAdapter());

  // Register Hive type adapters - Paper trading models
  Hive.registerAdapter(PaperAccountAdapter());
  Hive.registerAdapter(OrderSideAdapter());
  Hive.registerAdapter(OrderTypeAdapter());
  Hive.registerAdapter(OrderStatusAdapter());
  Hive.registerAdapter(PaperOrderAdapter());
  Hive.registerAdapter(PaperPositionAdapter());

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TradingJournalApp());
}

class TradingJournalApp extends StatelessWidget {
  const TradingJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication provider
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),

        // Repository (single instance)
        Provider<TradeRepository>(
          create: (_) => TradeRepository(),
          dispose: (_, repo) => repo.close(),
        ),

        // Trade state provider
        ChangeNotifierProxyProvider<TradeRepository, TradeProvider>(
          create: (context) => TradeProvider(context.read<TradeRepository>()),
          update: (_, repo, previous) => previous ?? TradeProvider(repo),
        ),

        // Market data provider (for live prices and charts)
        ChangeNotifierProvider<MarketDataProvider>(
          create: (_) => MarketDataProvider(),
        ),

        // Paper trading provider
        ChangeNotifierProxyProvider<TradeRepository, PaperTradingProvider>(
          create: (context) =>
              PaperTradingProvider(context.read<TradeRepository>()),
          update: (_, repo, previous) => previous ?? PaperTradingProvider(repo),
        ),

        // Chart drawing provider (for drawing tools)
        ChangeNotifierProvider<ChartDrawingProvider>(
          create: (_) => ChartDrawingProvider(),
        ),

        // Theme provider for light/dark mode
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Trading Journal',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

/// Handles app initialization and shows loading state
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    // Defer initialization to after the first frame to avoid
    // calling notifyListeners() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize the trade provider (which initializes the repository)
      await context.read<TradeProvider>().init();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _initError = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error state
    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.loss,
                ),
                const SizedBox(height: 24),
                Text(
                  'Failed to initialize',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  _initError!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _initError = null;
                      _isInitialized = false;
                    });
                    _initializeApp();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.show_chart_rounded,
                    size: 40,
                    color: AppColors.background,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Trading Journal',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Main app with authentication gate
    return const AuthGate();
  }
}

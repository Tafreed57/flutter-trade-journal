import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
import 'services/market_data_engine.dart';
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
  // Set up global error handlers for release builds
  _setupErrorHandlers();
  
  runZonedGuarded(() async {
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

    // Initialize MarketDataEngine (for chart data persistence)
    await MarketDataEngine.instance.init();
    Hive.registerAdapter(PaperOrderAdapter());
    Hive.registerAdapter(PaperPositionAdapter());

    // Set preferred orientations (allow landscape on desktop/tablet)
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

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
  }, (error, stackTrace) {
    // Catch any errors not caught by Flutter's error handling
    Log.e('Unhandled error in zone', error, stackTrace);
  });
}

/// Set up global error handlers
void _setupErrorHandlers() {
  // Handle Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kReleaseMode) {
      // In release mode, log but don't crash
      Log.e('Flutter error: ${details.exceptionAsString()}');
      // TODO: Send to crash reporting service (Firebase Crashlytics, Sentry, etc.)
    } else {
      // In debug mode, use default behavior (prints to console)
      FlutterError.presentError(details);
    }
  };
  
  // Handle platform dispatcher errors (Dart runtime errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.e('Platform error', error, stack);
    // Return true to indicate we handled the error
    return true;
  };
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
      // Get userId from auth for multi-user support
      final userId = context.read<AuthProvider>().user?.uid;
      
      // Initialize all providers with userId for multi-user support
      await context.read<TradeProvider>().init(userId: userId);
      await context.read<PaperTradingProvider>().init(userId: userId);
      await context.read<ChartDrawingProvider>().init(userId: userId);

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

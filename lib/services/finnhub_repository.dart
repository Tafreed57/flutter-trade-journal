import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/logger.dart';
import '../models/candle.dart';
import '../models/live_price.dart';
import '../models/timeframe.dart';
import 'market_data_repository.dart';

/// Finnhub.io market data implementation
/// 
/// Provides:
/// - Historical OHLCV candlestick data via REST API
/// - Real-time price updates via WebSocket
/// - Symbol search
/// - Quote snapshots
/// 
/// ## API Documentation
/// - REST: https://finnhub.io/docs/api
/// - WebSocket: https://finnhub.io/docs/api/websocket-trades
/// 
/// ## Rate Limits (Free Tier)
/// - REST: 60 calls/minute
/// - WebSocket: Unlimited subscriptions, but ~50 symbols recommended
class FinnhubMarketDataRepository implements MarketDataRepository {
  final String apiKey;
  
  // REST API base URL
  static const String _baseUrl = 'https://finnhub.io/api/v1';
  
  // WebSocket URL
  static const String _wsUrl = 'wss://ws.finnhub.io';
  
  // HTTP client for REST calls
  final http.Client _httpClient;
  
  // WebSocket connection
  WebSocketChannel? _wsChannel;
  
  // Stream controller for live prices
  final _priceController = StreamController<LivePrice>.broadcast();
  
  // Stream controller for connection state
  final _connectionController = StreamController<bool>.broadcast();
  
  // Currently subscribed symbols
  final Set<String> _subscribedSymbols = {};
  
  // Connection state
  bool _isConnected = false;
  
  // Disposed flag to prevent reconnection after disposal
  bool _isDisposed = false;
  
  // Reconnection timer
  Timer? _reconnectTimer;
  
  // Reconnection attempt count
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  
  // Rate limiting: track API calls
  final List<DateTime> _apiCalls = [];
  static const int _maxCallsPerMinute = 60;

  FinnhubMarketDataRepository({
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  // ==================== INITIALIZATION ====================

  @override
  Future<void> init() async {
    await _connectWebSocket();
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    try {
      await _wsChannel?.sink.close();
    } catch (_) {
      // Ignore errors when closing
    }
    
    _wsChannel = null;
    _isConnected = false;
    
    if (!_priceController.isClosed) {
      await _priceController.close();
    }
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
    
    _httpClient.close();
  }

  // ==================== CONNECTION STATE ====================

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  // ==================== REST API METHODS ====================

  @override
  Future<List<Candle>> getHistoricalCandles(
    String symbol,
    Timeframe timeframe,
    DateTime from,
    DateTime to,
  ) async {
    try {
      await _checkRateLimit();
      
      // Convert timestamps to Unix seconds
      final fromUnix = from.millisecondsSinceEpoch ~/ 1000;
      final toUnix = to.millisecondsSinceEpoch ~/ 1000;
      
      // Build URL
      // Note: Finnhub uses "resolution" parameter for timeframe
      final url = Uri.parse(
        '$_baseUrl/stock/candle?symbol=$symbol&resolution=${timeframe.apiValue}'
        '&from=$fromUnix&to=$toUnix&token=$apiKey',
      );
      
      Log.network('Fetching candles: $symbol (${timeframe.label})');
      
      final response = await _httpClient.get(url);
      
      if (response.statusCode != 200) {
        // 403 is expected for free tier - don't log as error
        if (response.statusCode == 403) {
          Log.d('Finnhub 403: Historical candles require paid plan');
        }
        throw MarketDataException(
          'Failed to fetch candles: ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }
      
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Check for "no_data" status
      if (json['s'] == 'no_data') {
        Log.w('No candle data available for $symbol');
        return [];
      }
      
      final candles = Candle.listFromFinnhub(json);
      Log.d('Received ${candles.length} candles for $symbol');
      
      return candles;
    } catch (e) {
      // Don't log 403 as error - it's expected for free tier
      if (e is MarketDataException && e.code == '403') {
        rethrow;
      }
      Log.e('Error fetching candles', e);
      if (e is MarketDataException) rethrow;
      throw MarketDataException('Failed to fetch candles', originalError: e);
    }
  }

  @override
  Future<Quote?> getQuote(String symbol) async {
    try {
      await _checkRateLimit();
      
      final url = Uri.parse('$_baseUrl/quote?symbol=$symbol&token=$apiKey');
      
      final response = await _httpClient.get(url);
      
      if (response.statusCode != 200) {
        throw MarketDataException(
          'Failed to fetch quote: ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }
      
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Check for valid response (c = 0 means no data)
      if (json['c'] == 0 || json['c'] == null) {
        return null;
      }
      
      return Quote.fromFinnhub(json);
    } catch (e) {
      Log.e('Error fetching quote', e);
      if (e is MarketDataException) rethrow;
      throw MarketDataException('Failed to fetch quote', originalError: e);
    }
  }

  @override
  Future<List<SymbolInfo>> searchSymbols(String query) async {
    try {
      await _checkRateLimit();
      
      final url = Uri.parse(
        '$_baseUrl/search?q=$query&token=$apiKey',
      );
      
      final response = await _httpClient.get(url);
      
      if (response.statusCode != 200) {
        throw MarketDataException(
          'Failed to search symbols: ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }
      
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['result'] as List? ?? [];
      
      return results
          .map((r) => SymbolInfo.fromFinnhub(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Log.e('Error searching symbols', e);
      if (e is MarketDataException) rethrow;
      throw MarketDataException('Failed to search symbols', originalError: e);
    }
  }

  // ==================== WEBSOCKET METHODS ====================

  Future<void> _connectWebSocket() async {
    try {
      Log.ws('Connecting to Finnhub WebSocket...');
      
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$_wsUrl?token=$apiKey'),
      );
      
      _isConnected = true;
      _reconnectAttempts = 0; // Reset on successful connect
      _connectionController.add(true);
      Log.ws('WebSocket connected successfully');
      
      // Listen to messages
      _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDone,
      );
      
      // Re-subscribe to previously subscribed symbols
      for (final symbol in _subscribedSymbols) {
        _sendSubscribe(symbol);
      }
    } catch (e) {
      Log.ws('WebSocket connection failed: $e', isError: true);
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      
      // Handle ping/pong
      if (json['type'] == 'ping') {
        _wsChannel?.sink.add(jsonEncode({'type': 'pong'}));
        return;
      }
      
      // Handle trade data
      if (json['type'] == 'trade') {
        final prices = LivePrice.listFromFinnhub(json);
        for (final price in prices) {
          _priceController.add(price);
        }
      }
    } catch (e) {
      Log.w('Error parsing WebSocket message: $e');
    }
  }

  void _handleWebSocketError(dynamic error) {
    Log.ws('WebSocket error: $error', isError: true);
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  void _handleWebSocketDone() {
    Log.ws('WebSocket disconnected');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    // Don't reconnect if disposed or max attempts reached
    if (_isDisposed) {
      Log.d('WebSocket disposed, not reconnecting');
      return;
    }
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      Log.w('Max WebSocket reconnect attempts reached, giving up');
      return;
    }
    
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_isDisposed) return;
      Log.ws('Attempting to reconnect (${_reconnectAttempts}/$_maxReconnectAttempts)...');
      _connectWebSocket();
    });
  }

  @override
  Stream<LivePrice> subscribeToLivePrice(String symbol) {
    _subscribedSymbols.add(symbol);
    _sendSubscribe(symbol);
    
    // Return filtered stream for this symbol only
    return _priceController.stream.where((p) => p.symbol == symbol);
  }

  @override
  void unsubscribeFromLivePrice(String symbol) {
    _subscribedSymbols.remove(symbol);
    _sendUnsubscribe(symbol);
  }

  @override
  void unsubscribeFromAll() {
    for (final symbol in _subscribedSymbols.toList()) {
      _sendUnsubscribe(symbol);
    }
    _subscribedSymbols.clear();
  }

  void _sendSubscribe(String symbol) {
    if (_isConnected && _wsChannel != null) {
      final message = jsonEncode({'type': 'subscribe', 'symbol': symbol});
      _wsChannel!.sink.add(message);
      Log.d('Subscribed to $symbol');
    }
  }

  void _sendUnsubscribe(String symbol) {
    if (_isConnected && _wsChannel != null) {
      final message = jsonEncode({'type': 'unsubscribe', 'symbol': symbol});
      _wsChannel!.sink.add(message);
      Log.d('Unsubscribed from $symbol');
    }
  }

  // ==================== RATE LIMITING ====================

  /// Check if we're within rate limits, wait if necessary
  Future<void> _checkRateLimit() async {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    // Remove old calls
    _apiCalls.removeWhere((call) => call.isBefore(oneMinuteAgo));
    
    // If at limit, wait
    if (_apiCalls.length >= _maxCallsPerMinute) {
      final oldestCall = _apiCalls.first;
      final waitTime = oldestCall.add(const Duration(minutes: 1)).difference(now);
      
      if (waitTime.isNegative == false) {
        Log.w('Rate limit reached, waiting ${waitTime.inMilliseconds}ms...');
        await Future.delayed(waitTime);
      }
    }
    
    _apiCalls.add(now);
  }
}


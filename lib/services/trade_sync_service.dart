import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/logger.dart';
import '../core/debug_trace.dart';
import '../models/trade.dart';
import '../main.dart' show isFirebaseAvailable;

/// Service for syncing trades to/from Firebase Firestore
/// 
/// This enables cross-device sync - trades created on PC will appear on phone.
/// Local Hive storage is used as a cache, but Firestore is the source of truth.
class TradeSyncService {
  final FirebaseFirestore _firestore;
  
  TradeSyncService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  
  /// Get the trades collection reference for a user
  CollectionReference<Map<String, dynamic>> _tradesCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('trades');
  }
  
  /// Fetch all trades for a user from Firestore
  /// Has a timeout to prevent infinite loading
  Future<List<Trade>> fetchTrades(String userId, {int limitCount = 100}) async {
    if (!isFirebaseAvailable) {
      JournalDebug.firestore('FETCH_SKIPPED', error: 'Firebase not available');
      return [];
    }
    
    JournalDebug.start('Firestore.fetchTrades');
    JournalDebug.firestore('FETCH_START', collection: 'users/$userId/trades');
    
    try {
      // Add limit to prevent loading too many trades at once
      // Add timeout to prevent infinite waiting
      final snapshot = await _tradesCollection(userId)
          .orderBy('entryDate', descending: true)
          .limit(limitCount)
          .get()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              JournalDebug.firestore('FETCH_TIMEOUT', 
                collection: 'users/$userId/trades',
                error: 'Timed out after 15 seconds',
              );
              throw Exception('Firestore fetch timed out');
            },
          );
      
      final trades = snapshot.docs.map((doc) {
        return _tradeFromFirestore(doc.data(), doc.id, userId);
      }).toList();
      
      JournalDebug.end('Firestore.fetchTrades', details: '${trades.length} trades');
      JournalDebug.firestore('FETCH_SUCCESS', 
        collection: 'users/$userId/trades',
        docCount: trades.length,
      );
      
      return trades;
    } catch (e) {
      JournalDebug.end('Firestore.fetchTrades', details: 'FAILED');
      JournalDebug.firestore('FETCH_ERROR', 
        collection: 'users/$userId/trades',
        error: e.toString(),
      );
      rethrow; // Let caller handle the error
    }
  }
  
  /// Save a trade to Firestore
  /// Has a timeout to prevent blocking forever
  Future<bool> saveTrade(Trade trade) async {
    if (!isFirebaseAvailable) {
      JournalDebug.firestore('SAVE_SKIPPED', 
        docId: trade.id,
        error: 'Firebase not available',
      );
      return false;
    }
    
    if (trade.userId == null) {
      JournalDebug.firestore('SAVE_SKIPPED', 
        docId: trade.id,
        error: 'No userId on trade',
      );
      return false;
    }
    
    JournalDebug.start('Firestore.saveTrade');
    JournalDebug.firestore('SAVE_START', 
      collection: 'users/${trade.userId}/trades',
      docId: trade.id,
    );
    
    try {
      await _tradesCollection(trade.userId!)
          .doc(trade.id)
          .set(_tradeToFirestore(trade))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              JournalDebug.firestore('SAVE_TIMEOUT',
                docId: trade.id,
                error: 'Timed out after 10 seconds',
              );
              throw Exception('Firestore save timed out');
            },
          );
      
      JournalDebug.end('Firestore.saveTrade', details: 'SUCCESS');
      JournalDebug.firestore('SAVE_SUCCESS', docId: trade.id);
      return true;
    } catch (e) {
      JournalDebug.end('Firestore.saveTrade', details: 'FAILED');
      JournalDebug.firestore('SAVE_ERROR', 
        docId: trade.id,
        error: e.toString(),
      );
      return false;
    }
  }
  
  /// Update a trade in Firestore
  Future<bool> updateTrade(Trade trade) async {
    return saveTrade(trade); // Same operation for Firestore
  }
  
  /// Delete a trade from Firestore
  Future<bool> deleteTrade(String tradeId, String userId) async {
    if (!isFirebaseAvailable) {
      return false;
    }
    
    try {
      await _tradesCollection(userId).doc(tradeId).delete();
      Log.d('Deleted trade $tradeId from Firestore');
      return true;
    } catch (e) {
      Log.e('Failed to delete trade from Firestore', e);
      return false;
    }
  }
  
  /// Sync local trades to Firestore (for migration)
  Future<int> syncLocalTradesToFirestore(List<Trade> localTrades, String userId) async {
    if (!isFirebaseAvailable) return 0;
    
    int syncedCount = 0;
    for (final trade in localTrades) {
      // Update trade with userId if missing
      final tradeWithUser = trade.userId == null 
          ? trade.copyWith(userId: userId)
          : trade;
      
      if (await saveTrade(tradeWithUser)) {
        syncedCount++;
      }
    }
    
    Log.i('Synced $syncedCount trades to Firestore');
    return syncedCount;
  }
  
  /// Convert Trade to Firestore document
  Map<String, dynamic> _tradeToFirestore(Trade trade) {
    return {
      'symbol': trade.symbol,
      'side': trade.side.name,
      'quantity': trade.quantity,
      'entryPrice': trade.entryPrice,
      'exitPrice': trade.exitPrice,
      'entryDate': Timestamp.fromDate(trade.entryDate),
      'exitDate': trade.exitDate != null ? Timestamp.fromDate(trade.exitDate!) : null,
      'tags': trade.tags,
      'notes': trade.notes,
      'stopLoss': trade.stopLoss,
      'takeProfit': trade.takeProfit,
      'setup': trade.setup,
      'userId': trade.userId,
      'createdAt': Timestamp.fromDate(trade.createdAt),
      'updatedAt': Timestamp.fromDate(trade.updatedAt),
    };
  }
  
  /// Convert Firestore document to Trade
  Trade _tradeFromFirestore(Map<String, dynamic> data, String id, String userId) {
    return Trade(
      id: id,
      symbol: data['symbol'] as String,
      side: TradeSide.values.firstWhere(
        (s) => s.name == data['side'],
        orElse: () => TradeSide.long,
      ),
      quantity: (data['quantity'] as num).toDouble(),
      entryPrice: (data['entryPrice'] as num).toDouble(),
      exitPrice: data['exitPrice'] != null ? (data['exitPrice'] as num).toDouble() : null,
      entryDate: (data['entryDate'] as Timestamp).toDate(),
      exitDate: data['exitDate'] != null ? (data['exitDate'] as Timestamp).toDate() : null,
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      notes: data['notes'] as String?,
      stopLoss: data['stopLoss'] != null ? (data['stopLoss'] as num).toDouble() : null,
      takeProfit: data['takeProfit'] != null ? (data['takeProfit'] as num).toDouble() : null,
      setup: data['setup'] as String?,
      userId: userId,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}


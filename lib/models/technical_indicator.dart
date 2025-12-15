import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'candle.dart';

/// Types of technical indicators
enum IndicatorType {
  sma,      // Simple Moving Average
  ema,      // Exponential Moving Average
  rsi,      // Relative Strength Index
  macd,     // Moving Average Convergence Divergence
  bollinger, // Bollinger Bands
}

/// Configuration for a technical indicator
class IndicatorConfig {
  final String id;
  final IndicatorType type;
  final int period;
  final int? period2;  // For MACD signal line, BB deviation, etc.
  final Color color;
  final bool enabled;
  final double strokeWidth;

  const IndicatorConfig({
    required this.id,
    required this.type,
    required this.period,
    this.period2,
    required this.color,
    this.enabled = true,
    this.strokeWidth = 1.5,
  });

  IndicatorConfig copyWith({
    bool? enabled,
    Color? color,
    int? period,
  }) {
    return IndicatorConfig(
      id: id,
      type: type,
      period: period ?? this.period,
      period2: period2,
      color: color ?? this.color,
      enabled: enabled ?? this.enabled,
      strokeWidth: strokeWidth,
    );
  }

  String get displayName {
    return switch (type) {
      IndicatorType.sma => 'SMA($period)',
      IndicatorType.ema => 'EMA($period)',
      IndicatorType.rsi => 'RSI($period)',
      IndicatorType.macd => 'MACD($period, ${period2 ?? 26})',
      IndicatorType.bollinger => 'BB($period, ${period2 ?? 2})',
    };
  }

  /// Default indicator presets
  static List<IndicatorConfig> get defaultPresets => [
    const IndicatorConfig(
      id: 'ema_9',
      type: IndicatorType.ema,
      period: 9,
      color: Color(0xFFFFD700), // Gold
    ),
    const IndicatorConfig(
      id: 'ema_21',
      type: IndicatorType.ema,
      period: 21,
      color: Color(0xFF00BFFF), // Deep Sky Blue
    ),
    const IndicatorConfig(
      id: 'sma_50',
      type: IndicatorType.sma,
      period: 50,
      color: Color(0xFFFF6B6B), // Coral
    ),
    const IndicatorConfig(
      id: 'sma_200',
      type: IndicatorType.sma,
      period: 200,
      color: Color(0xFF9B59B6), // Purple
    ),
    const IndicatorConfig(
      id: 'rsi_14',
      type: IndicatorType.rsi,
      period: 14,
      color: Color(0xFFE91E63), // Pink
      enabled: false,
    ),
  ];
}

/// Result data for an indicator calculation
class IndicatorResult {
  final IndicatorConfig config;
  final List<double?> values;
  final List<double?>? upperBand;   // For Bollinger Bands
  final List<double?>? lowerBand;   // For Bollinger Bands
  final List<double?>? signalLine;  // For MACD
  final List<double?>? histogram;   // For MACD

  const IndicatorResult({
    required this.config,
    required this.values,
    this.upperBand,
    this.lowerBand,
    this.signalLine,
    this.histogram,
  });
}

/// Technical indicator calculator
class TechnicalIndicators {
  /// Calculate Simple Moving Average
  static List<double?> calculateSMA(List<Candle> candles, int period) {
    if (candles.length < period) {
      return List.filled(candles.length, null);
    }

    final result = List<double?>.filled(candles.length, null);
    
    for (int i = period - 1; i < candles.length; i++) {
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += candles[i - j].close;
      }
      result[i] = sum / period;
    }
    
    return result;
  }

  /// Calculate Exponential Moving Average
  static List<double?> calculateEMA(List<Candle> candles, int period) {
    if (candles.length < period) {
      return List.filled(candles.length, null);
    }

    final result = List<double?>.filled(candles.length, null);
    final multiplier = 2 / (period + 1);

    // Start with SMA as first EMA value
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += candles[i].close;
    }
    result[period - 1] = sum / period;

    // Calculate EMA for remaining values
    for (int i = period; i < candles.length; i++) {
      final prevEma = result[i - 1]!;
      result[i] = (candles[i].close - prevEma) * multiplier + prevEma;
    }

    return result;
  }

  /// Calculate Relative Strength Index
  static List<double?> calculateRSI(List<Candle> candles, int period) {
    if (candles.length < period + 1) {
      return List.filled(candles.length, null);
    }

    final result = List<double?>.filled(candles.length, null);
    final gains = <double>[];
    final losses = <double>[];

    // Calculate initial gains and losses
    for (int i = 1; i <= period; i++) {
      final change = candles[i].close - candles[i - 1].close;
      if (change > 0) {
        gains.add(change);
        losses.add(0);
      } else {
        gains.add(0);
        losses.add(change.abs());
      }
    }

    double avgGain = gains.reduce((a, b) => a + b) / period;
    double avgLoss = losses.reduce((a, b) => a + b) / period;

    // First RSI value
    if (avgLoss == 0) {
      result[period] = 100;
    } else {
      final rs = avgGain / avgLoss;
      result[period] = 100 - (100 / (1 + rs));
    }

    // Calculate remaining RSI values using smoothed averages
    for (int i = period + 1; i < candles.length; i++) {
      final change = candles[i].close - candles[i - 1].close;
      final currentGain = change > 0 ? change : 0.0;
      final currentLoss = change < 0 ? change.abs() : 0.0;

      avgGain = ((avgGain * (period - 1)) + currentGain) / period;
      avgLoss = ((avgLoss * (period - 1)) + currentLoss) / period;

      if (avgLoss == 0) {
        result[i] = 100;
      } else {
        final rs = avgGain / avgLoss;
        result[i] = 100 - (100 / (1 + rs));
      }
    }

    return result;
  }

  /// Calculate Bollinger Bands
  static ({List<double?> middle, List<double?> upper, List<double?> lower}) 
      calculateBollingerBands(List<Candle> candles, int period, double stdDev) {
    final sma = calculateSMA(candles, period);
    final upper = List<double?>.filled(candles.length, null);
    final lower = List<double?>.filled(candles.length, null);

    for (int i = period - 1; i < candles.length; i++) {
      if (sma[i] == null) continue;

      // Calculate standard deviation
      double sumSquares = 0;
      for (int j = 0; j < period; j++) {
        final diff = candles[i - j].close - sma[i]!;
        sumSquares += diff * diff;
      }
      final std = math.sqrt(sumSquares / period);

      upper[i] = sma[i]! + (stdDev * std);
      lower[i] = sma[i]! - (stdDev * std);
    }

    return (middle: sma, upper: upper, lower: lower);
  }

  /// Calculate MACD
  static ({List<double?> macd, List<double?> signal, List<double?> histogram})
      calculateMACD(List<Candle> candles, {
        int fastPeriod = 12,
        int slowPeriod = 26,
        int signalPeriod = 9,
      }) {
    final fastEma = calculateEMA(candles, fastPeriod);
    final slowEma = calculateEMA(candles, slowPeriod);
    
    final macdLine = List<double?>.filled(candles.length, null);
    final signalLine = List<double?>.filled(candles.length, null);
    final histogram = List<double?>.filled(candles.length, null);

    // Calculate MACD line
    for (int i = slowPeriod - 1; i < candles.length; i++) {
      if (fastEma[i] != null && slowEma[i] != null) {
        macdLine[i] = fastEma[i]! - slowEma[i]!;
      }
    }

    // Calculate Signal line (EMA of MACD)
    final macdForSignal = macdLine.skip(slowPeriod - 1).take(signalPeriod).whereType<double>();
    if (macdForSignal.length >= signalPeriod) {
      final multiplier = 2 / (signalPeriod + 1);
      signalLine[slowPeriod - 1 + signalPeriod - 1] = 
          macdForSignal.reduce((a, b) => a + b) / signalPeriod;

      for (int i = slowPeriod + signalPeriod - 1; i < candles.length; i++) {
        if (macdLine[i] != null && signalLine[i - 1] != null) {
          signalLine[i] = (macdLine[i]! - signalLine[i - 1]!) * multiplier + signalLine[i - 1]!;
        }
      }
    }

    // Calculate histogram
    for (int i = 0; i < candles.length; i++) {
      if (macdLine[i] != null && signalLine[i] != null) {
        histogram[i] = macdLine[i]! - signalLine[i]!;
      }
    }

    return (macd: macdLine, signal: signalLine, histogram: histogram);
  }

  /// Calculate indicator based on config
  static IndicatorResult calculate(List<Candle> candles, IndicatorConfig config) {
    switch (config.type) {
      case IndicatorType.sma:
        return IndicatorResult(
          config: config,
          values: calculateSMA(candles, config.period),
        );
      case IndicatorType.ema:
        return IndicatorResult(
          config: config,
          values: calculateEMA(candles, config.period),
        );
      case IndicatorType.rsi:
        return IndicatorResult(
          config: config,
          values: calculateRSI(candles, config.period),
        );
      case IndicatorType.bollinger:
        final bb = calculateBollingerBands(
          candles, 
          config.period, 
          (config.period2 ?? 2).toDouble(),
        );
        return IndicatorResult(
          config: config,
          values: bb.middle,
          upperBand: bb.upper,
          lowerBand: bb.lower,
        );
      case IndicatorType.macd:
        final macd = calculateMACD(candles);
        return IndicatorResult(
          config: config,
          values: macd.macd,
          signalLine: macd.signal,
          histogram: macd.histogram,
        );
    }
  }
}


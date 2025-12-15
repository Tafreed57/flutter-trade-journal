// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TradeAdapter extends TypeAdapter<Trade> {
  @override
  final int typeId = 2;

  @override
  Trade read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Trade(
      id: fields[0] as String,
      symbol: fields[1] as String,
      side: fields[2] as TradeSide,
      quantity: fields[3] as double,
      entryPrice: fields[4] as double,
      exitPrice: fields[5] as double?,
      entryDate: fields[6] as DateTime,
      exitDate: fields[7] as DateTime?,
      tags: (fields[8] as List?)?.cast<String>(),
      notes: fields[9] as String?,
      createdAt: fields[10] as DateTime?,
      updatedAt: fields[11] as DateTime?,
      stopLoss: fields[12] as double?,
      takeProfit: fields[13] as double?,
      screenshotPath: fields[14] as String?,
      setup: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Trade obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.symbol)
      ..writeByte(2)
      ..write(obj.side)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.entryPrice)
      ..writeByte(5)
      ..write(obj.exitPrice)
      ..writeByte(6)
      ..write(obj.entryDate)
      ..writeByte(7)
      ..write(obj.exitDate)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.stopLoss)
      ..writeByte(13)
      ..write(obj.takeProfit)
      ..writeByte(14)
      ..write(obj.screenshotPath)
      ..writeByte(15)
      ..write(obj.setup);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TradeSideAdapter extends TypeAdapter<TradeSide> {
  @override
  final int typeId = 0;

  @override
  TradeSide read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TradeSide.long;
      case 1:
        return TradeSide.short;
      default:
        return TradeSide.long;
    }
  }

  @override
  void write(BinaryWriter writer, TradeSide obj) {
    switch (obj) {
      case TradeSide.long:
        writer.writeByte(0);
        break;
      case TradeSide.short:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeSideAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TradeOutcomeAdapter extends TypeAdapter<TradeOutcome> {
  @override
  final int typeId = 1;

  @override
  TradeOutcome read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TradeOutcome.win;
      case 1:
        return TradeOutcome.loss;
      case 2:
        return TradeOutcome.breakeven;
      case 3:
        return TradeOutcome.open;
      default:
        return TradeOutcome.win;
    }
  }

  @override
  void write(BinaryWriter writer, TradeOutcome obj) {
    switch (obj) {
      case TradeOutcome.win:
        writer.writeByte(0);
        break;
      case TradeOutcome.loss:
        writer.writeByte(1);
        break;
      case TradeOutcome.breakeven:
        writer.writeByte(2);
        break;
      case TradeOutcome.open:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeOutcomeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paper_trading.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaperAccountAdapter extends TypeAdapter<PaperAccount> {
  @override
  final int typeId = 10;

  @override
  PaperAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaperAccount(
      id: fields[0] as String,
      balance: fields[1] as double,
      initialBalance: fields[2] as double,
      realizedPnL: fields[3] as double,
      createdAt: fields[4] as DateTime?,
      userId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PaperAccount obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.balance)
      ..writeByte(2)
      ..write(obj.initialBalance)
      ..writeByte(3)
      ..write(obj.realizedPnL)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaperOrderAdapter extends TypeAdapter<PaperOrder> {
  @override
  final int typeId = 14;

  @override
  PaperOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaperOrder(
      id: fields[0] as String,
      symbol: fields[1] as String,
      side: fields[2] as OrderSide,
      type: fields[3] as OrderType,
      quantity: fields[4] as double,
      limitPrice: fields[5] as double?,
      status: fields[6] as OrderStatus,
      filledPrice: fields[7] as double?,
      createdAt: fields[8] as DateTime?,
      filledAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PaperOrder obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.symbol)
      ..writeByte(2)
      ..write(obj.side)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.limitPrice)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.filledPrice)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.filledAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaperPositionAdapter extends TypeAdapter<PaperPosition> {
  @override
  final int typeId = 15;

  @override
  PaperPosition read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaperPosition(
      id: fields[0] as String,
      symbol: fields[1] as String,
      side: fields[2] as OrderSide,
      quantity: fields[3] as double,
      entryPrice: fields[4] as double,
      stopLoss: fields[5] as double?,
      takeProfit: fields[6] as double?,
      openedAt: fields[7] as DateTime?,
      closedAt: fields[8] as DateTime?,
      exitPrice: fields[9] as double?,
      realizedPnL: fields[10] as double?,
      linkedToolId: fields[11] as String?,
      userId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PaperPosition obj) {
    writer
      ..writeByte(13)
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
      ..write(obj.stopLoss)
      ..writeByte(6)
      ..write(obj.takeProfit)
      ..writeByte(7)
      ..write(obj.openedAt)
      ..writeByte(8)
      ..write(obj.closedAt)
      ..writeByte(9)
      ..write(obj.exitPrice)
      ..writeByte(10)
      ..write(obj.realizedPnL)
      ..writeByte(11)
      ..write(obj.linkedToolId)
      ..writeByte(12)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperPositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderSideAdapter extends TypeAdapter<OrderSide> {
  @override
  final int typeId = 11;

  @override
  OrderSide read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OrderSide.buy;
      case 1:
        return OrderSide.sell;
      default:
        return OrderSide.buy;
    }
  }

  @override
  void write(BinaryWriter writer, OrderSide obj) {
    switch (obj) {
      case OrderSide.buy:
        writer.writeByte(0);
        break;
      case OrderSide.sell:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderSideAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderTypeAdapter extends TypeAdapter<OrderType> {
  @override
  final int typeId = 12;

  @override
  OrderType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OrderType.market;
      case 1:
        return OrderType.limit;
      default:
        return OrderType.market;
    }
  }

  @override
  void write(BinaryWriter writer, OrderType obj) {
    switch (obj) {
      case OrderType.market:
        writer.writeByte(0);
        break;
      case OrderType.limit:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderStatusAdapter extends TypeAdapter<OrderStatus> {
  @override
  final int typeId = 13;

  @override
  OrderStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OrderStatus.pending;
      case 1:
        return OrderStatus.filled;
      case 2:
        return OrderStatus.cancelled;
      case 3:
        return OrderStatus.rejected;
      default:
        return OrderStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, OrderStatus obj) {
    switch (obj) {
      case OrderStatus.pending:
        writer.writeByte(0);
        break;
      case OrderStatus.filled:
        writer.writeByte(1);
        break;
      case OrderStatus.cancelled:
        writer.writeByte(2);
        break;
      case OrderStatus.rejected:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

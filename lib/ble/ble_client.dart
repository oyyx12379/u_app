// lib/ble/ble_client.dart
import 'dart:async';
import 'dart:typed_data';

class BleDevice {
  final String id;     // Android: MAC / iOS: id / Windows: address
  final String name;
  BleDevice(this.id, this.name);
}

class BleCharacteristicRef {
  final String serviceUuid;
  final String characteristicUuid;
  BleCharacteristicRef(this.serviceUuid, this.characteristicUuid);
}

/// 统一抽象：扫描、连接、发现、写入、订阅
abstract class BleClient {
  Stream<List<BleDevice>> scan({Duration? timeout});
  Future<void> stopScan();

  Future<void> connect(String deviceId);
  Future<void> disconnect(String deviceId);

  /// 返回是否找到了期望的 RX / TX 特征
  Future<bool> discoverAndBind({
    required String deviceId,
    required String serviceUuid,
    required String rxUuid, // 写入用
    required String txUuid, // 通知用
  });

  Future<void> writeRx(List<int> data, {bool withoutResponse = false});

  /// 订阅 TX 通知（字符串/字节皆可，按设备协议）
  Stream<List<int>> notifications();

  bool get isConnected;
}

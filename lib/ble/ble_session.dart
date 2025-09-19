// lib/ble/ble_session.dart
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleSession {
  BleSession._();
  static final BleSession I = BleSession._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx; // 写入（APP->ESP）
  BluetoothCharacteristic? _tx; // 通知（ESP->APP）
  StreamSubscription<List<int>>? _txSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool get isConnected => _device?.isConnected ?? false;
  BluetoothDevice? get device => _device;

  /// 连接并绑定服务/特征（保持全局有效，直到 app 退出或你手动 disconnect）
  Future<void> connectAndBind({
    required BluetoothDevice device,
    required String serviceUuid,
    required String rxUuid,
    required String txUuid,
  }) async {
    // 如果已经连的是同一台，直接返回
    if (_device?.remoteId == device.remoteId && (_device?.isConnected ?? false)) {
      return;
    }
    // 若有旧连接，先清理但不主动断开（交由系统）
    await _cleanup(keepDevice: false);

    _device = device;

    // 连接：不要在页面 dispose 时调用 disconnect
    await _device!.connect(timeout: const Duration(seconds: 10));

    // 发现服务并绑定
    final services = await _device!.discoverServices();
    _rx = null; _tx = null;
    for (final s in services) {
      if (s.serviceUuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        for (final c in s.characteristics) {
          final cu = c.characteristicUuid.toString().toLowerCase();
          if (cu == rxUuid.toLowerCase()) _rx = c;
          if (cu == txUuid.toLowerCase()) _tx = c;
        }
      }
    }
    if (_rx == null || _tx == null) {
      throw StateError('未找到所需特征（RX/TX）。');
    }

    // 订阅通知（可选）
    await _tx!.setNotifyValue(true);
    await _txSub?.cancel();
    _txSub = _tx!.value.listen((bytes) {
      // 在这里处理 ESP 推来的数据
      // debugPrint('BLE Notify: $bytes');
    });

    // 监听连接状态：意外断开则尝试重连
    await _connSub?.cancel();
    _connSub = _device!.connectionState.listen((s) async {
      if (s == BluetoothConnectionState.disconnected) {
        // 简单自恢复：尝试重连（注意：不要疯狂循环，可适当退避）
        try {
          await _device!.connect(timeout: const Duration(seconds: 10));
          // 重连后需重新绑定特征
          await connectAndBind(
            device: _device!,
            serviceUuid: serviceUuid,
            rxUuid: rxUuid,
            txUuid: txUuid,
          );
        } catch (_) {
          // 忽略，等待用户手动再次进入或稍后重试
        }
      }
    });
  }

  /// 发送一条“数值指令”（[0x01, type, hi, lo, 0x00]）
  Future<void> sendStat(int typeByte, int value) async {
    if (_rx == null) throw StateError('RX 未绑定或未连接');
    final v = value.clamp(0, 999);
    final hi = (v >> 8) & 0xFF;
    final lo = v & 0xFF;
    final frame = <int>[0x01, typeByte & 0xFF, hi, lo, 0x00];
    await _rx!.write(frame, withoutResponse: false);
  }

  /// （可选）断开并清理；**正常不调用**，让连接贯穿全局直到关闭 App
  Future<void> disconnect() async {
    try { await _device?.disconnect(); } catch (_) {}
    await _cleanup(keepDevice: false);
  }

  Future<void> _cleanup({required bool keepDevice}) async {
    await _txSub?.cancel(); _txSub = null;
    await _connSub?.cancel(); _connSub = null;
    _rx = null; _tx = null;
    if (!keepDevice) _device = null;
  }
}

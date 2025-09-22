// lib/ble/ble_session.dart
import 'dart:async';
import 'dart:io' show Platform;
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

    // （可选）Android 上请求更大的 MTU，以便一次性写入较长帧
    await _ensureMtu(needed: 185);

    // 发现服务并绑定
    final services = await _device!.discoverServices();
    _rx = null;
    _tx = null;
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
          await _ensureMtu(needed: 185);
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

  /// ✅ 新增：写入任意原始字节（一次性发送）
  /// 会在 Android 上尝试请求较大 MTU（默认 23，净载 20），避免包长>20时写入失败。
  Future<void> writeRaw(List<int> data, {bool withoutResponse = false}) async {
    if (_rx == null) throw StateError('RX 未绑定或未连接');
    // 确保 MTU 足够（Android 有效；iOS/其它平台忽略）
    await _ensureMtu(needed: 185);
    await _rx!.write(data, withoutResponse: withoutResponse);
  }

  /// ✅ 可选：使用你新的“批量发送协议”一次性发送
  /// 格式：[0x02, type, high, low, 0x00, type, high, low, 0x00, ...]
  Future<void> sendAllBatch(Map<int, int> stats) async {
    if (_rx == null) throw StateError('RX 未绑定或未连接');
    final pkt = <int>[0x02];

    void addEntry(int type, int value) {
      final u = value.toUnsigned(16);
      final hi = (u >> 8) & 0xFF;
      final lo = u & 0xFF;
      pkt.addAll([type & 0xFF, hi, lo, 0x00]);
    }

    stats.forEach((type, value) => addEntry(type, value));
    await writeRaw(pkt); // 复用 writeRaw
  }

  /// 发送角色名字：首字节 0x03 + UTF-8 英文名（仅 ASCII）
  /// 要求：不包含中文（仅 [\x20-\x7E] 可见 ASCII）；长度你可按需限制（示例 <= 24）
  /// 若包含非法字符会抛异常
  Future<void> sendName(String name) async {
    if (_rx == null) throw StateError('RX 未绑定或未连接');

    final ascii = RegExp(r'^[\x20-\x7E]+$'); // 仅可见 ASCII（不含中文）
    if (name.isEmpty) {
      throw ArgumentError('角色名字不能为空');
    }
    if (!ascii.hasMatch(name)) {
      throw ArgumentError('角色名字只能包含英文/数字/常用符号（不支持中文）');
    }
    if (name.length > 24) {
      throw ArgumentError('角色名字过长（建议 ≤ 24 个字符）');
    }

    final bytes = <int>[0x03, ...name.codeUnits]; // ASCII == codeUnits
    await writeRaw(bytes); // 复用你已有的 writeRaw（会请求较大 MTU）
  }

  /// （可选）断开并清理；**正常不调用**，让连接贯穿全局直到关闭 App
  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (_) {}
    await _cleanup(keepDevice: false);
  }

  Future<void> _cleanup({required bool keepDevice}) async {
    await _txSub?.cancel();
    _txSub = null;
    await _connSub?.cancel();
    _connSub = null;
    _rx = null;
    _tx = null;
    if (!keepDevice) _device = null;
  }

  /// Android 上请求更大的 MTU；其它平台忽略异常
  Future<void> _ensureMtu({required int needed}) async {
    if (_device == null) return;
    try {
      // 只有 Android 支持 requestMtu；在其它平台调用会抛异常，直接吞掉
      if (Platform.isAndroid) {
        // FBP 里没有直接的 mtuNow getter，这里简单粗暴：每次写大包前请求到 185
        await _device!.requestMtu(needed);
        // 注意：部分手机厂商会限制最大 MTU（常见 185/517），不保证一定成功
        await Future.delayed(const Duration(milliseconds: 80));
      }
    } catch (_) {
      // 忽略：失败就交给底层拆包（若插件不拆包，则需自行分片协议）
    }
  }
}


// lib/ble/ble_client_flutterblue.dart
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_client.dart';

class FlutterBlueBleClient implements BleClient {
  final _scanCtl = StreamController<List<BleDevice>>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  StreamSubscription<List<int>>? _txNotifySub;
  final _notifyCtl = StreamController<List<int>>.broadcast();

  @override
  Stream<List<BleDevice>> scan({Duration? timeout}) {
    _scanSub?.cancel();
    final seen = <String, BleDevice>{};

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final d = r.device;
        final id = d.remoteId.str;

        final adName = r.advertisementData.advName;
        final devName = (adName != null && adName.isNotEmpty)
            ? adName
            : (d.platformName.isNotEmpty ? d.platformName : '未知设备');

        // 日志，确认能扫到
        print('[scan] id=$id name=$devName uuids=${r.advertisementData.serviceUuids}');

        seen[id] = BleDevice(id, devName);
      }
      _scanCtl.add(seen.values.toList());
    });

    FlutterBluePlus.startScan(
      timeout: timeout ?? const Duration(seconds: 15),
      // 按服务过滤，确保只扫 UART
      withServices: [Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E')],
    );

    return _scanCtl.stream;
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  @override
  Future<void> connect(String deviceId) async {
    // 关键修复：不要手动构造 BluetoothDevice；用 fromId 获取句柄
    await stopScan();
    _device = BluetoothDevice.fromId(deviceId);
    await _device!.connect(timeout: const Duration(seconds: 10));
  }

  @override
  Future<void> disconnect(String deviceId) async {
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
      _rxChar = null;
      _txChar = null;
    }
  }

  @override
  bool get isConnected => _device?.isConnected ?? false;

  @override
  Future<bool> discoverAndBind({
    required String deviceId,
    required String serviceUuid,
    required String rxUuid,
    required String txUuid,
  }) async {
    if (_device == null) return false;

    final services = await _device!.discoverServices();
    for (final s in services) {
      if (s.serviceUuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        for (final c in s.characteristics) {
          final cu = c.characteristicUuid.toString().toLowerCase();
          if (cu == rxUuid.toLowerCase()) _rxChar = c;
          if (cu == txUuid.toLowerCase()) _txChar = c;
        }
      }
    }

    if (_txChar != null) {
      await _txChar!.setNotifyValue(true);
      await _txNotifySub?.cancel();
      _txNotifySub = _txChar!.value.listen((bytes) {
        if (bytes.isNotEmpty) _notifyCtl.add(bytes);
      });
    }

    return _rxChar != null && _txChar != null;
  }

  @override
  Future<void> writeRx(List<int> data, {bool withoutResponse = false}) async {
    if (_rxChar == null) throw StateError('RX characteristic not bound');
    await _rxChar!.write(data, withoutResponse: withoutResponse);
  }

  @override
  Stream<List<int>> notifications() => _notifyCtl.stream;
}

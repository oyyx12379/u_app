// lib/scan_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:u_app/ble/ble_session.dart';
import 'package:u_app/esp32_device_screen.dart';

// === 与 ESP32 对应的服务/特征 UUID（保持与固件一致） ===
const String SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const String CHARACTERISTIC_UUID_RX = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // 写入 (APP->ESP)
const String CHARACTERISTIC_UUID_TX = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // 通知 (ESP->APP)

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isScanning = false;
  final Map<String, ScanResult> _resultMap = {}; // remoteId -> ScanResult
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  @override
  void initState() {
    super.initState();
    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      setState(() => _adapterState = s);
      if (s == BluetoothAdapterState.on && !_isScanning) {
        _startScan(); // 蓝牙打开时自动开始一次扫描
      }
    });
    _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    _adapterSub?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      if (_isScanning) return;
      // 清空旧结果
      setState(() {
        _resultMap.clear();
        _isScanning = true;
      });

      // 监听扫描结果
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((list) {
        for (final r in list) {
          _resultMap[r.device.remoteId.str] = r;
        }
        // 触发刷新
        if (mounted) setState(() {});
      }, onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('扫描错误：$e')));
        }
      });

      // 开始扫描（15s 超时自动停止）
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      // 额外兜底：15s 后停止（startScan 的 timeout 结束也会停，这里只是双保险）
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _isScanning) _stopScan();
      });
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('开始扫描失败：$e')));
      }
    }
  }

  Future<void> _stopScan() async {
    try {
      await _scanSub?.cancel();
      _scanSub = null;
      await FlutterBluePlus.stopScan();
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  List<ScanResult> get _resultsSorted {
    final list = _resultMap.values.toList();
    // 简单排序：ESP32 设备优先，其次按名称
    list.sort((a, b) {
      final an = a.device.platformName.toLowerCase();
      final bn = b.device.platformName.toLowerCase();
      final aes = an.contains('esp32') ? 0 : 1;
      final bes = bn.contains('esp32') ? 0 : 1;
      if (aes != bes) return aes - bes;
      return an.compareTo(bn);
    });
    return list;
  }

  Future<void> _connectAndOpen(ScanResult r) async {
    final dev = r.device; // 这是 FlutterBluePlus 的 BluetoothDevice ✅
    try {
      // 使用全局 BleSession 保持连接（直到退出 App 或手动 disconnect）
      await BleSession.I.connectAndBind(
        device: dev,
        serviceUuid: SERVICE_UUID,
        rxUuid: CHARACTERISTIC_UUID_RX,
        txUuid: CHARACTERISTIC_UUID_TX,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已连接：${dev.platformName.isEmpty ? dev.remoteId.str : dev.platformName}')),
      );

      // 进入设备详情页（注意，这个页面不会主动断开连接）
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ESP32DeviceScreen(device: dev),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('连接失败：$e')));
    }
  }

  Future<void> _disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已断开：${device.platformName.isEmpty ? device.remoteId.str : device.platformName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('断开失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _resultsSorted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙设备扫描'),
        actions: [
          IconButton(
            tooltip: _isScanning ? '停止扫描' : '重新扫描',
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _isScanning ? _stopScan : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: _isScanning ? Colors.blue.withOpacity(0.08) : Colors.grey.withOpacity(0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                    color: _isScanning ? Colors.blue : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _isScanning ? '正在扫描中…' : '扫描已停止',
                  style: TextStyle(
                    color: _isScanning ? Colors.blue : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isScanning) ...[
                  const SizedBox(width: 8),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('发现 ${results.length} 个设备',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    _isScanning ? '正在搜索设备…' : '未发现设备',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (!_isScanning)
                    TextButton(onPressed: _startScan, child: const Text('开始扫描')),
                ],
              ),
            )
                : ListView.builder(
              itemCount: results.length,
              itemBuilder: (c, i) {
                final r = results[i];
                final d = r.device; // BluetoothDevice ✅
                final isEsp32 = d.platformName.toLowerCase().contains('esp32');
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      isEsp32 ? Icons.memory : Icons.bluetooth,
                      color: isEsp32 ? Colors.blue : null,
                    ),
                    title: Text(
                      d.platformName.isEmpty ? '未知设备' : d.platformName,
                      style: TextStyle(
                        fontWeight: isEsp32 ? FontWeight.bold : FontWeight.normal,
                        color: isEsp32 ? Colors.blue : null,
                      ),
                    ),
                    subtitle: Text('MAC: ${d.remoteId.str}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '连接',
                          icon: const Icon(Icons.bluetooth_connected),
                          onPressed: () => _connectAndOpen(r),
                        ),
                        IconButton(
                          tooltip: '断开',
                          icon: const Icon(Icons.cable),
                          onPressed: () => _disconnect(d),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: _isScanning ? '停止扫描' : '开始扫描',
        onPressed: _isScanning ? _stopScan : _startScan,
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }
}

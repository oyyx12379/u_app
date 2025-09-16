// lib/scan_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'ble/ble_client.dart';
import 'ble/ble_impl.dart';
import 'esp32_device_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final BleClient _ble;
  StreamSubscription<List<BleDevice>>? _sub;
  List<BleDevice> _devices = [];
  List<BleDevice> _esp32 = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _ble = createBleClient();
    _startScan();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ble.stopScan();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _scanning = true;
      _devices = [];
      _esp32 = [];
    });

    _sub?.cancel();
    _sub = _ble.scan(timeout: const Duration(seconds: 15)).listen((list) {
      setState(() {
        _devices = list;
        _esp32 = list.where((d) => d.name.toLowerCase().contains('esp32')).toList();
      });
    }, onDone: () {
      if (mounted) setState(() => _scanning = false);
    }, onError: (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('扫描错误: $e')));
      }
    });
  }

  void _stopScan() async {
    await _ble.stopScan();
    setState(() => _scanning = false);
  }

  void _refresh() {
    _stopScan();
    _startScan();
  }

  void _onConnect(BleDevice d) async {
    // 跳转详情页（详情页再做连接）
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ESP32DeviceScreen(device: d)),
    );
  }

  Widget _tile(BleDevice d) {
    final isEsp32 = d.name.toLowerCase().contains('esp32');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.bluetooth, color: isEsp32 ? Colors.blue : Colors.grey),
        title: Text(d.name),
        subtitle: Text('ID: ${d.id}'),
        trailing: IconButton(
          icon: const Icon(Icons.bluetooth_connected),
          onPressed: () => _onConnect(d),
          tooltip: '连接',
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<BleDevice> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...list.map(_tile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final others = _devices.where((d) => !_esp32.contains(d)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙设备扫描 (Android / Windows)'),
        actions: [
          IconButton(
            icon: Icon(_scanning ? Icons.stop : Icons.refresh),
            onPressed: _scanning ? _stopScan : _refresh,
            tooltip: _scanning ? '停止扫描' : '重新扫描',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: _scanning ? Colors.blue.withOpacity(.1) : Colors.grey.withOpacity(.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_scanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                    color: _scanning ? Colors.blue : Colors.grey),
                const SizedBox(width: 8),
                Text(_scanning ? '正在扫描中...' : '扫描已停止',
                    style: TextStyle(
                      color: _scanning ? Colors.blue : Colors.grey,
                      fontWeight: FontWeight.bold,
                    )),
                if (_scanning) ...[
                  const SizedBox(width: 8),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('发现 ${_devices.length} 个设备 (${_esp32.length} 个ESP32)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_scanning ? '正在搜索设备...' : '未发现设备',
                      style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  if (!_scanning) TextButton(onPressed: _startScan, child: const Text('开始扫描')),
                ],
              ),
            )
                : ListView(
              children: [
                _buildSection('ESP32设备', _esp32),
                _buildSection('其他设备', others),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanning ? _stopScan : _startScan,
        child: Icon(_scanning ? Icons.stop : Icons.search),
      ),
    );
  }
}

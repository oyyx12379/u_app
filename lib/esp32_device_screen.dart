// lib/esp32_device_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'ble/ble_client.dart';
import 'ble/ble_impl.dart';
import 'widgets/stat_command_tile.dart';

// === BLE UART UUIDs (ESP32) ===
const String SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const String CHARACTERISTIC_UUID_RX = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
const String CHARACTERISTIC_UUID_TX = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

class ESP32DeviceScreen extends StatefulWidget {
  final BleDevice device;
  const ESP32DeviceScreen({super.key, required this.device});

  @override
  State<ESP32DeviceScreen> createState() => _ESP32DeviceScreenState();
}

class _ESP32DeviceScreenState extends State<ESP32DeviceScreen> {
  late final BleClient _ble;
  final List<String> _logs = [];
  StreamSubscription<List<int>>? _notifySub;
  bool _discovering = false;

  @override
  void initState() {
    super.initState();
    _ble = createBleClient();
    _connectAndDiscover();
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    _ble.disconnect(widget.device.id);
    super.dispose();
  }

  Future<void> _connectAndDiscover() async {
    try {
      setState(() => _discovering = true);
      await _ble.connect(widget.device.id);

      final ok = await _ble.discoverAndBind(
        deviceId: widget.device.id,
        serviceUuid: SERVICE_UUID,
        rxUuid: CHARACTERISTIC_UUID_RX,
        txUuid: CHARACTERISTIC_UUID_TX,
      );

      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到ESP32所需的特征值')),
        );
        Navigator.pop(context);
        return;
      }

      _notifySub = _ble.notifications().listen((bytes) {
        final msg = String.fromCharCodes(bytes);
        setState(() {
          _logs.add('收到: $msg');
          if (_logs.length > 200) _logs.removeAt(0);
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已连接 ${widget.device.name}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: $e')),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _sendByType({
    required int typeByte,
    required int value,
    required String label,
    int min = 0,
    int max = 999,
  }) async {
    if (!_ble.isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未连接')));
      return;
    }
    if (value < min || value > max) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 请输入 $min-$max')),
      );
      return;
    }

    try {
      final v = value & 0xFFFF;
      final high = (v >> 8) & 0xFF;
      final low = v & 0xFF;
      final data = [0x01, typeByte, high, low, 0x00];

      await _ble.writeRx(data);

      setState(() {
        _logs.add('发送 $label: $value (数据: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')})');
        if (_logs.length > 200) _logs.removeAt(0);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label $value 已发送')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  Future<void> _sendTestText() async {
    final text = 'Hello ESP32! ${DateTime.now().millisecondsSinceEpoch}\r\n';
    try {
      await _ble.writeRx(utf8.encode(text));
      setState(() {
        _logs.add('发送: $text');
        if (_logs.length > 200) _logs.removeAt(0);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _ble.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text('ESP32设备 - ${widget.device.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: connected ? _sendTestText : null,
            tooltip: '发送测试数据',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => setState(() => _logs.clear()),
            tooltip: '清空消息',
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部连接状态
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: connected ? Colors.green.withOpacity(.1) : Colors.red.withOpacity(.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: connected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connected ? '已连接' : (_discovering ? '连接中...' : '未连接'),
                      style: TextStyle(
                        color: connected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_discovering) ...[
                      const SizedBox(width: 8),
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ],
                ),
              ),
            ),

            // 四个输入小部件（先攻 + 三血量）
            SliverToBoxAdapter(
              child: Column(
                children: [
                  StatCommandTile(
                    title: '先攻值',
                    hint: '0-50',
                    min: 0,
                    max: 50,
                    typeByte: 0x02,
                    enabled: connected,
                    onSend: (v) => _sendByType(
                      typeByte: 0x02,
                      value: v,
                      label: '先攻值',
                      min: 0,
                      max: 50,
                    ),
                  ),
                  StatCommandTile(
                    title: '最大血量',
                    hint: '0-999',
                    min: 0,
                    max: 999,
                    typeByte: 0x08,
                    enabled: connected,
                    onSend: (v) => _sendByType(
                      typeByte: 0x08,
                      value: v,
                      label: '最大血量',
                      min: 0,
                      max: 999,
                    ),
                  ),
                  StatCommandTile(
                    title: '当前血量',
                    hint: '0-999',
                    min: 0,
                    max: 999,
                    typeByte: 0x07,
                    enabled: connected,
                    onSend: (v) => _sendByType(
                      typeByte: 0x07,
                      value: v,
                      label: '当前血量',
                      min: 0,
                      max: 999,
                    ),
                  ),
                  StatCommandTile(
                    title: '临时血量',
                    hint: '0-999',
                    min: 0,
                    max: 999,
                    typeByte: 0x09,
                    enabled: connected,
                    onSend: (v) => _sendByType(
                      typeByte: 0x09,
                      value: v,
                      label: '临时血量',
                      min: 0,
                      max: 999,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // “通信记录”标题
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('通信记录:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),

            // 日志列表（与页面同一滚动层）
            if (_logs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      '暂无通信记录\n输入并发送开始通信',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    return ListTile(
                      dense: true,
                      title: Text(_logs[index], style: const TextStyle(fontSize: 14)),
                    );
                  },
                  childCount: _logs.length,
                ),
              ),

            // 底部安全区留白
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
            ),
          ],
        ),
      ),
    );
  }
}

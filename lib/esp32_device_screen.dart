// lib/esp32_device_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble/ble_session.dart'; // 根据你的工程实际路径调整

// === 你的 ESP32 UART Service/Characteristic UUID（与 ESP32 端一致） ===
const String kServiceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const String kRxUuid     = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // APP -> ESP (Write)
const String kTxUuid     = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // ESP -> APP (Notify)

class ESP32DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  const ESP32DeviceScreen({super.key, required this.device});

  @override
  State<ESP32DeviceScreen> createState() => _ESP32DeviceScreenState();
}

class _ESP32DeviceScreenState extends State<ESP32DeviceScreen> {
  final _ctlRoleName = TextEditingController();
  String _connText = '连接中...';
  StreamSubscription<BluetoothConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    _connectAndBind();
    _listenConn();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _ctlRoleName.dispose();
    // 不在这里断开，让 BleSession 保持全局连接直至 App 退出
    super.dispose();
  }

  Future<void> _connectAndBind() async {
    try {
      await BleSession.I.connectAndBind(
        device: widget.device,
        serviceUuid: kServiceUuid,
        rxUuid: kRxUuid,
        txUuid: kTxUuid,
      );
      if (!mounted) return;
      setState(() => _connText = '已连接');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已连接到 ${widget.device.platformName.isEmpty ? widget.device.remoteId.str : widget.device.platformName}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _connText = '连接失败');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败：$e')),
      );
    }
  }

  void _listenConn() {
    _connSub?.cancel();
    _connSub = widget.device.connectionState.listen((s) {
      if (!mounted) return;
      setState(() {
        switch (s) {
          case BluetoothConnectionState.connected:
            _connText = '已连接';
            break;
          case BluetoothConnectionState.connecting:
            _connText = '连接中...';
            break;
          case BluetoothConnectionState.disconnecting:
            _connText = '断开中...';
            break;
          case BluetoothConnectionState.disconnected:
          default:
            _connText = '已断开（自动重连中）';
            break;
        }
      });
    });
  }

  Future<void> _sendName() async {
    final name = _ctlRoleName.text.trim();
    try {
      await BleSession.I.sendName(name); // 0x03 + ASCII name（已做校验）
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('角色名字已发送')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：$e')),
      );
    }
  }

  Future<void> _sendByType({
    required int typeByte,
    required int value,
    required String label,
    required int min,
    required int max,
  }) async {
    final v = value.clamp(min, max);
    try {
      await BleSession.I.sendStat(typeByte, v);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已发送 $label：$v')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送 $label 失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final devName = widget.device.platformName.isEmpty
        ? widget.device.remoteId.str
        : widget.device.platformName;

    final connected = BleSession.I.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text('ESP32设备 - $devName'),
      ),
      body: Column(
        children: [
          _ConnectionBanner(text: _connText, connected: connected),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 发送角色名字（0x03）
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('发送角色名字（仅英文/数字/常用符号）',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ctlRoleName,
                                  decoration: const InputDecoration(
                                    labelText: '角色名字（禁止中文，建议≤24字符）',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: connected ? _sendName : null,
                                icon: const Icon(Icons.drive_file_rename_outline),
                                label: const Text('发送名字'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('协议：0x03 + ASCII 名字字节（ESP端将拒绝非ASCII）。',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),

                  // 数值发送区域（使用统一小部件）
                  const SizedBox(height: 8),
                  _SectionTitle('战斗/状态数值设置'),
                  const SizedBox(height: 8),
                  _GridWrap(children: [
                    StatCommandTile(
                      title: '先攻',
                      hint: '0-50',
                      min: 0,
                      max: 50,
                      typeByte: 0x02,
                      enabled: connected,
                      onSend: (v) => _sendByType(
                        typeByte: 0x02,
                        value: v,
                        label: '先攻',
                        min: 0,
                        max: 50,
                      ),
                    ),
                    StatCommandTile(
                      title: '最大生命',
                      hint: '0-999',
                      min: 0,
                      max: 999,
                      typeByte: 0x08,
                      enabled: connected,
                      onSend: (v) => _sendByType(
                        typeByte: 0x08,
                        value: v,
                        label: '最大生命',
                        min: 0,
                        max: 999,
                      ),
                    ),
                    StatCommandTile(
                      title: '当前生命',
                      hint: '0-999',
                      min: 0,
                      max: 999,
                      typeByte: 0x07,
                      enabled: connected,
                      onSend: (v) => _sendByType(
                        typeByte: 0x07,
                        value: v,
                        label: '当前生命',
                        min: 0,
                        max: 999,
                      ),
                    ),
                    StatCommandTile(
                      title: '临时生命',
                      hint: '0-999',
                      min: 0,
                      max: 999,
                      typeByte: 0x09,
                      enabled: connected,
                      onSend: (v) => _sendByType(
                        typeByte: 0x09,
                        value: v,
                        label: '临时生命',
                        min: 0,
                        max: 999,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  _SectionTitle('防御/侦测/速度'),
                  const SizedBox(height: 8),
                  _GridWrap(children: [
                    StatCommandTile(
                      title: 'AC',
                      hint: '0-100',
                      min: 0,
                      max: 100,
                      typeByte: 0x13,
                      enabled: connected,
                      onSend: (v) => _sendByType(
                        typeByte: 0x13,
                        value: v,
                        label: 'AC',
                        min: 0,
                        max: 100,
                      ),
                    ),
                    StatCommandTile(
                      title: 'DC',
                      hint: '0-100',
                      min: 0,
                      max: 100,
                      typeByte: 0x14,
                      enabled: connected,
                      onSend: (v) => _sendByType(
                        typeByte: 0x14,
                        value: v,
                        label: 'DC',
                        min: 0,
                        max: 100,
                      ),
                    ),
                    StatCommandTile(
                      title: 'PP',
                      hint: '0-100',
                      min: 0,
                      max: 100,
                      typeByte: 0x15,
                      enabled: connected,
                      onSend: (v) => _sendByType(
                        typeByte: 0x15,
                        value: v,
                        label: 'PP',
                        min: 0,
                        max: 100,
                      ),
                    ),
                    StatCommandTile(
                      title: 'FT（速度）',
                      hint: '0-100',
                      min: 0,
                      max: 100,
                      typeByte: 0x16,
                      enabled: connected,
                      onSend: (v) => _sendByType(
                        typeByte: 0x16,
                        value: v,
                        label: 'FT',
                        min: 0,
                        max: 100,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),
                  const Text(
                    '说明：本页各项采用单条发送协议 [0x01, type, hi, lo, 0x00]。'
                        '若需一次性批量发送（0x02），请在角色卡汇总页使用“一键发送”。',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 连接状态横幅
class _ConnectionBanner extends StatelessWidget {
  final String text;
  final bool connected;
  const _ConnectionBanner({required this.text, required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      color: color.withOpacity(0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 小节标题
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

// 自适应网格（Wrap）
class _GridWrap extends StatelessWidget {
  final List<Widget> children;
  const _GridWrap({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, con) {
      final w = con.maxWidth;
      // 简单自适应：>=900 三列；>=600 两列；否则单列
      int cols = 1;
      if (w >= 900) cols = 3;
      else if (w >= 600) cols = 2;

      final itemWidth = (w - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children.map((e) => SizedBox(width: itemWidth, child: e)).toList(),
      );
    });
  }
}

/// 统一的数值发送小部件
class StatCommandTile extends StatefulWidget {
  final String title;
  final String hint;
  final int min;
  final int max;
  final int typeByte;
  final bool enabled;
  final Future<void> Function(int value) onSend;

  const StatCommandTile({
    super.key,
    required this.title,
    required this.hint,
    required this.min,
    required this.max,
    required this.typeByte,
    required this.enabled,
    required this.onSend,
  });

  @override
  State<StatCommandTile> createState() => _StatCommandTileState();
}

class _StatCommandTileState extends State<StatCommandTile> {
  final _ctl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入数值')),
      );
      return;
    }
    final v = int.tryParse(text);
    if (v == null || v < widget.min || v > widget.max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入 ${widget.min}-${widget.max} 的整数')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSend(v);
      _ctl.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    enabled: widget.enabled && !_busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: (widget.enabled && !_busy) ? _send : null,
                  icon: _busy
                      ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('发送'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('协议：0x01, 0x${widget.typeByte.toRadixString(16).padLeft(2, '0').toUpperCase()}, hi, lo, 0x00',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

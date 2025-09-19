// lib/esp32_device_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// 角色卡页面
import 'package:u_app/character_builder_wizard.dart';


// 全局 BLE 会话
import 'package:u_app/ble/ble_session.dart';



// === 你的 ESP32 服务/特征 UUID（保持与固件一致） ===
const String SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const String CHARACTERISTIC_UUID_RX = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // 写入 (APP->ESP)
const String CHARACTERISTIC_UUID_TX = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // 通知 (ESP->APP)

/// ESP32 设备详情页面（使用全局 BleSession 保持连接，页面退出不主动断开）
class ESP32DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const ESP32DeviceScreen({super.key, required this.device});

  @override
  State<ESP32DeviceScreen> createState() => _ESP32DeviceScreenState();
}

class _ESP32DeviceScreenState extends State<ESP32DeviceScreen> {
  bool _isConnected = false;
  bool _isDiscoveringServices = false; // 连接/绑定中转圈
  final List<String> _log = [];

  StreamSubscription<BluetoothConnectionState>? _connSub;

  // —— 示例：之前页面里的“先攻值”输入支持，这里保留一个可复用控制器（非必须）
  final TextEditingController _initiativeController = TextEditingController();
  final FocusNode _initiativeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _connectAndBind();
    _subscribeConnState();
  }

  void _subscribeConnState() {
    // 监听连接状态变化，用于顶部状态条显示
    final dev = widget.device;
    _connSub = dev.connectionState.listen((s) {
      setState(() {
        _isConnected = (s == BluetoothConnectionState.connected);
      });
    });
  }

  Future<void> _connectAndBind() async {
    try {
      setState(() {
        _isDiscoveringServices = true;
      });

      await BleSession.I.connectAndBind(
        device: widget.device,
        serviceUuid: SERVICE_UUID,
        rxUuid: CHARACTERISTIC_UUID_RX,
        txUuid: CHARACTERISTIC_UUID_TX,
      );

      setState(() {
        _isConnected = true;
        _isDiscoveringServices = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已连接：${widget.device.platformName}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDiscoveringServices = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接/绑定失败：$e')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    // ❗ 不要主动断开，让连接由 BleSession 贯穿全局，直到你退出 App 或手动调用 disconnect()
    _connSub?.cancel();
    _initiativeController.dispose();
    _initiativeFocusNode.dispose();
    super.dispose();
  }

  // 统一的数值发送（封装协议）
  Future<void> _sendByType({
    required int typeByte,
    required int value,
    String? label,
  }) async {
    if (!_isConnected) {
      _appendLog('⚠️ 未连接，无法发送（type=0x${typeByte.toRadixString(16)}, val=$value)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未连接蓝牙，无法发送')),
      );
      return;
    }
    try {
      final v = value.clamp(0, 999);
      await BleSession.I.sendStat(typeByte, v);
      _appendLog('发送 ${label ?? 'stat'}: type=0x${typeByte.toRadixString(16)}, value=$v');
    } catch (e) {
      _appendLog('❌ 发送失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：$e')),
      );
    }
  }

  void _appendLog(String line) {
    setState(() {
      _log.add(line);
      if (_log.length > 100) _log.removeAt(0);
    });
  }

  void _clearLog() => setState(_log.clear);

  @override
  Widget build(BuildContext context) {
    final connected = _isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text('ESP32设备 - ${widget.device.platformName}'),
        actions: [
          IconButton(
            tooltip: '角色卡',
            icon: const Icon(Icons.assignment_ind),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CharacterBuilderWizardPage(
                  // ✅ 关键：把单条发送函数注入
                  sendStat: (type, value) => BleSession.I.sendStat(type, value),
                ),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: '清空记录',
            onPressed: _clearLog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部状态条
          Container(
            padding: const EdgeInsets.all(12),
            color: connected ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  connected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                  color: connected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  connected
                      ? '已连接'
                      : (_isDiscoveringServices ? '连接中/绑定服务...' : '未连接'),
                  style: TextStyle(
                    color: connected ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isDiscoveringServices) ...[
                  const SizedBox(width: 8),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('数据发送', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // —— 先攻值（0x02）——
                StatCommandTile(
                  title: '先攻(Init)',
                  hint: '0-50',
                  min: 0,
                  max: 50,
                  typeByte: 0x02,
                  enabled: connected,
                  onSend: (v) => _sendByType(
                    typeByte: 0x02,
                    value: v,
                    label: '先攻',
                  ),
                ),

                const SizedBox(height: 8),

                // —— 三个生命值（0x08/0x07/0x09）——
                Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    SizedBox(
                      width: _tileWidth(context),
                      child: StatCommandTile(
                        title: '最大生命(Max HP)',
                        hint: '0-999',
                        min: 0,
                        max: 999,
                        typeByte: 0x08,
                        enabled: connected,
                        onSend: (v) => _sendByType(
                          typeByte: 0x08,
                          value: v,
                          label: '最大生命',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _tileWidth(context),
                      child: StatCommandTile(
                        title: '当前生命(Cur HP)',
                        hint: '0-999',
                        min: 0,
                        max: 999,
                        typeByte: 0x07,
                        enabled: connected,
                        onSend: (v) => _sendByType(
                          typeByte: 0x07,
                          value: v,
                          label: '当前生命',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _tileWidth(context),
                      child: StatCommandTile(
                        title: '临时生命(Temp HP)',
                        hint: '0-999',
                        min: 0,
                        max: 999,
                        typeByte: 0x09,
                        enabled: connected,
                        onSend: (v) => _sendByType(
                          typeByte: 0x09,
                          value: v,
                          label: '临时生命',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // —— AC / DC / PP / FT ——（你之前要求的四个模块）
                Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    SizedBox(
                      width: _tileWidth(context),
                      child: StatCommandTile(
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
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _tileWidth(context),
                      child: StatCommandTile(
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
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _tileWidth(context),
                      child: StatCommandTile(
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
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _tileWidth(context),
                      child: StatCommandTile(
                        title: 'FT (速度 尺)',
                        hint: '0-100',
                        min: 0,
                        max: 100,
                        typeByte: 0x16,
                        enabled: connected,
                        onSend: (v) => _sendByType(
                          typeByte: 0x16,
                          value: v,
                          label: 'FT(速度)',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Text('通信记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_log.isEmpty)
                  const Text('暂无记录', style: TextStyle(color: Colors.grey))
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minHeight: 80),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _log.length,
                      itemBuilder: (c, i) => ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        title: Text(_log[i], style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _tileWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // 宽屏时一行 3 个，窄屏时一行 1~2 个
    if (w > 1100) return (w - 48) / 3; // 粗略估算：左右 padding + Wrap spacing
    if (w > 720) return (w - 36) / 2;
    return w - 24;
  }
}

/// 统一的小部件：一个标题 + 数字输入 + “发送”按钮
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
  final TextEditingController _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final raw = _ctl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入 ${widget.title}（${widget.hint}）')),
      );
      return;
    }
    final v = int.tryParse(raw);
    if (v == null || v < widget.min || v > widget.max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.title} 必须是 ${widget.min}-${widget.max} 的整数')),
      );
      return;
    }
    await widget.onSend(v);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.enabled ? _handleSend : null,
                  child: const Text('发送'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('范围：${widget.min}-${widget.max}    协议: [0x01, 0x${widget.typeByte.toRadixString(16)}, hi, lo, 0x00]',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

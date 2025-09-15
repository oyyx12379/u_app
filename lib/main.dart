// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const FlutterBlueApp());
}

// 定义ESP32的UUID
const String SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const String CHARACTERISTIC_UUID_RX = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
const String CHARACTERISTIC_UUID_TX = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

// 蓝牙关闭界面
class BluetoothOffScreen extends StatelessWidget {
  final BluetoothAdapterState adapterState;

  const BluetoothOffScreen({super.key, required this.adapterState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙状态'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              '蓝牙适配器状态: ${_getAdapterStateText(adapterState)}',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (adapterState == BluetoothAdapterState.off)
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FlutterBluePlus.turnOn();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('打开蓝牙失败: $e')),
                    );
                  }
                },
                child: const Text('打开蓝牙'),
              ),
          ],
        ),
      ),
    );
  }

  String _getAdapterStateText(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.off:
        return '已关闭';
      case BluetoothAdapterState.on:
        return '已开启';
      case BluetoothAdapterState.turningOn:
        return '正在开启...';
      case BluetoothAdapterState.turningOff:
        return '正在关闭...';
      default:
        return '未知状态';
    }
  }
}

// 设备列表项
class DeviceListTile extends StatelessWidget {
  const DeviceListTile({
    super.key,
    required this.device,
    required this.onConnect,
    required this.onDisconnect,
  });

  final BluetoothDevice device;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  List<Widget> _buildTrailingButtons(BluetoothDevice device) {
    if (device.isConnected) {
      return [
        IconButton(
          icon: const Icon(Icons.cable, color: Colors.green),
          onPressed: onDisconnect,
          tooltip: '断开连接',
        )
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.bluetooth),
          onPressed: onConnect,
          tooltip: '连接设备',
        )
      ];
    }
  }

  String _getRssiText(int? rssi) {
    if (rssi == null) return '未知';
    return '$rssi dBm';
  }

  String _getDeviceType(BluetoothDevice device) {
    // 根据设备名称或服务来推断设备类型
    final name = device.platformName.toLowerCase();

    if (name.contains('esp32') || name.contains('esp')) {
      return 'ESP32设备';
    } else if (name.contains('mouse') || name.contains('mous')) {
      return '鼠标';
    } else if (name.contains('keyboard') || name.contains('kb')) {
      return '键盘';
    } else if (name.contains('headset') || name.contains('耳机')) {
      return '耳机';
    } else if (name.contains('speaker') || name.contains('音箱')) {
      return '音箱';
    } else if (name.contains('watch') || name.contains('手表')) {
      return '智能手表';
    } else if (name.contains('phone') || name.contains('手机')) {
      return '手机';
    } else if (name.contains('tablet') || name.contains('平板')) {
      return '平板';
    } else if (name.contains('computer') || name.contains('电脑')) {
      return '电脑';
    } else {
      return '蓝牙设备';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BluetoothConnectionState>(
      stream: device.connectionState,
      initialData: BluetoothConnectionState.disconnected,
      builder: (c, snapshot) {
        final isConnected = snapshot.data == BluetoothConnectionState.connected;
        final isEsp32 = device.platformName.toLowerCase().contains('esp32');

        return ListTile(
          leading: Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: isConnected ? Colors.green : (isEsp32 ? Colors.blue : Colors.grey),
          ),
          title: Text(
            device.platformName.isNotEmpty ? device.platformName : '未知设备',
            style: TextStyle(
              color: isEsp32 ? Colors.blue : null,
              fontWeight: isEsp32 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAC: ${device.remoteId.str}'),
              Text('类型: ${_getDeviceType(device)}'),
              Text('状态: ${isConnected ? '已连接' : '未连接'}'),
              if (isEsp32)
                Text('ESP32设备', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildTrailingButtons(device),
          ),
        );
      },
    );
  }
}

// ESP32设备详情页面
class ESP32DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const ESP32DeviceScreen({super.key, required this.device});

  @override
  State<ESP32DeviceScreen> createState() => _ESP32DeviceScreenState();
}

class _ESP32DeviceScreenState extends State<ESP32DeviceScreen> {
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  List<String> _receivedMessages = [];
  bool _isConnected = false;
  bool _isDiscoveringServices = false;
  final TextEditingController _initiativeController = TextEditingController();
  final FocusNode _initiativeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  @override
  void dispose() {
    _disconnectFromDevice();
    _initiativeController.dispose();
    _initiativeFocusNode.dispose();
    super.dispose();
  }

  void _connectToDevice() async {
    try {
      setState(() {
        _isConnected = false;
        _isDiscoveringServices = true;
      });

      // 连接设备
      await widget.device.connect();

      // 发现服务
      List<BluetoothService> services = await widget.device.discoverServices();

      // 查找ESP32服务
      for (BluetoothService service in services) {
        if (service.serviceUuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.characteristicUuid.toString().toLowerCase() ==
                CHARACTERISTIC_UUID_RX.toLowerCase()) {
              _rxCharacteristic = characteristic;
            } else if (characteristic.characteristicUuid.toString().toLowerCase() ==
                CHARACTERISTIC_UUID_TX.toLowerCase()) {
              _txCharacteristic = characteristic;
              // 监听TX特征值的通知
              await _txCharacteristic!.setNotifyValue(true);
              _txCharacteristic!.value.listen((value) {
                if (value.isNotEmpty) {
                  String message = String.fromCharCodes(value);
                  setState(() {
                    _receivedMessages.add('收到: $message');
                    if (_receivedMessages.length > 20) {
                      _receivedMessages.removeAt(0);
                    }
                  });
                }
              });
            }
          }
        }
      }

      if (_rxCharacteristic == null || _txCharacteristic == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到ESP32所需的特征值')),
        );
        Navigator.pop(context);
        return;
      }

      setState(() {
        _isConnected = true;
        _isDiscoveringServices = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已成功连接到 ${widget.device.platformName}')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: $e')),
      );
      Navigator.pop(context);
    }
  }

  void _disconnectFromDevice() async {
    try {
      await widget.device.disconnect();
      setState(() {
        _isConnected = false;
      });
    } catch (e) {
      print('断开连接错误: $e');
    }
  }

  // 发送先攻值数据
  void _sendInitiativeValue() async {
    if (_rxCharacteristic == null || !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未连接或特征值不可用')),
      );
      return;
    }

    // 验证输入
    final input = _initiativeController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入先攻值')),
      );
      return;
    }

    final initiativeValue = int.tryParse(input);
    if (initiativeValue == null || initiativeValue < 0 || initiativeValue > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入0-50之间的数字')),
      );
      return;
    }

    try {
      // 将数字转换为16位无符号整数
      final uint16Value = initiativeValue.toUnsigned(16);

      // 拆分高八位和低八位
      final highByte = (uint16Value >> 8) & 0xFF;
      final lowByte = uint16Value & 0xFF;

      // 构建数据包: 0x01, 0x02, 高八位, 低八位, 0x00
      final data = [0x01, 0x02, highByte, lowByte, 0x00];

      // 发送数据
      await _rxCharacteristic!.write(data);

      // 更新界面显示
      setState(() {
        _receivedMessages.add('发送先攻值: $initiativeValue (数据: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')})');
        if (_receivedMessages.length > 20) {
          _receivedMessages.removeAt(0);
        }
      });

      // 清空输入框
      _initiativeController.clear();
      _initiativeFocusNode.unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('先攻值 $initiativeValue 已发送')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
    }
  }

  // 发送测试数据
  void _sendTestData() async {
    if (_rxCharacteristic == null || !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未连接或特征值不可用')),
      );
      return;
    }

    try {
      String testMessage = 'Hello ESP32! ${DateTime.now().millisecondsSinceEpoch}\r\n';
      List<int> bytes = utf8.encode(testMessage);

      await _rxCharacteristic!.write(bytes);

      setState(() {
        _receivedMessages.add('发送: $testMessage');
        if (_receivedMessages.length > 20) {
          _receivedMessages.removeAt(0);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('测试数据已发送')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
    }
  }

  void _clearMessages() {
    setState(() {
      _receivedMessages.clear();
    });
  }

  // 输入验证 - 只允许数字和退格键
  void _validateInput(String value) {
    if (value.isNotEmpty) {
      final numValue = int.tryParse(value);
      if (numValue == null || numValue < 0 || numValue > 50) {
        // 如果输入无效，恢复到上一个有效值或清空
        final validValue = _initiativeController.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (validValue.isNotEmpty && int.parse(validValue) <= 50) {
          _initiativeController.text = validValue;
        } else {
          _initiativeController.clear();
        }
        _initiativeController.selection = TextSelection.collapsed(offset: _initiativeController.text.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ESP32设备 - ${widget.device.platformName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendTestData,
            tooltip: '发送测试数据',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearMessages,
            tooltip: '清空消息',
          ),
        ],
      ),
      body: Column(
        children: [
          // 连接状态
          Container(
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? '已连接' : '连接中...',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isDiscoveringServices) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),

          // 先攻值输入区域
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '先攻值设置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _initiativeController,
                        focusNode: _initiativeFocusNode,
                        decoration: const InputDecoration(
                          labelText: '先攻值 (0-50)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [],
                        onChanged: _validateInput,
                        onSubmitted: (_) => _sendInitiativeValue(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isConnected ? _sendInitiativeValue : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(80, 48),
                      ),
                      child: const Text('发送'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '输入0-50之间的数字，将作为16位无符号整数发送',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 测试数据发送按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _isConnected ? _sendTestData : null,
              icon: const Icon(Icons.message),
              label: const Text('发送测试文本数据'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 消息列表标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              '通信记录:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // 消息列表
          Expanded(
            child: _receivedMessages.isEmpty
                ? const Center(
              child: Text(
                '暂无通信记录\n输入先攻值并点击发送开始通信',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _receivedMessages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _receivedMessages[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 扫描界面
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _devices = [];
  List<BluetoothDevice> _esp32Devices = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  void _startScan() async {
    try {
      setState(() {
        _isScanning = true;
        _devices.clear();
        _esp32Devices.clear();
      });

      // 检查蓝牙是否开启
      if (await FlutterBluePlus.isAvailable == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('蓝牙不可用')),
        );
        return;
      }

      // 开始扫描
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _updateDeviceList(results);
      }, onError: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描错误: $e')),
        );
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      // 15秒后自动停止扫描
      Future.delayed(const Duration(seconds: 15), () {
        if (_isScanning) {
          _stopScan();
        }
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始扫描失败: $e')),
      );
      setState(() => _isScanning = false);
    }
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }

  void _updateDeviceList(List<ScanResult> results) {
    final newDevices = results.map((result) => result.device).toList();

    // 去重并更新设备列表
    final uniqueDevices = <BluetoothDevice>[];
    final uniqueEsp32Devices = <BluetoothDevice>[];

    for (var device in newDevices) {
      if (!uniqueDevices.any((d) => d.remoteId == device.remoteId)) {
        uniqueDevices.add(device);

        // 检查是否为ESP32设备
        if (device.platformName.toLowerCase().contains('esp32')) {
          if (!uniqueEsp32Devices.any((d) => d.remoteId == device.remoteId)) {
            uniqueEsp32Devices.add(device);
          }
        }
      }
    }


    setState(() {
      _devices = uniqueDevices;
      _esp32Devices = uniqueEsp32Devices;
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      // 如果是ESP32设备，跳转到详情页面
      if (device.platformName.toLowerCase().contains('esp32')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ESP32DeviceScreen(device: device),
          ),
        );
      } else {
        await device.connect();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已连接到 ${device.platformName}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: $e')),
      );
    }
  }

  void _disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已断开连接 ${device.platformName}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('断开连接失败: $e')),
      );
    }
  }

  void _refreshScan() {
    _stopScan();
    _startScan();
  }

  Widget _buildDeviceList(List<BluetoothDevice> devices, String title) {
    if (devices.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...devices.map((device) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: DeviceListTile(
            device: device,
            onConnect: () => _connectToDevice(device),
            onDisconnect: () => _disconnectFromDevice(device),
          ),
        )).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙设备扫描'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _isScanning ? _stopScan : _refreshScan,
            tooltip: _isScanning ? '停止扫描' : '重新扫描',
          ),
        ],
      ),
      body: Column(
        children: [
          // 扫描状态指示器
          Container(
            padding: const EdgeInsets.all(16),
            color: _isScanning ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                  color: _isScanning ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isScanning ? '正在扫描中...' : '扫描已停止',
                  style: TextStyle(
                    color: _isScanning ? Colors.blue : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isScanning) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),

          // 设备数量统计
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '发现 ${_devices.length} 个设备 (${_esp32Devices.length} 个ESP32设备)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // 设备列表
          Expanded(
            child: _devices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _isScanning ? '正在搜索设备...' : '未发现设备',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  if (!_isScanning)
                    TextButton(
                      onPressed: _startScan,
                      child: const Text('开始扫描'),
                    ),
                ],
              ),
            )
                : ListView(
              children: [
                _buildDeviceList(_esp32Devices, 'ESP32设备'),
                _buildDeviceList(
                    _devices.where((d) => !_esp32Devices.contains(d)).toList(),
                    '其他设备'
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? _stopScan : _startScan,
        child: Icon(_isScanning ? Icons.stop : Icons.search),
        tooltip: _isScanning ? '停止扫描' : '开始扫描',
      ),
    );
  }
}

//
// This widget shows BluetoothOffScreen or
// ScanScreen depending on the adapter state
//
class FlutterBlueApp extends StatefulWidget {
  const FlutterBlueApp({super.key});

  @override
  State<FlutterBlueApp> createState() => _FlutterBlueAppState();
}

class _FlutterBlueAppState extends State<FlutterBlueApp> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screen = _adapterState == BluetoothAdapterState.on
        ? const ScanScreen()
        : BluetoothOffScreen(adapterState: _adapterState);

    return MaterialApp(
      color: Colors.lightBlue,
      debugShowCheckedModeBanner: false,
      home: screen,
      navigatorObservers: [BluetoothAdapterStateObserver()],
    );
  }
}

//
// This observer listens for Bluetooth Off and dismisses the DeviceScreen
//
class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/DeviceScreen') {
      // Start listening to Bluetooth state changes when a new route is pushed
      _adapterStateSubscription ??= FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) {
          // Pop the current route if Bluetooth is off
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // Cancel the subscription when the route is popped
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}
import 'package:flutter/material.dart';
import 'dart:io' show Platform;


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _initiativeController = TextEditingController();
  final TextEditingController _currentHealthController = TextEditingController();
  final TextEditingController _maxHealthController = TextEditingController();

  // 平台检测
  bool get isWindows => Platform.isWindows;
  bool get isMobile => Platform.isAndroid || Platform.isIOS;

  // 蓝牙相关变量（只在移动端使用）
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  String _statusMessage = '蓝牙功能';

  @override
  void initState() {
    super.initState();
    _initializeBluetoothStatus();
  }

  void _initializeBluetoothStatus() {
    if (isWindows) {
      _statusMessage = 'Windows平台：使用模拟蓝牙功能';
    } else if (isMobile) {
      _statusMessage = '蓝牙未连接';
      // 移动端可以初始化真正的蓝牙功能
      // _checkBluetoothState();
    }
  }

  @override
  void dispose() {
    _initiativeController.dispose();
    _currentHealthController.dispose();
    _maxHealthController.dispose();
    super.dispose();
  }

  // 扫描设备（Windows模拟）
  Future<void> _scanDevices() async {
    if (isWindows) {
      setState(() {
        _isScanning = true;
        _statusMessage = 'Windows：模拟扫描蓝牙设备...';
      });
      
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isScanning = false;
        _statusMessage = '扫描完成（模拟）';
      });
    } else {
      // 移动端真实扫描代码
      // await FlutterBluePlus.startScan(...);
    }
  }

  // 连接设备（Windows模拟）
  Future<void> _connectToDevice() async {
    if (isWindows) {
      setState(() {
        _isConnecting = true;
        _statusMessage = 'Windows：模拟连接蓝牙设备...';
      });
      
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _statusMessage = '已连接到模拟设备';
      });
    } else {
      // 移动端真实连接代码
    }
  }

  // 断开连接
  Future<void> _disconnect() async {
    setState(() {
      _isConnected = false;
      _statusMessage = isWindows ? 'Windows：模拟断开连接' : '已断开连接';
    });
  }

  // 发送数据
  Future<void> _sendData() async {
    String data = '先攻:${_initiativeController.text},'
                 '当前生命:${_currentHealthController.text},'
                 '最大生命:${_maxHealthController.text}';

    if (isWindows) {
      // Windows平台模拟发送
      print('Windows模拟发送数据: $data');
      setState(() {
        _statusMessage = '数据发送成功（模拟）: $data';
      });
    } else {
      // 移动端真实发送
      // if (_characteristic != null) {
      //   List<int> bytes = data.codeUnits;
      //   await _characteristic!.write(bytes);
      //   setState(() {
      //     _statusMessage = '数据发送成功';
      //   });
      // } else {
      //   setState(() {
      //     _statusMessage = '请先连接蓝牙设备';
      //   });
      // }flu
      
      // 暂时也使用模拟
      setState(() {
        _statusMessage = '移动端数据发送: $data';
      });
    }
  }

  // 按钮点击处理方法
  void _onInitiativeButtonPressed() {
    _sendData();
  }

  void _onCurrentHealthButtonPressed() {
    _sendData();
  }

  void _onMaxHealthButtonPressed() {
    _sendData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isWindows ? '角色状态管理 - Windows版' : '角色状态管理 - 蓝牙版'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (!isWindows) // 只在移动端显示蓝牙按钮
          IconButton(
            icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
            onPressed: _isScanning ? null : _scanDevices,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态显示
            Card(
              color: _isConnected ? Colors.green[100] : Colors.blue[100],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isWindows)
                      const Text('（Windows平台使用模拟功能）', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Windows平台显示提示信息
            if (isWindows)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Windows平台使用模拟蓝牙功能\n真实蓝牙功能请在移动设备上测试',
                    style: TextStyle(color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // 连接/断开按钮
            if (!isWindows) // 只在移动端显示连接按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : _connectToDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isConnecting 
                        ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                        : const Text('连接设备'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _disconnect : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('断开连接'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 输入框行
            _buildInputRow(
              label: '先攻',
              controller: _initiativeController,
              onButtonPressed: _onInitiativeButtonPressed,
            ),
            
            const SizedBox(height: 20),
            
            _buildInputRow(
              label: '当前生命',
              controller: _currentHealthController,
              onButtonPressed: _onCurrentHealthButtonPressed,
            ),
            
            const SizedBox(height: 20),
            
            _buildInputRow(
              label: '最大生命',
              controller: _maxHealthController,
              onButtonPressed: _onMaxHealthButtonPressed,
            ),
            
            const SizedBox(height: 20),
            
            // 发送按钮
            ElevatedButton.icon(
              onPressed: _sendData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: Icon(isWindows ? Icons.send : Icons.bluetooth),
              label: Text(isWindows ? '模拟发送数据' : '蓝牙发送数据'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow({
    required String label,
    required TextEditingController controller,
    required VoidCallback onButtonPressed,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '请输入$label',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: onButtonPressed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('发送'),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
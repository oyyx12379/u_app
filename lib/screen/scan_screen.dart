import 'package:flutter/material.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan for Devices'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(
              Icons.bluetooth_searching,
              size: 200.0,
              color: Colors.blue,
            ),
            Text(
              'Scanning for Bluetooth devices...',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
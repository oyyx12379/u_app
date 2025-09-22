// lib/main.dart
import 'package:flutter/material.dart';
import 'package:u_app/dice_page.dart';

// 你的扫描页
import 'scan_screen.dart';

// 角色卡
import 'character_builder_wizard.dart';

// ✅ 导入 BleSession
import 'ble/ble_session.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'U App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const _RootShell(),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell({super.key});
  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ScanScreen(),

      // ✅ 把发送方法注入到角色卡页面
      CharacterBuilderWizardPage(
        sendStat:  (type, value) => BleSession.I.sendStat(type, value),
        sendBytes: (data)        => BleSession.I.writeRaw(data),
      ),

      const DicePage(),
    ];

    final titles = <String>['设备', '角色卡', '骰盘'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bluetooth_searching), label: '设备'),
          NavigationDestination(icon: Icon(Icons.assignment_ind_outlined), label: '角色卡'),
          NavigationDestination(
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino),
            label: '骰盘',
          ),
        ],
      ),
    );
  }
}

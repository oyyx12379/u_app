// lib/main.dart
import 'package:flutter/material.dart';
import 'package:u_app/dice_page.dart';

// === 你的原有页面 ===
// 如果你的扫描页文件名或路径不同，请改成你的实际文件。
import 'scan_screen.dart';

// === 新的角色卡页面（外置 JSON 版） ===
import 'character_builder_wizard.dart';

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

/// 底部导航：
/// 1) “设备” 使用你原来的扫描页
/// 2) “角色卡” 使用外置 SRD 数据的 demo 页面（替换你之前的角色卡实现）
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
      const ScanScreen(),               // 你的原有蓝牙扫描/连接页
      const CharacterBuilderWizardPage(),     // 新的角色创建向导
      const DicePage(),
    ];

    final titles = <String>[
      '设备',
      '角色卡',
      '骰盘'
    ];

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

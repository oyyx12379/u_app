// lib/dice_page.dart
import 'dart:math';
import 'package:flutter/material.dart';

/// 骰盘页面：支持 d4 / d6 / d8 / d10 / d12 / d20 添加到骰盘，roll / clear / save
class DicePage extends StatefulWidget {
  const DicePage({super.key});

  @override
  State<DicePage> createState() => _DicePageState();
}

class _DicePageState extends State<DicePage> {
  final Map<int, int> _tray = <int, int>{};      // 骰盘：面数 -> 数量
  final List<String> _history = <String>[];      // 历史记录（每次 roll 自动保存）
  final List<String> _saved = <String>[];        // 手动收藏的记录
  final Random _rng = Random();
  String? _lastResult;                           // 最近一次 roll 的结果字符串

  // 添加一个骰子到骰盘
  void _addDie(int sides) {
    setState(() => _tray.update(sides, (v) => v + 1, ifAbsent: () => 1));
  }

  // 计算当前骰盘的摘要，例如 "2d4 + 1d8"
  String _traySummary() {
    if (_tray.isEmpty) return '骰盘为空';
    final parts = _tray.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return parts.map((e) => '${e.value}d${e.key}').join(' + ');
  }

  // roll 当前骰盘，并生成结果字符串，如：2d4+1d8=2+2+6=10
  void _roll() {
    if (_tray.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('骰盘为空，先添加一些骰子吧')));
      return;
    }
    final parts = <String>[];
    final values = <int>[];
    int total = 0;

    // 左边公式：2d4+1d8
    final left = _tray.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    parts.add(left.map((e) => '${e.value}d${e.key}').join('+'));

    // 中间：每次投掷的明细 2+2+6
    final midRolls = <int>[];
    for (final entry in left) {
      final count = entry.value;
      final sides = entry.key;
      for (int i = 0; i < count; i++) {
        final v = _rng.nextInt(sides) + 1; // 1..sides
        midRolls.add(v);
        values.add(v);
        total += v;
      }
    }
    parts.add(midRolls.join('+'));

    // 拼装完整字符串：2d4+1d8=2+2+6=10
    final resultStr = '${parts[0]}=${parts[1]}=$total';

    setState(() {
      _lastResult = resultStr;
      _history.insert(0, resultStr); // 自动保存到历史
    });
  }

  // 清空骰盘（不清历史）
  void _clearTray() {
    setState(() {
      _tray.clear();
    });
  }

  // 收藏当前最新结果
  void _saveLast() {
    if (_lastResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('还没有可保存的记录')));
      return;
    }
    setState(() => _saved.insert(0, _lastResult!));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到收藏')));
  }

  Widget _buildDieButton(String label, int sides) {
    final count = _tray[sides] ?? 0;
    return ElevatedButton(
      onPressed: () => _addDie(sides),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('x$count', style: const TextStyle(fontSize: 12)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 骰子按钮区
          _sectionTitle('添加骰子'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildDieButton('d4', 4),
              _buildDieButton('d6', 6),
              _buildDieButton('d8', 8),
              _buildDieButton('d10', 10),
              _buildDieButton('d12', 12),
              _buildDieButton('d20', 20),
            ],
          ),

          const SizedBox(height: 12),

          // 操作区：roll / clear / save
          _sectionTitle('操作'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _roll,
                icon: const Icon(Icons.casino),
                label: const Text('Roll'),
              ),
              ElevatedButton.icon(
                onPressed: _clearTray,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
              ),
              ElevatedButton.icon(
                onPressed: _saveLast,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 当前骰盘摘要
          _sectionTitle('当前骰盘'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_traySummary()),
          ),

          // 最近一次结果
          _sectionTitle('最新结果'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_lastResult ?? '尚未投掷'),
          ),

          // 历史记录
          _sectionTitle('历史记录（自动保存）'),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('暂无'),
            )
          else
            ..._history.map((e) => ListTile(
              dense: true,
              leading: const Icon(Icons.history),
              title: Text(e),
            )),

          // 收藏
          _sectionTitle('收藏（手动保存）'),
          if (_saved.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('暂无'),
            )
          else
            ..._saved.map((e) => ListTile(
              dense: true,
              leading: const Icon(Icons.bookmark_added_outlined),
              title: Text(e),
            )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
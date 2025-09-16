// lib/widgets/stat_command_tile.dart
import 'package:flutter/material.dart';

typedef OnSend = Future<void> Function(int value);

class StatCommandTile extends StatefulWidget {
  final String title;          // e.g. '先攻值' / '最大血量'
  final String hint;           // e.g. '0-50' / '0-999'
  final int min;               // e.g. 0
  final int max;               // e.g. 50/999
  final int typeByte;          // e.g. 0x02 / 0x07 / 0x08 / 0x09
  final bool enabled;          // 连接后可用
  final OnSend onSend;         // 调用上层发送

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
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clamp() {
    final digits = _ctl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _ctl.clear();
      return;
    }
    int v = int.parse(digits);
    if (v < widget.min) v = widget.min;
    if (v > widget.max) v = widget.max;
    final s = v.toString();
    if (_ctl.text != s) {
      _ctl.text = s;
      _ctl.selection = TextSelection.collapsed(offset: s.length);
    }
  }

  Future<void> _send() async {
    final raw = _ctl.text.trim();
    if (raw.isEmpty) return;
    final v = int.tryParse(raw);
    if (v == null) return;
    await widget.onSend(v);
    _ctl.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${widget.title} (${widget.hint})',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) => _clamp(),
                    onSubmitted: (_) => _send(),
                    enabled: widget.enabled,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.enabled ? _send : null,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(80, 48)),
                  child: const Text('发送'),
                )
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '协议: [0x01, 0x${widget.typeByte.toRadixString(16).padLeft(2, '0')}, 高八位, 低八位, 0x00]',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

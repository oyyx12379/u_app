// lib/extra_page.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// 通过依赖倒置，只要求一个“发字节”的函数和“连接状态”函数，便于与你的 BleClient 解耦
class ExtraPage extends StatefulWidget {
  const ExtraPage({
    super.key,
    required this.isConnected,
    required this.sendBytes,
  });

  /// 当前是否已连接（用于控制按钮可用态）
  final bool Function() isConnected;

  /// 实际发送函数：把 bytes 写进 ESP32 的 RX 特征（由上层注入）
  final Future<void> Function(Uint8List bytes) sendBytes;

  @override
  State<ExtraPage> createState() => _ExtraPageState();
}

class _ExtraPageState extends State<ExtraPage> {
  Uint8List? _imageBytes;
  String? _fileName;
  double _progress = 0.0;
  bool _sending = false;
  String _log = '';

  Future<void> _pickImage() async {
    setState(() {
      _log = '';
      _imageBytes = null;
      _fileName = null;
      _progress = 0.0;
    });

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择要发送到 ESP32 的图片',
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      if (file.bytes == null) {
        setState(() => _log = '选择失败：无法读取文件字节（bytes 为 null）');
        return;
      }
      setState(() {
        _imageBytes = file.bytes!;
        _fileName = file.name;
        _log = '已选择：${file.name}（${_imageBytes!.length} 字节）';
      });
    }
  }

  /// 极简协议（测试用）：
  ///   [0..1] : uint16 BE -> totalLength（不含这 2 字节）
  ///   [2.. ] : payload   -> 原始图片字节
  ///
  /// 注意：<= 65535 字节的图片。若更大，需要换成 4 字节长度并做分片编号/校验。
  Future<void> _sendToEsp32() async {
    if (_imageBytes == null) {
      setState(() => _log = '请先选择图片');
      return;
    }
    if (!widget.isConnected()) {
      setState(() => _log = '未连接到 ESP32');
      return;
    }

    final total = _imageBytes!.length;
    if (total > 0xFFFF) {
      setState(() => _log = '图片过大（${total} 字节），请先压缩到 ≤ 65535 字节再测试');
      return;
    }

    setState(() {
      _sending = true;
      _progress = 0.0;
      _log = '开始发送...';
    });

    try {
      // 1) 先发 2 字节长度（大端）
      final header = Uint8List(2);
      header[0] = (total >> 8) & 0xFF;
      header[1] = (total     ) & 0xFF;
      await widget.sendBytes(header);

      // 2) 20 字节分包发 payload
      const chunk = 20;
      var sent = 0;
      while (sent < total) {
        final end = (sent + chunk <= total) ? sent + chunk : total;
        final part = _imageBytes!.sublist(sent, end);
        await widget.sendBytes(part);
        sent = end;

        // 轻微节流，避免某些平台的 buffer 堆积
        await Future.delayed(const Duration(milliseconds: 2));

        setState(() => _progress = sent / total);
      }

      setState(() => _log = '发送完成（${total} 字节）');
    } catch (e) {
      setState(() => _log = '发送失败：$e');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.isConnected();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: connected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                connected ? '已连接' : '未连接',
                style: TextStyle(
                  color: connected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _sending ? null : _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('选择图片'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (_sending || _imageBytes == null || !connected) ? null : _sendToEsp32,
                icon: const Icon(Icons.send),
                label: const Text('发送到 ESP32'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_fileName != null)
            Text('文件：$_fileName, 大小：${_imageBytes!.length} 字节'),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _sending ? _progress : null),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(child: Text(_log)),
            ),
          ),
        ],
      ),
    );
  }
}

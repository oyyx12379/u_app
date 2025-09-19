// lib/storage/last_device_store.dart
import 'package:shared_preferences/shared_preferences.dart';

class LastDeviceInfo {
  final String id;
  final String name;
  const LastDeviceInfo(this.id, this.name);
}

class LastDeviceStore {
  static const _kId = 'last_device_id';
  static const _kName = 'last_device_name';

  Future<void> save(String id, String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kId, id);
    await sp.setString(_kName, name);
  }

  Future<LastDeviceInfo?> read() async {
    final sp = await SharedPreferences.getInstance();
    final id = sp.getString(_kId);
    final name = sp.getString(_kName);
    if (id == null || id.isEmpty) return null;
    return LastDeviceInfo(id, name ?? '');
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kId);
    await sp.remove(_kName);
  }
}

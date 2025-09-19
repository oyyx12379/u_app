// lib/data/srd_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'srd_models.dart';

class SrdRepository {
  SrdRepository._();
  static final SrdRepository I = SrdRepository._();

  SrdManifest? _manifest;
  final Map<String, ClassData> _classCache = {};
  final Map<String, RaceData> _raceCache = {};
  final Map<String, BackgroundData> _bgCache = {};

  Future<SrdManifest> manifest() async {
    if (_manifest != null) return _manifest!;
    final s = await rootBundle.loadString('assets/srd/manifest.json');
    _manifest = SrdManifest.fromJson(jsonDecode(s));
    return _manifest!;
  }

  Future<List<ClassData>> loadAllClasses() async {
    final m = await manifest();
    final list = <ClassData>[];
    for (final path in m.classes) {
      if (_classCache.containsKey(path)) {
        list.add(_classCache[path]!);
        continue;
      }
      final s = await rootBundle.loadString('assets/srd/$path');
      final cd = ClassData.fromJson(jsonDecode(s));
      _classCache[path] = cd;
      list.add(cd);
    }
    return list;
  }

  Future<List<RaceData>> loadAllRaces() async {
    final m = await manifest();
    final list = <RaceData>[];
    for (final path in m.races) {
      if (_raceCache.containsKey(path)) {
        list.add(_raceCache[path]!);
        continue;
      }
      final s = await rootBundle.loadString('assets/srd/$path');
      final rd = RaceData.fromJson(jsonDecode(s));
      _raceCache[path] = rd;
      list.add(rd);
    }
    return list;
  }

  Future<List<BackgroundData>> loadAllBackgrounds() async {
    final m = await manifest();
    final list = <BackgroundData>[];
    for (final path in m.backgrounds) {
      if (_bgCache.containsKey(path)) {
        list.add(_bgCache[path]!);
        continue;
      }
      final s = await rootBundle.loadString('assets/srd/$path');
      final bd = BackgroundData.fromJson(jsonDecode(s));
      _bgCache[path] = bd;
      list.add(bd);
    }
    return list;
  }
}

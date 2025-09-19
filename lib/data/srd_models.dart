// lib/data/srd_models.dart
import 'dart:convert';

/// ---------- utils ----------
Map<String, int> _parseAbilityMap(Map<String, dynamic>? j) {
  if (j == null) return const {};
  final out = <String, int>{};
  j.forEach((k, v) {
    final key = k.toUpperCase().trim();          // STR/DEX/CON/INT/WIS/CHA
    final val = (v as num).toInt();              // 保证是 int
    out[key] = val;
  });
  return out;
}

/// ---------- classes ----------
class ClassFeature {
  final int level;
  final String title;
  final String desc;
  final String? detail;
  const ClassFeature({required this.level, required this.title, required this.desc, this.detail});
  factory ClassFeature.fromJson(Map<String, dynamic> j) => ClassFeature(
    level: (j['level'] as num?)?.toInt() ?? 1,
    title: j['title'] ?? '',
    desc: j['desc'] ?? '',
    detail: j['detail'],
  );
}

class SubClassData {
  final String id;
  final String name;
  final List<ClassFeature> features;
  const SubClassData({required this.id, required this.name, required this.features});
  factory SubClassData.fromJson(Map<String, dynamic> j) => SubClassData(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    features: (j['features'] as List? ?? []).map((e) => ClassFeature.fromJson(e)).toList(),
  );
}

class ClassData {
  final String id, name, intro, hitDice, skillsRule, version;
  final List<String> savingThrows, armorProfs, weaponProfs, toolProfs;
  final List<ClassFeature> features;
  final List<SubClassData> subclasses;
  const ClassData({
    required this.id,
    required this.name,
    required this.intro,
    required this.hitDice,
    required this.savingThrows,
    required this.armorProfs,
    required this.weaponProfs,
    required this.toolProfs,
    required this.skillsRule,
    required this.features,
    required this.subclasses,
    required this.version,
  });

  factory ClassData.fromJson(Map<String, dynamic> j) => ClassData(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    intro: j['intro'] ?? '',
    hitDice: j['hitDice'] ?? '',
    savingThrows: List<String>.from(j['savingThrows'] ?? const []),
    armorProfs: List<String>.from(j['armorProfs'] ?? const []),
    weaponProfs: List<String>.from(j['weaponProfs'] ?? const []),
    toolProfs: List<String>.from(j['toolProfs'] ?? const []),
    skillsRule: j['skillsRule'] ?? '',
    features: (j['features'] as List? ?? []).map((e) => ClassFeature.fromJson(e)).toList(),
    subclasses: (j['subclasses'] as List? ?? []).map((e) => SubClassData.fromJson(e)).toList(),
    version: j['version'] ?? '2014',
  );

  List<ClassFeature> featuresUpTo(int level, {SubClassData? sub}) {
    final base = features.where((f) => f.level <= level).toList();
    if (sub != null) base.addAll(sub.features.where((f) => f.level <= level));
    final seen = <String>{};
    base.retainWhere((f) {
      final k = '${f.level}-${f.title}';
      if (seen.contains(k)) return false;
      seen.add(k);
      return true;
    });
    base.sort((a, b) => a.level.compareTo(b.level));
    return base;
  }

  List<ClassFeature> featuresAt(int level, {SubClassData? sub}) {
    final list = features.where((f) => f.level == level).toList();
    if (sub != null) list.addAll(sub.features.where((f) => f.level == level));
    return list;
  }
}

/// ---------- races ----------
class SubRaceData {
  final String id;
  final String name;
  final List<String> traits;
  /// 新增：亚种能力值加成（如丘陵矮人 WIS +1）
  final Map<String, int> abilityBonuses;

  const SubRaceData({
    required this.id,
    required this.name,
    required this.traits,
    required this.abilityBonuses,
  });

  factory SubRaceData.fromJson(Map<String, dynamic> j) => SubRaceData(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    traits: List<String>.from(j['traits'] ?? const []),
    abilityBonuses: _parseAbilityMap(j['abilityBonuses'] as Map<String, dynamic>?),
  );
}

class RaceData {
  final String id, name, intro, version;
  final List<String> traits;
  final List<String> proficiencies;
  final List<SubRaceData> subraces;
  /// 新增：基础种族能力值加成（如矮人 CON +2）
  final Map<String, int> abilityBonuses;

  const RaceData({
    required this.id,
    required this.name,
    required this.intro,
    required this.traits,
    required this.proficiencies,
    required this.subraces,
    required this.version,
    required this.abilityBonuses,
  });

  factory RaceData.fromJson(Map<String, dynamic> j) => RaceData(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    intro: j['intro'] ?? '',
    traits: List<String>.from(j['traits'] ?? const []),
    proficiencies: List<String>.from(j['proficiencies'] ?? const []),
    subraces: (j['subraces'] as List? ?? []).map((e) => SubRaceData.fromJson(e)).toList(),
    version: j['version'] ?? '2014',
    abilityBonuses: _parseAbilityMap(j['abilityBonuses'] as Map<String, dynamic>?),
  );
}

/// ---------- backgrounds ----------
class BackgroundData {
  final String id, name, intro, version;
  final List<String> proficiencies, equipment;
  final Map<String, List<String>> tables;

  const BackgroundData({
    required this.id,
    required this.name,
    required this.intro,
    required this.proficiencies,
    required this.equipment,
    required this.tables,
    required this.version,
  });

  factory BackgroundData.fromJson(Map<String, dynamic> j) => BackgroundData(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    intro: j['intro'] ?? '',
    proficiencies: List<String>.from(j['proficiencies'] ?? const []),
    equipment: List<String>.from(j['equipment'] ?? const []),
    tables: (j['tables'] as Map<String, dynamic>? ?? const {})
        .map((k, v) => MapEntry(k, List<String>.from(v as List? ?? const []))),
    version: j['version'] ?? '2014',
  );
}

/// ---------- manifest ----------
class SrdManifest {
  final int schemaVersion;
  final String contentVersion;
  final List<String> classes, races, backgrounds;
  const SrdManifest({
    required this.schemaVersion,
    required this.contentVersion,
    required this.classes,
    required this.races,
    required this.backgrounds,
  });
  factory SrdManifest.fromJson(Map<String, dynamic> j) => SrdManifest(
    schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
    contentVersion: j['contentVersion'] ?? 'unknown',
    classes: List<String>.from(j['classes'] ?? const []),
    races: List<String>.from(j['races'] ?? const []),
    backgrounds: List<String>.from(j['backgrounds'] ?? const []),
  );
}

/// ---------- helper ----------
T decodeJson<T>(String s, T Function(Map<String, dynamic>) fromJson) {
  final j = jsonDecode(s) as Map<String, dynamic>;
  return fromJson(j);
}

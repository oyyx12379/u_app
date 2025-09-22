// lib/pages/character_builder_wizard.dart
import 'package:flutter/material.dart';
import '../data/srd_repository.dart';
import '../data/srd_models.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

typedef SendStatFn = Future<void> Function(int typeByte, int value);
typedef SendBytesFn = Future<void> Function(List<int> data);


const kAbilities = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
const kStandardArray = [15, 14, 13, 12, 10, 8];
const kAllSkills = [
  'Acrobatics','Animal Handling','Arcana','Athletics','Deception','History',
  'Insight','Intimidation','Investigation','Medicine','Nature','Perception',
  'Performance','Persuasion','Religion','Sleight of Hand','Stealth','Survival',
];

int abilityMod(int score) => ((score - 10) / 2).floor();
int pointBuyCost(int s) {
  switch (s) {
    case 8: return 0; case 9: return 1; case 10: return 2; case 11: return 3;
    case 12: return 4; case 13: return 5; case 14: return 7; case 15: return 9;
    default: return 99;
  }
}
int profBonusForLevel(int lv) => 2 + ((lv - 1) ~/ 4);

List<String> parseSkillLine(String line) {
  final idx = line.indexOf('技能：');
  if (idx < 0) return const [];
  final part = line.substring(idx + 3);
  return part
      .split(RegExp(r'[、,，]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class CharacterBuilderWizardPage extends StatefulWidget {
  final SendStatFn? sendStat;
  final SendBytesFn? sendBytes;  // ✅ 新增

  const CharacterBuilderWizardPage({super.key, this.sendStat, this.sendBytes}); // ✅ 构造函数也加上

  @override
  State<CharacterBuilderWizardPage> createState() => _CharacterBuilderWizardPageState();
}

class _CharacterBuilderWizardPageState extends State<CharacterBuilderWizardPage> {
  int _step = 0;

  List<ClassData>? _classes; List<RaceData>? _races; List<BackgroundData>? _bgs;

  ClassData? _cls; SubClassData? _sub; int _level = 1;
  RaceData? _race; SubRaceData? _subrace;
  BackgroundData? _bg;

  String? pickPersonality; String? pickIdeal; String? pickBond; String? pickFlaw;

  String _abilityMethod = 'pointbuy';
  int _pointLeft = 27;
  final Map<String, int> _scores = { for (final a in kAbilities) a: 8 };
  final List<int> _arrayPool = List<int>.from(kStandardArray);

  final Map<String, List<String>> _classSkillOptions = {
    'barbarian': [
      'Animal Handling','Athletics','Intimidation','Nature','Perception','Survival',
    ],
  };
  final Map<String, int> _classSkillPickCount = { 'barbarian': 2 };
  final Set<String> _classPickedSkills = {};
  final Set<String> _bgSkills = {};
  final Set<String> _raceSkills = {};

  String? _error;

  // 基础资料
  final _ctlCharName = TextEditingController();
  final _ctlPlayerName = TextEditingController();
  final _ctlHeight = TextEditingController();
  final _ctlWeight = TextEditingController();
  final _ctlAge = TextEditingController();
  String _gender = '未知';
  String _alignment = '未定';
  final _ctlFaith = TextEditingController();
  String _bodySize = '中型';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctlCharName.dispose();
    _ctlPlayerName.dispose();
    _ctlHeight.dispose();
    _ctlWeight.dispose();
    _ctlAge.dispose();
    _ctlFaith.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final classes = await SrdRepository.I.loadAllClasses();
      final races = await SrdRepository.I.loadAllRaces();
      final bgs = await SrdRepository.I.loadAllBackgrounds();
      setState(() {
        _classes = classes;
        _cls = classes.isNotEmpty ? classes.first : null;
        _sub = _cls != null && _cls!.subclasses.isNotEmpty ? _cls!.subclasses.first : null;

        _races = races;
        _race = races.isNotEmpty ? races.first : null;
        _subrace = _race != null && _race!.subraces.isNotEmpty ? _race!.subraces.first : null;

        _bgs = bgs;
        _bg = bgs.isNotEmpty ? bgs.first : null;

        _recalcAutoSkills();
      });
    } catch (e, st) {
      debugPrint('load error: $e\n$st');
      setState(() => _error = e.toString());
    }
  }

  void _recalcPointLeft() {
    int sum = 0; for (final s in _scores.values) sum += pointBuyCost(s);
    setState(() => _pointLeft = 27 - sum);
  }

  void _recalcAutoSkills() {
    _bgSkills.clear(); _raceSkills.clear();
    if (_bg != null) {
      for (final p in _bg!.proficiencies) { _bgSkills.addAll(parseSkillLine(p)); }
      for (final e in _bg!.tables.entries) {
        for (final line in e.value) { _bgSkills.addAll(parseSkillLine(line)); }
      }
    }
    if (_race != null) {
      for (final t in _race!.traits) { _raceSkills.addAll(parseSkillLine(t)); }
      if (_subrace != null) {
        for (final t in _subrace!.traits) { _raceSkills.addAll(parseSkillLine(t)); }
      }
    }
    setState(() {});
  }

  bool get _isLoaded => _classes != null && _races != null && _bgs != null && _error == null;

  Map<String, int> get _racialBonuses {
    final m = <String, int>{};
    if (_race != null) {
      _race!.abilityBonuses.forEach((k, v) { m[k] = (m[k] ?? 0) + v; });
    }
    if (_subrace != null) {
      _subrace!.abilityBonuses.forEach((k, v) { m[k] = (m[k] ?? 0) + v; });
    }
    return m;
  }

  Map<String, int> get _finalScores {
    final out = <String, int>{}; final rb = _racialBonuses;
    for (final a in kAbilities) { out[a] = _scores[a]! + (rb[a] ?? 0); }
    return out;
  }

  Set<String> get _finalProficientSkills {
    final set = <String>{};
    set.addAll(_classPickedSkills);
    set.addAll(_bgSkills);
    set.addAll(_raceSkills);
    return set;
  }

  int _hitDieSides() {
    final s = _cls?.hitDice ?? 'd8';
    final m = RegExp(r'd(\d+)').firstMatch(s);
    return m != null ? int.parse(m.group(1)!) : 8;
  }
  int _avgPerLevel() {
    final d = _hitDieSides();
    return (d ~/ 2) + 1;
  }
  bool _isHillDwarf() {
    final id = (_subrace?.id ?? '').toLowerCase();
    return id.contains('hill');
  }
  int get _conMod => abilityMod(_finalScores['CON'] ?? 10);

  int get _maxHP {
    final d = _hitDieSides();
    final lvl = _level;
    final first = d + _conMod + (_isHillDwarf() ? 1 : 0);
    if (lvl == 1) return first.clamp(1, 999);
    final restLevels = lvl - 1;
    final per = _avgPerLevel() + _conMod + (_isHillDwarf() ? 1 : 0);
    final hp = first + per * restLevels;
    return hp.clamp(1, 999);
  }

  String? _castingAbilityForClass(String id) {
    switch (id) {
      case 'bard': case 'paladin': case 'sorcerer': case 'warlock': return 'CHA';
      case 'cleric': case 'druid': case 'ranger': return 'WIS';
      case 'wizard': case 'artificer': return 'INT';
      default: return null;
    }
  }

  int? get _spellSaveDC {
    final id = _cls?.id;
    if (id == null) return null;
    final abil = _castingAbilityForClass(id);
    if (abil == null) return null;
    final mod = abilityMod(_finalScores[abil] ?? 10);
    return 8 + profBonusForLevel(_level) + mod;
  }

  int get _passivePerception {
    final wisMod = abilityMod(_finalScores['WIS'] ?? 10);
    final prof = _finalProficientSkills.contains('Perception') ? profBonusForLevel(_level) : 0;
    return 10 + wisMod + prof;
  }

  int get _speedFeet {
    int? _parseSpeedFromTraits(List<String> traits) {
      final re = RegExp(r'速度[:：]\s*(\d+)\s*尺');
      for (final t in traits) {
        final m = re.firstMatch(t);
        if (m != null) return int.tryParse(m.group(1)!);
      }
      return null;
    }
    if (_subrace != null) {
      final v = _parseSpeedFromTraits(_subrace!.traits);
      if (v != null) return v;
    }
    if (_race != null) {
      final v = _parseSpeedFromTraits(_race!.traits);
      if (v != null) return v;
    }
    return 30;
  }

  // ======== UI ========

  Widget _buildStep0Basic({required bool isWide}) {
    final left = _buildBasicSelectorsCard();
    final right = _buildFeaturesColumn(isWide: isWide);

    if (isWide) {
      // 大屏：左右两栏
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: left),
          const SizedBox(width: 12),
          Expanded(flex: 7, child: right),
        ],
      );
    } else {
      // 小屏：上下串联 + 可折叠
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }
  }

  Widget _buildBasicSelectorsCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Text('基础信息', style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(height: 12),
          _buildIdentityGrid(),
          const SizedBox(height: 12),

          // 职业与等级
          _buildClassAndLevelCard(),

          // 职业可选技能
          _buildClassSkillPickerCard(),

          const Divider(height: 24),

          // 种族/亚种
          _buildRaceCard(),

          const Divider(height: 24),

          // 背景
          _buildBackgroundCard(),
        ]),
      ),
    );
  }

  Widget _buildFeaturesColumn({required bool isWide}) {
    final nowFeatures = _cls?.featuresAt(_level, sub: _sub) ?? const [];
    final allFeatures = _cls?.featuresUpTo(_level, sub: _sub) ?? const [];

    // 小屏默认折叠，节省空间
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ExpansionTile(
              initiallyExpanded: isWide, // 大屏默认展开
              title: const Text('本等级获得的职业/子职业特性'),
              children: [
                if (nowFeatures.isEmpty)
                  const ListTile(title: Text('本等级无新特性'))
                else
                  ...nowFeatures.map((f) => ListTile(
                    dense: true,
                    title: Text(f.title),
                    subtitle: f.desc.isNotEmpty ? Text(f.desc) : null,
                  )),
              ],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ExpansionTile(
              initiallyExpanded: false,
              title: const Text('至今获得（≤当前等级）'),
              children: [
                if (allFeatures.isEmpty)
                  const ListTile(title: Text('暂无特性'))
                else
                  ...allFeatures.map((f) => ListTile(
                    dense: true,
                    leading: CircleAvatar(radius: 12, child: Text('${f.level}', style: const TextStyle(fontSize: 12))),
                    title: Text(f.title),
                    subtitle: f.desc.isNotEmpty ? Text(f.desc) : null,
                  )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityGrid() {
    // 手机上改为两列/一列的自适应布局
    return LayoutBuilder(builder: (ctx, con) {
      final w = con.maxWidth;
      int cols = 2;
      if (w < 520) cols = 1;

      Widget cell(Widget child) => Padding(
        padding: const EdgeInsets.all(6),
        child: child,
      );

      final fields = <Widget>[
        TextField(controller: _ctlCharName, decoration: const InputDecoration(labelText: '角色名字', border: OutlineInputBorder())),
        TextField(controller: _ctlPlayerName, decoration: const InputDecoration(labelText: '玩家名字', border: OutlineInputBorder())),
        TextField(controller: _ctlHeight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '身高（cm）', border: OutlineInputBorder())),
        TextField(controller: _ctlWeight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '体重（kg）', border: OutlineInputBorder())),
        TextField(controller: _ctlAge, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '年龄', border: OutlineInputBorder())),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(labelText: '性别', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: '未知', child: Text('未知')),
            DropdownMenuItem(value: '男', child: Text('男')),
            DropdownMenuItem(value: '女', child: Text('女')),
            DropdownMenuItem(value: '其它', child: Text('其它')),
          ],
          onChanged: (v) => setState(() => _gender = v ?? '未知'),
        ),
        TextField(controller: _ctlFaith, decoration: const InputDecoration(labelText: '信仰', border: OutlineInputBorder())),
        DropdownButtonFormField<String>(
          value: _alignment,
          decoration: const InputDecoration(labelText: '阵营', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: '未定', child: Text('未定')),
            DropdownMenuItem(value: '守序善良', child: Text('守序善良')),
            DropdownMenuItem(value: '中立善良', child: Text('中立善良')),
            DropdownMenuItem(value: '混乱善良', child: Text('混乱善良')),
            DropdownMenuItem(value: '守序中立', child: Text('守序中立')),
            DropdownMenuItem(value: '绝对中立', child: Text('绝对中立')),
            DropdownMenuItem(value: '混乱中立', child: Text('混乱中立')),
            DropdownMenuItem(value: '守序邪恶', child: Text('守序邪恶')),
            DropdownMenuItem(value: '中立邪恶', child: Text('中立邪恶')),
            DropdownMenuItem(value: '混乱邪恶', child: Text('混乱邪恶')),
          ],
          onChanged: (v) => setState(() => _alignment = v ?? '未定'),
        ),
        InputDecorator(
          decoration: const InputDecoration(labelText: '体型', border: OutlineInputBorder()),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _bodySize,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: '极小', child: Text('极小')),
                DropdownMenuItem(value: '小型', child: Text('小型')),
                DropdownMenuItem(value: '中型', child: Text('中型')),
                DropdownMenuItem(value: '大型', child: Text('大型')),
                DropdownMenuItem(value: '超大', child: Text('超大')),
                DropdownMenuItem(value: '巨型', child: Text('巨型')),
              ],
              onChanged: (v) => setState(() => _bodySize = v ?? '中型'),
            ),
          ),
        ),
      ];

      return Wrap(
        children: List.generate(fields.length, (i) => SizedBox(
          width: w / cols - 12,
          child: cell(fields[i]),
        )),
      );
    });
  }

  Widget _buildClassAndLevelCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('职业', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<ClassData>(
          value: _cls,
          items: _classes!.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
          onChanged: (c) => setState(() {
            _cls = c;
            _sub = _cls!.subclasses.isNotEmpty ? _cls!.subclasses.first : null;
            _classPickedSkills.clear();
          }),
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '职业'),
        ),
        const SizedBox(height: 8),
        if (_cls != null && _cls!.subclasses.isNotEmpty)
          DropdownButtonFormField<SubClassData>(
            value: _sub,
            items: _cls!.subclasses.map((s) => DropdownMenuItem(value: s, child: Text('子职业：${s.name}'))).toList(),
            onChanged: (s) => setState(() => _sub = s),
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '子职业'),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('等级：'),
            IconButton(onPressed: _level > 1 ? () => setState(() => _level--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('$_level'),
            IconButton(onPressed: _level < 20 ? () => setState(() => _level++) : null, icon: const Icon(Icons.add_circle_outline)),
            const Spacer(),
            Chip(label: Text('熟练加值 +${profBonusForLevel(_level)}')),
          ],
        ),
      ],
    );
  }

  Widget _buildClassSkillPickerCard() {
    final classId = _cls?.id ?? '';
    final options = _classSkillOptions[classId] ?? const <String>[];
    final pickCount = _classSkillPickCount[classId] ?? 0;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('职业可选技能', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (options.isNotEmpty)
              Chip(label: Text('从中选择 $pickCount 个（已选 ${_classPickedSkills.length}）')),
          ]),
          const SizedBox(height: 8),
          if (options.isEmpty)
            const Text('此职业未配置可选技能（可在 _classSkillOptions 中添加或改为从 JSON 读取）')
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: options.map((sk) {
                final picked = _classPickedSkills.contains(sk);
                final disabled = !picked && _classPickedSkills.length >= pickCount;
                return FilterChip(
                  label: Text(sk),
                  selected: picked,
                  onSelected: disabled && !picked ? null : (v) {
                    setState(() {
                      if (v) { _classPickedSkills.add(sk); } else { _classPickedSkills.remove(sk); }
                    });
                  },
                );
              }).toList(),
            ),
        ]),
      ),
    );
  }

  Widget _buildRaceCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('种族', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<RaceData>(
          value: _race,
          items: _races!.map((r) => DropdownMenuItem(value: r, child: Text(r.name))).toList(),
          onChanged: (r) => setState(() {
            _race = r;
            _subrace = _race!.subraces.isNotEmpty ? _race!.subraces.first : null;
            _recalcAutoSkills();
          }),
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '种族'),
        ),
        const SizedBox(height: 8),
        if (_race != null && _race!.subraces.isNotEmpty)
          DropdownButtonFormField<SubRaceData>(
            value: _subrace,
            items: _race!.subraces.map((s) => DropdownMenuItem(value: s, child: Text('支系：${s.name}'))).toList(),
            onChanged: (s) => setState(() { _subrace = s; _recalcAutoSkills(); }),
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '亚种/血统'),
          ),
        const SizedBox(height: 8),
        if (_racialBonuses.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _racialBonuses.entries.map((e) =>
                Chip(label: Text('种族加成 ${e.key}+${e.value}'))).toList(),
          ),
        const SizedBox(height: 8),
        if (_raceSkills.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('种族/亚种带来的熟练', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_raceSkills.join('、')),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildBackgroundCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('背景', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<BackgroundData>(
          value: _bg,
          items: _bgs!.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
          onChanged: (b) => setState(() { _bg = b; _recalcAutoSkills(); }),
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '背景'),
        ),
        const SizedBox(height: 8),
        Text(_bg?.intro ?? ''),
        const SizedBox(height: 8),
        if (_bgSkills.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('背景带来的熟练', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_bgSkills.join('、')),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildStep1BackgroundPicks() {
    if (_bg == null) return const SizedBox.shrink();
    final tables = _bg!.tables;

    Widget pick(String title, String? current, ValueChanged<String?> onChanged) {
      final list = tables[title] ?? const <String>[];
      if (list.isEmpty) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...list.map((line) => RadioListTile<String>(
              dense: true, title: Text(line), value: line, groupValue: current, onChanged: onChanged,
            )),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        pick('人格特质 (d8)', pickPersonality, (v) => setState(() => pickPersonality = v)),
        pick('理想 (d6)', pickIdeal, (v) => setState(() => pickIdeal = v)),
        pick('羁绊 (d6)', pickBond, (v) => setState(() => pickBond = v)),
        pick('缺点 (d6)', pickFlaw, (v) => setState(() => pickFlaw = v)),
        const SizedBox(height: 8),
        if (_bgSkills.isNotEmpty) Text('背景熟练：${_bgSkills.join('、')}'),
      ],
    );
  }

  Widget _buildStep2Abilities() {
    final rb = _racialBonuses;
    final fs = _finalScores;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'pointbuy', label: Text('标准购点')),
            ButtonSegment(value: 'array', label: Text('标准数组')),
          ],
          selected: {_abilityMethod},
          onSelectionChanged: (s) => setState(() {
            _abilityMethod = s.first;
            for (final a in kAbilities) { _scores[a] = 8; }
            _arrayPool..clear()..addAll(kStandardArray);
            _recalcPointLeft();
          }),
        ),
        const SizedBox(height: 12),

        if (_abilityMethod == 'pointbuy') ...[
          Text('剩余点数：$_pointLeft / 27', style: TextStyle(
              color: _pointLeft < 0 ? Colors.red : null, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...kAbilities.map((a) {
            final s = _scores[a]!;
            final bonus = rb[a] ?? 0;
            final finalVal = fs[a]!;
            return Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                SizedBox(width: 44, child: Text(a, style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(onPressed: s > 8 ? () { setState(() { _scores[a] = s - 1; _recalcPointLeft(); }); } : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$s (mod ${abilityMod(s) >= 0 ? '+${abilityMod(s)}' : abilityMod(s)})'),
                IconButton(onPressed: s < 15 ? () { setState(() { _scores[a] = s + 1; _recalcPointLeft(); }); } : null,
                    icon: const Icon(Icons.add_circle_outline)),
                const Spacer(),
                if (bonus != 0) Chip(label: Text('种族 +$bonus')),
                const SizedBox(width: 8),
                Text('最终 $finalVal (mod ${abilityMod(finalVal) >= 0 ? '+${abilityMod(finalVal)}' : abilityMod(finalVal)})'),
              ]),
            ));
          }),
          const SizedBox(height: 8),
          const Text('规则：8–15；成本 8/0, 9/1, 10/2, 11/3, 12/4, 13/5, 14/7, 15/9'),
        ] else ...[
          const Text('请把下列数值分配到 6 项属性：'),
          Wrap(spacing: 8, children: _arrayPool.map((v) => Chip(label: Text('$v'))).toList()),
          const SizedBox(height: 8),
          ...kAbilities.map((a) {
            final v = _scores[a]!;
            final bonus = rb[a] ?? 0;
            final finalVal = fs[a]!;
            return Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                SizedBox(width: 44, child: Text(a, style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: v,
                  items: ([v, ..._arrayPool].toSet().toList()..sort())
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                  onChanged: (n) {
                    if (n == null) return;
                    setState(() {
                      _arrayPool.remove(n);
                      _arrayPool.add(v);
                      _scores[a] = n;
                    });
                  },
                ),
                const Spacer(),
                if (bonus != 0) Chip(label: Text('种族 +$bonus')),
                const SizedBox(width: 8),
                Text('最终 $finalVal (mod ${abilityMod(finalVal) >= 0 ? '+${abilityMod(finalVal)}' : abilityMod(finalVal)})'),
              ]),
            ));
          }),
          Text('未分配：${_arrayPool.length}'),
        ],
      ],
    );
  }

  // 把 PNG/JPG 文件转成合适大小的 JPEG（默认不缩放；你可以改成 320x240 等）
  Future<Uint8List> _normalizeToJpeg(Uint8List inputBytes,
      {int? maxWidth, int? maxHeight, int jpegQuality = 85}) async {
    final src = img.decodeImage(inputBytes);
    if (src == null) {
      throw Exception('无法解码图片（仅支持 PNG/JPG）');
    }
    img.Image out = src;

    // 如果指定了缩放
    if (maxWidth != null || maxHeight != null) {
      out = img.copyResize(
        src,
        width: maxWidth,
        height: maxHeight,
        // 注意：这里没有 fit 参数，image 库会按照 width/height 强行缩放。
        // 如果你只传一个（width 或 height），则会按比例缩放。
      );
    }

    final jpg = img.encodeJpg(out, quality: jpegQuality);
    return Uint8List.fromList(jpg);
  }


  /// 根据你的分包协议（0x01 开始 / 0x02 数据 / 0x03 结束）打包成多帧
  /// 说明：HEADER = 1(head) +2(total) +2(index) +2(len) = 7，结尾 1 字节 checksum
  /// 这里选 dataChunk = 160，既能适配常见 MTU=185（净载约177），也较稳定；
  /// 如你确认目标设备 MTU 恒为 23，可把 dataChunk 改为 <=12（但传输变慢）。
  List<List<int>> _buildBleImagePackets(Uint8List data, {int dataChunk = 160}) {
    const headerSize = 1 + 2 + 2 + 2; // 7
    final totalBlocks = (data.length + dataChunk - 1) ~/ dataChunk;

    List<int> makeFrame({
      required int head,
      required int total,
      required int index,
      required int length,
      List<int>? payload,
    }) {
      final buf = <int>[];
      // 头部
      buf.add(head & 0xFF);
      buf.add(total & 0xFF);           // total low
      buf.add((total >> 8) & 0xFF);    // total high
      buf.add(index & 0xFF);           // index low
      buf.add((index >> 8) & 0xFF);    // index high
      buf.add(length & 0xFF);          // len low
      buf.add((length >> 8) & 0xFF);   // len high
      // 有效载荷
      if (payload != null && payload.isNotEmpty) {
        buf.addAll(payload);
      }
      // 校验和：对前面所有字节求和取反
      int sum = 0;
      for (final b in buf) sum = (sum + b) & 0xFF;
      final checksum = (~sum) & 0xFF;
      buf.add(checksum);
      return buf;
    }

    final frames = <List<int>>[];

    // 起始包
    frames.add(makeFrame(head: 0x01, total: totalBlocks, index: 0, length: 0));

    // 数据包
    for (int i = 0; i < totalBlocks; i++) {
      final start = i * dataChunk;
      final end = (start + dataChunk <= data.length) ? (start + dataChunk) : data.length;
      final slice = data.sublist(start, end);
      frames.add(makeFrame(
        head: 0x02,
        total: totalBlocks,
        index: i + 1,
        length: slice.length,
        payload: slice,
      ));
    }

    // 结束包
    frames.add(makeFrame(head: 0x03, total: totalBlocks, index: totalBlocks + 1, length: 0));

    return frames;
  }


  Widget _buildStep4Summary() {
    final fs = _finalScores;
    final mods = { for (final a in kAbilities) a: abilityMod(fs[a]!) };

    final dc = _spellSaveDC;
    final pp = _passivePerception;
    final ft = _speedFeet;
    final maxHp = _maxHP;
    final curHp = maxHp;
    final tempHp = 0;

    Future<void> _sendAll() async {
      // 计算角色的数值
      final dc = _spellSaveDC;
      final pp = _passivePerception;
      final ft = _speedFeet;
      final maxHp = _maxHP;
      final curHp = maxHp;
      final tempHp = 0;

      // 如果提供了 sendBytes（一次性发包），优先使用新的协议：
      // 格式：[0x02, type, high, low, 0x00, type, high, low, 0x00, ...]
      if (widget.sendBytes != null) {
        final pkt = <int>[0x02];

        void addEntry(int type, int value) {
          final u = value.toUnsigned(16);
          final hi = (u >> 8) & 0xFF;
          final lo = u & 0xFF;
          pkt.addAll([type, hi, lo, 0x00]);
        }

        addEntry(0x08, maxHp); // 最大生命
        addEntry(0x07, curHp); // 当前生命
        addEntry(0x09, tempHp); // 临时生命
        if (dc != null) addEntry(0x14, dc); // DC（有才发）
        addEntry(0x15, pp); // PP
        addEntry(0x16, ft); // FT（移动速度）

        try {
          await widget.sendBytes!(pkt);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已一次性发送全部角色数据')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败：$e')),
          );
        }
        return;
      }
    }

    // 手机上：用更紧凑的展示 + 按钮固定在可见区域
    return LayoutBuilder(builder: (ctx, con) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('角色卡预览', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('角色：${_ctlCharName.text.isEmpty ? '—' : _ctlCharName.text}    玩家：${_ctlPlayerName.text.isEmpty ? '—' : _ctlPlayerName.text}'),
                Text('身高：${_ctlHeight.text.isEmpty ? '—' : _ctlHeight.text}cm   体重：${_ctlWeight.text.isEmpty ? '—' : _ctlWeight.text}kg   年龄：${_ctlAge.text.isEmpty ? '—' : _ctlAge.text}'),
                Text('性别：$_gender   阵营：$_alignment   体型：$_bodySize   信仰：${_ctlFaith.text.isEmpty ? '—' : _ctlFaith.text}'),
                const Divider(),
                Text('职业：${_cls?.name ?? '-'}（子职业：${_sub?.name ?? '—'}）  等级：$_level   熟练加值：+${profBonusForLevel(_level)}'),
                Text('种族：${_race?.name ?? '-'}（${_subrace?.name ?? '—'}）    背景：${_bg?.name ?? '-'}'),
                const Divider(),
                const Text('属性'),
                Wrap(spacing: 8, runSpacing: 4, children: kAbilities.map((a) {
                  final s = fs[a]!, m = mods[a]!, ms = m >= 0 ? '+$m' : '$m';
                  return Chip(label: Text('$a $s ($ms)'));
                }).toList()),
                const Divider(),
                const Text('技能熟练'),
                Text(_finalProficientSkills.isEmpty ? '无' : _finalProficientSkills.join('、')),
                const Divider(),
                const Text('战斗关键数值'),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  Chip(label: Text('最大生命 $maxHp')),
                  Chip(label: Text('当前生命 $curHp')),
                  Chip(label: Text('临时生命 $tempHp')),
                  if (dc != null) Chip(label: Text('DC $dc')),
                  Chip(label: Text('PP $pp')),
                  Chip(label: Text('FT $ft 尺')),
                ]),const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: widget.sendBytes == null ? null : () async {
                    try {
                      // 1) 选文件（PNG/JPG）
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['png', 'jpg', 'jpeg'],
                        withData: true,
                      );
                      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                      final raw = res.files.first.bytes!;
                      // 2) 统一转为 JPEG（支持选择 PNG）；可指定缩放到你屏幕分辨率，如 320x240
                      final jpg = await _normalizeToJpeg(raw,
                          // 比如你的 TFT 是 320x240，就打开下一行
                          // maxWidth: 320, maxHeight: 240,
                          jpegQuality: 85);

                      // 3) 分包
                      final packets = _buildBleImagePackets(jpg, dataChunk: 160);

                      // 4) 逐包发送（每包稍微等一下更稳）
                      for (final p in packets) {
                        await widget.sendBytes!(p); // 复用你注入的 writeRaw
                        await Future.delayed(const Duration(milliseconds: 5));
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('图片已发送（自动转为JPEG）')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('发送失败：$e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('发送角色图片（支持PNG/JPG）'),
                ),

                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.sendStat == null ? null : _sendAll,
                  icon: const Icon(Icons.send),
                  label: const Text('一键发送'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('角色已生成（Demo）')));
            },
            icon: const Icon(Icons.check),
            label: const Text('完成并保存'),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: const Text('角色创建向导')), body: Center(child: Text('加载失败：$_error')));
    }
    if (!_isLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 900; // 手机/小平板使用窄屏布局

    final steps = <Widget>[
      // 每个步骤外再包一层 ListView/Column，避免小屏溢出
      SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildStep0Basic(isWide: isWide),
      ),
      _buildStep1BackgroundPicks(),
      _buildStep2Abilities(),
      _buildStep4Summary(),
    ];
    final titles = ['基础', '背景选项', '属性', '汇总'];

    return Scaffold(
      appBar: AppBar(title: const Text('角色创建向导（DND5e）')),
      body: Column(
        children: [
          // 顶部步骤：自动换行
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(titles.length, (i) {
                final active = i == _step;
                return ActionChip(
                  label: Text(titles[i]),
                  avatar: CircleAvatar(radius: 10, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  onPressed: () => setState(() => _step = i),
                  backgroundColor: active ? Theme.of(context).colorScheme.primaryContainer : null,
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: steps[_step]),
          // 底部“上一步/下一步”条：小屏始终可见
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(children: [
                OutlinedButton.icon(
                  onPressed: _step > 0 ? () => setState(() => _step--) : null,
                  icon: const Icon(Icons.chevron_left), label: const Text('上一步'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _canNext() ? () => setState(() => _step++) : null,
                  icon: const Icon(Icons.chevron_right),
                  label: Text(_step == titles.length - 1 ? '完成' : '下一步'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool _canNext() {
    if (_step == 0) {
      final classId = _cls?.id ?? '';
      final need = _classSkillPickCount[classId] ?? 0;
      if ((_classSkillOptions[classId]?.isNotEmpty ?? false) &&
          _classPickedSkills.length != need) {
        return false;
      }
    }
    if (_step == 2) {
      if (_abilityMethod == 'pointbuy' && _pointLeft < 0) return false;
      if (_abilityMethod == 'array' && _arrayPool.isNotEmpty) return false;
    }
    if (_step >= 3) return false;
    return true;
  }
}

// lib/pages/dnd_class_demo_page.dart
import 'package:flutter/material.dart';

/// ===== 数据模型 =====
class ClassData {
  final String id;                   // 英文 key，例如 barbarian
  final String name;                 // 展示名，例如 野蛮人 Barbarian
  final String shortIntro;           // 简介（SRD 摘要/意译）
  final String hitDice;              // 生命骰说明
  final List<String> savingThrows;   // 豁免熟练
  final List<String> armorProfs;     // 护甲熟练
  final List<String> weaponProfs;    // 武器熟练
  final List<String> toolProfs;      // 工具熟练
  final String skillsRule;           // 技能选择规则（文本）
  final Map<int, List<String>> featuresByLevel; // 等级 -> 特性列表

  const ClassData({
    required this.id,
    required this.name,
    required this.shortIntro,
    required this.hitDice,
    required this.savingThrows,
    required this.armorProfs,
    required this.weaponProfs,
    required this.toolProfs,
    required this.skillsRule,
    required this.featuresByLevel,
  });

  /// 返回 <= level 的所有特性（去重）
  List<String> featuresUpTo(int level) {
    final out = <String>[];
    for (final entry in featuresByLevel.entries) {
      if (entry.key <= level) {
        for (final f in entry.value) {
          if (!out.contains(f)) out.add(f);
        }
      }
    }
    return out;
  }
}

/// ===== Demo 数据（SRD 摘要/意译，非逐字引用） =====
const _classes = <ClassData>[
  ClassData(
    id: 'barbarian',
    name: '野蛮人 Barbarian',
    shortIntro:
    '前排斗士，以「狂暴」强化近战与生存能力；生命值高，承伤能力强，机动朴实有力。',
    hitDice: '每等级 1d12',
    savingThrows: ['力量 STR', '体质 CON'],
    armorProfs: ['轻甲', '中甲', '盾牌'],
    weaponProfs: ['简易武器', '军用武器'],
    toolProfs: [],
    skillsRule: '从：动物驯养、运动、威吓、自然、察觉、生存 中选 2 个。',
    featuresByLevel: {
      1: ['狂暴 Rage（获得额外伤害与抗性）', '无甲防御 Unarmored Defense（以体质提升 AC）'],
      2: ['鲁莽攻击 Reckless Attack（用优势换取被打劣势）', '危险直觉 Danger Sense（对可见陷阱/效果敏捷豁免优势）'],
      3: ['原始路径 Primal Path（选择子职业）'],
      4: ['属性提升/专长 Ability Score Improvement（ASI/Feat）'],
      5: ['额外攻击 Extra Attack（攻击动作打两次）', '快速移动 Fast Movement（+10 英尺速度）'],
    },
  ),
  ClassData(
    id: 'bard',
    name: '吟游诗人 Bard',
    shortIntro:
    '全能型施法者与支援者，依靠灵感激励与多才多艺在战斗与社交中都能发挥作用。',
    hitDice: '每等级 1d8',
    savingThrows: ['敏捷 DEX', '魅力 CHA'],
    armorProfs: ['轻甲'],
    weaponProfs: ['简易武器', '手弩', '长剑', '细剑', '短剑'],
    toolProfs: ['任意三种乐器'],
    skillsRule: '任选四个技能（吟游诗人可选范围广）。',
    featuresByLevel: {
      1: ['诗人灵感 Bardic Inspiration（作为奖励动作鼓舞同伴）', '施法 Spellcasting（魅力为施法属性）'],
      2: ['万事通 Jack of All Trades（非熟练检定加部分加值）', '安魂曲 Song of Rest（短休额外回复）'],
      3: ['诗人学派 Bard College（选择子职业）', '专精 Expertise（两个技能双倍熟练）'],
      4: ['属性提升/专长 ASI/Feat'],
      5: ['激励骰升级（d8）', '额外魔法祈唤/刻印（视 SRD 版本，可略）'],
    },
  ),
  ClassData(
    id: 'cleric',
    name: '牧师 Cleric',
    shortIntro:
    '神术施法者，兼具治疗与驱散不死之能；领域（Domain）决定定位与法术侧重。',
    hitDice: '每等级 1d8',
    savingThrows: ['感知 WIS', '魅力 CHA'],
    armorProfs: ['轻甲', '中甲', '盾牌'],
    weaponProfs: ['简易武器'],
    toolProfs: [],
    skillsRule: '从：历史、洞察、医药、说服、宗教 中选 2 个。',
    featuresByLevel: {
      1: ['施法 Spellcasting（感知为施法属性）', '神圣领域 Divine Domain（选择子职业并获得其特性）'],
      2: ['引导神力 Channel Divinity（根据领域产生效果）'],
      3: ['2 环法术（更高阶法术位）'],
      4: ['属性提升/专长 ASI/Feat'],
      5: ['摧毁不死 Destroy Undead（更强的驱散效果）'],
    },
  ),
];

/// ===== 页面：职业选择 + 等级特性展示（Demo） =====
class DndClassDemoPage extends StatefulWidget {
  const DndClassDemoPage({super.key});

  @override
  State<DndClassDemoPage> createState() => _DndClassDemoPageState();
}

class _DndClassDemoPageState extends State<DndClassDemoPage> {
  ClassData _selected = _classes.first;
  int _level = 1;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DND 5e · 职业 Demo（SRD 摘要）'),
      ),
      body: LayoutBuilder(
        builder: (_, box) {
          final left = SizedBox(
            width: wide ? 360 : box.maxWidth,
            child: _buildLeftPane(),
          );
          final right = Expanded(child: _buildRightPane());

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: wide
                ? [left, const VerticalDivider(width: 1), right]
                : [
              // 窄屏：上下排列
              Expanded(child: SingleChildScrollView(child: left)),
              const Divider(height: 1),
              Expanded(child: _buildRightPane()),
            ],
          );
        },
      ),
    );
  }

  // ===== 左侧：选择职业 + 等级 + 简介 =====
  Widget _buildLeftPane() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择职业', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<ClassData>(
                value: _selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '职业（Class）',
                  border: OutlineInputBorder(),
                ),
                items: _classes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                    .toList(),
                onChanged: (c) => setState(() => _selected = c ?? _selected),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('等级：', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _level > 1 ? () => setState(() => _level--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: '降低等级',
                  ),
                  Text('$_level', style: const TextStyle(fontSize: 16)),
                  IconButton(
                    onPressed: _level < 20 ? () => setState(() => _level++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: '提升等级',
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 180,
                    child: Slider(
                      value: _level.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: 'Lv $_level',
                      onChanged: (v) => setState(() => _level = v.round()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selected.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_selected.shortIntro, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 右侧：规则详情（随等级动态） =====
  Widget _buildRightPane() {
    final feats = _selected.featuresUpTo(_level);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      child: ListView(
        children: [
          _sectionTitle('特质 / 基础'),
          _infoCard(children: [
            _kv('生命骰', _selected.hitDice),
            _kv('豁免熟练', _selected.savingThrows.join('、')),
            _kv('护甲熟练', _selected.armorProfs.isEmpty ? '—' : _selected.armorProfs.join('、')),
            _kv('武器熟练', _selected.weaponProfs.isEmpty ? '—' : _selected.weaponProfs.join('、')),
            _kv('工具熟练', _selected.toolProfs.isEmpty ? '—' : _selected.toolProfs.join('、')),
            _kv('技能选择', _selected.skillsRule),
          ]),
          const SizedBox(height: 12),
          _sectionTitle('职业特性（随等级解锁）'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: feats.isEmpty
                  ? const Text('该等级还没有可用特性。')
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: feats
                    .map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(f)),
                    ],
                  ),
                ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('按等级查看'),
          // 展示 1~5 级（demo），你可以拓展到 20 级
          ...List.generate(5, (i) => i + 1).map((lv) {
            final list = _selected.featuresByLevel[lv] ?? const <String>[];
            return ExpansionTile(
              initiallyExpanded: lv == _level,
              title: Text('Lv $lv'),
              children: list.isEmpty
                  ? [const ListTile(title: Text('—'))]
                  : list.map((f) => ListTile(title: Text(f))).toList(),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===== 复用小部件 =====
  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _infoCard({required List<Widget> children}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: children
            .expand((w) => [w, const Divider(height: 16)])
            .toList()
          ..removeLast(),
      ),
    ),
  );

  Widget _kv(String k, String v) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 90, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
      const SizedBox(width: 8),
      Expanded(child: Text(v)),
    ],
  );
}

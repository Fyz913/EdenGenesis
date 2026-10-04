extends Node
class_name TechnologyManager
## 0.17 技术总管：个人经验 → 文明知识池 → 发明 → 时代演化 → 建筑/经济变化。
## 分层：daily=技能积累/传授；monthly=知识汇总/发明检查；yearly=时代/传播/衰减/文化。

const KnowledgeScript: Script = preload("res://scripts/technology/knowledge_system.gd")
const SkillScript: Script = preload("res://scripts/technology/skill_system.gd")
const InventionScript: Script = preload("res://scripts/technology/invention_system.gd")
const ResearchScript: Script = preload("res://scripts/technology/research_group.gd")
const SpreadScript: Script = preload("res://scripts/technology/technology_spread.gd")
const CultureEvoScript: Script = preload("res://scripts/culture/cultural_evolution.gd")

var world: Node = null
var knowledge: Node          # KnowledgeSystem
var skill: Node              # SkillSystem
var invention: Node          # InventionSystem
var research: Node           # ResearchGroup
var spread: Node             # TechnologySpread
var culture_evo: Node        # CulturalEvolution

var current_era: String = "原始时代"
var era_visual_done: String = ""       # 已做过视觉升级的时代（防止重复建楼）
var _tick: int = 0

func _init() -> void:
	knowledge = KnowledgeScript.new()
	skill = SkillScript.new()
	invention = InventionScript.new()
	research = ResearchScript.new()
	spread = SpreadScript.new()
	culture_evo = CultureEvoScript.new()
	add_child(knowledge)
	add_child(skill)
	add_child(invention)
	add_child(research)
	add_child(spread)
	add_child(culture_evo)

func bind(w: Node) -> void:
	world = w
	spread.bind(w)
	culture_evo.bind(w)

# ---- 每天：个人技能积累（4 天节流，远距离纯数据层） ----
func daily_tick(residents: Array) -> void:
	_tick += 1
	if _tick % 4 != 0: return
	for n in residents:
		if not n.get("job") or n.job == "孩子": continue
		if n.skill_sys == null: continue
		var info: Dictionary = n.skill_sys.work_gain(n.skills, n.job, n.education)
		n.skill_exp += 1
		# 实验记录：主技能越接近领域前沿越"尝试新东西"
		if n.skills.get(info.field, 0.0) > 40.0 and randf() < 0.05:
			n.skill_exp += 1
	# 师徒传授：年长高技者向年轻学徒转移 20%×0.05
	for n in residents:
		if n.get("age") == null or n.age < 45 or n.job == "孩子": continue
		if n.skills.is_empty(): continue
		var best_field: String = _best_skill(n.skills)
		if n.skills[best_field] < 60.0: continue
		for s in residents:
			if s == n or s.age > 30 or s.job == "孩子": continue
			if s.skill_sys == null: continue
			if randf() < 0.1:
				n.skill_sys.teach(n.skills, s.skills, best_field)
				break

func _best_skill(skills: Dictionary) -> String:
	var best: String = ""
	var bv: float = -1.0
	for k in skills:
		if skills[k] > bv:
			bv = skills[k]; best = k
	return best

# ---- 每月：技能 → 文明知识池（研究组织加成 + 教育贡献），发明检查 ----
func monthly_tick(residents: Array, city) -> void:
	var civ = world.get("civ")
	if civ == null: return
	var org_mgr = world.get("org_mgr")
	# 1) 工作知识汇总（真实来源：个人技能）
	var acc: Dictionary = {}
	for n in residents:
		if n.skill_sys == null or n.skills.is_empty(): continue
		var c: Dictionary = n.skill_sys.contribute_to_knowledge(n.skills, n.job)
		acc[c.field] = acc.get(c.field, 0.0) + c.amount
	for f in acc:
		var mult: float = research.bonus_for(f, org_mgr)
		knowledge.gain(f, acc[f] * mult)
	# 2) 教育贡献：学校提升数学/工程（0.19.1 提高系数，使工程知识随城镇学校数量可见增长）
	var schools: int = city.schools if city else 0
	if schools > 0:
		knowledge.gain("mathematics", 0.05 * schools)
		knowledge.gain("engineering", 0.05 * schools)
	# 3) 发明检查
	var new_ones: Array = invention.monthly_tick(knowledge, residents, city)
	for ev in new_ones:
		ev.year = _year()
		_record("发明", "%s 发明了「%s」，%s" % [ev.creator, ev.invention_name, ev.effect_text])
		_toast("💡", ev.invention_name + "：" + ev.effect_text)
		civ.culture.adjust_belief("knowledge", 3.0)
	# 4) 历法发明加速整体知识
	if invention.inventions.size() > 0:
		for inv in invention.inventions:
			if inv.field == "astronomy" and inv.era_bonus >= 0.05:
				for f in knowledge.knowledge:
					knowledge.gain(f, knowledge.get_value(f) * 0.004)

# ---- 每年：时代评估 → 视觉升级 → 传播 → 战争衰减 → 文化演化 ----
func yearly_tick(city, residents: Array) -> void:
	var civ = world.get("civ")
	if civ == null: return
	var diplomacy = world.get("diplomacy")
	var pop: int = civ.civilization.population if civ.get("civilization") else 0
	# 1) 时代评估（不按年份）
	var era: String = knowledge.evaluate_era(city, pop)
	if era != current_era:
		_record("时代", "Eden 进入「%s」" % era)
		_toast("🏛", "Eden 进入" + era)
		current_era = era
	# 2) 时代视觉升级（每时代一次，增量建筑）
	if era_visual_done != current_era:
		_era_visuals(era)
		era_visual_done = current_era
	# 3) 技术沿贸易路线传播（Eden ↔ 各文明）
	spread.yearly_spread(knowledge, diplomacy)
	# 4) 战争知识流失
	var at_war: bool = false
	var war_mgr = world.get("war_mgr")
	if war_mgr and war_mgr.has_method("get_active_war_for"):
		at_war = war_mgr.get_active_war_for("Eden") != null
	if at_war:
		spread.yearly_war_decay(knowledge, true, residents)
		_record("知识", "战争让 Eden 的知识积累蒙受损失")
	# 5) 文化演化（传统/语言/价值观）
	culture_evo.yearly_tick(civ, diplomacy)

## 时代升级 → 真实建筑变化（增量，不删旧）
func _era_visuals(era: String) -> void:
	var cm = world.get("city_mgr")
	var expansion = cm.expansion if cm else null
	if expansion == null: return
	match era:
		"农业时代":
			expansion.add_era_buildings("stone", 8)     # 石屋（灰顶）
			_record("建设", "农业时代来临，村庄建起石屋与更多农田")
		"工业时代":
			expansion.add_era_buildings("factory", 2)   # 工厂烟囱
			expansion.add_era_buildings("rail", 1)      # 铁轨色带
			_record("建设", "工业时代来临，Eden 升起烟囱、铺下铁轨")
		"信息时代":
			expansion.add_era_buildings("tower", 2)     # 高塔
			expansion.add_era_buildings("lamp", 6)      # 路灯
			_record("建设", "信息时代来临，高塔与路灯点亮 Eden")
		"星际时代":
			expansion.add_era_buildings("beacon", 1)    # 星港信标
			_record("建设", "星际时代来临，Eden 树起星港信标")

func _record(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(), kind, text])

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

func _toast(icon: String, text: String) -> void:
	var toast = world.get_node_or_null("/root/Main/EventToast")
	if toast and toast.has_method("show_event"):
		toast.show_event(icon, text)

## 面板数据（TAB 文明·知识）
func panel_data(civ) -> Dictionary:
	return {
		"era": current_era,
		"knowledge": knowledge.summary(),
		"inventions": invention.inventions.map(func(ev): return ev.serialize()),
		"language": civ.culture.language if civ and civ.get("culture") else "Eden语",
		"values": civ.culture.values if civ and civ.get("culture") else [],
		"beliefs": civ.culture.beliefs if civ and civ.get("culture") else {},
		"research_groups": research.summary(world.get("org_mgr")),
	}

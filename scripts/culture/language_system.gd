extends Node
class_name LanguageSystem
## 0.17 语言演化：不是随机改名——按隔离时间/交流频率计算方言分化与借词。
## 与文明长期贸易→吸收借词；长期隔离（外交冷淡）→形成方言。

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 每年更新语言状态
func yearly_tick(culture, diplomacy) -> void:
	if culture == null: return
	var peers: int = 0
	var friendly: int = 0
	if diplomacy:
		var multiciv = world.get("multiciv") if world else null
		if multiciv:
			for civ in multiciv.civs:
				if civ.civ_name == "Eden": continue
				peers += 1
				if diplomacy.relation_value("Eden", civ.civ_name) >= 40.0:
					friendly += 1
	# 基础语言名
	var base: String = "Eden语"
	if culture.language == "":
		culture.language = base
		return
	# 方言形成：与主要文明长期冷淡（>3 个关系冷淡）→ 语言分化
	if peers >= 2 and friendly < peers - 1:
		if culture.language == base:
			culture.language = base + "（北地腔）"
			_record("语言", "与外界长期疏离，Eden 语在北方聚落形成了方言")
	# 借词：友好贸易吸收对方词汇
	elif friendly >= 1 and culture.language == base + "（北地腔）":
		culture.language = base
		_record("语言", "贸易恢复，方言重新与标准语融合")

func _record(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	var yr: int = 1
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"): yr = eco.season_sys.year
	if hist: hist.record("第%d年[%s] %s" % [yr, kind, text])

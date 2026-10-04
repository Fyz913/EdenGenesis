extends Node
class_name TechnologySpread
## 0.17 技术传播与丢失：
## 传播——沿真实贸易路线，两个文明的知识池互相渗透（每年 5%，封顶）。
## 丢失——战争/人口骤减/专家流失时，文明知识衰减（战争每年 -5%，领域低于 10 视为失传）。

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 每年：贸易路线传播（Eden 与各文明之间）
func yearly_spread(knowledge, diplomacy) -> void:
	if knowledge == null or diplomacy == null: return
	for route in diplomacy.trade_routes:
		if not route.active: continue
		var other: String = _peer(route, "Eden")
		if other == "": continue
		var peer_knowledge = _peer_knowledge(other)
		if peer_knowledge == null: continue
		# Eden → 对方：5%
		for f in knowledge.knowledge:
			var delta: float = knowledge.get_value(f) * 0.05
			peer_knowledge.gain(f, delta)
			knowledge.decay(f, delta * 0.3)   # 分享知识略微稀释"独占优势"（保留 30% 付出感）
		# 对方 → Eden：5%（对方数据不足则按当前知识池保守扩散）
		for f in knowledge.knowledge:
			var incoming: float = peer_knowledge.get_value(f) * 0.05
			if incoming > knowledge.get_value(f):
				knowledge.gain(f, incoming - knowledge.get_value(f))
		_record("技术", "Eden 与" + other + "的贸易线让两地知识互相流通")

func _peer(route, self_name: String) -> String:
	if route.from_civilization == self_name: return route.to_civilization
	if route.to_civilization == self_name: return route.from_civilization
	return ""

## 其他文明的知识池：动态创建（简化的对手文明知识，从文明列表同步）
func _peer_knowledge(peer_name: String):
	var multiciv = world.get("multiciv") if world else null
	if multiciv == null: return null
	for civ in multiciv.civs:
		if civ.civ_name == peer_name:
			var k = civ.get("knowledge")
			if k == null:
				k = load("res://scripts/technology/knowledge_system.gd").new()
				var v: float = civ.population * 0.02
				k.reset()
				for f in ["agriculture", "construction", "metallurgy", "medicine", "mathematics", "engineering"]:
					k.gain(f, clamp(v, 0.0, 40.0))
				civ.knowledge = k
			return k
	return null

## 每年：战争知识流失
func yearly_war_decay(knowledge, at_war: bool, residents: Array) -> void:
	if not at_war: return
	var loss: float = 5.0
	for f in knowledge.knowledge:
		knowledge.decay(f, loss * 0.2)
	# 专家流失：领域技能最高的居民去世/离开的模拟（按从业者人数下降）
	var experts: int = 0
	for n in residents:
		if n.get("skills") != null and not n.skills.is_empty():
			experts += 1
	if experts < 3:
		_record("知识", "战乱不止，工匠四散，部分技艺濒临失传")

func _record(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	var yr: int = 1
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"): yr = eco.season_sys.year
	if hist: hist.record("第%d年[%s] %s" % [yr, kind, text])

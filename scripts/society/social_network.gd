extends Node
class_name SocialNetwork
## 0.16 社会网络：关系不随机生成，按生活空间产生——
## 家人 > 邻居（住宅相近）> 同事（同一工作建筑）> 市场常客
## 每日随机抽取少量活跃关系互动（避免 O(n²) 全量重算）

var world: Node = null
var edges: Array = []   # [{a, b, kind}] 活跃关系边，供每日互动抽样

func bind(w: Node) -> void:
	world = w

## 重建关系网络（每月一次 / 人口结构变化时）
func build_network(residents: Array) -> void:
	edges.clear()
	_family_edges(residents)
	_neighbor_edges(residents)
	_coworker_edges(residents)

func _add_edge(a, b, kind: String, value: int) -> void:
	if a == null or b == null or a == b: return
	# 去重：同对只保留最亲密的边
	for e in edges:
		if (e.a == a and e.b == b) or (e.a == b and e.b == a):
			e.value = max(e.value, value)
			return
	edges.append({"a": a, "b": b, "kind": kind, "value": value})

func _family_edges(residents: Array) -> void:
	var seen: Array = []
	for n in residents:
		if n.family == null or n.family in seen: continue
		seen.append(n.family)
		var ms: Array = n.family.get_members()
		for i in range(ms.size()):
			for j in range(i + 1, ms.size()):
				_add_edge(ms[i], ms[j], "家人", 55)

## 邻居：同宅（公寓）跨家庭 + 宅号相邻（数值差 <= 1）
func _neighbor_edges(residents: Array) -> void:
	var buckets: Dictionary = {}
	for n in residents:
		if n.home_house_id == "": continue
		if not buckets.has(n.home_house_id):
			buckets[n.home_house_id] = []
		buckets[n.home_house_id].append(n)
	var ids: Array = buckets.keys()
	for id_a in ids:
		var la: Array = buckets[id_a]
		# 同宅跨家庭互为邻居
		if la.size() >= 2:
			for i in range(la.size()):
				for j in range(i + 1, la.size()):
					if la[i].family and la[j].family and la[i].family == la[j].family: continue
					_add_edge(la[i], la[j], "邻居", 10)
		# 相邻宅号
		var na: int = _house_num(id_a)
		for id_b in ids:
			if id_a == id_b: continue
			var nb: int = _house_num(id_b)
			if abs(na - nb) > 1: continue
			for a in la:
				for b in buckets[id_b]:
					_add_edge(a, b, "邻居", 8)

func _house_num(house_id: String) -> int:
	var m: PackedStringArray = house_id.split("_", false)
	if m.is_empty(): return 9999
	return m[-1].to_int()

## 同事：同一工作建筑
func _coworker_edges(residents: Array) -> void:
	var buckets: Dictionary = {}
	for n in residents:
		if n.job_building_id == "": continue
		if not buckets.has(n.job_building_id):
			buckets[n.job_building_id] = []
		buckets[n.job_building_id].append(n)
	for id in buckets:
		var group: Array = buckets[id]
		if group.size() < 2: continue
		for i in range(group.size()):
			for j in range(i + 1, group.size()):
				_add_edge(group[i], group[j], "同事", 15)

## 每日互动：抽样少量活跃关系，产生友谊/信任微变化
func daily_interaction(count: int = 4) -> void:
	if edges.is_empty(): return
	for _i in range(min(count, edges.size())):
		var e: Dictionary = edges.pick_random()
		var delta: int = randi_range(1, 3)
		if e.a and e.b:
			e.a.relationship.add_relation(e.b.npc_name, delta)
			e.b.relationship.add_relation(e.a.npc_name, delta)

## 重大社会事件：关系变化 + 双方记忆（犯罪/帮助/冲突等）
func social_event(a, b, delta: int, text: String, importance: int = 40) -> void:
	var yr: int = 1
	if world and world.get("ecosystem") and world.ecosystem.get("season_sys"):
		yr = world.ecosystem.season_sys.year
	if a:
		if b: a.relationship.add_relation(b.npc_name, delta)
		if text != "" and a.get("life_memory"):
			a.life_memory.record(text, importance, yr, "重要")
	if b:
		if a: b.relationship.add_relation(a.npc_name, delta)
		if text != "" and b.get("life_memory"):
			b.life_memory.record(text, importance, yr, "重要")

## 获取某人关系摘要（面板用）：按数值降序
func summary_of(npc) -> Array:
	var out: Array = []
	if npc == null or npc.get("relationship") == null: return out
	for k in npc.relationship.relations:
		out.append({"name": k, "value": npc.relationship.relations[k]})
	out.sort_custom(func(x, y): return x.value > y.value)
	return out

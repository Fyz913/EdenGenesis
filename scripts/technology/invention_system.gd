extends Node
class_name InventionSystem
## 0.17 发明系统：发明不是随机奖励，必须由真实条件触发：
## 领域知识阈值 + 相关从业者数量 + 实验/工作累计次数 + 相关建筑数量。
## 每次发明提高该领域门槛（防止连发）；发明写入历史并给该领域产出加成。

const InnovationScript: Script = preload("res://scripts/technology/innovation_event.gd")

## 发明清单：{name, field, 知识阈值, 从业者最低数, 实验最低数, 建筑最低数, 效果文案, 产出加成}
const INVENTIONS := [
	{"name": "石制农具", "field": "agriculture", "k": 30.0, "w": 3, "e": 200, "b": 2,
		"effect": "农田产出 +8%", "bonus": 0.08},
	{"name": "改良犁", "field": "agriculture", "k": 55.0, "w": 4, "e": 600, "b": 3,
		"effect": "农田产出 +15%", "bonus": 0.15},
	{"name": "强化钢工具", "field": "metallurgy", "k": 60.0, "w": 2, "e": 700, "b": 3,
		"effect": "铁矿产出 +20%", "bonus": 0.2},
	{"name": "砖石营造法", "field": "construction", "k": 45.0, "w": 3, "e": 500, "b": 3,
		"effect": "建设效率 +12%", "bonus": 0.12},
	{"name": "水车", "field": "engineering", "k": 50.0, "w": 2, "e": 600, "b": 3,
		"effect": "工业产出 +15%", "bonus": 0.15},
	{"name": "草药医学", "field": "medicine", "k": 35.0, "w": 2, "e": 400, "b": 1,
		"effect": "居民康复速度提升", "bonus": 0.1},
	{"name": "历法", "field": "astronomy", "k": 40.0, "w": 1, "e": 500, "b": 1,
		"effect": "文明知识 +5%/年", "bonus": 0.05},
	{"name": "数学基础", "field": "mathematics", "k": 30.0, "w": 1, "e": 400, "b": 1,
		"effect": "全体教育效率 +10%", "bonus": 0.1},
]

var invented: Dictionary = {}   # field -> 已触发阈值（防连发）
var inventions: Array = []      # InnovationEvent 列表

## 每月检查所有领域；返回本次新增发明列表
func monthly_tick(knowledge, residents: Array, city) -> Array:
	var new_ones: Array = []
	for inv in INVENTIONS:
		if invented.has(inv.field) and invented[inv.field] >= inv.k:
			continue
		var kv: float = knowledge.get_value(inv.field)
		if kv < inv.k: continue
		# 从业者数量
		var workers: int = 0
		for n in residents:
			if _worker_matches(n, inv.field): workers += 1
		if workers < inv.w: continue
		# 实验/工作累计次数（取从业者总和）
		var exp: int = 0
		for n in residents:
			if _worker_matches(n, inv.field): exp += n.skill_exp
		if exp < inv.e: continue
		# 建筑数量
		var buildings: int = _field_buildings(city, inv.field)
		if buildings < inv.b: continue
		# 触发发明
		invented[inv.field] = inv.k
		var ev = InnovationScript.new(inv.name, inv.field, _pick_creator(residents, inv.field), 0, inv.effect, inv.bonus)
		inventions.append(ev)
		new_ones.append(ev)
	return new_ones

func _worker_matches(n, field: String) -> bool:
	match field:
		"agriculture": return n.job in ["农民", "农夫", "渔夫"]
		"metallurgy": return n.job == "铁匠"
		"construction": return n.job in ["矿工", "伐木工"]
		"engineering": return n.job in ["铁匠", "织布工", "矿工"]
		"medicine": return n.job in ["面包师", "织布工"]
		"astronomy": return n.job in ["渔夫", "商人"]
		"mathematics": return n.job in ["商人", "织布工"]
	return false

func _field_buildings(city, field: String) -> int:
	if city == null: return 0
	match field:
		"agriculture": return city.commercial_buildings + city.public_buildings
		"metallurgy": return city.industrial_buildings
		"construction": return city.public_buildings
		"engineering": return city.industrial_buildings
		"medicine": return city.clinics + city.hospitals
		"astronomy": return city.public_buildings
		"mathematics": return city.schools
	return 0

func _pick_creator(residents: Array, field: String) -> String:
	for n in residents:
		if _worker_matches(n, field):
			return n.npc_name
	return "无名匠人"

## 领域累计产出加成（经济层调用）：同名领域只取最大
func field_bonus(field: String) -> float:
	var best: float = 0.0
	for inv in inventions:
		if inv.field == field and inv.era_bonus > best:
			best = inv.era_bonus
	return best

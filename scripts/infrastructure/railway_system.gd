extends Node
class_name RailwaySystem
## 0.19 铁路系统：工业时代 + 工程知识 + 财政能力 → 铁路网络。
## 铁路加成：贸易量翻倍、迁移加速、工业发展。

class Railway:
	var from_city: String = ""
	var to_city: String = ""
	var length: float = 0.0
	var built_year: int = 0
	func _init(a: String, b: String, l: float, y: int) -> void:
		from_city = a; to_city = b; length = l; built_year = y

var railways: Array = []

func can_build(world, era: String) -> bool:
	if era != "工业时代" and era != "信息时代" and era != "星际时代": return false
	var tech_mgr = world.get("tech_mgr") if world else null
	if tech_mgr:
		var eng: float = tech_mgr.knowledge.knowledge.get("engineering", 0.0)
		if eng < 60.0: return false
	return true

func build_railway(a: String, b: String, dist: float, year: int) -> void:
	for r in railways:
		if (r.from_city == a and r.to_city == b) or (r.from_city == b and r.to_city == a):
			return
	railways.append(Railway.new(a, b, dist, year))

func has_rail(a: String, b: String) -> bool:
	for r in railways:
		if (r.from_city == a and r.to_city == b) or (r.from_city == b and r.to_city == a):
			return true
	return false

func network_bonus(city_id: String) -> float:
	var n: int = 0
	for r in railways:
		if r.from_city == city_id or r.to_city == city_id:
			n += 1
	return float(n) * 1.5   # 每条铁路线贸易/迁移 +150%

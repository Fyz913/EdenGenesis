extends Node
class_name RoadSystem
## 0.19 道路系统：城市间道路（真实连接），等级随时代演化。
## 道路影响：贸易加成 / 迁移加成 / 军队移动速度 / 行政效率。
## 断路（quality 归零）→ 该城市贸易与迁移下降（可观测）。

class Road:
	var from_city: String = ""
	var to_city: String = ""
	var length: float = 0.0        # 米
	var level: int = 1            # 1 泥路 / 2 石路 / 3 公路 / 4 高速
	var type_name: String = "泥路"
	var quality: float = 1.0      # 0~1
	var capacity: float = 10.0    # 通行能力
	var built_year: int = 1
	func _init(a: String, b: String, l: float, lv: int, tn: String) -> void:
		from_city = a; to_city = b; length = l; level = lv; type_name = tn
	func speed() -> float:
		return 1.0 + float(level) * 0.5   # 通行速度倍率

var roads: Array = []   # Road

func road_type_by_era(era: String) -> Dictionary:
	match era:
		"原始时代": return {"level": 1, "name": "泥路"}
		"农业时代": return {"level": 2, "name": "石路"}
		"工业时代": return {"level": 3, "name": "公路"}
		"信息时代": return {"level": 4, "name": "高速"}
		"星际时代": return {"level": 5, "name": "悬浮道"}
	return {"level": 1, "name": "泥路"}

func build_road(a: String, b: String, dist: float, era: String, year: int) -> void:
	for r in roads:
		if (r.from_city == a and r.to_city == b) or (r.from_city == b and r.to_city == a):
			return   # 已存在
	var spec: Dictionary = road_type_by_era(era)
	var r = Road.new(a, b, dist, spec["level"], spec["name"])
	r.built_year = year
	roads.append(r)

func road_between(a: String, b: String):
	for r in roads:
		if (r.from_city == a and r.to_city == b) or (r.from_city == b and r.to_city == a):
			return r
	return null

func has_road(a: String, b: String) -> bool:
	return road_between(a, b) != null

## 断路：道路被破坏（战争/灾害），质量归零 → 贸易/迁移下降
func break_road(a: String, b: String) -> void:
	var r = road_between(a, b)
	if r:
		r.quality = 0.0
		r.capacity = 0.0

func repair_roads() -> void:
	for r in roads:
		if r.quality < 1.0:
			r.quality = minf(1.0, r.quality + 0.5)
			r.capacity = 10.0 + float(r.level) * 5.0

## 城市网络加成（道路数量 × 质量 × 速度，供行政/贸易使用）
func network_bonus(city_id: String) -> float:
	var bonus: float = 0.0
	for r in roads:
		if r.from_city == city_id or r.to_city == city_id:
			bonus += r.quality * r.speed() * r.capacity * 0.01
	return bonus

## 军队移动加成：该军队所在城市（或最近城市）的道路速度
func army_speed_mult(city_id: String) -> float:
	var r = road_between(city_id, city_id)
	if r: return r.speed() * r.quality
	# 城市在任意路上 → 取最高速度
	var best: float = 1.0
	for road in roads:
		if road.from_city == city_id or road.to_city == city_id:
			best = maxf(best, road.speed() * road.quality)
	return best

## 道路 ASCII（TAB 基建）
func road_map_text(city_mgr) -> String:
	if roads.is_empty(): return "（无道路）"
	var lines: Array = []
	for r in roads:
		var a = city_mgr.get_city(r.from_city)
		var b = city_mgr.get_city(r.to_city)
		var an: String = a.city_name if a else r.from_city
		var bn: String = b.city_name if b else r.to_city
		lines.append("  %s ──[%s L%d 速x%.1f]── %s" % [an, r.type_name, r.level, r.speed(), bn])
	return "\n".join(lines)

extends Node
class_name BridgeSystem
## 0.19 桥梁系统：河流阻隔 → 桥梁连接两岸（两城连线跨河则自动建桥）。
## 无桥跨河城市无法通商/通行（道路无效）；建桥恢复连接。

class Bridge:
	var city_a: String = ""
	var city_b: String = ""
	var length: float = 0.0
	var built_year: int = 0
	func _init(a: String, b: String, l: float, y: int) -> void:
		city_a = a; city_b = b; length = l; built_year = y

var bridges: Array = []
const RIVER_Z: float = 0.0

## 两城连线是否跨河（线段与 z=0 相交）
func crosses_river(a: Vector3, b: Vector3) -> bool:
	return (a.z < RIVER_Z and b.z > RIVER_Z) or (a.z > RIVER_Z and b.z < RIVER_Z)

func needs_bridge(a: Vector3, b: Vector3) -> bool:
	return crosses_river(a, b)

func build_bridge(city_a: String, city_b: String, length: float, year: int) -> void:
	for br in bridges:
		if (br.city_a == city_a and br.city_b == city_b) or (br.city_a == city_b and br.city_b == city_a):
			return
	bridges.append(Bridge.new(city_a, city_b, length, year))

func has_bridge(a: String, b: String) -> bool:
	for br in bridges:
		if (br.city_a == a and br.city_b == b) or (br.city_a == b and br.city_b == a):
			return true
	return false

func bridge_text(city_mgr) -> String:
	if bridges.is_empty(): return "（无桥梁）"
	var lines: Array = []
	for br in bridges:
		var a = city_mgr.get_city(br.city_a)
		var b = city_mgr.get_city(br.city_b)
		lines.append("  🌉 %s ── %s（跨河 %.0fm）" % [
			a.city_name if a else br.city_a, b.city_name if b else br.city_b, br.length])
	return "\n".join(lines)

extends Node
class_name PortSystem
## 0.19 港口系统：沿海城市（距河/海近）发展港口。
## 港口影响：贸易量 / 人口吸引 / 文化交流 / 科技传播。

class Port:
	var city_id: String = ""
	var capacity: float = 50.0
	var trade_volume: float = 0.0
	var built_year: int = 0
	func _init(cid: String, y: int) -> void:
		city_id = cid; built_year = y

var ports: Array = []
const RIVER_Z: float = 0.0   # 世界河流 z=0 一线（0.10.6 布局）

func is_coastal(city) -> bool:
	if city == null: return false
	return absf(city.center.z - RIVER_Z) < 35.0

func can_build_port(city) -> bool:
	if city == null: return false
	return is_coastal(city) and city.level >= 3

func build_port(city_id: String, year: int) -> void:
	for p in ports:
		if p.city_id == city_id: return
	ports.append(Port.new(city_id, year))

func trade_bonus(city_id: String) -> float:
	for p in ports:
		if p.city_id == city_id:
			return p.capacity * 0.01   # 每港贸易 +容量%
	return 0.0

func port_text(city_mgr) -> String:
	if ports.is_empty(): return "（无港口）"
	var lines: Array = []
	for p in ports:
		var c = city_mgr.get_city(p.city_id)
		lines.append("  ⚓ %s 港口（容量%.0f 贸易%.0f）" % [c.city_name if c else p.city_id, p.capacity, p.trade_volume])
	return "\n".join(lines)

extends Node
class_name TradeRouteSystem
## 0.19 贸易路线系统：扩展 0.13 diplomacy.trade_routes（不新建第二套）。
## 运输速度 = 道路等级 × 质量 ×（铁路×2 × 港口×1.5）；
## 断路 → 该路线贸易量下降（可观测）。不伪造商品：只调整速率。

## 某条路线运输速度倍率
func route_speed(world, route) -> float:
	var infra_mgr = world.get("infra_mgr") if world else null
	if infra_mgr == null: return 1.0
	# 城市间道路（Eden 内部路线）
	var city_mgr = world.get("city_mgr") if world else null
	var speed: float = 1.0
	if city_mgr:
		var from_city = _city_by_name(city_mgr, route.from_civilization)
		var to_city = _city_by_name(city_mgr, route.to_civilization)
		if from_city and to_city:
			if infra_mgr.road_sys.has_road(from_city.id, to_city.id):
				var road = infra_mgr.road_sys.road_between(from_city.id, to_city.id)
				speed = road.speed() * road.quality
				if infra_mgr.railway.has_rail(from_city.id, to_city.id):
					speed *= 2.0
				if _city_has_port(infra_mgr, from_city.id) or _city_has_port(infra_mgr, to_city.id):
					speed *= 1.5
			else:
				speed = 0.3   # 无路：贸易几乎停滞
	return speed

func _city_by_name(city_mgr, name: String):
	for city in city_mgr.get_all_cities():
		if city.city_name == name or city.id == name:
			return city
	return null

func _city_has_port(infra_mgr, city_id: String) -> bool:
	for p in infra_mgr.port_sys.ports:
		if p.city_id == city_id: return true
	return false

## 月度：更新每条贸易路线的实际流速（记录到 route，供外交/经济消费）
func monthly_update(world) -> void:
	var diplomacy = world.get("diplomacy") if world else null
	if diplomacy == null: return
	for route in diplomacy.trade_routes:
		var sp: float = route_speed(world, route)
		# 兼容 EdenTradeRoute 对象与 Dictionary（自测/存档）
		if route is Dictionary:
			route["speed_mult"] = sp
			route["active"] = sp >= 0.5
		else:
			route.speed_mult = sp
			route.active = sp >= 0.5

## 面板：贸易路线状态
func routes_text(world) -> String:
	var diplomacy = world.get("diplomacy") if world else null
	if diplomacy == null: return "（无贸易路线）"
	var lines: Array = []
	for route in diplomacy.trade_routes:
		var sp: float = route.speed_mult if route.get("speed_mult") != null else 1.0
		var st: String = "停运" if not route.active else ("速x%.1f" % sp)
		lines.append("  %s → %s  %s（%d/日）" % [route.from_civilization, route.to_civilization, st, route.amount_per_day])
	return "\n".join(lines)

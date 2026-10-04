extends Node
class_name TransportManager
## 0.19 交通总管：物流（货物）、迁移（人口）、贸易线（0.13 扩展）、军队移动（0.14 连接）。
## 分层调度：月度=物流+迁移+贸易线；年度=基建规划（由 infra_mgr 处理）。

const LogisticsScript: Script = preload("res://scripts/transport/logistics_system.gd")
const MigrationScript: Script = preload("res://scripts/transport/migration_system.gd")
const TradeRouteScript: Script = preload("res://scripts/transport/trade_route_system.gd")

var world: Node = null
var logistics: Node
var migration: Node
var trade_routes: Node

func bind(w: Node) -> void:
	world = w
	logistics = LogisticsScript.new(); add_child(logistics)
	migration = MigrationScript.new(); add_child(migration)
	trade_routes = TradeRouteScript.new(); add_child(trade_routes)

func eden_country():
	var cm = world.get("country_mgr") if world else null
	return cm.eden_country() if cm else null

## 月度：物流 + 迁移 + 贸易线速度
func monthly_tick() -> void:
	var country = eden_country()
	if country == null: return
	logistics.monthly_flow(world, country)
	migration.monthly_migrate(world)
	trade_routes.monthly_update(world)
	# 军队移动加成（0.14 连接：道路加速行军——写入 army 供战争系统消费）
	var army_mgr = world.get("army_mgr") if world else null
	if army_mgr and army_mgr.armies.get("Eden"):
		var army = army_mgr.armies["Eden"]
		var infra_mgr = world.get("infra_mgr")
		if infra_mgr:
			army.speed_mult = infra_mgr.army_speed_mult(_nearest_city(army.location))
		else:
			army.speed_mult = 1.0

func _nearest_city(pos: Vector3) -> String:
	var city_mgr = world.get("city_mgr") if world else null
	if city_mgr == null: return ""
	var best_id: String = ""
	var best_d: float = 1e9
	for city in city_mgr.get_all_cities():
		if city.civilization_id != "Eden": continue
		var d: float = city.center.distance_to(pos)
		if d < best_d:
			best_d = d
			best_id = city.id
	return best_id

## 面板
func panel_data(country) -> Dictionary:
	return {
		"logistics": logistics.summary(),
		"migration": migration.summary(),
		"routes": trade_routes.routes_text(world),
	}

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

extends Node
## 外交管理器：Eden 与北境部落 / 沙漠城邦的关系、条约、贸易路线。
## 关系影响经济：关系降到冷淡以下 → 对应贸易路线停用 → 出口减少 → 市场现金承压。

const RelationScript: Script = preload("res://scripts/diplomacy/relation.gd")
const TreatyScript: Script = preload("res://scripts/diplomacy/treaty.gd")
const TradeRouteScript: Script = preload("res://scripts/diplomacy/trade_route.gd")

var relations: Dictionary = {}
var treaties: Array = []
var trade_routes: Array = []

func setup() -> void:
	add_relation("Eden", "北境部落", 30.0)   # 和睦
	add_relation("Eden", "沙漠城邦", 10.0)   # 中立
	# 初始条约与贸易路线（出口原材料换现金，贸易路线停用即断财路）
	treaties.append(TreatyScript.new("贸易协定", "Eden", "北境部落", 1))
	trade_routes.append(TradeRouteScript.new("Eden", "北境部落", "wood", 5))
	trade_routes.append(TradeRouteScript.new("Eden", "北境部落", "cloth", 3))
	trade_routes.append(TradeRouteScript.new("Eden", "沙漠城邦", "iron", 3))
	trade_routes.append(TradeRouteScript.new("沙漠城邦", "Eden", "stone", 3))
	print("[Diplomacy] 外交就绪：Eden-北境=30 和睦，Eden-沙漠=10 中立")

func add_relation(a: String, b: String, v: float) -> void:
	relations[_key(a, b)] = RelationScript.new(a, b, v)

func _key(a: String, b: String) -> String:
	return a + "_" + b if a < b else b + "_" + a

func get_relation(a: String, b: String):
	return relations.get(_key(a, b), null)

func relation_value(a: String, b: String) -> float:
	var r = get_relation(a, b)
	return r.value if r else 0.0

func relation_label(a: String, b: String) -> String:
	var r = get_relation(a, b)
	return r.level_label() if r else "未知"

## 外交事件（任务书表）
func apply_event(a: String, b: String, kind: String) -> void:
	var r = get_relation(a, b)
	if r == null: return
	match kind:
		"贸易": r.adjust(5.0)
		"赠送资源": r.adjust(10.0)
		"边境冲突": r.adjust(-15.0)
		"攻击": r.adjust(-60.0)
		"共同抗灾": r.adjust(20.0)
		"粮食援助": r.adjust(8.0)

## 每日：按外交关系刷新贸易路线活性 + 关系缓慢向中立回归
func daily_tick() -> void:
	for route in trade_routes:
		var r = get_relation(route.from_civilization, route.to_civilization)
		route.active = (r != null and r.trade_allowed)
	for rel in relations.values():
		if rel.value != 0.0:
			rel.adjust(-signf(rel.value) * 0.2)

## 某商品当前有几条活跃出口路线（决定外贸能否出口该商品）
func active_routes_for(item: String) -> int:
	var cnt: int = 0
	for route in trade_routes:
		if route.resource == item and route.active and route.from_civilization == "Eden":
			cnt += 1
	return cnt

extends Node
## 0.20 市场供需管理器：每日采集需求（人口食物需求 + 企业原料需求），
## 供给 = 市场库存 → 需求/供给 比值驱动价格微调（叠加到 market.update_prices 的库存逻辑上）。
## 铁律：价格只由真实供需驱动，禁止写死或凭空涨跌。

var demand: Dictionary = {}       # resource_id -> 当日总需求（估算）
var supply: Dictionary = {}       # resource_id -> 当日供给（市场库存 + 资源池）
var price_index: Dictionary = {}  # resource_id -> 指数（相对基准价 1.0 = 正常）
var history: Array = []           # 近 30 日 {day, food_price, iron_price, demand_ratio} 供经济面板

func collect_demand(residents: Array, world) -> void:
	demand = {}
	var pop: int = residents.size()
	demand["food"] = float(pop) * 1.2          # 每人每天 1.2 份口粮
	demand["water"] = float(pop) * 0.5
	# 企业原料需求：汇总所有工厂的每小时配方输入（按 24 小时折算日需求）
	var prod_mgr = world.get("production_mgr") if world else null
	var input_demand: Dictionary = {}
	if prod_mgr and prod_mgr.get("factories") != null:
		for fid in prod_mgr.factories:
			var f: Dictionary = prod_mgr.factories[fid]
			var inputs: Dictionary = f.get("inputs", {})
			for res in inputs:
				input_demand[res] = input_demand.get(res, 0.0) + inputs[res] * 24.0
	for res in input_demand:
		demand[res] = demand.get(res, 0.0) + input_demand[res]

func collect_supply(market, world) -> void:
	supply = {}
	var resource_mgr = world.get("resource_mgr") if world else null
	if market and market.get("stock") != null:
		for k in market.stock:
			supply[k] = market.stock[k]
	if resource_mgr:
		for k in resource_mgr.pool:
			supply[k] = supply.get(k, 0.0) + resource_mgr.pool[k]

## 由 economy_simulation 每日调用：收集供需 → 更新价格指数 → 返回指数表
func daily_update(market, residents: Array, world) -> void:
	collect_demand(residents, world)
	collect_supply(market, world)
	price_index = {}
	for k in demand:
		var s: float = supply.get(k, 0.0)
		var ratio: float = demand[k] / max(1.0, s)
		price_index[k] = clampf(ratio, 0.3, 3.0)
	# 历史记录（封顶 30 条）
	history.append({
		"day": _day_count(world),
		"food_price": market.prices.get("food", 5.0) if market else 5.0,
		"iron_price": market.prices.get("iron", 20.0) if market else 20.0,
		"demand_ratio": price_index.get("food", 1.0),
	})
	if history.size() > 30:
		history.pop_front()

## 价格调节因子：把供需指数叠加到市场现有价格（economy_manager 日循环调用）
func apply_price_adjust(market) -> void:
	if market == null: return
	var strength: float = 0.15   # 供需指数对价格的每日调节强度（避免暴涨暴跌）
	for k in price_index:
		if market.prices.has(k):
			market.prices[k] = clampf(market.prices[k] * (1.0 + (price_index[k] - 1.0) * strength), 1.0, 100.0)

func stats() -> Dictionary:
	return {"demand": demand.duplicate(), "supply": supply.duplicate(),
		"index": price_index.duplicate(), "history_days": history.size()}

func _day_count(world) -> int:
	var d = world.get("director") if world else null
	if d and d.get("day_count") != null:
		return d.day_count
	return 0

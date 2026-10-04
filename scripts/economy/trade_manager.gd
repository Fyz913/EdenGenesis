extends Node
## 0.20 区域贸易管理器：区域间 CargoBatch 批量运输（禁止单 NPC 搬货）。
## 职责：区域路线（Eden↔北境↔沙漠）→ 生成货单批次 → 每日推进到达 → 货物入资源池/市场。
## 复用：0.12 trade_system 仍负责市场进出口与外汇（不重复发钱）；本管理器只做区域物流 + 贸易量统计。

var routes: Array = []       # {id, from_region, to_region, goods, amount_per_day, active}
var batches: Array = []      # CargoBatch: {id, goods, amount, source, destination, eta_days, day_remaining}
var trade_volume: float = 0.0   # 累计贸易量（件数）
var route_counter: int = 0
var batch_counter: int = 0

func setup_routes() -> void:
	route_counter = 0; batch_counter = 0
	routes = [
		{"id": "r1", "from_region": "eden", "to_region": "north", "goods": "food", "amount_per_day": 4.0, "active": true},
		{"id": "r2", "from_region": "north", "to_region": "eden", "goods": "wood", "amount_per_day": 4.0, "active": true},
		{"id": "r3", "from_region": "desert", "to_region": "eden", "goods": "iron", "amount_per_day": 2.0, "active": true},
	]

## 每日：按活跃路线生成批次（货源充足才发），推进在途批次
func daily_tick(world) -> void:
	var resource_mgr = world.get("resource_mgr") if world else null
	# 1) 生成新批次：区域密度决定货源能力，且本地池有货才发
	for r in routes:
		if not r["active"]: continue
		var src_pool: float = 0.0
		if resource_mgr:
			src_pool = resource_mgr.amount(r["goods"])
		var can_ship: float = min(r["amount_per_day"], src_pool * 0.05)
		if can_ship < 0.5: continue
		if resource_mgr:
			resource_mgr.consume(r["goods"], can_ship)
		_spawn_batch(r["goods"], can_ship, r["from_region"], r["to_region"])
	# 2) 推进批次
	var arrived: Array = []
	for b in batches:
		b["day_remaining"] = int(b["day_remaining"]) - 1
		if b["day_remaining"] <= 0:
			arrived.append(b)
	for b in arrived:
		batches.erase(b)
		# 到货 → 进入资源池（到 Eden 的货同时进市场库存，供居民购买）
		if resource_mgr:
			resource_mgr.add(b["goods"], b["amount"])
		trade_volume += b["amount"]

func _spawn_batch(goods: String, amount: float, src: String, dst: String) -> void:
	batch_counter += 1
	batches.append({
		"id": "batch_%d" % batch_counter, "goods": goods, "amount": amount,
		"source": src, "destination": dst, "eta_days": 3,
		"day_remaining": 3,
	})
	if batches.size() > 100:
		batches.pop_front()

func active_routes_count() -> int:
	var n: int = 0
	for r in routes:
		if r["active"]: n += 1
	return n

func batch_count() -> int:
	return batches.size()

func stats() -> Dictionary:
	return {"routes": routes.size(), "active_routes": active_routes_count(),
		"batches": batches.size(), "trade_volume": trade_volume,
		"volume_per_month": trade_volume / max(1.0, _months_run())}

func serialize() -> Dictionary:
	return {
		"routes": routes.duplicate(true),
		"batches": batches.duplicate(true),
		"trade_volume": trade_volume,
	}

func restore(data: Dictionary) -> void:
	if not (data is Dictionary): return
	routes = data.get("routes", routes).duplicate(true)
	batches = data.get("batches", []).duplicate(true)
	trade_volume = float(data.get("trade_volume", 0.0))

func _months_run() -> float:
	var w = get_node_or_null("/root/Main/World")
	if w:
		var d = w.get("director")
		if d and d.get("day_count") != null:
			return float(d.day_count) / 10.0
	return 1.0

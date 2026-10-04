extends Node
## 0.20 资源管理器：区域资源分布 + 世界资源池（自然资源 / 加工资源 / 高级资源）。
## 铁律：资源不凭空产生——只能来自区域开采 / 工厂生产；不凭空消失——只能被工厂消耗 / 居民消费。
## 加工资源（steel/tools/machine/electronics）只能由工厂生产产生，初始为 0。

var pool: Dictionary = {}           # resource_id -> amount（世界资源池，工厂生产/消耗走这里）
var regions: Dictionary = {}        # region_id -> {name, resources:{id: density 0~1}}
var base_prices: Dictionary = {}    # 资源基准价（与 market 基准价一致，供工厂成本核算）

func setup() -> void:
	pool = {
		"food": 500.0, "wood": 300.0, "stone": 200.0, "iron": 50.0,
		"coal": 0.0, "oil": 0.0, "water": 500.0,
		"steel": 0.0, "tools": 0.0, "machine": 0.0, "electronics": 0.0,
	}
	base_prices = {
		"food": 5.0, "wood": 8.0, "stone": 10.0, "iron": 20.0, "coal": 14.0,
		"oil": 40.0, "water": 2.0, "steel": 35.0, "tools": 30.0,
		"machine": 60.0, "electronics": 120.0,
	}
	regions = {
		"eden": {"name": "Eden谷", "resources": {"food": 0.6, "wood": 0.8, "stone": 0.2, "iron": 0.2, "water": 0.9}},
		"north": {"name": "北境", "resources": {"wood": 0.9, "coal": 0.7, "iron": 0.3, "food": 0.2, "water": 0.4}},
		"desert": {"name": "沙漠城邦", "resources": {"iron": 0.6, "coal": 0.4, "oil": 0.9, "food": 0.1, "water": 0.1}},
	}

func add(res: String, amt: float) -> void:
	if amt <= 0.0: return
	pool[res] = pool.get(res, 0.0) + amt

func consume(res: String, amt: float) -> bool:
	if amt <= 0.0: return true
	if pool.get(res, 0.0) < amt: return false
	pool[res] -= amt
	return true

func has(res: String, amt: float) -> bool:
	return pool.get(res, 0.0) >= amt

func amount(res: String) -> float:
	return pool.get(res, 0.0)

## 区域资源密度（0~1）：供贸易 / 工厂选址参考
func region_density(region_id: String, res: String) -> float:
	var r = regions.get(region_id)
	if r == null: return 0.0
	return r["resources"].get(res, 0.0)

func pool_snapshot() -> Dictionary:
	return pool.duplicate()

## 面板 / 存档用：按类别分组
func grouped() -> Dictionary:
	var natural: Array = []
	var processed: Array = []
	var advanced: Array = []
	var natural_set := ["food", "wood", "stone", "iron", "coal", "oil", "water"]
	for k in pool:
		var item: Dictionary = {"id": k, "amount": pool[k], "price": base_prices.get(k, 1.0)}
		if natural_set.has(k):
			natural.append(item)
		elif k in ["steel", "tools", "machine"]:
			processed.append(item)
		else:
			advanced.append(item)
	return {"natural": natural, "processed": processed, "advanced": advanced}

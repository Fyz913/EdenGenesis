extends Node
class_name LogisticsSystem
## 0.19 物流系统：Cargo 货物真实在城市间流动（农田/富余 → 紧缺城市）。
## 不凭空产粮：只转移已有城市 food_supply，受道路等级/距离/铁路影响。
## 粮食短缺 → 幸福下降 + 迁移压力 + 政治压力（真实后果）。

class Cargo:
	var type: String = ""
	var amount: float = 0.0
	var source: String = ""
	var destination: String = ""
	func _init(t: String, a: float, s: String, d: String) -> void:
		type = t; amount = a; source = s; destination = d

var cargos: Array = []

## 每月：富余城市 → 紧缺城市 粮食运输
func monthly_flow(world, country) -> void:
	var city_mgr = world.get("city_mgr") if world else null
	var infra_mgr = world.get("infra_mgr") if world else null
	if city_mgr == null or infra_mgr == null: return
	cargos = []
	var cities: Array = city_mgr.get_all_cities()
	var surplus: Array = []   # {city, amount}
	var deficit: Array = []
	for city in cities:
		if city.civilization_id != "Eden": continue
		var need: float = float(city.population) * 2.0
		if city.food_supply > need * 1.5:
			surplus.append({"city": city, "amount": city.food_supply - need * 1.5})
		elif city.food_supply < need:
			deficit.append({"city": city, "need": need - city.food_supply})
	for s in surplus:
		for d in deficit:
			if d["need"] <= 0.0: break
			if not infra_mgr.road_sys.has_road(s["city"].id, d["city"].id):
				continue   # 无路不通（跨河无桥则无路）
			var road = infra_mgr.road_sys.road_between(s["city"].id, d["city"].id)
			var speed: float = road.speed() * road.quality
			if infra_mgr.railway.has_rail(s["city"].id, d["city"].id):
				speed *= 2.0   # 铁路提速
			var transfer: float = minf(s["amount"], d["need"]) * minf(speed, 2.0)
			transfer = minf(transfer, s["amount"])
			s["city"].food_supply -= transfer
			d["city"].food_supply += transfer
			s["amount"] -= transfer
			d["need"] -= transfer
			cargos.append(Cargo.new("food", transfer, s["city"].id, d["city"].id))
			if transfer > 10.0:
				_hist("[物流]", "%s → %s 粮食运输 %.0f 单位" % [s["city"].city_name, d["city"].city_name, transfer])
	# 短缺后果
	for city in cities:
		if city.civilization_id != "Eden": continue
		if city.food_supply < float(city.population) * 1.0:
			city.happiness = maxf(10.0, city.happiness - 3.0)
			city.migration_pressure = minf(100.0, city.migration_pressure + 5.0)
			_hist("[粮荒]", "%s 粮食短缺，居民不安（库存 %.0f < 需求 %.0f）" % [
				city.city_name, city.food_supply, float(city.population)])

func summary() -> Dictionary:
	var total: float = 0.0
	var count: int = 0
	for c in cargos:
		total += c.amount
		count += 1
	return {"cargos": count, "total": int(total)}

func _hist(kind: String, text: String) -> void:
	var civ = get_node_or_null("/root/Main/World").get("civ")
	if civ == null: return
	var hist = civ.get("history")
	if hist:
		var eco = get_node_or_null("/root/Main/World").get("ecosystem")
		var yr: int = eco.season_sys.year if eco and eco.get("season_sys") else 1
		hist.record("第%d年[%s] %s" % [yr, kind, text])

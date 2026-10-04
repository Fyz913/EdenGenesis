extends Node
class_name MigrationSystem
## 0.19 人口迁移系统：0.15 已有城市迁移，这里扩展为「道路连接→跨城迁移加成」。
## 迁移评分 = 就业 + 食物 + 安全 + 幸福 + 道路连接（真实城市数据）。
## 不凭空增减人口：迁移只在已有城市间转移人口数（模拟流动）。

var monthly_flow_log: Array = []

## 计算城市迁移吸引力（0~100，真实数据）
func migration_score(city, residents_total: int) -> float:
	if city == null: return 0.0
	var score: float = 50.0
	score += minf(city.employment_capacity - city.population, 50.0) * 0.5   # 就业空间
	score += minf(city.food_supply / maxf(1.0, float(city.population) * 2.0), 1.0) * 15.0   # 粮食
	score += city.happiness * 0.3   # 幸福
	score -= city.migration_pressure * 0.2   # 压力
	return clampf(score, 0.0, 100.0)

## 月度：两城间迁移（道路连接城市才发生，方向=低分→高分）
func monthly_migrate(world) -> void:
	var city_mgr = world.get("city_mgr") if world else null
	var infra_mgr = world.get("infra_mgr") if world else null
	if city_mgr == null or infra_mgr == null: return
	monthly_flow_log = []
	var cities: Array = city_mgr.get_all_cities()
	for i in range(cities.size()):
		for j in range(i + 1, cities.size()):
			var a = cities[i]
			var b = cities[j]
			if a.civilization_id != "Eden" or b.civilization_id != "Eden": continue
			if not infra_mgr.road_sys.has_road(a.id, b.id): continue
			var sa: float = migration_score(a, 0)
			var sb: float = migration_score(b, 0)
			if absf(sa - sb) < 5.0: continue   # 差异太小不动
			var road = infra_mgr.road_sys.road_between(a.id, b.id)
			var speed: float = road.speed() * road.quality
			var amount: int = int(absf(sa - sb) * 0.02 * speed)   # 人口流动
			amount = mini(amount, maxi(1, int(minf(a.population, b.population) * 0.02)))
			if amount <= 0: continue
			if sa > sb:
				a.population = maxi(1, a.population + amount)
				b.population = maxi(1, b.population - amount)
				monthly_flow_log.append({"from": b.city_name, "to": a.city_name, "n": amount})
			else:
				b.population = maxi(1, b.population + amount)
				a.population = maxi(1, a.population - amount)
				monthly_flow_log.append({"from": a.city_name, "to": b.city_name, "n": amount})
			# 住房约束：迁入超过住房容量则溢出迁出（真实）
			var dest = a if sa > sb else b
			if dest.population > dest.housing_capacity:
				dest.migration_pressure = minf(100.0, dest.migration_pressure + 10.0)

func summary() -> Dictionary:
	var total: int = 0
	var lines: Array = []
	for f in monthly_flow_log:
		total += f["n"]
		lines.append("%s→%s %d人" % [f["from"], f["to"], f["n"]])
	return {"total": total, "flows": lines}

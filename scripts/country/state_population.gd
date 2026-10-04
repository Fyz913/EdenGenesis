extends Node
class_name StatePopulation
## 0.18 国家人口统计：从城市聚合，绝不凭空造人口。
## 城市人口变化 → 国家人口自动同步。

func total_population(world, country, city_mgr) -> int:
	if city_mgr == null: return 0
	var total: int = 0
	for city_id in country.city_ids:
		var city = city_mgr.get_city(city_id)
		if city: total += city.population
	return total

## 各城市人口分布（面板用）
func urban_distribution(world, country, city_mgr) -> Array:
	var out: Array = []
	if city_mgr == null: return out
	for city_id in country.city_ids:
		var city = city_mgr.get_city(city_id)
		if city:
			out.append({"name": city.city_name, "population": city.population, "level": city.level})
	return out

## 真实居民数（HumanManager 一致来源）
func residents(world) -> Array:
	var society = world.get("society") if world else null
	if society == null: return []
	return society.population.residents

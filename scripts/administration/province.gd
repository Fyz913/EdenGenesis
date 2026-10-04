extends RefCounted
class_name Province
## 0.19 省级行政区数据：国家 → 省 → 区 → 城市。
## 省长必须是真实居民（governor_id = npc_name）。

var id: String = ""
var name: String = ""
var country_id: String = ""
var city_ids: Array = []
var population: int = 0
var governor_id: String = ""
var development: float = 0.0        # 0~100 发展度
var tax_income: float = 0.0         # 本月税收（统计口径：国家收入按省人口占比分摊）
var infrastructure_level: float = 0.0 # 省基建水平
var admin_capacity: float = 50.0    # 行政能力 0~100
var corruption: float = 0.0         # 腐败率 0~1

func _init(i: String = "", n: String = "", cid: String = "") -> void:
	id = i
	name = n
	country_id = cid

func center_city(city_mgr):
	if city_ids.is_empty(): return null
	return city_mgr.get_city(city_ids[0])

func serialize() -> Dictionary:
	return {
		"id": id, "name": name, "country_id": country_id,
		"city_ids": city_ids.duplicate(), "population": population,
		"governor_id": governor_id, "development": development,
		"tax_income": tax_income, "infrastructure_level": infrastructure_level,
		"admin_capacity": admin_capacity, "corruption": corruption,
	}

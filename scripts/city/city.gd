extends RefCounted
## 城市数据（0.15）：一个城市的完整状态。
## 纯数据对象，不碰渲染；视觉由 city_expansion.gd 负责。

var id: String = ""
var city_name: String = ""
var civilization_id: String = ""
var center: Vector3 = Vector3.ZERO
var population: int = 0
var level: int = 1
var housing_capacity: int = 0      # 理论容纳（按每栋房屋容量计）
var employment_capacity: int = 0   # 岗位数
var happiness: float = 50.0
var prosperity: float = 50.0
var infrastructure: float = 10.0
var food_supply: float = 100.0
var water_supply: float = 100.0

var districts: Array = []          # district 对象
var buildings: Array = []          # {type, pos, health}
var roads: Array = []              # {from, to}

var founded_year: int = 1
var expansion_radius: float = 30.0
var active: bool = true

# 建筑计数（供升级条件）
var commercial_buildings: int = 0
var industrial_buildings: int = 0
var public_buildings: int = 0
var house_count: int = 0

# 0.16 社会设施计数（教育/医疗/治安）
var schools: int = 0
var clinics: int = 0
var hospitals: int = 0
var guard_posts: int = 0
var police_stations: int = 0
var social_stability: float = 70.0

# 迁移统计（面板显示）
var migration_in: int = 0
var migration_out: int = 0
var migration_pressure: float = 0.0
var unemployed: int = 0

func level_name() -> String:
	match level:
		1: return "村落"
		2: return "聚落"
		3: return "城镇"
		4: return "城市"
		5: return "大型城市"
	return "村落"

func serialize() -> Dictionary:
	return {
		"id": id,
		"name": city_name,
		"civilization_id": civilization_id,
		"population": population,
		"level": level,
		"housing_capacity": housing_capacity,
		"employment_capacity": employment_capacity,
		"happiness": happiness,
		"prosperity": prosperity,
		"infrastructure": infrastructure,
		"center": {"x": center.x, "y": center.y, "z": center.z},
		"founded_year": founded_year,
		"commercial": commercial_buildings,
		"industrial": industrial_buildings,
		"public": public_buildings,
		"food": food_supply,
	}

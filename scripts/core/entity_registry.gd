extends Node
## 0.19.7 统一实体注册表：Human/Building/City/Country 的 ID → 对象索引，
## 禁止重复 ID。SaveValidator 用它检查引用完整性，加载时重建。

var humans: Dictionary = {}      # id -> Node (NPC)
var buildings: Dictionary = {}   # id -> Object
var cities: Dictionary = {}      # id -> Object
var countries: Dictionary = {}   # id -> Object
var armies: Dictionary = {}      # id -> Object

func register_human(human) -> bool:
	if human == null: return false
	var id: String = str(human.get("id") if human.get("id") != null else human.get("npc_name") if human.get("npc_name") != null else "")
	if id == "": return false
	if humans.has(id):
		push_warning("[Registry] 重复 Human ID: " + id)
		return false
	humans[id] = human
	return true

func register_building(building) -> bool:
	if building == null: return false
	var id: String = str(building.get("id") if building.get("id") != null else "")
	if id == "": return false
	if buildings.has(id):
		push_warning("[Registry] 重复 Building ID: " + id)
		return false
	buildings[id] = building
	return true

func register_city(city) -> bool:
	if city == null: return false
	var id: String = str(city.get("id") if city.get("id") != null else "")
	if id == "": return false
	if cities.has(id):
		push_warning("[Registry] 重复 City ID: " + id)
		return false
	cities[id] = city
	return true

func register_country(country) -> bool:
	if country == null: return false
	var id: String = str(country.get("id") if country.get("id") != null else "")
	if id == "": return false
	if countries.has(id):
		push_warning("[Registry] 重复 Country ID: " + id)
		return false
	countries[id] = country
	return true

func register_army(army) -> bool:
	if army == null: return false
	var id: String = str(army.get("id") if army.get("id") != null else "")
	if id == "": return false
	if armies.has(id):
		push_warning("[Registry] 重复 Army ID: " + id)
		return false
	armies[id] = army
	return true

func get_human(id: String):
	return humans.get(id, null)

func get_building(id: String):
	return buildings.get(id, null)

func get_city(id: String):
	return cities.get(id, null)

func get_country(id: String):
	return countries.get(id, null)

## 从当前世界重建注册表（读档后调用）
func rebuild_from_world(world: Node) -> void:
	humans.clear(); buildings.clear(); cities.clear(); countries.clear(); armies.clear()
	var society = world.get("society") if world else null
	if society and society.get("population") and society.population.residents != null:
		for n in society.population.residents:
			register_human(n)
	var city_mgr = world.get("city_mgr") if world else null
	if city_mgr and city_mgr.has_method("get_all_cities"):
		for c in city_mgr.get_all_cities():
			register_city(c)
	var cm = world.get("country_mgr") if world else null
	if cm and cm.has_method("eden_country"):
		var ec = cm.eden_country()
		if ec: register_country(ec)
	var army_mgr = world.get("army_mgr") if world else null
	if army_mgr and army_mgr.get("armies") != null:
		for a in army_mgr.armies.values():
			register_army(a)

func stats() -> Dictionary:
	return {"humans": humans.size(), "buildings": buildings.size(),
		"cities": cities.size(), "countries": countries.size(), "armies": armies.size()}

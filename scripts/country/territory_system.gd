extends Node
class_name TerritorySystem
## 0.18 领土系统：国家领土来自真实城市影响范围（网格化区域），不随机画圈。
## 地图标签：TAB → WORLD 显示 ASCII 世界地图。

var cells: Dictionary = {}   # region_id -> {x, z, radius, city_id, owner}

func bind(w: Node) -> void:
	world = w

var world: Node = null

## 建国时按城市影响范围认领领土（城市等级越高影响越大）
func claim_cells(w, country, city_mgr) -> void:
	world = w
	if city_mgr == null: return
	var region_counter: int = 0
	for city_id in country.city_ids:
		var city = city_mgr.get_city(city_id)
		if city == null: continue
		var radius: int = 12 + city.level * 8
		var center: Vector3 = city.center
		for gx in range(-radius, radius + 1, 4):
			for gz in range(-radius, radius + 1, 4):
				if gx * gx + gz * gz > radius * radius: continue
				var rx: float = center.x + gx
				var rz: float = center.z + gz
				var rid: String = "r%d_%d" % [int(rx), int(rz)]
				if cells.has(rid): continue
				region_counter += 1
				cells[rid] = {
					"x": rx, "z": rz, "radius": 4.0,
					"city_id": city_id, "owner": country.id,
				}
				country.territory_cells.append(rid)

## 每年领土随城市扩张增长（城市升级 → 影响范围扩大）
func yearly_grow(w, country) -> void:
	world = w
	var city_mgr = world.get("city_mgr") if world else null
	if city_mgr == null: return
	var before: int = country.territory_cells.size()
	for city_id in country.city_ids:
		var city = city_mgr.get_city(city_id)
		if city == null: continue
		var radius: int = 12 + city.level * 8
		var center: Vector3 = city.center
		for gx in range(-radius, radius + 1, 4):
			for gz in range(-radius, radius + 1, 4):
				if gx * gx + gz * gz > radius * radius: continue
				var rx: float = center.x + gx
				var rz: float = center.z + gz
				var rid: String = "r%d_%d" % [int(rx), int(rz)]
				if cells.has(rid): continue
				cells[rid] = {"x": rx, "z": rz, "radius": 4.0, "city_id": city_id, "owner": country.id}
				country.territory_cells.append(rid)
	if country.territory_cells.size() > before:
		country.record("第%d年 领土扩张至 %d 个区域" % [_year(), country.territory_cells.size()])

## ASCII 世界地图（TAB → WORLD）
func world_map_text(country, city_mgr) -> String:
	var lines: Array = []
	var size := 21
	for iz in range(size, -1, -1):
		var row: Array = []
		for ix in range(0, size + 1):
			var wx: float = (ix - size / 2.0) * 4.0
			var wz: float = (iz - size / 2.0) * 4.0
			var rid: String = "r%d_%d" % [int(wx), int(wz)]
			var ch: String = "░"
			if cells.has(rid) and cells[rid].owner == country.id:
				ch = "█"
			if city_mgr:
				for city in city_mgr.get_all_cities():
					if abs(city.center.x - wx) < 3.0 and abs(city.center.z - wz) < 3.0:
						ch = "🏠" if city.civilization_id == "Eden" else "◈"
			row.append(ch)
		lines.append("".join(row))
	return "\n".join(lines)

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

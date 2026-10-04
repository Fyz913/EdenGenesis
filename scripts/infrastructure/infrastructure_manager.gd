extends Node
class_name InfrastructureManager
## 0.19 基建总管：连接城市（道路/桥梁/铁路/港口）、月度升级、视觉段生成。
## 铁律：不新建地图/城市/经济系统，全部基于 city_mgr 真实城市与坐标。

const RoadSystemScript: Script = preload("res://scripts/infrastructure/road_system.gd")
const RailwayScript: Script = preload("res://scripts/infrastructure/railway_system.gd")
const PortScript: Script = preload("res://scripts/infrastructure/port_system.gd")
const BridgeScript: Script = preload("res://scripts/infrastructure/bridge_system.gd")
const UpgradeScript: Script = preload("res://scripts/infrastructure/infrastructure_upgrade.gd")

var world: Node = null
var road_sys: Node
var railway: Node
var port_sys: Node
var bridge: Node
var upgrade: Node
var visual_root: Node3D = null

func bind(w: Node) -> void:
	world = w
	road_sys = RoadSystemScript.new(); add_child(road_sys)
	railway = RailwayScript.new(); add_child(railway)
	port_sys = PortScript.new(); add_child(port_sys)
	bridge = BridgeScript.new(); add_child(bridge)
	upgrade = UpgradeScript.new(); add_child(upgrade)

func eden_country():
	var cm = world.get("country_mgr") if world else null
	return cm.eden_country() if cm else null

func current_era() -> String:
	var tm = world.get("tech_mgr") if world else null
	return tm.current_era if tm else "原始时代"

# ---------------- 连接城市（建国后一次性规划） ----------------
func plan_network(country) -> void:
	var city_mgr = world.get("city_mgr")
	if city_mgr == null: return
	var cities: Array = city_mgr.get_all_cities()
	if cities.size() < 2: return
	var year: int = _year()
	# 城市两两连线（真实距离）
	for i in range(cities.size()):
		for j in range(i + 1, cities.size()):
			var a = cities[i]
			var b = cities[j]
			if a.civilization_id != "Eden" or b.civilization_id != "Eden": continue
			var dist: float = a.center.distance_to(b.center)
			# 跨河需先建桥
			if bridge.needs_bridge(a.center, b.center) and not bridge.has_bridge(a.id, b.id):
				bridge.build_bridge(a.id, b.id, dist, year)
			road_sys.build_road(a.id, b.id, dist, current_era(), year)
	# 港口：满足条件城市（沿海 + 城镇）
	for city in cities:
		if port_sys.can_build_port(city):
			port_sys.build_port(city.id, year)
	spawn_road_visual(world)   # 3D 世界可见的城市间道路
	_record("[基建]", "国家道路网络建成（%d 条道路 / %d 桥 / %d 港）" % [
		road_sys.roads.size(), bridge.bridges.size(), port_sys.ports.size()])

# ---------------- 月度：维护 + 财政基建支出 ----------------
func monthly_tick() -> void:
	var country = eden_country()
	if country == null: return
	if road_sys.roads.is_empty() and country:
		plan_network(country)
	var civ = world.get("civ")
	var gov = civ.get("government") if civ else null
	# 基建维护费（真实财政支出）
	var maintain: float = road_sys.roads.size() * 5.0 + bridge.bridges.size() * 10.0 + port_sys.ports.size() * 15.0
	if gov and gov.treasury >= maintain:
		gov.treasury -= maintain
		country.expenses += maintain
	# 道路随战争受损自动修复（和平月）
	if not _at_war():
		road_sys.repair_roads()

func _at_war() -> bool:
	var wm = world.get("war_mgr") if world else null
	if wm == null: return false
	for w in wm.wars:
		if w.active: return true
	return false

# ---------------- 年度：铁路/港口扩建 + 道路升级 ----------------
func yearly_tick() -> void:
	var country = eden_country()
	if country == null: return
	var civ = world.get("civ")
	var gov = civ.get("government") if civ else null
	var city_mgr = world.get("city_mgr")
	var era: String = current_era()
	var year: int = _year()
	# 铁路：工业时代 + 工程知识 + 已联网（≥1 条路即两城互联）
	if railway.can_build(world, era) and road_sys.roads.size() >= 1:
		var built_any: bool = false
		for r in road_sys.roads:
			if not railway.has_rail(r.from_city, r.to_city):
				railway.build_railway(r.from_city, r.to_city, r.length, year)
				built_any = true
		if built_any:
			country.record("第%d年 铁路网建成：%d 条线路贯通（工业运输时代）" % [year, railway.railways.size()])
			_hist("[基建]", "Eden 建成铁路网，贸易与迁移大幅提速")
	# 港口扩建（满足条件城市自动建港）
	var port_added: bool = false
	if city_mgr:
		for city in city_mgr.get_all_cities():
			if city.civilization_id != "Eden": continue
			if port_sys.can_build_port(city) and not _city_has_port(city.id):
				port_sys.build_port(city.id, year)
				port_added = true
	if port_added:
		_hist("[基建]", "Eden 新建港口，沿海贸易开启")
	# 道路升级（财政允许时：等级未达时代上限）
	var upgraded_any: bool = false
	for r in road_sys.roads:
		var cost: float = upgrade.road_upgrade_cost(r)
		if upgrade.upgrade_road(r, era, gov, cost):
			upgraded_any = true
	if upgraded_any:
		_hist("[基建]", "Eden 道路网升级（石路/公路）")

func _city_has_port(city_id: String) -> bool:
	for p in port_sys.ports:
		if p.city_id == city_id: return true
	return false

## 省道路加成（行政效率用）
func province_road_bonus(province) -> float:
	var bonus: float = 0.0
	var city_mgr = world.get("city_mgr") if world else null
	if city_mgr == null: return 0.0
	for city_id in province.city_ids:
		bonus += road_sys.network_bonus(city_id) * 0.5
	return clampf(bonus, 0.0, 20.0)

## 军队移动速度加成（0.14 战争连接：有路=行军快）
func army_speed_mult(city_id: String) -> float:
	return road_sys.army_speed_mult(city_id)

# ---------------- 视觉：城市间道路段（真实 Mesh，非 UI） ----------------
func spawn_road_visual(world) -> void:
	if visual_root != null: return
	visual_root = Node3D.new()
	visual_root.name = "InfraVisual"
	world.add_child(visual_root)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.42, 0.3)
	for r in road_sys.roads:
		var city_mgr = world.get("city_mgr")
		var a = city_mgr.get_city(r.from_city)
		var b = city_mgr.get_city(r.to_city)
		if a == null or b == null: continue
		_place_segments(a.center, b.center, 4.0, mat)

func _place_segments(from: Vector3, to: Vector3, seg: float, mat) -> void:
	var dist: float = from.distance_to(to)
	var n: int = maxi(1, int(dist / seg))
	for i in range(n):
		var t: float = (float(i) + 0.5) / float(n)
		var pos: Vector3 = from.lerp(to, t)
		pos.y = 0.12
		var m = MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		var box: BoxMesh = m.mesh
		box.size = Vector3(3.0, 0.2, 0.4)
		m.material_override = mat
		m.position = pos
		# 朝向：沿连线旋转
		var dir: Vector3 = (to - from).normalized()
		m.rotation.y = atan2(dir.x, dir.z)
		visual_root.add_child(m)

# ---------------- 面板 ----------------
func panel_data(country) -> Dictionary:
	return {
		"roads": _road_list(country),
		"railways": _rail_list(country),
		"ports": _port_list(country),
		"bridges": _bridge_list(country),
		"road_map": road_sys.road_map_text(world.get("city_mgr")) if world else "（无）",
		"port_text": port_sys.port_text(world.get("city_mgr")) if world else "（无）",
		"bridge_text": bridge.bridge_text(world.get("city_mgr")) if world else "（无）",
		"era": current_era(),
	}

func _road_list(country) -> Array:
	var out: Array = []
	var city_mgr = world.get("city_mgr") if world else null
	for r in road_sys.roads:
		var a = city_mgr.get_city(r.from_city) if city_mgr else null
		var b = city_mgr.get_city(r.to_city) if city_mgr else null
		out.append({"from": a.city_name if a else r.from_city, "to": b.city_name if b else r.to_city,
			"type": r.type_name, "level": r.level, "quality": r.quality})
	return out

func _rail_list(country) -> Array:
	var out: Array = []
	var city_mgr = world.get("city_mgr") if world else null
	for r in railway.railways:
		var a = city_mgr.get_city(r.from_city) if city_mgr else null
		var b = city_mgr.get_city(r.to_city) if city_mgr else null
		out.append({"from": a.city_name if a else r.from_city, "to": b.city_name if b else r.to_city})
	return out

func _port_list(country) -> Array:
	var out: Array = []
	var city_mgr = world.get("city_mgr") if world else null
	for p in port_sys.ports:
		var c = city_mgr.get_city(p.city_id) if city_mgr else null
		out.append({"city": c.city_name if c else p.city_id, "capacity": p.capacity})
	return out

func _bridge_list(country) -> Array:
	var out: Array = []
	var city_mgr = world.get("city_mgr") if world else null
	for br in bridge.bridges:
		var a = city_mgr.get_city(br.city_a) if city_mgr else null
		var b = city_mgr.get_city(br.city_b) if city_mgr else null
		out.append({"from": a.city_name if a else br.city_a, "to": b.city_name if b else br.city_b})
	return out

func _record(kind: String, text: String) -> void:
	_hist(kind, text)

func _hist(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(), kind, text])

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

extends Node
const FactoryScript: Script = preload("res://scripts/visual/building_factory.gd")

func expand(city, world, new_level: int) -> void:
	if city == null or world == null: return
	var settlement = world.get("settlement")
	var building_root = world.get("building_root")
	if settlement == null or building_root == null: return
	# 聚落现有建筑层级（1→2→3），增量补建
	if new_level >= 2 and settlement.level < 2:
		settlement.upgrade_to(2)
	if new_level >= 3 and settlement.level < 3:
		settlement.upgrade_to(3)
	# 城市层建筑：从当前等级逐级补到目标等级（避免跳级漏建中间层级建筑）
	for lv in range(2, new_level + 1):
		match lv:
			2: _expand_lv2(city, world, settlement, building_root)
			3: _expand_lv3(city, world, settlement, building_root)
			4: _expand_lv4(city, world, settlement, building_root)
			5: _expand_lv5(city, world, settlement, building_root)
	# 道路网连接真实建筑
	var roads = world.get("city_roads")
	if roads and roads.has_method("connect_city"):
		roads.connect_city(world)
	# 城区地面标注
	var dm = world.get("district_mgr")
	if dm and dm.has_method("apply_visual"):
		dm.apply_visual(world)
# ---------- 0.17 时代建筑：文明时代升级时的增量视觉（石屋/工厂/铁轨/高塔/路灯/星港信标） ----------
func add_era_buildings(kind: String, count: int) -> void:
	var world = get_node_or_null("/root/Main/World") as Node
	if world == null: return
	var settlement = world.get("settlement")
	var building_root = world.get("building_root")
	if settlement == null or building_root == null: return
	var center: Vector3 = settlement.get("center_pos") if settlement.get("center_pos") != null else Vector3(0, 0, 0)
	match kind:
		"stone":
			for i in range(count):
				var pos: Vector3 = _ring_pos(center, i, 22.0, 7.0)
				_add_stone_house(pos, building_root)
		"factory":
			for i in range(count):
				var pos: Vector3 = _ring_pos(center, i, 26.0, 10.0)
				_add_factory(pos, building_root)
		"rail":
			_add_rail(center, building_root)
		"tower":
			for i in range(count):
				var pos: Vector3 = _ring_pos(center, i, 30.0, 12.0)
				_add_tower(pos, building_root)
		"lamp":
			for i in range(count):
				var pos: Vector3 = _ring_pos(center, i, 18.0, 5.0)
				_add_lamp(pos, building_root)
		"beacon":
			_add_beacon(center, building_root)

func _ring_pos(center: Vector3, idx: int, radius: float, step: float) -> Vector3:
	var angle: float = idx * 0.9
	var r: float = radius + (idx % 3) * step
	return center + Vector3(cos(angle) * r, 0, sin(angle) * r)

func _add_stone_house(pos: Vector3, root: Node) -> void:
	FactoryScript.make_house(root, pos, 3)

func _add_factory(pos: Vector3, root: Node) -> void:
	_box(root, Vector3(4.0, 3.0, 4.0), pos + Vector3(0, 1.5, 0), Color(0.4, 0.38, 0.35))
	var chimney := MeshInstance3D.new()
	chimney.mesh = CylinderMesh.new(); chimney.mesh.top_radius = 0.3; chimney.mesh.bottom_radius = 0.4; chimney.mesh.height = 4.0
	chimney.position = pos + Vector3(1.2, 4.0, 0)
	var cmat := StandardMaterial3D.new(); cmat.albedo_color = Color(0.3, 0.28, 0.26)
	chimney.material_override = cmat
	root.add_child(chimney)
	var flame := MeshInstance3D.new()
	flame.mesh = SphereMesh.new(); flame.mesh.radius = 0.35; flame.mesh.height = 0.7
	flame.position = pos + Vector3(1.2, 2.2, 0)
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.9, 0.45, 0.1); fmat.emission_enabled = true; fmat.emission = Color(0.9, 0.45, 0.1)
	flame.material_override = fmat
	root.add_child(flame)

func _add_rail(center: Vector3, root: Node) -> void:
	for i in range(12):
		var pos: Vector3 = center + Vector3(-30.0 + i * 5.0, 0.06, 40.0)
		_box(root, Vector3(4.5, 0.12, 0.8), pos, Color(0.22, 0.2, 0.18))

func _add_tower(pos: Vector3, root: Node) -> void:
	var tower := MeshInstance3D.new()
	tower.mesh = CylinderMesh.new(); tower.mesh.top_radius = 0.5; tower.mesh.bottom_radius = 0.7; tower.mesh.height = 8.0
	tower.position = pos + Vector3(0, 4.0, 0)
	var tmat := StandardMaterial3D.new(); tmat.albedo_color = Color(0.55, 0.6, 0.65)
	tower.material_override = tmat
	root.add_child(tower)
	var light := MeshInstance3D.new()
	light.mesh = SphereMesh.new(); light.mesh.radius = 0.3; light.mesh.height = 0.6
	light.position = pos + Vector3(0, 8.4, 0)
	var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color(1.0, 0.85, 0.4); lmat.emission_enabled = true; lmat.emission = Color(1.0, 0.85, 0.4)
	light.material_override = lmat
	root.add_child(light)

func _add_lamp(pos: Vector3, root: Node) -> void:
	var pole := MeshInstance3D.new()
	pole.mesh = CylinderMesh.new(); pole.mesh.top_radius = 0.08; pole.mesh.bottom_radius = 0.1; pole.mesh.height = 2.6
	pole.position = pos + Vector3(0, 1.3, 0)
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(0.3, 0.3, 0.32)
	pole.material_override = pmat
	root.add_child(pole)
	var lamp := MeshInstance3D.new()
	lamp.mesh = SphereMesh.new(); lamp.mesh.radius = 0.18; lamp.mesh.height = 0.36
	lamp.position = pos + Vector3(0, 2.7, 0)
	var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color(1.0, 0.9, 0.5); lmat.emission_enabled = true; lmat.emission = Color(1.0, 0.9, 0.5)
	lamp.material_override = lmat
	root.add_child(lamp)

func _add_beacon(center: Vector3, root: Node) -> void:
	var pos: Vector3 = center + Vector3(0, 0, 44.0)
	var beacon := MeshInstance3D.new()
	beacon.mesh = CylinderMesh.new(); beacon.mesh.top_radius = 0.8; beacon.mesh.bottom_radius = 1.4; beacon.mesh.height = 14.0
	beacon.position = pos + Vector3(0, 7.0, 0)
	var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(0.75, 0.8, 0.9)
	beacon.material_override = bmat
	root.add_child(beacon)
	var core := MeshInstance3D.new()
	core.mesh = SphereMesh.new(); core.mesh.radius = 1.0; core.mesh.height = 2.0
	core.position = pos + Vector3(0, 15.0, 0)
	var cmat := StandardMaterial3D.new(); cmat.albedo_color = Color(0.5, 0.8, 1.0); cmat.emission_enabled = true; cmat.emission = Color(0.3, 0.6, 1.0)
	core.material_override = cmat
	root.add_child(core)

# ---------- Lv2 聚落：市场扩大 + 仓库 + 农田 + 学校 ----------
func _expand_lv2(city, world, settlement, building_root) -> void:
	var market_pos: Vector3 = settlement.districts.market
	for i in range(2):
		_add_stall(market_pos + Vector3(3 + i * 2.0, 0, -1), building_root, city)
	_add_warehouse(Vector3(10, 0, 6), building_root, city)
	_add_farm_plot(Vector3(10, 0, 18), settlement, city)
	# 0.16 学校（教育区，议事厅西侧）
	var civic_pos: Vector3 = settlement.districts.civic
	_add_school(civic_pos + Vector3(-8, 0, 2), building_root, city)
	city.commercial_buildings += 2
	city.public_buildings += 1   # 学校
	city.schools += 1
	print("[City] Lv2 聚落扩张：市场 + 摊位 x2、仓库、农田、学校")

# ---------- Lv3 城镇：商业街 + 工坊 + 粮仓 + 诊所/守卫站 ----------
func _expand_lv3(city, world, settlement, building_root) -> void:
	var market_pos: Vector3 = settlement.districts.market
	# 商业街：4 间店铺沿市场南侧
	for i in range(4):
		_add_shop(market_pos + Vector3(-6 + i * 3.2, 0, 4), building_root, city)
	# 工坊（工业区扩充）
	var ind_pos: Vector3 = settlement.districts.industrial
	_add_workshop(ind_pos + Vector3(5, 0, 2), building_root, city)
	# 粮仓（公共建筑）
	var civic_pos: Vector3 = settlement.districts.civic
	_add_granary(civic_pos + Vector3(6, 0, 0), building_root, city)
	# 0.16 诊所（市场东侧）+ 守卫站（城镇入口）
	_add_clinic(market_pos + Vector3(8, 0, 8), building_root, city)
	_add_guard_post(civic_pos + Vector3(0, 0, -10), building_root, city)
	city.commercial_buildings += 4
	city.industrial_buildings += 1
	city.public_buildings += 3   # 粮仓 + 诊所 + 守卫站
	city.clinics += 1
	city.guard_posts += 1
	print("[City] Lv3 城镇扩张：商业街 x4、工坊、粮仓、诊所、守卫站")

# ---------- Lv4 城市：市政厅 + 商业/工业/住宅区 + 医院/警察局 ----------
func _expand_lv4(city, world, settlement, building_root) -> void:
	var civic_pos: Vector3 = settlement.districts.civic
	_add_town_hall(civic_pos + Vector3(0, 0, 6), building_root, city)
	# 商业区扩展（市场西侧）
	var market_pos: Vector3 = settlement.districts.market
	for i in range(4):
		_add_shop(market_pos + Vector3(-8 + i * 3.0, 0, 7), building_root, city)
	# 工业区扩展
	var ind_pos: Vector3 = settlement.districts.industrial
	for i in range(2):
		_add_workshop(ind_pos + Vector3(-3 + i * 4.0, 0, 6), building_root, city)
	# 0.16 医院（市场南）+ 警察局（广场侧）
	_add_hospital(market_pos + Vector3(6, 0, -10), building_root, city)
	_add_police_station(civic_pos + Vector3(-10, 0, 0), building_root, city)
	# 住宅区扩展（南扩新一批房屋，沿既有巷道）
	var st = settlement
	if st.has_method("spawn_extra_house"):
		for i in range(8):
			var col: int = i % 3
			var row: int = i / 3
			var pos: Vector3 = Vector3(-8.0 - col * 6.0, 0, 18.0 + row * 6.0)
			st.spawn_extra_house(pos)
	city.commercial_buildings += 4
	city.industrial_buildings += 2
	city.public_buildings += 3   # 市政厅 + 医院 + 警察局
	city.hospitals += 1
	city.police_stations += 1
	print("[City] Lv4 城市扩张：市政厅、商业区、工业区、住宅区、医院、警察局")

# ---------- Lv5 大型城市：城墙 + 更多道路与住宅 ----------
func _expand_lv5(city, world, settlement, building_root) -> void:
	_add_walls(settlement, building_root, city)
	if settlement.has_method("spawn_extra_house"):
		for i in range(12):
			var col: int = i % 4
			var row: int = i / 4
			var pos: Vector3 = Vector3(-10.0 - col * 6.0, 0, 24.0 + row * 6.0)
			settlement.spawn_extra_house(pos)
	print("[City] Lv5 大型城市扩张：城墙、新区住宅")

# ---------- 建筑样式（与现有箱子风格一致） ----------
func _box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new(); m.mesh.size = size
	m.position = pos
	var mat := StandardMaterial3D.new(); mat.albedo_color = color
	m.material_override = mat
	parent.add_child(m)

func _add_stall(pos: Vector3, root: Node, city) -> void:
	var cloths := [Color(0.85, 0.5, 0.25), Color(0.55, 0.7, 0.35), Color(0.5, 0.55, 0.8), Color(0.8, 0.4, 0.4)]
	FactoryScript.make_stall(root, pos, cloths[city.buildings.size() % cloths.size()])
	city.buildings.append({"type": "stall", "pos": pos, "health": 100.0})

func _add_warehouse(pos: Vector3, root: Node, city) -> void:
	FactoryScript.make_warehouse(root, pos)
	city.buildings.append({"type": "warehouse", "pos": pos, "health": 100.0})

func _add_farm_plot(pos: Vector3, settlement, city) -> void:
	for i in range(4):
		for j in range(3):
			var crop := MeshInstance3D.new()
			crop.mesh = BoxMesh.new(); crop.mesh.size = Vector3(0.4, 0.5, 0.4)
			crop.position = pos + Vector3(i * 0.8, 0.3, j * 0.8)
			var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.3, 0.7, 0.25)
			crop.material_override = mat
			var terrain_root = settlement.get("terrain_root")
			(terrain_root if terrain_root else settlement).add_child(crop)
	city.buildings.append({"type": "farm", "pos": pos, "health": 100.0})

func _add_shop(pos: Vector3, root: Node, city) -> void:
	# 店铺：墙 + 顶 + 招牌色带
	_box(root, Vector3(2.4, 2.0, 2.4), pos + Vector3(0, 1.0, 0), Color(0.72, 0.62, 0.45))
	_box(root, Vector3(2.8, 0.2, 2.8), pos + Vector3(0, 2.1, 0), Color(0.45, 0.25, 0.15))
	_box(root, Vector3(1.6, 0.3, 0.1), pos + Vector3(0, 1.6, 1.25), Color(0.85, 0.6, 0.2))
	city.buildings.append({"type": "shop", "pos": pos, "health": 100.0})

func _add_workshop(pos: Vector3, root: Node, city) -> void:
	_box(root, Vector3(2.6, 1.8, 2.6), pos + Vector3(0, 0.9, 0), Color(0.5, 0.45, 0.4))
	_box(root, Vector3(3.0, 0.18, 3.0), pos + Vector3(0, 1.9, 0), Color(0.3, 0.25, 0.2))
	# 炉口红光
	_box(root, Vector3(0.5, 0.5, 0.2), pos + Vector3(0, 0.6, 1.3), Color(0.95, 0.3, 0.05))
	city.buildings.append({"type": "workshop", "pos": pos, "health": 100.0})

func _add_granary(pos: Vector3, root: Node, city) -> void:
	_box(root, Vector3(3.4, 2.4, 3.4), pos + Vector3(0, 1.2, 0), Color(0.78, 0.62, 0.3))
	_box(root, Vector3(3.8, 0.2, 3.8), pos + Vector3(0, 2.5, 0), Color(0.5, 0.35, 0.15))
	city.buildings.append({"type": "granary", "pos": pos, "health": 100.0})

func _add_town_hall(pos: Vector3, root: Node, city) -> void:
	FactoryScript.make_townhall(root, pos)
	city.buildings.append({"type": "townhall", "pos": pos, "health": 100.0})

# ---------- 0.16 社会设施 ----------
func _add_school(pos: Vector3, root: Node, city) -> void:
	# 学校：两间教室 + 屋顶 + 旗杆
	_box(root, Vector3(4.0, 2.2, 3.0), pos + Vector3(0, 1.1, 0), Color(0.8, 0.72, 0.55))
	_box(root, Vector3(4.5, 0.18, 3.5), pos + Vector3(0, 2.3, 0), Color(0.4, 0.28, 0.18))
	var flag := MeshInstance3D.new()
	flag.mesh = CylinderMesh.new(); flag.mesh.top_radius = 0.05; flag.mesh.bottom_radius = 0.05; flag.mesh.height = 3.2
	flag.position = pos + Vector3(0, 1.6, 0)
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.7, 0.7, 0.7)
	flag.material_override = fm
	root.add_child(flag)
	city.buildings.append({"type": "school", "pos": pos, "health": 100.0})

func _add_clinic(pos: Vector3, root: Node, city) -> void:
	# 诊所：白墙 + 红十字
	_box(root, Vector3(2.8, 1.8, 2.8), pos + Vector3(0, 0.9, 0), Color(0.92, 0.92, 0.9))
	_box(root, Vector3(3.2, 0.18, 3.2), pos + Vector3(0, 1.9, 0), Color(0.75, 0.75, 0.75))
	_box(root, Vector3(0.7, 0.7, 0.12), pos + Vector3(0, 1.5, 1.45), Color(0.85, 0.1, 0.1))
	_box(root, Vector3(0.12, 0.7, 0.7), pos + Vector3(0, 1.5, 1.45), Color(0.85, 0.1, 0.1))
	city.buildings.append({"type": "clinic", "pos": pos, "health": 100.0})

func _add_hospital(pos: Vector3, root: Node, city) -> void:
	# 医院：大型白建筑 + 双红十字 + 门
	_box(root, Vector3(6.0, 3.0, 4.5), pos + Vector3(0, 1.5, 0), Color(0.95, 0.95, 0.93))
	_box(root, Vector3(6.5, 0.2, 5.0), pos + Vector3(0, 3.1, 0), Color(0.8, 0.8, 0.8))
	_box(root, Vector3(1.2, 1.2, 0.15), pos + Vector3(-1.2, 2.0, 2.3), Color(0.85, 0.1, 0.1))
	_box(root, Vector3(0.15, 1.2, 1.2), pos + Vector3(-1.2, 2.0, 2.3), Color(0.85, 0.1, 0.1))
	_box(root, Vector3(1.2, 1.2, 0.15), pos + Vector3(1.6, 2.0, 2.3), Color(0.85, 0.1, 0.1))
	_box(root, Vector3(0.15, 1.2, 1.2), pos + Vector3(1.6, 2.0, 2.3), Color(0.85, 0.1, 0.1))
	_box(root, Vector3(1.4, 2.0, 0.2), pos + Vector3(0, 1.0, 2.3), Color(0.3, 0.3, 0.35))
	city.buildings.append({"type": "hospital", "pos": pos, "health": 100.0})

func _add_guard_post(pos: Vector3, root: Node, city) -> void:
	# 守卫站：小塔（底座 + 柱 + 顶）
	_box(root, Vector3(1.6, 0.4, 1.6), pos + Vector3(0, 0.2, 0), Color(0.6, 0.58, 0.55))
	_box(root, Vector3(1.2, 2.0, 1.2), pos + Vector3(0, 1.4, 0), Color(0.55, 0.5, 0.45))
	_box(root, Vector3(1.9, 0.3, 1.9), pos + Vector3(0, 2.55, 0), Color(0.35, 0.32, 0.3))
	city.buildings.append({"type": "guard_post", "pos": pos, "health": 100.0})

func _add_police_station(pos: Vector3, root: Node, city) -> void:
	# 警察局：蓝顶白墙
	_box(root, Vector3(5.0, 2.4, 3.8), pos + Vector3(0, 1.2, 0), Color(0.9, 0.9, 0.88))
	_box(root, Vector3(5.6, 0.25, 4.4), pos + Vector3(0, 2.55, 0), Color(0.2, 0.3, 0.6))
	_box(root, Vector3(1.6, 2.0, 0.2), pos + Vector3(0, 1.0, 1.9), Color(0.25, 0.3, 0.5))
	city.buildings.append({"type": "police_station", "pos": pos, "health": 100.0})

func _add_walls(settlement, root: Node, city) -> void:
	# 城墙：围绕城市四边的矮墙段
	var pts := [
		Vector3(-26, 0, -14), Vector3(18, 0, -14),
		Vector3(18, 0, -14),  Vector3(18, 0, 26),
		Vector3(18, 0, 26),   Vector3(-26, 0, 26),
		Vector3(-26, 0, 26),  Vector3(-26, 0, -14),
	]
	for i in range(0, pts.size(), 2):
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var mid: Vector3 = (a + b) * 0.5
		var len: float = Vector2(b.x - a.x, b.z - a.z).length()
		var wall := MeshInstance3D.new()
		wall.mesh = BoxMesh.new(); wall.mesh.size = Vector3(0.8, 2.4, len)
		wall.position = Vector3(mid.x, 1.2, mid.z)
		wall.rotation.y = atan2(b.x - a.x, b.z - a.z)
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.55, 0.52, 0.48)
		wall.material_override = mat
		root.add_child(wall)
	city.buildings.append({"type": "wall", "pos": Vector3(0, 0, 6), "health": 100.0})

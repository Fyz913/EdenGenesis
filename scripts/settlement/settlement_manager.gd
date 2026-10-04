extends Node
## 聚落生成器：紧凑村庄网格 + 道路网 + 住宅绑定
## 层级：区域地面/道路 -> terrain_root；建筑 -> building_root（由 world 注入）
## 住宅统一 4×2.8×4，间距 6，门朝东(+X)，居民出生在门前（不会卡进墙）。

const HouseScene: PackedScene = preload("res://scenes/house.tscn")
const BlacksmithScene: PackedScene = preload("res://scenes/blacksmith.tscn")
const RoadScript: Script = preload("res://scripts/building/road_generator.gd")
const FactoryScript: Script = preload("res://scripts/visual/building_factory.gd")

var terrain_root: Node = null
var building_root: Node = null
var roads: Node3D

var districts: Dictionary = {
	"industrial":  Vector3(12, 0, -2),
	"farm":        Vector3(14, 0, 14),
	"market":      Vector3(0, 0, 14),
	"civic":       Vector3(0, 0, -8),
	"river":       Vector3(0, 0, -15),
	"plaza":       Vector3(0, 0, 0),
}

# 住宅网格：3 列 × 5 行 = 15 栋，门朝 +X
const HOUSE_COLS := [-8.0, -14.0, -20.0]
const HOUSE_ROWS := [-9.0, -3.0, 3.0, 9.0, 15.0]
const DOOR_OFFSET := Vector3(3.0, 0, 0)   # 门在 +X 面，门外出生点
const HOUSE_YAW := PI / 2.0

var home_slots: Array = []   # [{center, door, owner}]
var level: int = 1
var buildings: Array = []
var _townhall_built: bool = false

func _terrain() -> Node:
	return terrain_root if terrain_root else get_parent()

func _buildroot() -> Node:
	return building_root if building_root else get_parent()

func _ready() -> void:
	roads = RoadScript.new()
	_terrain().add_child(roads)
	_layout_zones()
	_build_road_network()
	_build_for_level(2)

# ---------- 区域地面 ----------
func _layout_zones() -> void:
	_add_plane(districts.plaza, Vector2(7, 7), Color(0.72, 0.66, 0.5))
	_add_plane(districts.industrial, Vector2(7, 7), Color(0.5, 0.45, 0.4))
	_add_plane(districts.farm, Vector2(9, 7), Color(0.5, 0.4, 0.2))
	_add_plane(districts.market, Vector2(8, 4), Color(0.55, 0.45, 0.55))

func _add_plane(pos: Vector3, size: Vector2, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = PlaneMesh.new(); mi.mesh.size = size
	mi.position = pos
	var mat := StandardMaterial3D.new(); mat.albedo_color = color
	mi.material_override = mat
	_terrain().add_child(mi)

# ---------- 道路网 ----------
func _build_road_network() -> void:
	roads.create_patch(districts.plaza, 7.0)
	# 南北主干道：广场 x=0 到市场 z=14
	roads.create_path(Vector3(0, 0, 3), Vector3(0, 0, 14))
	# 广场到工坊
	roads.create_path(Vector3(3, 0, 0), Vector3(11, 0, -2))
	# 广场到农田
	roads.create_path(Vector3(3, 0, 2), Vector3(13, 0, 13))
	# 住宅南北脊柱 x=-3
	roads.create_path(Vector3(-3, 0, -12), Vector3(-3, 0, 17))
	# 广场连脊柱
	roads.create_path(Vector3(-3, 0, 0), Vector3(-1, 0, 0))
	# 每排住宅的东西巷道
	for z in HOUSE_ROWS:
		roads.create_path(Vector3(-22, 0, z), Vector3(-3, 0, z))

# ---------- 等级建造 ----------
func _build_for_level(lv: int) -> void:
	level = lv
	for i in range(1, lv + 1):
		match i:
			1: _build_lv1()
			2: _build_lv2()
			3: _build_lv3()

func _all_house_centers() -> Array:
	var pts: Array = []
	for z in HOUSE_ROWS:
		for x in HOUSE_COLS:
			pts.append(Vector3(x, 0, z))
	return pts

func _build_lv1() -> void:
	var centers := _all_house_centers()
	for i in range(5):
		_spawn_house(centers[i])
	_spawn_campfire(Vector3(-3, 0, 3))
	for i in range(2):
		_add_farm_plot(Vector3(11 + i*1.4, 0, 12))

func _build_lv2() -> void:
	var centers := _all_house_centers()
	for i in range(5, centers.size()):
		_spawn_house(centers[i])
	_add_flag(districts.plaza + Vector3(2.5, 0, -2.5))
	# 铁匠铺（0.19.1 精致版）
	var bs: Node = FactoryScript.make_blacksmith(_buildroot(), districts.industrial)
	buildings.append({"node": bs, "type": "blacksmith", "pos": districts.industrial, "health": 100.0})
	# 仓库
	_add_warehouse(Vector3(8, 0, 4))
	# 市场摊位
	for i in range(3):
		_add_stall(Vector3(-2 + i*2, 0, 14))
	# 扩大农田
	for i in range(3):
		_add_farm_plot(Vector3(12 + i*1.4, 0, 15))

func _build_lv3() -> void:
	add_townhall(districts.civic)

# ---------- 建筑 ----------
func _spawn_house(center: Vector3) -> void:
	# 0.19.1 精致房屋（视觉工厂，带碰撞；门朝 +Z 旋转到 +X）
	var h: Node = FactoryScript.make_house(_buildroot(), center, _tier_for_level(level))
	h.rotation.y = HOUSE_YAW
	var door: Vector3 = center + DOOR_OFFSET
	home_slots.append({"center": center, "door": door, "owner": ""})
	buildings.append({"node": h, "type": "house", "pos": center, "health": 100.0})

func _add_flag(pos: Vector3) -> void:
	# 旗杆
	var pole := MeshInstance3D.new()
	pole.mesh = BoxMesh.new(); pole.mesh.size = Vector3(0.12, 4.0, 0.12)
	pole.position = pos + Vector3(0, 2.0, 0)
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(0.4, 0.3, 0.2)
	pole.material_override = pmat
	_buildroot().add_child(pole)
	# 旗帜
	var cloth := MeshInstance3D.new()
	cloth.mesh = BoxMesh.new(); cloth.mesh.size = Vector3(1.2, 0.7, 0.05)
	cloth.position = pos + Vector3(0.65, 3.4, 0)
	var cmat := StandardMaterial3D.new(); cmat.albedo_color = Color(0.8, 0.2, 0.2)
	cmat.emission_enabled = true; cmat.emission = Color(0.3, 0.05, 0.05)
	cloth.material_override = cmat
	_buildroot().add_child(cloth)

func _add_warehouse(pos: Vector3) -> void:
	FactoryScript.make_warehouse(_buildroot(), pos)

func _spawn_campfire(pos: Vector3) -> void:
	FactoryScript.make_campfire(_buildroot(), pos)

func _add_farm_plot(pos: Vector3) -> void:
	FactoryScript.make_farm_plot(_terrain(), pos)

func _add_stall(pos: Vector3) -> void:
	var cloths := [Color(0.85, 0.5, 0.25), Color(0.55, 0.7, 0.35), Color(0.5, 0.55, 0.8)]
	FactoryScript.make_stall(_buildroot(), pos, cloths[home_slots.size() % cloths.size()])

## 议事厅（村社/城镇制度升级的视觉标志）：0.19.1 精致版（石基柱廊三角山墙）+ 门前双旗
## 仅建一次（Lv3 与政治升级共用）
func add_townhall(district: Vector3) -> void:
	if _townhall_built: return
	_townhall_built = true
	var pos: Vector3 = district + Vector3(0, 0, 2)
	FactoryScript.make_townhall(_buildroot(), pos)
	# 门前双旗
	_add_flag(pos + Vector3(-2.4, 0, 2.6))
	_add_flag(pos + Vector3(2.4, 0, 2.6))
	print("[Settlement] 议事厅建成于：", pos)

# ---------- 时代视觉分级 ----------
func _tier_for_level(lv: int) -> int:
	return 3 if lv >= 3 else (2 if lv >= 2 else 1)

# ---------- 住宅分配 ----------
func capacity() -> int:
	return home_slots.size()

## 保证住房数 >= 人口，不足则沿南侧逐行新建并铺路
func ensure_housing(pop_count: int) -> void:
	while home_slots.size() < pop_count:
		var idx: int = home_slots.size()
		var col: int = idx % HOUSE_COLS.size()
		var row: int = idx / HOUSE_COLS.size()
		var z: float = -9.0 + row * 6.0
		var x: float = HOUSE_COLS[col]
		_spawn_house(Vector3(x, 0, z))
		# 新一排补一条东西巷道连到脊柱
		roads.create_path(Vector3(-22, 0, z), Vector3(-3, 0, z))
		print("[Settlement] 人口增长，新建住宅 #", home_slots.size())

func get_home_for(index: int) -> Vector3:
	if home_slots.is_empty(): return Vector3(-8, 0, 0)
	return home_slots[index % home_slots.size()].door

func bind_owner(index: int, npc_name: String) -> void:
	if index >= 0 and index < home_slots.size():
		home_slots[index].owner = npc_name

func get_work_for(job: String) -> Vector3:
	match job:
		"铁匠": return districts.industrial + Vector3(1, 0, 1)
		"农夫", "农民": return districts.farm + Vector3(randf_range(-2,2), 0, randf_range(-2,2))
		"渔夫": return districts.river + Vector3(randf_range(-3,3), 0, 0)
		"商人": return districts.market + Vector3(randf_range(-2,2), 0, 0)
		"面包师", "织布工": return districts.market + Vector3(randf_range(-2,2), 0, 1)
	return districts.plaza

func get_food_position() -> Vector3:
	return districts.market

# ---------- 升级 ----------
## 聚落自动升级：人口 + 粮食储备 + 住房 同时满足
func upgrade_to(new_level: int) -> void:
	if new_level <= level: return
	while level < new_level:
		level += 1
		match level:
			2: _build_lv2()
			3: _build_lv3()
	print("[Settlement] 升级到 Lv", level)

## 城市扩张专用：在指定位置盖一栋房并铺路（0.15，只增不删）
func spawn_extra_house(pos: Vector3) -> void:
	_spawn_house(pos)
	roads.create_path(Vector3(pos.x + 8.0, 0, pos.z), Vector3(-3, 0, pos.z))

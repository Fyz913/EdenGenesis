extends Node
## 城区管理器（0.15）：城区数据 + 城区地面视觉标注（进 Terrain 层，纯增量）
## 城区类型：residential / commercial / industrial / agricultural / government / military

const DistrictScript: Script = preload("res://scripts/city/district.gd")

var districts: Dictionary = {}   # id -> District
var counter: int = 0
var _visual_built: bool = false

const TYPE_COLORS := {
	"residential": Color(0.62, 0.55, 0.4),
	"commercial": Color(0.55, 0.45, 0.6),
	"industrial": Color(0.5, 0.48, 0.45),
	"agricultural": Color(0.55, 0.6, 0.35),
	"government": Color(0.45, 0.55, 0.65),
	"military": Color(0.6, 0.45, 0.4),
}

func create_district(city_id: String, district_type: String, position: Vector3, radius: float = 15.0):
	counter += 1
	var district = DistrictScript.new()
	district.id = "district_%d" % counter
	district.city_id = city_id
	district.district_type = district_type
	district.center = position
	district.radius = radius
	districts[district.id] = district
	return district

func get_districts_for_city(city_id: String) -> Array:
	var out: Array = []
	for d in districts.values():
		if d.city_id == city_id:
			out.append(d)
	return out

func count_by_type(city_id: String, d_type: String) -> int:
	var n: int = 0
	for d in districts.values():
		if d.city_id == city_id and d.district_type == d_type:
			n += 1
	return n

## 在城市中心周围画出城区地面色块（只建一次，纯增量）
func apply_visual(world) -> void:
	if _visual_built: return
	_visual_built = true
	var terrain_root = world.get("terrain_root")
	if terrain_root == null: return
	var center: Vector3 = Vector3.ZERO
	var layout := [
		["residential", Vector3(-11, 0, 3), Vector2(16, 20)],
		["commercial",  Vector3(0, 0, 14),  Vector2(10, 8)],
		["industrial",  Vector3(12, 0, -2), Vector2(12, 8)],
		["agricultural", Vector3(14, 0, 16), Vector2(14, 10)],
		["government",  Vector3(0, 0, -8),  Vector2(12, 8)],
		["military",    Vector3(6, 0, -8),  Vector2(8, 8)],
	]
	for item in layout:
		var m := MeshInstance3D.new()
		m.mesh = PlaneMesh.new(); m.mesh.size = item[2]
		m.position = center + item[1] + Vector3(0, 0.02, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TYPE_COLORS.get(item[0], Color.WHITE)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.35
		m.material_override = mat
		terrain_root.add_child(m)
	print("[District] 城区地面标注完成")

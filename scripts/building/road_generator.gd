extends Node3D
## 道路生成器：在两点之间铺一条窄土路（贴地）
## 所有道路进 Terrain 层，宽度统一，避免大块色面。

var road_width: float = 1.6
var road_mat: StandardMaterial3D

func _ready() -> void:
	road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.62, 0.52, 0.36, 1)
	road_mat.roughness = 1.0

## 在 from->to 之间铺一段路
func create_path(from: Vector3, to: Vector3) -> void:
	var dir: Vector3 = to - from
	var length: float = Vector2(dir.x, dir.z).length()
	if length < 0.3: return
	var seg := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(road_width, 0.04, length)
	seg.mesh = box
	seg.material_override = road_mat
	seg.position = Vector3((from.x + to.x) / 2.0, 0.06, (from.z + to.z) / 2.0)
	# local +Z 对齐到水平方向
	seg.rotation.y = atan2(dir.x, dir.z)
	add_child(seg)

## 铺设一小块广场/路口
func create_patch(center: Vector3, size: float) -> void:
	var p := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	p.mesh = plane
	p.position = Vector3(center.x, 0.05, center.z)
	p.material_override = road_mat
	add_child(p)

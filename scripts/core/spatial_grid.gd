extends Node
class_name SpatialGrid
## 0.19.6 空间网格：O(1) 附近查询，替代"每帧对所有 NPC 算距离"。
## Cell 50m；查询只访问目标 Cell 相邻 3×3。

var cell_size: float = 50.0
var cells: Dictionary = {}   # key: Vector2i -> Array

func get_cell(position: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(position.x / cell_size)),
		int(floor(position.z / cell_size))
	)

func add_object(object, position: Vector3) -> void:
	var cell: Vector2i = get_cell(position)
	if not cells.has(cell):
		cells[cell] = []
	if not cells[cell].has(object):
		cells[cell].append(object)

func remove_object(object, position: Vector3) -> void:
	var cell: Vector2i = get_cell(position)
	if cells.has(cell):
		cells[cell].erase(object)

func get_nearby(position: Vector3, radius_cells: int = 1) -> Array:
	var center: Vector2i = get_cell(position)
	var result: Array = []
	for x in range(center.x - radius_cells, center.x + radius_cells + 1):
		for z in range(center.y - radius_cells, center.y + radius_cells + 1):
			var cell: Vector2i = Vector2i(x, z)
			if cells.has(cell):
				result.append_array(cells[cell])
	return result

## 从对象列表重建索引（O(N)），供周期性刷新
func rebuild(objects: Array) -> void:
	cells.clear()
	for o in objects:
		if is_instance_valid(o):
			add_object(o, o.global_position)

func count() -> int:
	var n: int = 0
	for k in cells:
		n += cells[k].size()
	return n

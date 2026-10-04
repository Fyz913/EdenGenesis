extends Node
## 市场货架动态化（0.14.5）：把 economy.market.stock 映射到市场摊位上的商品堆
## 库存越多 → 商品堆越高；卖光 → 货架空。经济循环直接"看得见"。
## 纯新增视觉，不修改任何现有系统。

var _stalls: Dictionary = {}   # item -> 商品堆的 MeshInstance3D 数组
var _tick: float = 0.0

const ITEM_COLORS := {
	"food": Color(0.9, 0.75, 0.3),
	"wood": Color(0.55, 0.35, 0.15),
	"stone": Color(0.5, 0.5, 0.52),
	"iron": Color(0.6, 0.62, 0.7),
	"cloth": Color(0.85, 0.8, 0.9),
}
const ITEMS := ["food", "wood", "stone", "iron", "cloth"]

func setup(market_pos: Vector3, building_root: Node) -> void:
	# 在 market 区右侧摆 5 个货台，每个商品一格
	for i in ITEMS.size():
		var item: String = ITEMS[i]
		var pos: Vector3 = market_pos + Vector3(2.6, 0.02, -2.0 + i * 1.5)
		# 货台
		var stall := MeshInstance3D.new()
		stall.mesh = BoxMesh.new(); stall.mesh.size = Vector3(1.1, 0.6, 1.1)
		stall.position = pos + Vector3(0, 0.3, 0)
		var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.6, 0.5, 0.35)
		stall.material_override = sm
		building_root.add_child(stall)
		# 商品堆：最多 5 个小方块，初始隐藏
		var pile: Array = []
		for k in 5:
			var cube := MeshInstance3D.new()
			cube.mesh = BoxMesh.new(); cube.mesh.size = Vector3(0.4, 0.35, 0.4)
			cube.position = pos + Vector3(0, 0.75 + k * 0.38, 0)
			var cm := StandardMaterial3D.new()
			cm.albedo_color = ITEM_COLORS.get(item, Color.WHITE)
			cube.material_override = cm
			cube.visible = false
			building_root.add_child(cube)
			pile.append(cube)
		_stalls[item] = {"pile": pile, "pos": pos}

## 每 ~0.5 秒刷新一次商品堆数量（按市场库存比例 0-5）
func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5: return
	_tick = 0.0
	var world = get_node_or_null("/root/Main/World")
	if world == null: return
	var economy = world.get("economy")
	if economy == null or economy.get("market") == null: return
	var stock: Dictionary = economy.market.stock
	for item in ITEMS:
		var data = _stalls.get(item)
		if data == null: continue
		var qty: float = stock.get(item, 0.0)
		var shown: int = mini(5, int(round(qty / 20.0)))
		var pile: Array = data["pile"]
		for k in pile.size():
			pile[k].visible = k < shown

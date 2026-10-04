extends Node
class_name WorldStreamingManager
## 0.19.6 世界流式管理：Region 状态机 + 分帧加载预算。
## 原则：Simulation 决定世界发生什么，Rendering 决定玩家看到什么。
## 世界当前只有 Eden 一村（500×500），全部区域默认 ACTIVE；
## 本管理器提供状态机与分帧接口，为未来大世界铺路，不删除任何模拟数据。

const MAX_LOAD_PER_FRAME: int = 20   # 每帧最多加载的视觉对象数
const RegionScript = preload("res://scripts/world/simulation_region.gd")

var regions: Dictionary = {}   # id -> SimulationRegion
var _pending_load: int = 0
var _load_counter: int = 0     # 本帧已加载数
var active_region_id: String = ""

func _process(_delta: float) -> void:
	_load_counter = 0

## 创建 3×3 区域网格（世界 500×500，中心为 Eden 村）
func create_world_regions(world_size: float = 500.0) -> void:
	var n: int = 3
	var cell: float = world_size / float(n)
	var names: Array = [
		["西北", "北", "东北"],
		["西", "中心", "东"],
		["西南", "南", "东南"],
	]
	for i in range(n):
		for j in range(n):
			var r := RegionScript.new()
			r.id = "region_%d_%d" % [i, j]
			r.name = "Eden-" + names[i][j]
			r.center = Vector3(
				(i - 1.0) * cell, 0.0, (j - 1.0) * cell
			)
			r.state = RegionScript.State.SIMULATION
			r.active = false
			r.loaded = false
			regions[r.id] = r
	set_active("region_1_1")

func set_active(region_id: String) -> void:
	if not regions.has(region_id): return
	active_region_id = region_id
	for id in regions:
		var r = regions[id]
		if id == region_id:
			r.state = RegionScript.State.ACTIVE
			r.active = true
			r.loaded = true
		else:
			r.state = RegionScript.State.SIMULATION
			r.active = false
			r.loaded = true   # 数据常驻，视觉可卸载

## 请求加载：进入预算队列（分帧执行）
func request_load(count: int) -> void:
	_pending_load += count

## 每帧消费加载预算：返回本帧实际加载数
func consume_load_budget() -> int:
	var allowed: int = MAX_LOAD_PER_FRAME - _load_counter
	if allowed <= 0: return 0
	var take: int = mini(_pending_load, allowed)
	_pending_load -= take
	_load_counter += take
	return take

func stats() -> Dictionary:
	var loaded: int = 0
	var active: int = 0
	for r in regions.values():
		if r.loaded: loaded += 1
		if r.active: active += 1
	return {"loaded": loaded, "active": active}

extends Node
## 0.19.5 SimulationScheduler：分层模拟时钟 + 性能统计中枢。
## 原则：Scheduler 只"通知 Manager"，不直接操作 NPC/经济/战争。
## 分层：Frame=视觉 / 1秒=NPC行为 / 10秒=局部AI / 60秒=城市局部 / 1天=经济物流人口
## 更长的 周/月/年 由 game_director 的 day_count 分桶处理（本调度器不重复触发）。

signal perf_updated(stats: Dictionary)

# 分桶计时器
var _s: float = 0.0
var _10s: float = 0.0
var _60s: float = 0.0
var _day: float = 0.0

# ---- 每秒性能统计 ----
var perf: Dictionary = {
	"fps": 0.0, "frame_ms": 0.0,
	"humans_total": 0, "humans_active": 0, "humans_sim": 0, "humans_data": 0,
	"buildings_total": 0, "buildings_active": 0,
	"regions_loaded": 0, "regions_active": 0,
	"ai_ticks": 0, "pathfinds": 0, "nav_ticks": 0,
	"ai_ms": 0.0, "economy_ms": 0.0, "nav_ms": 0.0, "ui_ms": 0.0,
	"nodes": 0, "draw_calls": 0,
	"history_total": 0, "memory_total": 0,
}
var _ai_counter: int = 0
var _path_counter: int = 0
var _nav_counter: int = 0
var _economy_ms_acc: float = 0.0
var _ui_ms_acc: float = 0.0
var _fps_frames: int = 0
var _fps_time: float = 0.0

func _process(delta: float) -> void:
	# 0.19.7：每帧从模拟队列消费至多 MAX_SIM_PER_FRAME 个（LOD2 数据层状态推进）
	var world := get_node_or_null("/root/Main/World")
	if world:
		var simq = world.get_node_or_null("SimQueue")
		if simq and simq.has_method("process_batch"):
			simq.process_batch(MAX_SIM_PER_FRAME)
	__orig_process(delta)

const MAX_SIM_PER_FRAME: int = 30

func second_tick() -> void:
	pass

func ten_second_tick() -> void:
	## 0.19.7：把居民整体放入模拟队列（Data 层轻量模拟，分批消费，不每帧全量）
	var world := get_node_or_null("/root/Main/World")
	if world == null: return
	var simq = world.get_node_or_null("SimQueue")
	if simq == null or not simq.has_method("clear"): return
	simq.clear()
	var society = world.get("society")
	if society and society.get("population") and society.population.residents != null:
		for n in society.population.residents:
			if is_instance_valid(n):
				simq.add(n)

func __orig_process(delta: float) -> void:
	var scaled: float = delta
	_s += scaled; _10s += scaled; _60s += scaled; _day += scaled
	if _s >= 1.0:
		_s -= 1.0
		second_tick()
	if _10s >= 10.0:
		_10s -= 10.0
		ten_second_tick()
	if _60s >= 60.0:
		_60s -= 60.0
		minute_tick()
	# 帧率统计（1 秒窗口）
	_fps_frames += 1
	_fps_time += scaled
	if _fps_time >= 1.0:
		perf["fps"] = float(_fps_frames) / _fps_time
		perf["frame_ms"] = 1000.0 * _fps_time / float(_fps_frames)
		_fps_frames = 0; _fps_time = 0.0
		perf["ai_ticks"] = _ai_counter
		perf["pathfinds"] = _path_counter
		perf["nav_ticks"] = _nav_counter
		perf["economy_ms"] = _economy_ms_acc
		perf["ui_ms"] = _ui_ms_acc
		_ai_counter = 0; _path_counter = 0; _nav_counter = 0
		_economy_ms_acc = 0.0; _ui_ms_acc = 0.0
		_collect_world_stats()
		perf_updated.emit(perf)

func minute_tick() -> void:
	pass

# ---- 供外部上报的计数 ----
func note_ai_tick() -> void:
	_ai_counter += 1

func note_pathfind() -> void:
	_path_counter += 1

func note_nav() -> void:
	_nav_counter += 1

func note_economy_ms(ms: float) -> void:
	_economy_ms_acc += ms

func note_ui_ms(ms: float) -> void:
	_ui_ms_acc += ms

# ---- 每秒汇总世界规模 ----
func _collect_world_stats() -> void:
	var world := get_node_or_null("/root/Main/World")
	if world == null: return
	perf["humans_total"] = 0
	perf["humans_active"] = 0
	perf["humans_sim"] = 0
	perf["humans_data"] = 0
	var society = world.get("society")
	if society and society.get("population") and society.population.residents != null:
		var list: Array = society.population.residents
		var player = get_node_or_null("/root/Main/Player")
		var lod_mgr = world.get_node_or_null("NpcLod")
		if lod_mgr and lod_mgr.has_method("stats"):
			var st: Dictionary = lod_mgr.stats(list, player)
			perf["humans_total"] = st["total"]
			perf["humans_active"] = st["active"]
			perf["humans_sim"] = st["sim"]
			perf["humans_data"] = st["data"]
	# 建筑
	perf["buildings_total"] = 0
	perf["buildings_active"] = 0
	if world.get("building_root"):
		perf["buildings_total"] = world.building_root.get_child_count()
		perf["buildings_active"] = world.building_root.get_child_count()
	# 区域
	perf["regions_loaded"] = 0
	perf["regions_active"] = 0
	var stream = world.get_node_or_null("Streaming")
	if stream and stream.has_method("stats"):
		var rs: Dictionary = stream.stats()
		perf["regions_loaded"] = rs["loaded"]
		perf["regions_active"] = rs["active"]
	# 节点数
	perf["nodes"] = world.get_tree().get_node_count()
	# 历史/记忆总量
	perf["history_total"] = 0
	perf["memory_total"] = 0
	var civ = world.get("civ")
	if civ and civ.get("history"):
		perf["history_total"] = civ.history.events.size()
	# 0.20 经济统计
	perf["gdp"] = 0.0; perf["companies"] = 0; perf["factories"] = 0; perf["trade_volume"] = 0.0
	var econ_sim = world.get("econ_sim")
	if econ_sim and econ_sim.has_method("stats"):
		var est: Dictionary = econ_sim.stats(world, world.get("city_mgr"), world.get("economy").market if world.get("economy") else null, world.society.population.residents if world.get("society") else [])
		perf["gdp"] = est.get("gdp", 0.0)
		perf["companies"] = est.get("companies", 0)
		perf["factories"] = est.get("factories", 0)
		perf["trade_volume"] = est.get("trade_volume", 0.0)
	if society:
		for npc in society.population.residents:
			if not is_instance_valid(npc): continue
			if npc.get("life_memory") and npc.life_memory.memories != null:
				perf["memory_total"] += npc.life_memory.memories.size()

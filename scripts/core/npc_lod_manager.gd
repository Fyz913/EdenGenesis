extends Node
class_name NPCLodManager
## 0.19.6 NPC LOD 分级：LOD0 Active / LOD1 Simulation / LOD2 Data。
## 只做分级与统计，不直接操作 NPC；NPC 在 _process 里读取 get_lod 决定自身行为强度。

const ACTIVE_DISTANCE: float = 100.0      # 玩家 100m 内：完整 3D
const SIMULATION_DISTANCE: float = 1000.0 # 100~1000m：简化模拟

func get_lod(distance: float) -> int:
	if distance <= ACTIVE_DISTANCE:
		return 0
	if distance <= SIMULATION_DISTANCE:
		return 1
	return 2

## 统计玩家周围 LOD 分布（供 PERFORMANCE 面板）
## 返回 {"total", "active", "sim", "data"}
func stats(residents: Array, player: Node3D) -> Dictionary:
	var out := {"total": 0, "active": 0, "sim": 0, "data": 0}
	out["total"] = residents.size()
	if player == null:
		out["sim"] = residents.size()
		return out
	for npc in residents:
		if not is_instance_valid(npc): continue
		var d: float = npc.position.distance_to(player.position)
		match get_lod(d):
			0: out["active"] += 1
			1: out["sim"] += 1
			_: out["data"] += 1
	return out

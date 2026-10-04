extends RefCounted
class_name SimulationRegion
## 0.19.6 模拟区域数据。Region = 一块可独立加载/卸载的世界分区。
## 状态：UNLOADED → LOADING → ACTIVE → SIMULATION → UNLOADING → UNLOADED

enum State { UNLOADED, LOADING, ACTIVE, SIMULATION, UNLOADING }

var id: String = ""
var name: String = ""
var center: Vector3 = Vector3.ZERO
var radius: float = 500.0
var state: State = State.UNLOADED
var active: bool = false
var loaded: bool = false

var city_ids: Array = []
var population: int = 0
var food: float = 0.0
var wealth: float = 0.0
var buildings: int = 0

func state_text() -> String:
	match state:
		State.UNLOADED: return "UNLOADED"
		State.LOADING: return "LOADING"
		State.ACTIVE: return "ACTIVE"
		State.SIMULATION: return "SIMULATION"
		State.UNLOADING: return "UNLOADING"
	return "?"

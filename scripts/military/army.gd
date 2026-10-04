extends RefCounted
class_name EdenArmy
## 军队数据：数量、士气、战力、粮草、装备、驻地、激活状态
## 军队必须受人口约束（max = 人口*0.15），不能凭空出现

var id: String = ""
var civilization_id: String = ""
var soldiers: int = 0
var morale: float = 100.0
var strength: float = 0.0
var food_supply: float = 0.0
var equipment: float = 0.5        # 0~1 装备水平
var location: Vector3 = Vector3.ZERO
var active: bool = false
var speed_mult: float = 1.0   # 0.19 基础设施：道路/铁路影响军队行军速度
var soldier_refs: Array = []      # 参战居民引用（与 0.11 生命系统连接）

func max_soldiers(population: int) -> int:
	return maxi(1, int(population * 0.15))

func recompute_strength() -> void:
	# 战力 = 数量 * 装备 + 士气加成（简化模型）
	strength = soldiers * (0.6 + equipment * 0.8) * (morale / 100.0)

func casualties(n: int) -> void:
	soldiers = maxi(0, soldiers - n)
	recompute_strength()

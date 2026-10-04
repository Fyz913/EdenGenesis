extends Node
class_name CultureSystem
## 0.16 文化系统：传统/节日/价值观；丰收节一年一次（Autumn）
## 节日影响：全体幸福 +5、社会凝聚力 +3；消耗食物（进入真实市场账本）
## 文化传播：外交友好文明的价值观随贸易/交流逐渐融合（每年）

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 每年结算
func yearly_tick(residents: Array, city) -> Dictionary:
	var out: Dictionary = {}
	out["festival"] = _try_festival(residents, city)
	out["spread"] = _culture_spread()
	return out

## 丰收节（秋季，一年一次）：消耗食物、全体幸福提升
func _try_festival(residents: Array, city) -> bool:
	var eco = world.get("ecosystem") if world else null
	if eco == null: return false
	var season: String = eco.season_sys.season if eco.get("season_sys") else "Spring"
	if season != "Autumn": return false
	var culture: Node = _culture()
	if culture == null: return false
	culture.add_festival("丰收节", "Autumn")
	culture.add_tradition("秋收感恩")
	var econ = world.get("economy") if world else null
	var cost: float = residents.size() * 0.5
	if econ and econ.market.stock.get("food", 0.0) >= cost:
		econ.market.stock["food"] -= cost
		for n in residents:
			if n.get("needs"):
				n.needs.happiness = min(100.0, n.needs.happiness + 5.0)
		_record("文化", "Eden 举办丰收节，全村共享秋收的喜悦（消耗食物 %d）" % int(cost))
		return true
	_record("文化", "粮食不足，今年的丰收节从简举行")
	return false

## 文化传播：与友好文明（外交关系 > 40）吸收价值观（每年概率）
func _culture_spread() -> bool:
	var civ = world.get("civ") if world else null
	if civ == null: return false
	var diplo = world.get("diplomacy") if world else null
	if diplo == null: return false
	var culture: Node = _culture()
	if culture == null: return false
	var changed: bool = false
	for key in diplo.relations:
		var rel_obj = diplo.relations[key]
		var rel: float = rel_obj.value if rel_obj else 0.0
		if rel >= 40.0 and randf() < 0.25:
			var peer: String = key.replace("eden_", "").replace("_eden", "")
			if peer != "" and not culture.has_value(peer + "之风"):
				culture.create_value(peer + "之风")
				culture.add_tradition("与" + peer + "交流互鉴")
				_record("文化", "Eden 吸收了" + peer + "的文化元素")
				changed = true
	return changed

func _culture():
	var civ = world.get("civ") if world else null
	return civ.get("culture") if civ else null

func _record(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	var yr: int = 1
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"): yr = eco.season_sys.year
	if hist: hist.record("第%d年[%s] %s" % [yr, kind, text])

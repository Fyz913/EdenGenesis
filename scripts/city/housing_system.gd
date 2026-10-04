extends Node
## 住房系统（0.15）：按建筑类型计算住房容量；判断是否缺房。

const HOUSE_CAPACITY := {
	"house": 4,
	"large_house": 8,
	"apartment": 20,
}

## 统计建筑列表的住房总容量
func calculate_capacity(buildings: Array) -> int:
	var cap: int = 0
	for b in buildings:
		if typeof(b) != TYPE_DICTIONARY: continue
		var t: String = b.get("type", "")
		cap += HOUSE_CAPACITY.get(t, 0)
	return cap

## 是否缺房：人口达到理论容纳的 85% 即触发需求
func needs_more_housing(city, population: int) -> bool:
	var cap: int = city.housing_capacity
	if cap <= 0: return true
	return float(population) >= float(cap) * 0.85

extends Node
## 社会阶层：按居民当前财富动态划分，并统计贫富差距
## 不做永久标签，每次结算都按近期财富重新计算。

func class_of(money: float) -> String:
	if money < 20.0: return "贫困"
	elif money < 100.0: return "普通"
	elif money < 300.0: return "富裕"
	return "富裕阶层"

## 返回 {平均, 中位, 最低, 最高, 各阶层人数}
func wealth_stats(residents: Array) -> Dictionary:
	var wealth: Array = []
	var counts := {"贫困": 0, "普通": 0, "富裕": 0, "富裕阶层": 0}
	for n in residents:
		var m: float = n.get("money") if n.get("money") != null else 0.0
		wealth.append(m)
		counts[class_of(m)] += 1
	if wealth.is_empty():
		return {"avg": 0.0, "median": 0.0, "min": 0.0, "max": 0.0, "counts": counts}
	wealth.sort()
	var total: float = 0.0
	for v in wealth: total += v
	var mid: int = wealth.size() / 2
	var median: float = wealth[mid] if wealth.size() % 2 == 1 else (wealth[mid - 1] + wealth[mid]) / 2.0
	return {
		"avg": total / wealth.size(),
		"median": median,
		"min": wealth[0],
		"max": wealth[wealth.size() - 1],
		"counts": counts,
	}

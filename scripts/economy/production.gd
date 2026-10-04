extends Node
## 职业 -> 资源产出

func work(job: String) -> Dictionary:
	match job:
		"农民": return {"food": 10.0}
		"农夫": return {"food": 10.0}
		"伐木工": return {"wood": 8.0}
		"矿工": return {"stone": 5.0}
		"铁匠": return {"iron": 3.0}
		"渔夫": return {"food": 6.0}
		"织布工": return {"cloth": 4.0}
		"面包师": return {"food": 4.0}
		"商人": return {"cloth": 3.0}  # 商人组织交易品（布/杂货），供外贸出口
	return {}

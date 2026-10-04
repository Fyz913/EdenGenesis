extends RefCounted
class_name EdenPolicy
## 政策：一组真实影响经济的参数
## 森林保护 → 木材出口减半（价格上行）；粮食储备 → 保障口粮优先；
## 税率 → 财政来源但伤幸福；外贸税 → 出口收入进国库

var data: Dictionary = {
	"forest_protection": false,  # 木材稀缺化：出口配额减半
	"food_reserve": 30.0,        # 粮食目标储备：低于此则优先保口粮（禁出口粮 + 促进口）
	"trade_tax": 0.05,           # 外贸出口税率（进国库）
	"tax_rate": 0.05,            # 居民收入税率
}

func get_val(key: String, default = null):
	return data.get(key, default)

func set_policy(key: String, value) -> void:
	data[key] = value
	print("[Policy] 政策变更：", key, " = ", value)

func summary() -> Array:
	var list: Array = []
	if data["forest_protection"]: list.append("森林保护")
	list.append("粮储" + str(int(data["food_reserve"])))
	list.append("税" + str(int(data["tax_rate"] * 100)) + "%")
	return list

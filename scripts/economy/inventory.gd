extends RefCounted
class_name EdenInventory
## 通用库存：居民 / 家庭 / 市场都用它，不允许库存为负

var items: Dictionary = {}

func add_item(item: String, amount: float) -> void:
	items[item] = items.get(item, 0.0) + amount

func remove_item(item: String, amount: float) -> bool:
	if items.get(item, 0.0) < amount:
		return false
	items[item] -= amount
	return true

func get_amount(item: String) -> float:
	return items.get(item, 0.0)

func to_dict() -> Dictionary:
	return items.duplicate()

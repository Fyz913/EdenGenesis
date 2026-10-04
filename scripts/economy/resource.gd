extends Node
## 资源库存

var resources: Dictionary = {
	"food": 500.0,
	"wood": 300.0,
	"stone": 200.0,
	"iron": 50.0,
}

func add(type: String, value: float) -> void:
	resources[type] = resources.get(type, 0.0) + value

func consume(type: String, value: float) -> void:
	resources[type] = max(0.0, resources.get(type, 0.0) - value)

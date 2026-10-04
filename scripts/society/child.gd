extends Node
class_name Child
## 孩子：有父母，会成长

var father: Node = null
var mother: Node = null
var age: float = 0.0

func setup(f: Node, m: Node) -> void:
	father = f
	mother = m

func grow(delta: float) -> void:
	age += delta

func is_adult() -> bool:
	return age >= 18.0

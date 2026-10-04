extends Node
class_name Settlement
## 聚落：村庄 -> 城镇 -> 城市

var settlement_name: String = "Eden村"
var population: int = 10
var level: int = 1

func grow(pop: int) -> void:
	population = pop
	if pop > 50 and level < 2:
		level = 2; settlement_name = "Eden城镇"
	elif pop > 500 and level < 3:
		level = 3; settlement_name = "Eden城市"

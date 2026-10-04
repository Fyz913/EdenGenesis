extends Node
class_name Civilization
## 文明核心

var civ_name: String = "Eden"
var population: int = 0
var technology_level: int = 1
var culture_level: int = 1
var age: int = 0

func update() -> void:
	age += 1
	check_growth()

func check_growth() -> void:
	if population > 100 and technology_level < 2:
		technology_level = 2
	if population > 500 and technology_level < 3:
		technology_level = 3

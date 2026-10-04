extends Node3D
## 动物系统：鹿、兔子在陆地漫游，鱼在河里

const AnimalScene: PackedScene = preload("res://scenes/animal.tscn")

var populations: Dictionary = {
	"鹿": 6,
	"兔子": 8,
	"鱼": 10,
}
var animals: Array = []

func _ready() -> void:
	_spawn_land_animal("鹿", Vector3(-20, 0, -20), 0.9, Color(0.55, 0.35, 0.2))
	_spawn_land_animal("鹿", Vector3(20, 0, -25), 0.9, Color(0.5, 0.32, 0.18))
	_spawn_land_animal("鹿", Vector3(-25, 0, 15), 0.9, Color(0.6, 0.4, 0.22))
	for i in range(8):
		var p := Vector3(randf_range(-30, 30), 0, randf_range(-30, 25))
		if abs(p.x) < 12 and abs(p.z) < 15: p.x += 20
		_spawn_land_animal("兔子", p, 0.4, Color(0.8, 0.75, 0.7))
	for i in range(10):
		_spawn_fish(Vector3(randf_range(-20, 20), -0.1, -15 + randf_range(-1.5, 1.5)))

func _spawn_land_animal(animal_name: String, pos: Vector3, scale: float, color: Color) -> void:
	var a := AnimalScene.instantiate()
	a.set("animal_name", animal_name)
	a.set("kind", "land")
	a.position = pos
	a.scale = Vector3.ONE * scale
	a.set("body_color", color)
	add_child(a)
	animals.append(a)

func _spawn_fish(pos: Vector3) -> void:
	var a := AnimalScene.instantiate()
	a.set("animal_name", "鱼")
	a.set("kind", "fish")
	a.position = pos
	a.scale = Vector3(0.3, 0.3, 0.3)
	a.set("body_color", Color(0.3, 0.5, 0.8))
	add_child(a)
	animals.append(a)

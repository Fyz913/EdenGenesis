extends Node
## NPC 需求：饥饿 / 精力 / 快乐

var hunger: float = 100.0
var energy: float = 100.0
var happiness: float = 70.0

func update(delta: float) -> void:
	hunger -= delta * 0.3
	energy -= delta * 0.1
	hunger = clamp(hunger, 0.0, 100.0)
	energy = clamp(energy, 0.0, 100.0)

func hungry() -> bool:
	return hunger < 30.0

func tired() -> bool:
	return energy < 20.0

func eat() -> void:
	hunger = 100.0

func sleep() -> void:
	energy = 100.0

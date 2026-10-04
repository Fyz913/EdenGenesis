extends Node
## NPC 记忆

var memories: Array = []

const MAX_MEM: int = 50

func add(text: String) -> void:
	memories.append(text)
	if memories.size() > MAX_MEM:
		memories.pop_front()

func remember() -> Array:
	return memories

func top(n: int = 3) -> Array:
	var start: int = max(0, memories.size() - n)
	return memories.slice(start, memories.size())

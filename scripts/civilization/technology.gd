extends Node
## 科技

var technologies: Array = []

func research(name: String) -> void:
	if not has(name):
		technologies.append(name)

func has(name: String) -> bool:
	return name in technologies

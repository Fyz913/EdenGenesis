extends Node
## 贸易（0.08 占位）

func trade(civ_a: String, civ_b: String, resource: String, amount: float) -> void:
	print("[Trade] ", civ_a, " -> ", civ_b, " ", resource, " x", amount)

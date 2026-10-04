extends Node
class_name BeliefSystem
## 0.17 价值观演化：文明在三轴（战争/贸易/知识）上形成倾向，
## 来自真实历史事件；倾向反过来影响政府决策偏好与外交基调。

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 每年：历史事件 → 信念漂移（缓慢、累计）
func yearly_tick(culture, history) -> void:
	if culture == null or history == null: return
	var combined: String = ""
	for ev in history.events:
		combined += " " + str(ev)
	if "战争" in combined:
		culture.adjust_belief("war", 2.0)
		culture.adjust_belief("trade", -0.5)
	if "贸易" in combined:
		culture.adjust_belief("trade", 1.5)
	if "发明" in combined or "技术" in combined or "历法" in combined:
		culture.adjust_belief("knowledge", 1.2)
	if "洪水" in combined or "灾害" in combined:
		culture.adjust_belief("knowledge", 0.8)   # 灾难促使求知

## 主流倾向（返回 key）
func dominant(culture) -> String:
	if culture == null: return "knowledge"
	var best: String = "knowledge"
	var best_v: float = -1.0
	for k in culture.beliefs:
		if culture.beliefs[k] > best_v:
			best_v = culture.beliefs[k]
			best = k
	return best

## 倾向 → 政策偏好（0.13 politics 读取）
func policy_preference(culture) -> Dictionary:
	var d: String = dominant(culture)
	var out := {"military_budget": 10.0, "trade_tax": 5.0, "education_funding": 5.0}
	if d == "war":
		out["military_budget"] = 30.0
	elif d == "trade":
		out["trade_tax"] = -5.0
		out["education_funding"] = 8.0
	else:
		out["education_funding"] = 25.0
	return out

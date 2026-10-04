extends Node
## 人格系统：每个居民有独立特质分数（0-100），影响决策与对话

var traits: Dictionary = {
	"勤劳": 50, "社交": 50, "勇敢": 50, "好奇": 50,
	"贪婪": 20, "懒惰": 10, "耐心": 50,
}
var archetype: String = "普通"

func _init(job: String = "", seed_variant: float = 0.0) -> void:
	_randomize_for_job(job, seed_variant)

func _randomize_for_job(job: String, v: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v * 100000.0) + job.hash()
	for k in traits:
		traits[k] = clampi(traits[k] + rng.randi_range(-25, 25), 0, 100)
	# 职业倾向
	match job:
		"铁匠":
			traits["勤劳"] = randi_range_clamped(70, 95); traits["耐心"] = randi_range_clamped(60, 90); archetype = "坚毅匠人"
		"农夫", "农民":
			traits["勤劳"] = randi_range_clamped(75, 98); traits["耐心"] = randi_range_clamped(65, 95); archetype = "勤劳耕者"
		"渔夫":
			traits["耐心"] = randi_range_clamped(75, 98); traits["社交"] = randi_range_clamped(20, 50); archetype = "沉稳渔人"
		"商人":
			traits["社交"] = randi_range_clamped(70, 95); traits["贪婪"] = randi_range_clamped(30, 70); traits["好奇"] = randi_range_clamped(60, 90); archetype = "精明商人"
		"面包师":
			traits["社交"] = randi_range_clamped(65, 90); traits["勤劳"] = randi_range_clamped(60, 85); archetype = "热情手艺人"
		"织布工":
			traits["耐心"] = randi_range_clamped(70, 95); traits["社交"] = randi_range_clamped(40, 70); archetype = "细腻织者"
		"孩子":
			traits["好奇"] = randi_range_clamped(75, 99); traits["懒惰"] = randi_range_clamped(30, 60); archetype = "天真孩童"
		_:
			archetype = "普通村民"

func randi_range_clamped(a: int, b: int) -> int:
	return clampi(randi_range(a, b), 0, 100)

## 从父母继承部分性格（孩子用）
func inherit_from(parent_a: Dictionary, parent_b: Dictionary) -> void:
	for k in traits:
		var avg: int = int((parent_a.get(k, 50) + parent_b.get(k, 50)) / 2.0)
		traits[k] = clampi(avg + randi_range(-15, 15), 0, 100)
	archetype = "家族血脉"

func dominant_trait() -> String:
	var best: String = "勤劳"
	var best_v: int = -1
	for k in traits:
		if traits[k] > best_v:
			best_v = traits[k]; best = k
	return best

func to_dict() -> Dictionary:
	return {"archetype": archetype, "traits": traits}

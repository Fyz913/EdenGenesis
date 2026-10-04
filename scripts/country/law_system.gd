extends Node
class_name LawSystem
## 0.18 法律系统：五类基础法律，效果真实挂钩（每年应用）。
## 不做"菜单开关"：贸易税法改贸易税倍率、劳动法改幸福与稳定、
## 军事法改征兵比例、财产税法启用财产税、税法设税率上限。

const LawScript: Script = preload("res://scripts/country/law.gd")

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 初始法律（国家建立时启用基础法）
func setup_defaults(country) -> void:
	if not country.laws.is_empty(): return
	country.laws = [
		LawScript.new("labor_law", "劳动法", "labor", true, {"happiness": 2.0, "stability": 1.0}),
		LawScript.new("tax_law", "税法", "tax", true, {"tax_cap": 0.25}),
		LawScript.new("property_law", "财产税法", "tax", false, {"property_mult": 0.5}),
		LawScript.new("trade_law", "贸易税法", "trade", false, {"trade_tax_mult": 0.5}),
		LawScript.new("military_law", "军事法", "military", false, {"soldier_ratio": 0.15}),
	]

func enact(country, law_id: String) -> void:
	for l in country.laws:
		if l.id == law_id and not l.enabled:
			l.enabled = true
			country.record("第%d年 颁布《%s》" % [_year(), l.name])
			_hist("[法律]", "颁布《" + l.name + "》")

func repeal(country, law_id: String) -> void:
	for l in country.laws:
		if l.id == law_id and l.enabled:
			l.enabled = false
			country.record("第%d年 废止《%s》" % [_year(), l.name])
			_hist("[法律]", "废止《" + l.name + "》")

## 每年应用法律效果（真实影响，记录变化）
func apply_effects(w, country, gov) -> void:
	world = w
	for l in country.laws:
		if not l.enabled: continue
		var ef: Dictionary = l.effects
		# 劳动法：全体幸福 +2，社会稳定 +1
		if ef.has("happiness"):
			var society = world.get("society") if world else null
			if society:
				for n in society.population.residents:
					if n.get("needs"):
						n.needs.happiness = min(100.0, n.needs.happiness + ef["happiness"])
			if gov: gov.legitimacy = min(100.0, gov.legitimacy + ef["happiness"] * 0.1)
		# 税法：税率上限（国家不得无限加税）
		if ef.has("tax_cap") and gov:
			if gov.tax_rate > ef["tax_cap"]:
				gov.tax_rate = ef["tax_cap"]
				_hist("[法律]", "税法生效：税率回落至上限 " + str(int(ef["tax_cap"] * 100)) + "%")
		# 贸易税法：贸易税倍率（供 tax_system 使用，经 country 记录）
		if ef.has("trade_tax_mult"):
			country.set_meta("trade_tax_mult", ef["trade_tax_mult"])
		# 军事法：征兵比例（供 army 上限使用）
		if ef.has("soldier_ratio"):
			country.set_meta("soldier_ratio", ef["soldier_ratio"])
		# 财产税法：财产税倍率
		if ef.has("property_mult"):
			country.set_meta("property_mult", ef["property_mult"])

## 查询生效法律倍率（默认值）
func mult(country, key: String, default_val: float) -> float:
	if country == null: return default_val
	return country.get_meta(key, default_val)

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

func _hist(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(), kind, text])

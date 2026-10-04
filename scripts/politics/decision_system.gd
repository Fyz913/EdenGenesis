extends Node
## 决策系统：发现问题 → 议事会提议 → 居民按职业偏好投票 → 政策执行
## 返回 {title, passed, desc}；无问题返回空字典

## 0.19.7：年内已裁决提案去重（否则每个政策每 4 天重复记录/重复投票）
var _decided: Dictionary = {}   # year -> [title]

func check_and_decide(world, gov, policy_sys, residents: Array) -> Dictionary:
	if gov == null or policy_sys == null: return {}
	var yr: int = _current_year(world)
	var econ = world.get("economy") if world else null
	# 问题1：粮食危机 → 提议增加储备
	if econ and econ.market.stock.get("food", 0.0) < residents.size() * 2.0 and policy_sys.get_val("food_reserve", 30.0) < 60.0:
		return _decide_or_skip(yr, _vote(residents, {
			"title": "增加粮食储备",
			"desc": "把粮食储备目标提高到 60，优先保障口粮",
			"key": "food_reserve", "value": 60.0,
			"favors": ["农民", "农夫", "渔夫", "面包师", "孩子"],
		}))
	# 问题2：财政紧张 → 提议加税
	if gov.treasury < 150.0 and gov.tax_rate < 0.10:
		return _decide_or_skip(yr, _vote(residents, {
			"title": "提高税率",
			"desc": "税率提高到 8%，充实村财政",
			"key": "tax_rate", "value": 0.08,
			"favors": ["铁匠", "织布工", "面包师"],
		}))
	# 问题3：贸易繁荣 + 森林健康 → 提议森林保护
	if econ and econ.market.cash > 1800.0 and not policy_sys.get_val("forest_protection", false):
		return _decide_or_skip(yr, _vote(residents, {
			"title": "森林保护",
			"desc": "限制木材出口，让森林休养生息",
			"key": "forest_protection", "value": true,
			"favors": ["农民", "农夫", "渔夫", "织布工"],
		}))
	return {}

func _current_year(world) -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

## 同一年同一提案只裁决一次（无论通过与否决）
func _decide_or_skip(yr: int, result: Dictionary) -> Dictionary:
	var title: String = str(result.get("title", ""))
	if not _decided.has(yr):
		_decided[yr] = []
	if _decided[yr].has(title):
		return {}
	_decided[yr].append(title)
	if _decided[yr].size() > 100:
		_decided[yr].pop_front()
	return result

## 按职业偏好投票（支持者=提案利好职业），简单多数通过
func _vote(residents: Array, proposal: Dictionary) -> Dictionary:
	var supporters: int = 0
	var opponents: int = 0
	for r in residents:
		var job: String = r.get("job") if r.get("job") != null else ""
		var a = r.get("age") if r.get("age") != null else 0
		if a < 18: continue
		if proposal["favors"].has(job): supporters += 1
		else: opponents += 1
	var passed: bool = supporters > opponents
	return {"title": proposal["title"], "passed": passed, "desc": proposal["desc"]}

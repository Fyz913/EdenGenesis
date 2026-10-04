extends Node
## 领袖系统：声望计算、领袖与议事会推举、动态支持率

## 声望：年龄 + 勤劳 + 社交（长者与勤劳者更有威望）
func prestige(npc) -> float:
	var age_v: float = npc.get("age") if npc.get("age") != null else 20.0
	var score: float = age_v * 0.4
	var ps = npc.get("personality_sys")
	if ps:
		score += ps.traits.get("勤劳", 50.0) * 0.3
		score += ps.traits.get("社交", 50.0) * 0.2
	return score

## 声望最高的成年居民（可指定数量）
func top_elders(residents: Array, n: int) -> Array:
	var adults: Array = []
	for r in residents:
		var a = r.get("age") if r.get("age") != null else 0
		if a >= 18: adults.append(r)
	adults.sort_custom(func(a, b): return prestige(a) > prestige(b))
	return adults.slice(0, mini(n, adults.size()))

func pick_leader(residents: Array):
	var elders := top_elders(residents, 1)
	return elders[0] if elders.size() > 0 else null

## 支持率：以平均幸福为基础，受粮食短缺与高税率惩罚
func approval(residents: Array, gov, last_fed_ratio: float) -> float:
	var base: float = 50.0
	var happy_sum: float = 0.0
	var cnt: int = 0
	for r in residents:
		var nd = r.get("needs")
		if nd:
			happy_sum += nd.happiness
			cnt += 1
	if cnt > 0: base = happy_sum / cnt
	if last_fed_ratio < 0.999:
		base -= (1.0 - last_fed_ratio) * 40.0
	if gov:
		var rate: float = gov.tax_rate if gov.get("tax_rate") != null else 0.05
		base -= max(0.0, rate - 0.05) * 300.0
	return clampf(base, 5.0, 100.0)

extends Node
class_name CountryManager
## 0.18 国家总管：国家形成（真实条件）、月度财政/政治结算、年度稳定/危机/继承。
## 国家是文明的上层协调层：读取 City/Human/Org/Government/Economy 真实数据，
## 不另起炉灶、不造假账；国家只通过 法律/税收/预算/行政/军事 影响居民。

const CountryScript: Script = preload("res://scripts/country/country.gd")
const BudgetScript: Script = preload("res://scripts/country/state_budget.gd")
const TaxScript: Script = preload("res://scripts/country/tax_system.gd")
const LawScript: Script = preload("res://scripts/country/law_system.gd")
const GovSystemScript: Script = preload("res://scripts/country/government_system.gd")
const PoliticalScript: Script = preload("res://scripts/country/political_system.gd")
const StatsScript: Script = preload("res://scripts/country/national_statistics.gd")
const TerritoryScript: Script = preload("res://scripts/country/territory_system.gd")
const PopulationScript: Script = preload("res://scripts/country/state_population.gd")

var world: Node = null
var countries: Dictionary = {}   # id -> Country
var budget: Node
var tax: Node
var law: Node
var gov_system: Node
var political: Node
var stats: Node
var territory: Node
var population_sys: Node

var _last_country_year: int = 0

func _ready() -> void:
	budget = BudgetScript.new(); add_child(budget)
	tax = TaxScript.new(); add_child(tax)
	law = LawScript.new(); add_child(law)
	gov_system = GovSystemScript.new(); add_child(gov_system)
	political = PoliticalScript.new(); add_child(political)
	stats = StatsScript.new(); add_child(stats)
	territory = TerritoryScript.new(); add_child(territory)
	population_sys = PopulationScript.new(); add_child(population_sys)

func bind(w: Node) -> void:
	world = w
	law.bind(w)
	political.bind(w)
	territory.bind(w)

func eden_country():
	return countries.get("eden", null)

# ---------------- 国家形成（真实条件，不按年份） ----------------
## 形成条件：≥2 个同文明城市、总人口≥300、存在政治组织、政府已建立、
## 城市同属 Eden 文明（文化同源 → 相似度成立）
func can_form_country() -> bool:
	if world == null: return false
	var city_mgr = world.get("city_mgr")
	if city_mgr == null: return false
	var cities: Array = city_mgr.get_all_cities() if city_mgr.has_method("get_all_cities") else []
	if cities.size() < 2: return false
	var total: int = 0
	for city in cities:
		if city.civilization_id != "Eden": return false
		total += city.population
	if total < 300: return false
	var org_mgr = world.get("org_mgr")
	if org_mgr == null or org_mgr.organizations.size() < 2: return false
	var civ = world.get("civ")
	if civ == null or civ.get("government") == null: return false
	return true

## 建国：首都=人口最多城市；领袖=政府现有领袖（真实居民）或声望最高者
func form_country():
	var city_mgr = world.get("city_mgr")
	var cities: Array = city_mgr.get_all_cities() if city_mgr else []
	var capital = cities[0]
	for city in cities:
		if city.population > capital.population:
			capital = city
	var country = CountryScript.new()
	country.id = "eden"
	country.name = "Eden王国"
	country.civilization_id = "Eden"
	country.capital_city_id = capital.id
	country.founded_year = _year()
	for city in cities:
		country.city_ids.append(city.id)
	# 领土：以城市影响范围认领（真实区域）
	territory.claim_cells(world, country, city_mgr)
	# 法律：建国启用基础法
	law.setup_defaults(country)
	# 领袖：政府现有领袖（0.13 推举的真实居民）
	var civ = world.get("civ")
	var gov = civ.get("government") if civ else null
	if gov == null or gov.leader_id == "":
		_ensure_leader(gov, country)
	country.record("第%d年 国家建立，首都定于 %s" % [_year(), capital.city_name])
	_hist("[国家]", "Eden 王国建立，首都 %s（%d 座城市）" % [capital.city_name, cities.size()])
	_toast("🏛", "Eden 王国建立！首都 " + capital.city_name)
	countries[country.id] = country
	return country

func _ensure_leader(gov, country) -> void:
	var society = world.get("society") if world else null
	if society == null: return
	var residents: Array = society.population.residents
	var best: Node = null
	for r in residents:
		if r.get("age") == null or r.age < 25: continue
		if best == null or _leadership_score(r) > _leadership_score(best):
			best = r
	if best:
		gov.leader_id = best.npc_name
		country.record("第%d年 %s 成为国家领袖" % [_year(), best.npc_name])

func _leadership_score(r) -> float:
	var s: float = float(r.age)
	var nd = r.get("needs")
	if nd: s += nd.happiness * 0.2
	if r.get("education") != null: s += r.education * 0.1
	var rel = r.get("relationship")
	if rel and rel.relations: s += rel.relations.size() * 2.0
	return s

# ---------------- 月度结算（财政 + 税收 + 政治压力） ----------------
func monthly_tick() -> void:
	var country = eden_country()
	if country == null: return
	var civ = world.get("civ")
	var gov = civ.get("government") if civ else null
	if gov == null: return
	# 财政：真实收入（三类税实抽）→ 支出（预算实扣）→ 赤字
	budget.monthly_settle(world, country, gov)
	tax.monthly_collect(world, country, gov)
	# 政治集团压力（真实成员）
	political.monthly_pressure(world, country)
	_sync_country(country, gov)

# ---------------- 年度结算（形成 / 稳定 / 危机 / 政府转型 / 继承） ----------------
func yearly_tick() -> void:
	if world == null: return
	var country = eden_country()
	if country == null:
		if can_form_country():
			country = form_country()
		else:
			return
	var civ = world.get("civ")
	var gov = civ.get("government") if civ else null
	if gov == null: return
	_sync_country(country, gov)
	law.apply_effects(world, country, gov)        # 法律真实效果（每年）
	country.stability = stats.calculate_stability(world, country)
	country.legitimacy = gov.legitimacy
	country.revolution_risk = political.annual_crisis(world, country, gov)
	gov_system.evaluate_transition(world, gov, country)   # 王国/共和/帝国（条件触发）
	_check_succession(gov, country)
	territory.yearly_grow(world, country)

func _sync_country(country, gov) -> void:
	var city_mgr = world.get("city_mgr") if world else null
	country.population = population_sys.total_population(world, country, city_mgr)
	country.tax_rate = gov.tax_rate
	country.government_type = gov.type
	country.legitimacy = gov.legitimacy

# ---------------- 领导人继承（真实 Human，按制度方式） ----------------
func _check_succession(gov, country) -> void:
	if gov.leader_id == "": return
	var society = world.get("society")
	if society == null: return
	var alive: bool = false
	for r in society.population.residents:
		if r.npc_name == gov.leader_id:
			alive = true
			break
	if alive: return
	# 领袖死亡（或离开）→ 按现有制度产生新领袖
	var old: String = gov.leader_id
	_ensure_leader(gov, country)
	if gov.leader_id != "" and gov.leader_id != old:
		country.record("第%d年 领袖 %s 之后，%s 继任" % [_year(), old, gov.leader_id])
		_hist("[国家]", gov.type + "选出新领袖：" + gov.leader_id)

# ---------------- 记录 ----------------
func _hist(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(), kind, text])

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

func _toast(icon: String, text: String) -> void:
	var toast = get_node_or_null("/root/Main/EventToast")
	if toast and toast.has_method("show_event"):
		toast.show_event(icon, text)

## 面板数据（TAB 国家）——完整聚合，全部真实
func panel_data() -> Dictionary:
	var country = eden_country()
	if country == null:
		return {"formed": false, "reason": _formation_blocker()}
	return stats.nation_data(world, country, self)

func _formation_blocker() -> String:
	var city_mgr = world.get("city_mgr") if world else null
	if city_mgr == null: return "缺少城市系统"
	var cities: Array = city_mgr.get_all_cities() if city_mgr.has_method("get_all_cities") else []
	if cities.size() < 2: return "需至少 2 座城市（当前 %d 座）" % cities.size()
	var total: int = 0
	for city in cities: total += city.population
	if total < 300: return "总人口需 ≥300（当前 %d）" % total
	var org_mgr = world.get("org_mgr") if world else null
	if org_mgr == null or org_mgr.organizations.size() < 2: return "需成立政治组织"
	return "政府尚未建立"

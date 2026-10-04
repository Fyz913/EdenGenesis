extends Node
## 城市总管（0.15）：城市创建、每日统计、每年升级评估 + 扩张。
## 铁律：所有统计来自真实系统（人口/住房/就业/幸福/繁荣/食物），不造假；
## 升级按真实条件（city_growth），每年一次，不做每帧计算。

const CityScript: Script = preload("res://scripts/city/city.gd")
const GrowthScript: Script = preload("res://scripts/city/city_growth.gd")
const ExpansionScript: Script = preload("res://scripts/city/city_expansion.gd")
const MigrationScript: Script = preload("res://scripts/city/migration_system.gd")
const HousingScript: Script = preload("res://scripts/city/housing_system.gd")

var cities: Dictionary = {}   # id -> City
var city_counter: int = 0
var growth: Node
var expansion: Node
var migration: Node
var housing: Node
var _last_city_year: int = 0

func _ready() -> void:
	growth = GrowthScript.new(); add_child(growth)
	expansion = ExpansionScript.new(); add_child(expansion)
	migration = MigrationScript.new(); add_child(migration)
	housing = HousingScript.new(); add_child(housing)

func create_city(city_name: String, civilization_id: String, position: Vector3):
	city_counter += 1
	var city = CityScript.new()
	city.id = "city_%d" % city_counter
	city.city_name = city_name
	city.civilization_id = civilization_id
	city.center = position
	city.founded_year = _current_year()
	cities[city.id] = city
	return city

func get_city(city_id: String):
	return cities.get(city_id, null)

func get_all_cities() -> Array:
	return cities.values()

func eden_city():
	if cities.is_empty(): return null
	return cities.values()[0]

func _current_year() -> int:
	var w = get_node_or_null("/root/Main/World")
	if w:
		var eco = w.get("ecosystem")
		if eco and eco.get("season_sys"):
			return eco.season_sys.year
	return 1

## 初始化 Eden 城市（world._ready 调用，注入城区数据）
func setup_eden(world) -> void:
	var city = create_city("Eden", "Eden", Vector3.ZERO)
	city.population = _pop(world)
	city.house_count = _houses(world)
	city.housing_capacity = city.house_count * 4
	# 初始城区数据
	var dm = world.get("district_mgr")
	if dm:
		var layout := {
			"residential": Vector3(-11, 0, 3),
			"commercial": Vector3(0, 0, 14),
			"industrial": Vector3(12, 0, -2),
			"agricultural": Vector3(14, 0, 16),
			"government": Vector3(0, 0, -8),
			"military": Vector3(6, 0, -8),
		}
		for t in layout:
			var d = dm.create_district(city.id, t, layout[t], 12.0)
			city.districts.append(d)
	# 初始建筑计数（世界已存在的事实）
	city.commercial_buildings = 3   # 市场 3 个摊位
	city.industrial_buildings = 1   # 铁匠铺
	city.public_buildings = 1       # 议事厅
	city.expansion_radius = 30.0
	_stats(world, city)
	# 等级：按真实条件
	city.level = growth.evaluate(city)
	print("[City] Eden 城市初始化：Lv%d %s | 人口 %d | 住房 %d/%d" % [
		city.level, city.level_name(), city.population, city.house_count, city.housing_capacity])

## 每天统计（director 每天调用）：真实数据 + 迁移压力
func daily_tick(world) -> void:
	var city = eden_city()
	if city == null: return
	_stats(world, city)
	# 迁移压力：战争 / 缺粮 / 低幸福 → 压力上升
	var war_mgr = world.get("war_mgr")
	var at_war: bool = war_mgr and war_mgr.has_method("get_active_war_for") and war_mgr.get_active_war_for("Eden") != null
	if at_war: city.migration_pressure += 3.0
	if city.food_supply < city.population * 1.0: city.migration_pressure += 2.0
	if city.happiness < 25.0: city.migration_pressure += 5.0
	city.migration_pressure = clampf(city.migration_pressure, 0.0, 100.0)
	# 住房需求：人口接近房屋承载 → 真盖房（复用 ensure_housing）
	if city.population > _houses(world) * 3:
		var st = world.get("settlement")
		if st and st.has_method("ensure_housing"):
			st.ensure_housing(city.population)
			_stats(world, city)

## 每年评估 + 升级扩张（director 年变时调用）
func yearly_tick(world) -> void:
	var city = eden_city()
	if city == null: return
	_stats(world, city)
	var target: int = growth.evaluate(city)
	if target > city.level:
		_expand_to(world, city, target)
	elif target < city.level:
		# 条件不再满足：不降级，但提示
		print("[City] 城市条件回落，维持 Lv%d（不降级）" % city.level)
	# 迁移（每年一次）
	migration.yearly_tick(city, world)
	_stats(world, city)

func _expand_to(world, city, target: int) -> void:
	var old_level: int = city.level
	city.level = target
	expansion.expand(city, world, target)
	# 文明命名联动
	var c = world.get("civ")
	if c and c.get("settlement"):
		match target:
			2: c.settlement.settlement_name = "Eden聚落"
			3: c.settlement.settlement_name = "Eden城镇"
			4: c.settlement.settlement_name = "Eden城市"
			5: c.settlement.settlement_name = "Eden大都会"
	# 升级提示（3 秒淡出 toast）
	var toast = get_node_or_null("/root/Main/EventToast")
	var msg: String = "Eden 聚落 → " + city.level_name()
	if toast and toast.has_method("show_event"):
		toast.show_event("🏛", msg)
	# 历史记录
	if c and c.get("history"):
		c.history.record("第%d年：Eden 升级为 %s（Lv%d）" % [_current_year(), city.level_name(), target])
	print("[City] 城市升级：Lv%d → Lv%d %s" % [old_level, target, city.level_name()])

## 真实统计
func _stats(world, city) -> void:
	var society = world.get("society")
	var economy = world.get("economy")
	var settlement = world.get("settlement")
	if society == null or settlement == null: return
	var residents: Array = society.population.residents
	var pop: int = residents.size()
	city.population = pop
	city.house_count = _houses(world)
	city.housing_capacity = city.house_count * 4
	# 就业容量：成年居民 + 工作建筑提供岗位
	var adults: int = 0
	for n in residents:
		if n.get("age") >= 18 and n.get("job") != "孩子":
			adults += 1
	var work_buildings: int = city.commercial_buildings + city.industrial_buildings + 1   # +1 初始铁匠铺
	city.employment_capacity = adults + work_buildings * 2
	city.unemployed = maxi(0, adults - city.employment_capacity)
	# 幸福（居民真实情绪均值）
	var happy_sum: float = 0.0
	for n in residents:
		var nd = n.get("needs")
		if nd: happy_sum += nd.happiness
	city.happiness = (happy_sum / pop) if pop > 0 else 50.0
	# 繁荣（财富 + 市场健康）
	var prosperity: float = 50.0
	if economy:
		var ws: Dictionary = economy.wealth_stats(residents)
		prosperity = minf(100.0, ws.get("avg", 0.0) / 4.0 + 40.0)
		if economy.market and economy.market.status_text() == "正常":
			prosperity += 10.0
	city.prosperity = minf(100.0, prosperity)
	# 基础设施：房屋 + 道路 + 公共建筑
	var road_count: int = 0
	if settlement.get("roads"): road_count = settlement.roads.get_child_count()
	city.infrastructure = minf(100.0, 10.0 + city.house_count * 1.0 + road_count * 0.5 + city.public_buildings * 5.0)
	# 食物
	if economy and economy.market:
		city.food_supply = economy.market.stock.get("food", 0.0)

func _pop(world) -> int:
	var s = world.get("society")
	return s.population.count() if s else 0

func _houses(world) -> int:
	var st = world.get("settlement")
	if st == null: return 0
	return st.home_slots.size()

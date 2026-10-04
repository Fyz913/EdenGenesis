extends Node
## 文明大脑：把 civilization/ 和 economy/ 串起来

const CivClass = preload("res://scripts/civilization/civilization.gd")
const SettlementClass = preload("res://scripts/civilization/settlement.gd")
const TechClass = preload("res://scripts/civilization/technology.gd")
const CultureClass = preload("res://scripts/civilization/culture.gd")
const GovClass = preload("res://scripts/civilization/government.gd")
const HistoryClass = preload("res://scripts/civilization/history.gd")
const ResourceClass = preload("res://scripts/economy/resource.gd")
const ProductionClass = preload("res://scripts/economy/production.gd")

var civilization: Node
var settlement: Node
var tech: Node
var culture: Node
var government: Node
var history: Node
var resource: Node
var production: Node

var _year_tick: float = 0.0
var _year: int = 0

signal civilization_changed()

func _ready() -> void:
	civilization = CivClass.new(); add_child(civilization)
	settlement = SettlementClass.new(); add_child(settlement)
	tech = TechClass.new(); add_child(tech)
	culture = CultureClass.new(); add_child(culture)
	government = GovClass.new(); add_child(government)
	history = HistoryClass.new(); add_child(history)
	resource = ResourceClass.new(); add_child(resource)
	production = ProductionClass.new(); add_child(production)

	culture.create_value("尊重自然")
	culture.create_value("探索未知")
	history.record("第 0 年：Eden 村庄建立")
	tech.research("石器")
	tech.research("农业")
	print("[Civ] Eden 文明诞生")

func set_population(n: int) -> void:
	civilization.population = n
	settlement.grow(n)
	# 政府制度升级由 politics_system 按条件触发（0.13）

func _process(_delta: float) -> void:
	# 0.19.1：年份统一由季节系统驱动（消除双年计数器）
	var world = get_node_or_null("/root/Main/World")
	if world == null: return
	var eco = world.get("ecosystem")
	if eco == null or eco.get("season_sys") == null: return
	var sy: int = eco.season_sys.year
	if sy != _year:
		_year = sy
		_yearly_update()

func _yearly_update() -> void:
	civilization.update()
	history.record("第 %d 年：人口 %d，%s，科技等级 %d，%s" % [
		_year, civilization.population, settlement.settlement_name, civilization.technology_level, government.type
	])
	if civilization.population > 100 and not tech.has("冶炼"):
		tech.research("冶炼")
		history.record("第 %d 年：发现冶炼技术" % _year)
	civilization_changed.emit()

func produce_day(residents: Array) -> void:
	for npc in residents:
		if not is_instance_valid(npc): continue
		var out: Dictionary = production.work(npc.job)
		for k in out.keys():
			resource.add(k, out[k])

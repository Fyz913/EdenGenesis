extends Node3D
## 世界入口（World 层）
## 严格层级：Terrain（地形/积雪）/ Buildings（建筑）/ Residents（居民）/ Ecology（动物天气）
## 生态系统只能改 Terrain/SnowLayer 与灯光，绝不触碰建筑和居民。

const TreeScene: PackedScene = preload("res://scenes/tree.tscn")
const FactoryScript: Script = preload("res://scripts/visual/building_factory.gd")
const NpcScene: PackedScene = preload("res://scenes/npc.tscn")
const SettlementScript: Script = preload("res://scripts/settlement/settlement_manager.gd")
const SocietyManagerScript: Script = preload("res://scripts/world/society_manager.gd")
const CivManagerScript: Script = preload("res://scripts/world/civilization_manager.gd")
const MultiCivScript: Script = preload("res://scripts/world/multi_civ_manager.gd")
const EcosystemScript: Script = preload("res://scripts/ecology/ecosystem_manager.gd")
const DirectorScript: Script = preload("res://scripts/core/game_director.gd")
const SaveScript: Script = preload("res://scripts/core/save_manager.gd")
const EconomyScript: Script = preload("res://scripts/economy/economy_manager.gd")
const OrgMgrScript: Script = preload("res://scripts/organization/organization_manager.gd")
const PoliticsScript: Script = preload("res://scripts/politics/politics_system.gd")
const DiplomacyScript: Script = preload("res://scripts/diplomacy/diplomacy_manager.gd")
const ArmyMgrScript: Script = preload("res://scripts/military/army_manager.gd")
const WarMgrScript: Script = preload("res://scripts/war/war_manager.gd")
const MarketDisplayScript: Script = preload("res://scripts/visual/market_display.gd")
const CityMgrScript: Script = preload("res://scripts/city/city_manager.gd")
const DistrictMgrScript: Script = preload("res://scripts/city/district_manager.gd")
const CityRoadScript: Script = preload("res://scripts/city/city_road_system.gd")
const SocialSimScript: Script = preload("res://scripts/society/social_simulation.gd")
const TechMgrScript: Script = preload("res://scripts/technology/technology_manager.gd")
const CountryMgrScript: Script = preload("res://scripts/country/country_manager.gd")
const AdminMgrScript: Script = preload("res://scripts/administration/administration_manager.gd")
const InfraMgrScript: Script = preload("res://scripts/infrastructure/infrastructure_manager.gd")
const TransportMgrScript: Script = preload("res://scripts/transport/transport_manager.gd")
# 0.20 经济帝国：资源/生产/企业/市场供需/区域贸易/银行/经济总循环
const ResourceMgrScript: Script = preload("res://scripts/economy/resource_manager.gd")
const ProductionMgrScript: Script = preload("res://scripts/economy/production_manager.gd")
const CompanyMgrScript: Script = preload("res://scripts/economy/company_manager.gd")
const MarketMgrScript: Script = preload("res://scripts/economy/market_manager.gd")
const TradeMgrScript: Script = preload("res://scripts/economy/trade_manager.gd")
const FinanceMgrScript: Script = preload("res://scripts/economy/finance_manager.gd")
const EconSimScript: Script = preload("res://scripts/economy/economy_simulation.gd")

@onready var clock: Node = get_node("../WorldTime")
var society: Node
var civ: Node
var multiciv: Node
var settlement: Node
var ecosystem: Node
var director: Node
var save_mgr: Node
var economy: Node
var org_mgr: Node
var politics: Node
var diplomacy: Node
var army_mgr: Node
var war_mgr: Node
var market_display: Node
var city_mgr: Node
var district_mgr: Node
var city_roads: Node
var social_sim: Node
var social_network: Node
var education_sys: Node
var health_sys: Node
var crime_sys: Node
var culture_sys: Node
var tech_mgr: Node   # 0.17 技术总管
var country_mgr: Node   # 0.18 国家总管
var admin_mgr: Node   # 0.19 行政区总管
var infra_mgr: Node   # 0.19 基建总管
var transport_mgr: Node   # 0.19 交通物流总管
var resource_mgr: Node    # 0.20 资源管理器
var production_mgr: Node  # 0.20 工厂生产管理器
var company_mgr: Node     # 0.20 企业管理器
var market_mgr: Node      # 0.20 市场供需管理器
var trade_mgr: Node       # 0.20 区域贸易管理器（CargoBatch）
var finance_mgr: Node     # 0.20 银行（钱庄）
var econ_sim: Node        # 0.20 经济总循环 + GDP 统计
var camp_banner: MeshInstance3D = null   # 军营旗帜（战争可见化）

# 层级容器
var terrain_root: Node3D
var building_root: Node3D
var resident_root: Node3D

# 生态可安全修改的对象
var ground_mesh: MeshInstance3D
var ground_material: StandardMaterial3D
var snow_layer: MeshInstance3D
var snow_material: StandardMaterial3D

var _npcs: Dictionary = {}
var entity_registry: Node = null   # 0.19.7 统一实体注册表
var sim_queue: Node = null         # 0.19.7 模拟队列（批处理）

func _ready() -> void:
	# 0.19.5 性能调度器（分层时钟 + 性能统计）
	var sched = preload("res://scripts/core/simulation_scheduler.gd").new()
	sched.name = "Scheduler"
	add_child(sched)
	# 0.19.6 世界分区 + LOD：空间网格 / NPC LOD / 流式区域
	var grid = preload("res://scripts/core/spatial_grid.gd").new()
	grid.name = "SpatialGrid"
	add_child(grid)
	var lodm = preload("res://scripts/core/npc_lod_manager.gd").new()
	lodm.name = "NpcLod"
	add_child(lodm)
	var stream = preload("res://scripts/core/world_streaming_manager.gd").new()
	stream.name = "Streaming"
	add_child(stream)
	stream.create_world_regions(500.0)
	# 0.19.7 统一实体注册表（防重复 ID）+ 模拟队列（批处理基础设施）
	var registry = preload("res://scripts/core/entity_registry.gd").new()
	registry.name = "EntityRegistry"
	add_child(registry)
	entity_registry = registry
	var simq = preload("res://scripts/core/simulation_queue.gd").new()
	simq.name = "SimQueue"
	add_child(simq)
	sim_queue = simq
	# 1) 先建层级容器
	terrain_root = Node3D.new(); terrain_root.name = "Terrain"; add_child(terrain_root)
	building_root = Node3D.new(); building_root.name = "Buildings"; add_child(building_root)
	resident_root = Node3D.new(); resident_root.name = "Residents"; add_child(resident_root)

	# 2) 管理器
	society = SocietyManagerScript.new(); add_child(society); society.world = self
	civ = CivManagerScript.new(); add_child(civ)
	multiciv = MultiCivScript.new(); add_child(multiciv)
	# 聚落：注入层级容器后再入树（_ready 里才会生成）
	settlement = SettlementScript.new()
	settlement.terrain_root = terrain_root
	settlement.building_root = building_root
	add_child(settlement)
	ecosystem = EcosystemScript.new(); add_child(ecosystem)
	economy = EconomyScript.new(); add_child(economy)
	# 社会组织 / 政治 / 外交（0.13 增量，纯 Manager 数据，不碰渲染）
	org_mgr = OrgMgrScript.new(); add_child(org_mgr)
	politics = PoliticsScript.new(); add_child(politics)
	diplomacy = DiplomacyScript.new(); add_child(diplomacy); diplomacy.setup()
	# 军事 / 战争（0.14 增量，纯 Manager 数据）
	army_mgr = ArmyMgrScript.new(); add_child(army_mgr)
	war_mgr = WarMgrScript.new(); add_child(war_mgr)
	market_display = MarketDisplayScript.new(); add_child(market_display)
	# 城市系统（0.15 增量：数据 + 扩张，全部纯增量）
	city_mgr = CityMgrScript.new(); add_child(city_mgr)
	district_mgr = DistrictMgrScript.new(); add_child(district_mgr)
	city_roads = CityRoadScript.new(); add_child(city_roads)
	# 社会系统（0.16 增量：网络/教育/健康/犯罪/文化/稳定度）
	social_sim = SocialSimScript.new(); add_child(social_sim); social_sim.bind(self)
	# 技术系统（0.17 增量：知识/技能/发明/研究组/传播/文化演化）
	tech_mgr = TechMgrScript.new(); add_child(tech_mgr); tech_mgr.bind(self)
	# 国家系统（0.18 增量：国家/领土/财政/法律/政治，上层协调层）
	country_mgr = CountryMgrScript.new(); add_child(country_mgr); country_mgr.bind(self)
	# 行政/基建/交通（0.19 增量：国家管理土地与连接）
	admin_mgr = AdminMgrScript.new(); add_child(admin_mgr); admin_mgr.bind(self)
	infra_mgr = InfraMgrScript.new(); add_child(infra_mgr); infra_mgr.bind(self)
	transport_mgr = TransportMgrScript.new(); add_child(transport_mgr); transport_mgr.bind(self)
	# 0.20 经济帝国：资源/企业/工厂/供需/贸易/银行/总循环（纯 Manager 数据层，不碰渲染）
	resource_mgr = ResourceMgrScript.new(); add_child(resource_mgr)
	production_mgr = ProductionMgrScript.new(); add_child(production_mgr)
	company_mgr = CompanyMgrScript.new(); add_child(company_mgr)
	market_mgr = MarketMgrScript.new(); add_child(market_mgr)
	trade_mgr = TradeMgrScript.new(); add_child(trade_mgr)
	finance_mgr = FinanceMgrScript.new(); add_child(finance_mgr)
	econ_sim = EconSimScript.new(); add_child(econ_sim)
	director = DirectorScript.new(); add_child(director); director.bind(self)
	save_mgr = SaveScript.new(); add_child(save_mgr)

	# 3) 地形 / 建筑 / 居民
	_build_terrain()
	_build_foreign_villages()
	_setup_organizations()
	_setup_culture()
	_spawn_npcs()
	_setup_families()
	_setup_economy_020()
	politics.bind(self)   # 领袖/议事会推举（需居民就绪）
	_build_military_camp()
	army_mgr.ensure_army("Eden", society.population.count(), Vector3(6, 0, -8))
	market_display.setup(districts_market_pos(), building_root)
	city_mgr.setup_eden(self)
	district_mgr.apply_visual(self)
	civ.set_population(society.population.count())
	load_saved_world()
	print("[World] Eden 就绪 | 人口: ", society.population.count(), " | 住宅: ", settlement.home_slots.size())

func districts_market_pos() -> Vector3:
	if settlement and settlement.get("districts"):
		return settlement.districts.get("market", Vector3(0, 0, 14))
	return Vector3(0, 0, 14)

# ---------- 0.20 经济初始化：资源地图 / 初始企业+工厂 / 居民归属 / 贸易路线 ----------
func _setup_economy_020() -> void:
	if resource_mgr and resource_mgr.has_method("setup"):
		resource_mgr.setup()
	if trade_mgr and trade_mgr.has_method("setup_routes"):
		trade_mgr.setup_routes()
	var residents: Array = society.population.residents if society and society.get("population") else []
	# 居民按职业归属企业（company_manager 内部兜底创建 5 家固定 id 企业）
	if company_mgr:
		company_mgr.auto_assign(residents, production_mgr)
	# 初始工厂（农庄农田 / 林场 / 采石场 / 铁坊炼钢）
	if production_mgr and company_mgr:
		var f1: Dictionary = production_mgr.create_factory("Eden农田", "eden_farm", "farm")
		var f2: Dictionary = production_mgr.create_factory("Eden林场", "eden_wood", "wood_camp")
		var f3: Dictionary = production_mgr.create_factory("Eden采石场", "eden_stone", "stone_quarry")
		var f4: Dictionary = production_mgr.create_factory("Eden炼钢厂", "eden_iron", "smithy")
		company_mgr.get_company("eden_farm")["factories"].append(f1["id"])
		company_mgr.get_company("eden_wood")["factories"].append(f2["id"])
		company_mgr.get_company("eden_stone")["factories"].append(f3["id"])
		company_mgr.get_company("eden_iron")["factories"].append(f4["id"])
		# 工厂工人 = 对应企业员工
		for cid in company_mgr.companies:
			var comp: Dictionary = company_mgr.companies[cid]
			for fid in comp["factories"]:
				if production_mgr.factories.has(fid):
					production_mgr.factories[fid]["workers"] = comp["employees"].duplicate()

# ---------- 军营（0.14 视觉，仅一组静态建筑+旗帜，不生成士兵模型） ----------
func _build_military_camp() -> void:
	var camp_pos: Vector3 = Vector3(6, 0, -8)
	# 训练木桩
	for i in range(3):
		var post := MeshInstance3D.new()
		post.mesh = BoxMesh.new(); post.mesh.size = Vector3(0.25, 2.2, 0.25)
		post.position = camp_pos + Vector3(-1 + i * 1.2, 1.1, -1.5)
		var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.55, 0.4, 0.25)
		post.material_override = pm; building_root.add_child(post)
	# 军旗（红底，与村旗区分）
	var pole := MeshInstance3D.new()
	pole.mesh = BoxMesh.new(); pole.mesh.size = Vector3(0.14, 5.0, 0.14)
	pole.position = camp_pos + Vector3(0, 2.5, 0)
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(0.35, 0.25, 0.15)
	pole.material_override = pmat; building_root.add_child(pole)
	var cloth := MeshInstance3D.new()
	cloth.mesh = BoxMesh.new(); cloth.mesh.size = Vector3(1.5, 0.9, 0.05)
	cloth.position = camp_pos + Vector3(0.8, 4.2, 0)
	var cmat := StandardMaterial3D.new(); cmat.albedo_color = Color(0.75, 0.1, 0.1)
	cmat.emission_enabled = true; cmat.emission = Color(0.25, 0.02, 0.02)
	cloth.material_override = cmat; building_root.add_child(cloth)
	camp_banner = cloth   # 0.14.5 战争可见化：开战时旗帜变亮红并闪烁

func _process(_delta: float) -> void:
	# 战争可见化：Eden 参战 → 军营旗帜亮红闪烁
	if camp_banner:
		var at_war: bool = false
		if war_mgr and war_mgr.get_active_war_for("Eden"):
			at_war = true
		var mat: StandardMaterial3D = camp_banner.material_override
		if mat:
			if at_war:
				var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
				mat.emission = Color(0.9, 0.08, 0.05) * pulse
				mat.albedo_color = Color(0.95, 0.12, 0.08)
			else:
				mat.emission = Color(0.25, 0.02, 0.02)
				mat.albedo_color = Color(0.75, 0.1, 0.1)

# ---------- 社会组织（0.13） ----------
func _setup_organizations() -> void:
	org_mgr.create_organization("eden_village", "Eden村")
	org_mgr.create_organization("merchant_guild", "商会")
	org_mgr.create_organization("farmers_guild", "农民协会")
	org_mgr.create_organization("crafts_guild", "工匠协会")

# ---------- 初始文化（0.16） ----------
func _setup_culture() -> void:
	var c = civ.get("culture")
	if c:
		c.create_value("探索")
		c.create_value("互助")
		c.add_tradition("秋收感恩")
		c.add_tradition("炉火不灭")
		c.add_festival("丰收节", "Autumn")

# ---------- 地形（全部进 Terrain 容器） ----------
func _build_terrain() -> void:
	ground_mesh = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	pm.subdivide_width = 48
	pm.subdivide_depth = 48
	var arr := pm.get_mesh_arrays()
	var verts: PackedVector3Array = Array(arr[Mesh.ARRAY_VERTEX])
	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		var h: float = sin(v.x * 0.08) * cos(v.z * 0.07) * 1.2 + sin(v.x*0.02+v.z*0.03)*2.0
		var center_dist: float = Vector2(v.x, v.z).length()
		if center_dist < 22: h *= center_dist / 22.0
		verts[i] = Vector3(v.x, h, v.z)
	arr[Mesh.ARRAY_VERTEX] = verts
	var surf := ArrayMesh.new()
	surf.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ground_mesh.mesh = surf
	ground_material = FactoryScript.make_ground_material(1234)
	ground_mesh.material_override = ground_material
	terrain_root.add_child(ground_mesh)

	# 积雪覆盖层（独立、透明，默认不可见；冬季淡入，绝不替换地面材质）
	snow_layer = MeshInstance3D.new()
	var spm := PlaneMesh.new(); spm.size = Vector2(200, 200)
	snow_layer.mesh = spm
	snow_layer.position = Vector3(0, 0.12, 0)
	snow_material = StandardMaterial3D.new()
	snow_material.albedo_color = Color(0.93, 0.95, 1.0, 0.0)
	snow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	snow_layer.material_override = snow_material
	snow_layer.visible = false
	terrain_root.add_child(snow_layer)

	# 河流
	var river := MeshInstance3D.new()
	river.mesh = PlaneMesh.new(); river.mesh.size = Vector2(200, 5)
	river.position = Vector3(0, -0.2, -15)
	river.material_override = FactoryScript.make_water_material(); terrain_root.add_child(river)

	# 远景山脉环（空气透视蓝灰）
	for i in range(14):
		var ang: float = TAU * i / 14.0
		var dist: float = randf_range(62, 78)
		var mtn := MeshInstance3D.new()
		mtn.mesh = SphereMesh.new()
		mtn.mesh.radius = randf_range(10, 18); mtn.mesh.height = randf_range(12, 22)
		mtn.position = Vector3(cos(ang)*dist, -2, sin(ang)*dist)
		var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.32, 0.4, 0.42, 1)
		mtn.material_override = mm; terrain_root.add_child(mtn)

	# 近景小山
	for i in range(6):
		var hill := MeshInstance3D.new()
		hill.mesh = SphereMesh.new(); hill.mesh.radius = randf_range(8, 16); hill.mesh.height = randf_range(4, 9)
		hill.position = Vector3(randf_range(-55, 55), -1, randf_range(-55, 55))
		if abs(hill.position.x) < 25 and abs(hill.position.z) < 25: continue
		var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.3, 0.45, 0.25, 1)
		hill.material_override = hm; terrain_root.add_child(hill)

	# 矿区（东北）
	for i in range(8):
		var rock := MeshInstance3D.new()
		rock.mesh = SphereMesh.new(); rock.mesh.radius = randf_range(0.5, 1.5); rock.mesh.height = randf_range(0.5, 1.5)
		rock.position = Vector3(randf_range(22, 32), 0.3, randf_range(-20, -10))
		var rock_mat := StandardMaterial3D.new(); rock_mat.albedo_color = Color(0.4, 0.4, 0.42, 1)
		rock.material_override = rock_mat; terrain_root.add_child(rock)

	# 森林（北边）—— 0.19.1 精致树（随机变体 + 少量灌木）
	for i in range(28):
		FactoryScript.make_tree(terrain_root, Vector3(randf_range(-35, 35), 0, randf_range(-40, -25)), i)
	for i in range(12):
		FactoryScript.make_tree(terrain_root, Vector3(randf_range(-45, 45), 0, randf_range(-45, 45)), i + 7)
	for i in range(14):
		FactoryScript.make_tree(terrain_root, Vector3(randf_range(-20, 20), 0, randf_range(20, 38)), i + 3)

	# 0.19.1 地面装饰：野花 / 草丛 / 小石（村庄周边 60m 内，避开建筑区中心）
	for i in range(70):
		var dx: float = randf_range(-30, 40)
		var dz: float = randf_range(-30, 40)
		if abs(dx) < 6 and abs(dz) < 6: continue
		var dmat := StandardMaterial3D.new()
		var kind: int = i % 4
		match kind:
			0: dmat.albedo_color = Color(0.9, 0.95, 0.7); dmat.roughness = 1.0
			1: dmat.albedo_color = Color(0.85, 0.6, 0.75); dmat.roughness = 1.0
			2: dmat.albedo_color = Color(0.3, 0.45, 0.22); dmat.roughness = 1.0
			_: dmat.albedo_color = Color(0.55, 0.55, 0.5); dmat.roughness = 1.0
		var dm := MeshInstance3D.new()
		if kind == 3:
			dm.mesh = SphereMesh.new(); dm.mesh.radius = randf_range(0.1, 0.22); dm.mesh.height = dm.mesh.radius * 1.4
			dm.position = Vector3(dx, dm.mesh.radius * 0.5, dz)
		else:
			dm.mesh = CylinderMesh.new(); dm.mesh.top_radius = 0.05; dm.mesh.bottom_radius = 0.07; dm.mesh.height = 0.28
			dm.position = Vector3(dx, 0.14, dz)
			dm.rotation.y = randf() * TAU
		dm.material_override = dmat
		terrain_root.add_child(dm)
# ---------- 其他文明村庄（进 Buildings 容器） ----------
func _build_foreign_villages() -> void:
	for i in range(2):
		var h := preload("res://scenes/house.tscn").instantiate()
		h.position = Vector3(-28 + i*5, 0, -28 + i*2)
		h.scale = Vector3(0.7, 0.7, 0.7)
		building_root.add_child(h)
	var fire := MeshInstance3D.new()
	fire.mesh = SphereMesh.new(); fire.mesh.radius = 0.4; fire.mesh.height = 0.8
	fire.position = Vector3(-28, 0.5, -25)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1, 0.5, 0.1); fm.emission_enabled = true; fm.emission = Color(1, 0.4, 0.05)
	fire.material_override = fm; building_root.add_child(fire)
	for i in range(2):
		var h := preload("res://scenes/house.tscn").instantiate()
		h.position = Vector3(28 + i*5, 0, 22 + i*3)
		h.scale = Vector3(0.8, 0.8, 0.8)
		building_root.add_child(h)
	var sand := MeshInstance3D.new()
	sand.mesh = PlaneMesh.new(); sand.mesh.size = Vector2(30, 20)
	sand.position = Vector3(28, 0.02, 22)
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.85, 0.75, 0.5, 1)
	sand.material_override = sm; terrain_root.add_child(sand)

# ---------- NPC（进 Residents 容器） ----------
func _spawn_npcs() -> void:
	var roster = [
		["阿尔", 32, "铁匠"], ["莉娜", 29, "织布工"],
		["阿花", 28, "农夫"], ["老陈", 45, "渔夫"],
		["小李", 25, "商人"], ["王婆", 60, "面包师"],
		["大刘", 35, "农夫"], ["二妞", 22, "织布工"],
		["铁柱", 40, "铁匠"], ["小芳", 26, "农夫"],
		["老吴", 50, "渔夫"], ["阿强", 30, "商人"],
		["春花", 33, "面包师"], ["二狗", 27, "农夫"],
		["三妹", 24, "织布工"],
	]
	for i in range(roster.size()):
		var r = roster[i]
		var home: Vector3 = settlement.get_home_for(i)
		var work: Vector3 = settlement.get_work_for(r[2])
		var food: Vector3 = settlement.get_food_position()
		_npcs[r[0]] = _spawn_one(r[0], r[1], r[2], home, work, food)
		settlement.bind_owner(i, r[0])

func _setup_families() -> void:
	society.register_family(_npcs["阿尔"], _npcs["莉娜"])


## 读档核心（0.19.1）：恢复人口/住宅/时间/资源/时代/城市等级
func load_saved_world() -> bool:
	if save_mgr == null or not save_mgr.has_method("load_core"): return false
	var ok: bool = save_mgr.load_core(self)
	# 0.19.7：读档后同步季节渲染镜像 + 注册表重建 + 校验
	var eco = get("ecosystem")
	if ok and eco and eco.get("season_sys") and eco.season_sys.has_method("sync_from_clock"):
		eco.season_sys.sync_from_clock()
	if ok and entity_registry and entity_registry.has_method("rebuild_from_world"):
		entity_registry.rebuild_from_world(self)
	return ok

func save_game() -> void:
	if save_mgr:
		save_mgr.save_all(self)
		if save_mgr.has_method("validate_world"):
			var issues: Array = save_mgr.validate_world(self)
			if issues.size() > 0:
				print("[SaveValidator] 发现 %d 项一致性问题（不影响运行，已记录）" % issues.size())

func _spawn_one(n, a, j, home, work, food) -> Node:
	var npc: CharacterBody3D = NpcScene.instantiate()
	npc.set("npc_name", n); npc.set("age", a); npc.set("job", j)
	npc.set("gender", "男" if (randi() % 2 == 0) else "女")
	resident_root.add_child(npc)
	npc.setup(home, work, food)
	clock.subscribe(npc)
	society.register(npc)
	return npc

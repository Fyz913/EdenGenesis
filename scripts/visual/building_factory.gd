extends Node
## 0.19.1 视觉工厂：从 0 重建 Eden 的精致画面。
## 全部程序化生成（无外部美术），统一材质语言：哑光木/石/茅草 + 暖色窗光 + 斜屋顶 + 阴影。
## 铁律：建筑带碰撞、尺寸与旧系统一致（房屋 4×2.8×4、门朝 +Z 由调用方旋转）、只增不删。

# ---------- 材质辅助 ----------
static func _mat(color: Color, rough: float = 0.9, metal: float = 0.0, emiss: Color = Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emiss.a > 0.01:
		m.emission_enabled = true
		m.emission = emiss
	return m

## 自然色噪声纹理（草/土斑驳）
static func noise_tex(seed_v: int, freq: float, c0: Color, c1: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = 3
	n.fractal_gain = 0.6
	var nt := NoiseTexture2D.new()
	nt.noise = n
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	nt.color_ramp = g
	return nt

static func _mesh(parent: Node, mtype: Mesh, pos: Vector3, mat: Material, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mtype
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return _mesh(parent, b, pos, mat)

static func _cyl(parent: Node, top: float, bot: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = top; c.bottom_radius = bot; c.height = h
	return _mesh(parent, c, pos, mat)

static func _sph(parent: Node, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = r; s.height = h
	return _mesh(parent, s, pos, mat)

# ---------- 房屋（精致版）：台阶 + 墙体 + 暖光窗 + 门框 + 斜屋顶 + 烟囱 + 屋檐 ----------
## tier: 1=部落茅草(泥墙/黄顶) 2=村庄木屋(木墙/棕瓦) 3=城镇石屋(石墙/红瓦)
static func make_house(parent: Node, pos: Vector3, tier: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var wall_col: Color
	var roof_col: Color
	match tier:
		1: wall_col = Color(0.58, 0.5, 0.36); roof_col = Color(0.78, 0.66, 0.25)   # 茅草
		2: wall_col = Color(0.62, 0.47, 0.3); roof_col = Color(0.42, 0.26, 0.16)   # 棕瓦
		_: wall_col = Color(0.7, 0.66, 0.6); roof_col = Color(0.6, 0.25, 0.18)     # 红瓦
	var wall_mat := _mat(wall_col, 0.95)
	var roof_mat := _mat(roof_col, 0.85)
	var trim_mat := _mat(Color(0.35, 0.26, 0.17), 0.9)
	var glass_mat := _mat(Color(1.0, 0.85, 0.5), 0.4, 0.0, Color(1.0, 0.8, 0.45, 1.0))
	var door_mat := _mat(Color(0.35, 0.23, 0.13), 0.8)
	# 门槛/基础（防浮空）
	_box(body, Vector3(4.4, 0.16, 4.4), Vector3(0, 0.08, 0), wall_mat)
	# 台阶（门前 +Z）
	_box(body, Vector3(2.2, 0.14, 0.9), Vector3(0, 0.14, 2.45), _mat(Color(0.55, 0.5, 0.42), 0.95))
	# 墙体
	_box(body, Vector3(4.0, 2.2, 4.0), Vector3(0, 1.2, 0), wall_mat)
	# 窗（两侧 + 正面两窗）——暖光
	_box(body, Vector3(0.9, 0.75, 0.14), Vector3(1.35, 1.75, 2.02), glass_mat)
	_box(body, Vector3(0.9, 0.75, 0.14), Vector3(-1.35, 1.75, 2.02), glass_mat)
	_box(body, Vector3(0.14, 0.75, 0.9), Vector3(2.02, 1.75, 0.8), glass_mat)
	# 窗框
	_box(body, Vector3(1.1, 0.08, 0.16), Vector3(1.35, 2.15, 2.02), trim_mat)
	_box(body, Vector3(0.08, 0.95, 0.16), Vector3(1.35, 1.75, 2.02), trim_mat)
	_box(body, Vector3(1.1, 0.08, 0.16), Vector3(-1.35, 2.15, 2.02), trim_mat)
	_box(body, Vector3(0.08, 0.95, 0.16), Vector3(-1.35, 1.75, 2.02), trim_mat)
	# 门框 + 门板
	_box(body, Vector3(1.3, 1.9, 0.14), Vector3(0, 1.2, 2.03), trim_mat)
	_box(body, Vector3(1.0, 1.65, 0.12), Vector3(0, 1.15, 2.1), door_mat)
	_box(body, Vector3(0.1, 0.1, 0.04), Vector3(0.36, 1.0, 2.18), _mat(Color(0.8, 0.7, 0.4), 0.5))  # 门把手
	# 斜屋顶（两片，屋脊沿 X）
	var over: float = 0.5
	var roof_len: float = 4.0 + over * 2.0
	var slope: float = 0.62
	var panel_w: float = sqrt(2.2 * 2.2 + slope * slope)  # 半宽 2.2 + 升 slope
	var a: float = atan2(slope, 2.2)
	var roof_y: float = 2.3
	for s in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var rm := BoxMesh.new(); rm.size = Vector3(roof_len, 0.16, panel_w)
		p.mesh = rm
		p.position = Vector3(0, roof_y + slope * 0.5, s * 1.1)
		p.rotation.x = -s * a
		p.material_override = roof_mat
		body.add_child(p)
	# 屋脊压条
	_box(body, Vector3(roof_len, 0.14, 0.22), Vector3(0, roof_y + slope, 0), _mat(Color(0.3, 0.22, 0.14), 0.9))
	# 烟囱（屋脊偏后）+ 烟
	_box(body, Vector3(0.5, 1.4, 0.5), Vector3(1.1, roof_y + slope + 0.6, -1.0), _mat(Color(0.5, 0.45, 0.4), 0.95))
	var smoke := _sph(body, 0.16, 0.32, Vector3(1.1, roof_y + slope + 1.6, -1.0), _mat(Color(0.8, 0.8, 0.82, 0.55), 0.8))
	smoke.get_surface_override_material(0)  # noop
	var sm_mat := smoke.material_override as StandardMaterial3D
	sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat.albedo_color = Color(0.85, 0.85, 0.88, 0.5)
	# 碰撞
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new(); shp.size = Vector3(4.0, 2.8, 4.0)
	col.shape = shp; col.position = Vector3(0, 1.4, 0)
	body.add_child(col)
	return body

# ---------- 铁匠铺：石墙 + 大斜顶 + 烟囱 + 炉口火焰 + 铁砧 + 工具架 ----------
static func make_blacksmith(parent: Node, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var stone_mat := _mat(Color(0.5, 0.47, 0.43), 0.95)
	var roof_mat := _mat(Color(0.4, 0.28, 0.18), 0.85)
	var dark_mat := _mat(Color(0.22, 0.2, 0.18), 0.7, 0.3)
	var fire_mat := _mat(Color(1.0, 0.55, 0.15), 0.5, 0.0, Color(1.0, 0.5, 0.12, 1.0))
	var wood_mat := _mat(Color(0.5, 0.36, 0.22), 0.9)
	_box(body, Vector3(7.0, 3.2, 6.0), Vector3(0, 1.6, 0), stone_mat)
	# 斜屋顶（沿 X）
	for s in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var rm := BoxMesh.new(); rm.size = Vector3(7.8, 0.18, 2.9)
		p.mesh = rm
		p.position = Vector3(0, 3.35, s * 1.45)
		p.rotation.x = -s * 0.45
		p.material_override = roof_mat
		body.add_child(p)
	_box(body, Vector3(7.8, 0.12, 0.24), Vector3(0, 3.7, 0), dark_mat)
	# 烟囱
	_box(body, Vector3(1.0, 3.2, 1.0), Vector3(2.2, 3.4, -1.8), _mat(Color(0.38, 0.35, 0.33), 0.95))
	# 大门口（+Z 面）
	_box(body, Vector3(2.4, 2.4, 0.16), Vector3(0, 1.4, 3.02), _mat(Color(0.25, 0.18, 0.1), 0.8))
	# 炉口（+X 面，发光）
	_box(body, Vector3(0.3, 1.1, 1.4), Vector3(3.55, 0.9, 0), fire_mat)
	var anvil_mat := _mat(Color(0.15, 0.15, 0.16), 0.4, 0.8)
	# 铁砧（前院）
	_box(body, Vector3(1.3, 0.45, 0.7), Vector3(4.2, 0.22, 2.6), anvil_mat)
	_box(body, Vector3(0.55, 0.55, 0.55), Vector3(4.2, 0.72, 2.6), anvil_mat)
	_box(body, Vector3(0.9, 0.12, 0.5), Vector3(4.2, 1.0, 2.6), anvil_mat)
	# 工具架（侧墙）
	_box(body, Vector3(1.4, 0.08, 0.5), Vector3(-2.6, 2.2, 1.6), wood_mat)
	_box(body, Vector3(0.06, 0.9, 0.06), Vector3(-2.9, 1.75, 1.6), dark_mat)
	_box(body, Vector3(0.06, 0.9, 0.06), Vector3(-2.3, 1.75, 1.6), dark_mat)
	# 碰撞
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new(); shp.size = Vector3(7.0, 3.2, 6.0)
	col.shape = shp; col.position = Vector3(0, 1.6, 0)
	body.add_child(col)
	return body

# ---------- 仓库：木框架 + 坡顶 + 大门 ----------
static func make_warehouse(parent: Node, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var wood_mat := _mat(Color(0.55, 0.42, 0.26), 0.95)
	var roof_mat := _mat(Color(0.4, 0.3, 0.2), 0.9)
	var dark_mat := _mat(Color(0.3, 0.24, 0.16), 0.9)
	_box(body, Vector3(3.2, 2.4, 3.2), Vector3(0, 1.2, 0), wood_mat)
	# 横木框架
	for x in [-1.0, 1.0]:
		_box(body, Vector3(0.18, 2.4, 0.18), Vector3(x * 1.5, 1.2, 0), dark_mat)
	for z in [-1.0, 1.0]:
		_box(body, Vector3(0.18, 2.4, 0.18), Vector3(0, 1.2, z * 1.5), dark_mat)
	# 坡顶（单坡朝 +Z）
	var p := MeshInstance3D.new()
	var rm := BoxMesh.new(); rm.size = Vector3(3.8, 0.16, 2.4)
	p.mesh = rm
	p.position = Vector3(0, 2.7, 0.6)
	p.rotation.x = 0.35
	p.material_override = roof_mat
	body.add_child(p)
	# 大门
	_box(body, Vector3(1.8, 1.9, 0.12), Vector3(0, 1.1, 1.65), _mat(Color(0.32, 0.24, 0.15), 0.8))
	# 门前木箱
	_box(body, Vector3(0.8, 0.5, 0.6), Vector3(1.1, 0.25, 1.9), wood_mat)
	_box(body, Vector3(0.6, 0.4, 0.5), Vector3(-1.0, 0.2, 1.95), _mat(Color(0.45, 0.38, 0.28), 0.9))
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new(); shp.size = Vector3(3.2, 2.4, 3.2)
	col.shape = shp; col.position = Vector3(0, 1.2, 0)
	body.add_child(col)
	return body

# ---------- 市场摊位：木台 + 彩色布篷 + 货箱 ----------
static func make_stall(parent: Node, pos: Vector3, cloth_col: Color = Color(0.85, 0.5, 0.25)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var wood_mat := _mat(Color(0.6, 0.46, 0.28), 0.9)
	var cloth_mat := _mat(cloth_col, 0.8)
	var dark_mat := _mat(Color(0.35, 0.28, 0.2), 0.9)
	# 木台
	_box(body, Vector3(1.4, 0.9, 1.1), Vector3(0, 0.45, 0), wood_mat)
	# 桌腿
	for x in [-0.6, 0.6]:
		for z in [-0.4, 0.4]:
			_box(body, Vector3(0.12, 0.9, 0.12), Vector3(x, 0.45, z), dark_mat)
	# 布篷（斜）
	for s in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var rm := BoxMesh.new(); rm.size = Vector3(1.7, 0.06, 0.9)
		p.mesh = rm
		p.position = Vector3(0, 1.75, s * 0.45)
		p.rotation.x = -s * 0.5
		p.material_override = cloth_mat
		body.add_child(p)
	# 撑杆
	_box(body, Vector3(0.07, 1.5, 0.07), Vector3(0.6, 0.75, 0), dark_mat)
	_box(body, Vector3(0.07, 1.5, 0.07), Vector3(-0.6, 0.75, 0), dark_mat)
	# 货箱（台上）
	_box(body, Vector3(0.5, 0.35, 0.4), Vector3(0.4, 1.0, 0.15), _mat(Color(0.5, 0.42, 0.3), 0.9))
	_box(body, Vector3(0.4, 0.3, 0.35), Vector3(-0.42, 1.0, -0.12), _mat(Color(0.68, 0.5, 0.28), 0.9))
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new(); shp.size = Vector3(1.4, 0.9, 1.1)
	col.shape = shp; col.position = Vector3(0, 0.45, 0)
	body.add_child(col)
	return body

# ---------- 议事厅：石基 + 柱廊 + 三角山墙 + 大斜顶 ----------
static func make_townhall(parent: Node, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var stone_mat := _mat(Color(0.68, 0.63, 0.55), 0.95)
	var roof_mat := _mat(Color(0.45, 0.28, 0.17), 0.85)
	var col_mat := _mat(Color(0.85, 0.82, 0.75), 0.9)
	var dark_mat := _mat(Color(0.3, 0.24, 0.16), 0.9)
	# 底座
	_box(body, Vector3(8.0, 0.55, 6.2), Vector3(0, 0.28, 0), _mat(Color(0.55, 0.5, 0.44), 0.95))
	# 墙体
	_box(body, Vector3(6.0, 2.8, 4.6), Vector3(0, 1.9, 0), stone_mat)
	# 门廊立柱（正面 +Z）
	for x in [-2.0, 0.0, 2.0]:
		_cyl(body, 0.22, 0.26, 3.0, Vector3(x, 1.5, 2.6), col_mat)
	# 门廊顶
	_box(body, Vector3(6.8, 0.22, 1.6), Vector3(0, 3.15, 2.6), roof_mat)
	# 大门
	_box(body, Vector3(1.8, 2.4, 0.2), Vector3(0, 1.2, 2.15), dark_mat)
	# 大斜顶（沿 X）
	for s in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var rm := BoxMesh.new(); rm.size = Vector3(8.4, 0.2, 3.2)
		p.mesh = rm
		p.position = Vector3(0, 3.5, s * 1.6)
		p.rotation.x = -s * 0.5
		p.material_override = roof_mat
		body.add_child(p)
	_box(body, Vector3(8.4, 0.14, 0.28), Vector3(0, 3.95, 0), dark_mat)
	# 三角山墙（+Z 面填充）
	var gable := MeshInstance3D.new()
	var gm := PrismMesh.new(); gm.size = Vector3(6.4, 1.2, 0.3)
	gable.mesh = gm
	gable.position = Vector3(0, 3.1, 2.32)
	gable.material_override = stone_mat
	body.add_child(gable)
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new(); shp.size = Vector3(6.0, 3.4, 4.6)
	col.shape = shp; col.position = Vector3(0, 1.9, 0)
	body.add_child(col)
	return body

# ---------- 篝火：石圈 + 柴火 + 火焰 + 光晕 ----------
static func make_campfire(parent: Node, pos: Vector3) -> void:
	var stone_mat := _mat(Color(0.55, 0.52, 0.48), 0.95)
	var wood_mat := _mat(Color(0.4, 0.28, 0.16), 0.9)
	var fire_mat := _mat(Color(1.0, 0.6, 0.15), 0.6, 0.0, Color(1.0, 0.5, 0.1, 1.0))
	# 石圈
	for i in range(6):
		var a: float = TAU * i / 6.0
		_sph(parent, 0.14, 0.26, pos + Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), stone_mat)
	# 柴火
	for i in range(4):
		var a: float = TAU * i / 4.0 + 0.4
		var log_m := MeshInstance3D.new()
		var lm := CylinderMesh.new(); lm.top_radius = 0.07; lm.bottom_radius = 0.09; lm.height = 0.9
		log_m.mesh = lm
		log_m.position = pos + Vector3(cos(a) * 0.22, 0.16, sin(a) * 0.22)
		log_m.rotation.y = a + PI / 2
		log_m.rotation.z = 0.4
		log_m.material_override = wood_mat
		parent.add_child(log_m)
	# 火焰（发光）
	_sph(parent, 0.28, 0.6, pos + Vector3(0, 0.4, 0), fire_mat)
	_sph(parent, 0.16, 0.34, pos + Vector3(0, 0.62, 0), _mat(Color(1.0, 0.85, 0.4), 0.6, 0.0, Color(1.0, 0.8, 0.35, 1.0)))
	# 光晕（地面暖光）
	var halo := MeshInstance3D.new()
	var hm := PlaneMesh.new(); hm.size = Vector2(2.6, 2.6)
	halo.mesh = hm
	halo.position = pos + Vector3(0, 0.03, 0)
	halo.rotation.x = -PI / 2
	var halo_mat := _mat(Color(1.0, 0.6, 0.2, 0.18), 1.0)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.16)
	halo.material_override = halo_mat
	parent.add_child(halo)

# ---------- 农田：土垄 + 作物行 ----------
static func make_farm_plot(parent: Node, pos: Vector3, rows: int = 3, cols: int = 4) -> void:
	var soil_mat := _mat(Color(0.45, 0.33, 0.18), 1.0)
	var crop_mat := _mat(Color(0.25, 0.62, 0.2), 0.9)
	var crop_mat2 := _mat(Color(0.5, 0.72, 0.25), 0.9)
	# 土垄
	for r in range(rows):
		var ridge := MeshInstance3D.new()
		var rm := BoxMesh.new(); rm.size = Vector3(cols * 0.75, 0.14, 0.45)
		ridge.mesh = rm
		ridge.position = pos + Vector3(0, 0.07, (r - rows / 2.0) * 0.9)
		ridge.material_override = soil_mat
		parent.add_child(ridge)
	# 作物
	for r in range(rows):
		for c in range(cols):
			var m: Material = crop_mat if (r + c) % 2 == 0 else crop_mat2
			_cyl(parent, 0.05, 0.07, 0.5, pos + Vector3(c * 0.75 - (cols - 1) * 0.75 / 2.0, 0.25, (r - rows / 2.0) * 0.9), m)

# ---------- 精致树：树干 + 多层树冠（变体） ----------
static func make_tree(parent: Node, pos: Vector3, variant: int = 0) -> void:
	var bark_mat := _mat(Color(0.38, 0.26, 0.13), 0.95)
	var leaf_c: Color
	match variant % 3:
		0: leaf_c = Color(0.12, 0.4, 0.16)
		1: leaf_c = Color(0.16, 0.5, 0.14)
		_: leaf_c = Color(0.3, 0.55, 0.16)
	var leaf_mat := _mat(leaf_c, 0.9)
	var trunk_h: float = 1.8 + (variant % 3) * 0.5
	_cyl(parent, 0.12, 0.24, trunk_h, pos + Vector3(0, trunk_h / 2.0, 0), bark_mat)
	# 树冠 3 层
	var r: float = 0.9 + (variant % 3) * 0.25
	_sph(parent, r, r * 1.5, pos + Vector3(0, trunk_h + r * 0.5, 0), leaf_mat)
	_sph(parent, r * 0.72, r * 1.1, pos + Vector3(0.25, trunk_h + r * 1.15, 0.15), _mat(leaf_c.lightened(0.08), 0.9))
	_sph(parent, r * 0.6, r * 0.9, pos + Vector3(-0.22, trunk_h + r * 0.85, -0.2), _mat(leaf_c.darkened(0.1), 0.9))

# ---------- 地形材质 ----------
static func make_ground_material(seed_v: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = noise_tex(seed_v, 0.015, Color(0.32, 0.55, 0.22), Color(0.46, 0.68, 0.28))
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	m.uv1_scale = Vector3(6, 6, 1)
	return m

static func make_water_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.42, 0.72, 0.9)
	m.roughness = 0.05
	m.metallic = 0.15
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func make_road_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = noise_tex(42, 0.09, Color(0.58, 0.48, 0.32), Color(0.52, 0.44, 0.3))
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	return m

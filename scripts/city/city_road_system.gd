extends Node
## 城市道路系统（0.15）：让道路真正生成到场景并连接真实建筑。
## 复用现有 RoadGenerator（settlement.roads），只增量补路，不重画已有路网。

func connect_city(world) -> void:
	var settlement = world.get("settlement")
	if settlement == null or settlement.get("roads") == null: return
	var roads = settlement.roads
	var d: Dictionary = settlement.districts
	# 住宅脊柱 → 市场
	roads.create_path(Vector3(-3, 0, 17), d.market)
	# 市场 → 市政（civic）
	roads.create_path(d.market, d.civic + Vector3(0, 0, 3))
	# 市政 → 工业
	roads.create_path(d.civic, d.industrial)
	# 市场 → 商业延伸（市场南侧商铺）
	roads.create_path(d.market + Vector3(0, 0, 3), d.market + Vector3(0, 0, 6))
	# 工业 → 农田
	roads.create_path(d.industrial, d.farm)
	# 市场 → 农田
	roads.create_path(d.market, d.farm)
	# 军营接入
	roads.create_path(Vector3(3, 0, -8), Vector3(5, 0, -8))
	# 南扩新区接入（Lv4+ 住宅区）
	roads.create_path(Vector3(-8, 0, 18), Vector3(-8, 0, 24))
	print("[City] 城市道路网扩展完成")

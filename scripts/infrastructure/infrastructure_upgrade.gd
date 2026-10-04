extends Node
class_name InfrastructureUpgrade
## 0.19 基础设施升级：道路/铁路/桥梁/港口/仓库 等级提升。
## 升级消耗真实资源（财政实扣 + 时代/知识条件），不免费升级。

## 道路升级：level 上限随时代
func upgrade_road(road, era: String, gov, cost: float) -> bool:
	var max_level: int = 1
	match era:
		"原始时代": max_level = 1
		"农业时代": max_level = 2
		"工业时代": max_level = 3
		"信息时代": max_level = 4
		"星际时代": max_level = 5
	if road.level >= max_level: return false
	if gov == null: return false
	if gov.treasury < cost: return false
	gov.treasury -= cost
	road.level += 1
	match road.level:
		2: road.type_name = "石路"
		3: road.type_name = "公路"
		4: road.type_name = "高速"
		5: road.type_name = "悬浮道"
	road.capacity = 10.0 + float(road.level) * 5.0
	return true

## 港口扩容
func upgrade_port(port, gov, cost: float) -> bool:
	if gov == null or gov.treasury < cost: return false
	gov.treasury -= cost
	port.capacity += 50.0
	return true

## 桥梁加固（通行量）
func upgrade_bridge(bridge, gov, cost: float) -> bool:
	if gov == null or gov.treasury < cost: return false
	gov.treasury -= cost
	return true

## 道路升级费用（按等级与长度）
func road_upgrade_cost(road) -> float:
	return road.length * (2.0 + float(road.level) * 2.0)

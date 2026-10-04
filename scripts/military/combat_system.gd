extends Node
## 简化战斗模型（第一阶段）：不写复杂物理战斗
## 攻击 = 战力 * 士气加成；胜败 = 双方战力差 + 随机扰动

func calculate_battle(attacker, defender) -> float:
	var attack_power: float = attacker.strength * (attacker.morale / 100.0)
	var defense_power: float = defender.strength * (defender.morale / 100.0)
	return attack_power - defense_power

## 结算一场战斗，返回结果字典
## 结果按战力差决定胜方与伤亡比例；双方伤亡由各自士气保护
func resolve_battle(attacker, defender) -> Dictionary:
	var diff: float = calculate_battle(attacker, defender)
	var roll: float = randf_range(-0.15, 0.15)
	var net: float = diff * (1.0 + roll)
	var attacker_won: bool = net >= 0.0
	# 伤亡：基于对方战力带来的伤害，受己方士气削弱
	var dmg_a: float = attacker.strength * 0.10 * (1.0 - defender.morale / 200.0)
	var dmg_d: float = defender.strength * 0.10 * (1.0 - attacker.morale / 200.0)
	if attacker_won:
		dmg_a *= 0.7
		dmg_d *= 1.3
	else:
		dmg_a *= 1.3
		dmg_d *= 0.7
	var a_loss: int = mini(attacker.soldiers, maxi(1, int(round(dmg_a * randf_range(0.6, 1.4)))))
	var d_loss: int = mini(defender.soldiers, maxi(1, int(round(dmg_d * randf_range(0.6, 1.4)))))
	return {
		"attacker_won": attacker_won,
		"attacker_casualties": a_loss,
		"defender_casualties": d_loss,
		"diff": net,
	}

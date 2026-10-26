class_name CombatHit
extends RefCounted

## 一次「待结算的敌方攻击」。
##
## 设计目的（GDD §4.1~§4.4）：
##   · 把「伤害、来源、是否可弹反、击退」从动画/敌人脚本里解耦，玩家只负责结算；
##   · 弹反资格是攻击本身的属性，而不是玩家状态；训练敌人可为每招单独配置；
##   · 时间判断不需要攻击方参与：玩家在受击瞬间检查「本次防御已经按了多久」，
##     因此弹反窗口天然以「攻击实际命中时刻」为基准（见 prismatic_player.gd）。

## 结算伤害（格挡/弹反会在玩家侧再折算）。
var damage: float = 0.0
## 攻击者节点；弹反成功时玩家会调用其 on_parried()（若存在）。
var source: Node = null
## 攻击者世界坐标，用于正面 120° 判断。
var source_position: Vector3 = Vector3.ZERO
## 命中点，仅用于表现/日志。
var hit_position: Vector3 = Vector3.ZERO
## 是否具有弹反资格。GDD §4.4：所有可弹反攻击必须有清晰前摇 + 统一音效前奏。
var parryable: bool = true
## 击退强度（m/s 初速）。三段攻击第三段使用。
var knockback: float = 0.0
## 是否重击（留给 M2 的帧冻结/音效分级使用）。
var is_heavy: bool = false


func _init(p_damage: float = 0.0, p_source: Node = null, p_parryable: bool = true) -> void:
	damage = p_damage
	source = p_source
	parryable = p_parryable
	if p_source is Node3D:
		source_position = (p_source as Node3D).global_position

extends CharacterBody3D
class_name TrainingDummy

## M1 训练木桩（GDD §4.1 验证用）：
##   · 真实受击：只接受 CombatHit，扣血、显示伤害数字；
##   · 第三段击退：CharacterBody3D 速度冲量 + 阻尼，约 0.5m 位移；
##   · 不是正式敌人，不参与 M3 的 AI / 掉落 / 关卡设计。
##
## Hurtbox 采用「目标本体碰撞层 = Targets（layer 3）」：
##   player 的攻击窗口用 PhysicsShapeQueryParameters3D 查询 layer 3 的实体，
##   因此命中是真实物理相交，不是按动画进度无条件扣血。

@export var max_health: float = 200.0
## 击退阻尼（m/s²）。v=5、a=25 时位移 v²/2a = 0.5m，对应 GDD §4.6 的击退目标。
@export var knockback_drag: float = 25.0
@export var gravity: float = 18.0
@export var reset_delay: float = 2.0

var health: float = 0.0
var _spawn_transform: Transform3D
var _broken: bool = false
var _hit_count: int = 0
var _last_damage: float = 0.0
var _last_hit_from: Vector3 = Vector3.ZERO
## 自动测试用：按顺序记录每一次实际命中伤害（不参与玩法）。
var damage_log: Array[float] = []

var _visual: Node3D
var _hp_label: Label3D
var _hit_sfx: AudioStreamPlayer3D
var _hit_flash: float = 0.0

const HIT_SFX := preload("res://audio/SoundFX/hit/hit_blunt_02.wav")


func _ready() -> void:
	add_to_group("combat_target")
	collision_layer = 5  # layer 1 World + layer 3 Targets
	collision_mask = 1
	health = max_health
	_spawn_transform = global_transform
	_visual = get_node_or_null("Visual") as Node3D
	_build_labels()
	_build_sfx()
	_refresh_label()


func receive_hit(hit) -> int:
	if _broken or hit == null:
		return 0
	_last_damage = float(hit.damage)
	_last_hit_from = hit.source_position
	_hit_count += 1
	damage_log.append(_last_damage)
	health = maxf(0.0, health - _last_damage)

	var dir: Vector3 = global_position - hit.source_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001 and float(hit.knockback) > 0.0:
		var push: Vector3 = dir.normalized() * float(hit.knockback)
		velocity.x += push.x
		velocity.z += push.z

	_spawn_damage_label(_last_damage, hit.knockback)
	_hit_flash = 0.10
	if _visual != null:
		_visual.rotation.x = -0.10
	_play_hit_sfx()
	_refresh_label()
	if health <= 0.0:
		_break_dummy()
	return 1


func _physics_process(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_drag * delta)
	velocity.z = move_toward(velocity.z, 0.0, knockback_drag * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	if _visual != null:
		_visual.rotation.x = lerpf(_visual.rotation.x, 0.0, clampf(1.0 - exp(-10.0 * delta), 0.0, 1.0))
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		_update_flash()


func reset_dummy() -> void:
	_broken = false
	health = max_health
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	visible = true
	set_physics_process(true)
	damage_log.clear()
	_hit_count = 0
	_refresh_label()


func is_alive() -> bool:
	return not _broken and health > 0.0


func hit_count() -> int:
	return _hit_count


func last_damage() -> float:
	return _last_damage


func last_hit_from() -> Vector3:
	return _last_hit_from


func _break_dummy() -> void:
	if _broken:
		return
	_broken = true
	_refresh_label()
	print("[M1] 训练木桩被击碎，%.1fs 后自动复位" % reset_delay)
	await get_tree().create_timer(reset_delay).timeout
	if is_inside_tree():
		reset_dummy()


func _build_labels() -> void:
	_hp_label = Label3D.new()
	_hp_label.name = "HpLabel"
	_hp_label.font_size = 40
	_hp_label.outline_size = 8
	_hp_label.modulate = Color(1.0, 0.96, 0.82, 1.0)
	_hp_label.outline_modulate = Color(0.08, 0.06, 0.04, 1.0)
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.position = Vector3(0, 2.15, 0)
	add_child(_hp_label)


func _refresh_label() -> void:
	if _hp_label == null:
		return
	if _broken:
		_hp_label.text = "木桩：已击碎"
		_hp_label.modulate = Color(1.0, 0.55, 0.45, 1.0)
	else:
		_hp_label.text = "训练木桩  %.0f / %.0f" % [health, max_health]
		_hp_label.modulate = Color(1.0, 0.96, 0.82, 1.0)


func _spawn_damage_label(damage: float, knockback: float) -> void:
	var label := Label3D.new()
	if knockback <= 0.0:
		label.text = "-%.0f" % damage
	else:
		label.text = "-%.0f  击退!" % damage
	label.font_size = 56
	label.outline_size = 10
	label.modulate = Color(1.0, 0.86, 0.38, 1.0)
	label.outline_modulate = Color(0.10, 0.05, 0.02, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		label.queue_free()
		return
	host.add_child(label)
	label.global_position = global_position + Vector3(0, 1.9, 0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3(0, 0.9, 0), 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)


func _build_sfx() -> void:
	_hit_sfx = AudioStreamPlayer3D.new()
	_hit_sfx.name = "HitSfx"
	_hit_sfx.stream = HIT_SFX
	_hit_sfx.unit_size = 8.0
	_hit_sfx.max_distance = 30.0
	add_child(_hit_sfx)


func _play_hit_sfx() -> void:
	if _hit_sfx != null:
		_hit_sfx.pitch_scale = randf_range(0.92, 1.08)
		_hit_sfx.play()


func _update_flash() -> void:
	# 用视觉节点的临时缩放做“挨了一下”的轻微反馈，不改材质资源。
	if _visual != null:
		var s := 1.0 + 0.06 * (_hit_flash / 0.10)
		_visual.scale = Vector3(s, s, s)
		if _hit_flash <= 0.0:
			_visual.scale = Vector3.ONE

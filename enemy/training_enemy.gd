extends CharacterBody3D
class_name TrainingEnemy

## M1 简易攻击训练对象（GDD §4.2~§4.4 验证用）。
##
## 它只负责三件事：
##   1) 在玩家靠近时，以「清晰夸张的慢速前摇 + 统一低沉嗡鸣前奏」发动一次可弹反攻击；
##   2) 在 impact_time 这个明确的命中时刻，构造 CombatHit 交给玩家结算；
##   3) 被弹反时进入约 1.5s 硬直（打断攻击），让玩家看到零伤害与反击窗口。
##
## 明确不做（M3 范畴）：巡逻、发现、追击、多招 AI、掉落、正式关卡遭遇战。
## 可读性遵守 GDD §4.4：无红光提示；前奏音效与动作前摇是唯一提示。

enum State { IDLE, WINDUP, STAGGERED, DEAD }

const CombatHitScript := preload("res://combat/combat_hit.gd")
const PRELUDE := preload("res://audio/SoundFX/combat/parry_prelude.wav")
const SFX_SWING := preload("res://audio/SoundFX/swish/swish_2.wav")
const SFX_STAGGER := preload("res://audio/SoundFX/hit/hit_blunt_06.wav")
const SFX_HIT := preload("res://audio/SoundFX/hit/hit_blunt_02.wav")

@export var max_health: float = 120.0
@export var attack_damage: float = 20.0
## 进入攻击的距离。
@export var attack_range: float = 3.0
## 命中时刻允许的最大距离。
@export var attack_reach: float = 3.2
## 前摇时长 = 命中时刻（秒）。GDD §4.4 要求明确、可预期。
@export var impact_time: float = 0.9
## 命中后的收招时长。
@export var recovery_time: float = 0.8
## 两次攻击之间的间隔。
@export var cooldown_time: float = 1.1
@export var stagger_duration: float = 1.5
@export var respawn_delay: float = 4.0
@export var attack_clip: StringName = &"1H_Melee_Attack_Chop"
@export var turn_speed: float = 7.0
## 命中需要的正面夹角（dot）。0.2 ≈ 78° 半角，比玩家防御 120° 略宽。
@export var hit_cone_dot: float = 0.2
@export var gravity: float = 18.0

var health: float = 0.0
var state: State = State.IDLE
var last_hit_result: int = 0
var _timer: float = 0.0
var _cooldown: float = 0.0
var _impact_done: bool = false
var _reset_generation: int = 0
var _spawn_transform: Transform3D
var _player: Node3D

var _anim_player: AnimationPlayer
var _model: Node3D
var _hp_label: Label3D
var _prelude: AudioStreamPlayer3D
var _sfx: AudioStreamPlayer3D
var _hit_sfx: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("combat_target")
	collision_layer = 5  # layer 1 World + layer 3 Targets
	collision_mask = 1
	health = max_health
	_spawn_transform = global_transform
	_model = get_node_or_null("Model") as Node3D
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_build_labels()
	_build_audio()
	_play_idle()
	_find_player()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# 第三段击退会短暂推动守卫；这里是最小物理响应，不引入 AI/寻路。
	velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()

	if _player == null or not is_instance_valid(_player):
		_find_player()

	if state == State.STAGGERED:
		_timer = maxf(0.0, _timer - delta)
		if _timer <= 0.0:
			state = State.IDLE
			_cooldown = 0.35
			_play_idle()
		return

	if state == State.WINDUP:
		_timer += delta
		if not _impact_done:
			_face_player(delta)
			if _timer >= impact_time:
				_impact()
		if _timer >= impact_time + recovery_time:
			state = State.IDLE
			_cooldown = cooldown_time
			_play_idle()
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	# 待机时缓慢面向玩家，避免玩家一进场只看到守卫的背影；不改变攻击判定。
	_face_player(delta * 0.5)
	if _cooldown > 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("is_alive") and not _player.is_alive():
		return
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() <= attack_range:
		_start_attack()


func _start_attack() -> void:
	state = State.WINDUP
	_timer = 0.0
	_impact_done = false
	_face_player(1.0)
	var total := impact_time + recovery_time
	var clip_length := 1.0
	if _anim_player != null and _anim_player.has_animation(attack_clip):
		clip_length = _anim_player.get_animation(attack_clip).length
		_anim_player.play(attack_clip, 0.12, clip_length / maxf(total, 0.1))
	if _prelude != null:
		_prelude.play()
	print("[M1] 训练守卫起手：前摇 %.2fs（统一低沉嗡鸣前奏）→ %.2fs 命中" % [impact_time, impact_time])


func _impact() -> void:
	_impact_done = true
	if _sfx != null and SFX_SWING != null:
		_sfx.stream = SFX_SWING
		_sfx.pitch_scale = 0.9
		_sfx.play()
	if _player == null or not is_instance_valid(_player):
		return
	var to_player: Vector3 = _player.global_position - global_position
	if to_player.length() > attack_reach:
		return
	to_player.y = 0.0
	if to_player.length_squared() > 0.0001:
		var forward := -global_transform.basis.z
		if forward.dot(to_player.normalized()) < hit_cone_dot:
			return
	# The training strike is melee: world geometry must occlude it, and height
	# must count toward reach instead of projecting an infinite vertical column.
	var excluded: Array[RID] = [get_rid()]
	if _player is CollisionObject3D:
		excluded.append(_player.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP, _player.global_position + Vector3.UP, 1, excluded)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return
	var hit = CombatHitScript.new(attack_damage, self, true)
	hit.source_position = global_position
	hit.hit_position = _player.global_position + Vector3.UP
	last_hit_result = _player.receive_hit(hit)
	print("[M1] 训练守卫攻击命中判定 → 玩家结算结果 %d（0=忽略 1=受伤 2=格挡 3=弹反）" % last_hit_result)


## 玩家弹反成功时由 PrismaticPlayer 调用（GDD §4.3：敌人硬直约 1.5s）。
func on_parried() -> void:
	if state == State.DEAD:
		return
	state = State.STAGGERED
	_timer = stagger_duration
	_impact_done = true
	if _prelude != null:
		_prelude.stop()
	if _anim_player != null and _anim_player.has_animation(&"Hit_B"):
		_anim_player.play(&"Hit_B", 0.06, 1.0)
	if _sfx != null:
		_sfx.stream = SFX_STAGGER
		_sfx.pitch_scale = 0.8
		_sfx.play()
	print("[M1] 训练守卫被弹反 → 硬直 %.2fs" % stagger_duration)


func receive_hit(hit) -> int:
	if state == State.DEAD or hit == null:
		return 0
	health = maxf(0.0, health - float(hit.damage))
	var dir: Vector3 = global_position - hit.source_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001 and float(hit.knockback) > 0.0:
		velocity += dir.normalized() * float(hit.knockback)
	_spawn_damage_label(float(hit.damage))
	if _hit_sfx != null:
		_hit_sfx.pitch_scale = randf_range(0.92, 1.05)
		_hit_sfx.play()
	_refresh_label()
	if _model != null:
		_model.scale = Vector3(1.05, 0.95, 1.05)
		var tween := create_tween()
		tween.tween_property(_model, "scale", Vector3.ONE, 0.12)
	if health <= 0.0:
		_die()
	return 1


func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	var generation := _reset_generation
	if _prelude != null:
		_prelude.stop()
	if _anim_player != null and _anim_player.has_animation(&"Death_A"):
		_anim_player.play(&"Death_A", 0.1, 1.0)
	collision_layer = 1
	_refresh_label()
	print("[M1] 训练守卫倒下，%.1fs 后复位" % respawn_delay)
	await get_tree().create_timer(respawn_delay).timeout
	if is_inside_tree() and generation == _reset_generation:
		reset_enemy()


func reset_enemy() -> void:
	_reset_generation += 1
	state = State.IDLE
	_timer = 0.0
	_cooldown = 0.0
	_impact_done = false
	health = max_health
	last_hit_result = 0
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	collision_layer = 5
	if _model != null:
		_model.scale = Vector3.ONE
	if _prelude != null:
		_prelude.stop()
	_refresh_label()
	_play_idle()


func _face_player(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-to_player.x, -to_player.z)
	var t := clampf(1.0 - exp(-turn_speed * maxf(delta, 0.0)), 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_yaw, t)


func _play_idle() -> void:
	if _anim_player != null and _anim_player.has_animation(&"Idle"):
		_anim_player.play(&"Idle", 0.2, 1.0)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	_player = players[0] as Node3D if not players.is_empty() else null


func _build_audio() -> void:
	_prelude = AudioStreamPlayer3D.new()
	_prelude.name = "PreludeSfx"
	_prelude.stream = PRELUDE
	_prelude.unit_size = 12.0
	_prelude.max_distance = 60.0
	_prelude.volume_db = 2.0
	add_child(_prelude)

	_sfx = AudioStreamPlayer3D.new()
	_sfx.name = "ActionSfx"
	_sfx.unit_size = 10.0
	_sfx.max_distance = 50.0
	add_child(_sfx)

	_hit_sfx = AudioStreamPlayer3D.new()
	_hit_sfx.name = "HitSfx"
	_hit_sfx.stream = SFX_HIT
	_hit_sfx.unit_size = 8.0
	_hit_sfx.max_distance = 30.0
	add_child(_hit_sfx)


func _build_labels() -> void:
	_hp_label = Label3D.new()
	_hp_label.name = "HpLabel"
	_hp_label.font_size = 40
	_hp_label.outline_size = 8
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.position = Vector3(0, 2.35, 0)
	add_child(_hp_label)
	_refresh_label()


func _refresh_label() -> void:
	if _hp_label == null:
		return
	if state == State.DEAD:
		_hp_label.text = "训练守卫：已倒下"
		_hp_label.modulate = Color(1.0, 0.55, 0.45, 1.0)
	else:
		_hp_label.text = "训练守卫  %.0f / %.0f" % [health, max_health]
		_hp_label.modulate = Color(0.86, 0.94, 1.0, 1.0)


func _spawn_damage_label(damage: float) -> void:
	var label := Label3D.new()
	label.text = "-%.0f" % damage
	label.font_size = 56
	label.outline_size = 10
	label.modulate = Color(1.0, 0.86, 0.38, 1.0)
	label.outline_modulate = Color(0.06, 0.05, 0.02, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		label.queue_free()
		return
	host.add_child(label)
	label.global_position = global_position + Vector3(0, 2.1, 0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3(0, 0.9, 0), 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)


# ---------------------------------------------------------------- 测试 / HUD 查询
func is_alive() -> bool:
	return state != State.DEAD


func is_staggered() -> bool:
	return state == State.STAGGERED


func stagger_time_left() -> float:
	return _timer if state == State.STAGGERED else 0.0


func time_to_impact() -> float:
	if state != State.WINDUP:
		return -1.0
	return maxf(0.0, impact_time - _timer)


func state_name() -> String:
	match state:
		State.WINDUP:
			return "WINDUP"
		State.STAGGERED:
			return "STAGGERED"
		State.DEAD:
			return "DEAD"
		_:
			return "IDLE"


func health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)


func prelude_playing() -> bool:
	return _prelude != null and _prelude.playing


func start_attack_for_test() -> void:
	if state == State.IDLE:
		_start_attack()

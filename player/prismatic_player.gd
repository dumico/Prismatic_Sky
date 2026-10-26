extends CharacterBody3D
class_name PrismaticPlayer

## 棱彩天空 · 玩家控制器（M0）
##
## 本文件按里程碑分阶段补齐，严禁越界实现（GDD §0.3、§8、§9）：
##   M0-3：挂上 KayKit Adventurers 模型、碰撞体、动画骨架，
##         并保留模板的「格挡/弹反」信号框架锚点供 M1 使用（GDD §8、§11.1）。
##   M0-4（本次）：按 §3.3 参数表实现移动手感（全部 @export，基础值 × 修正系数，
##         土狼时间 + 跳跃缓冲，落速硬直 + 尘土粒子）。
##   M0-5：按 §3.2 实现滑翔（0.25s 进入过渡、俯冲加速、拉升耗速换高度）。
##
## 模型：KayKit Adventurers 1.0 / Rogue_Hooded（GDD §7 台账「玩家模型」职责，CC0）。
##       该 GLB 自带 76 条动画（Idle / Walking_A~C / Running_A~B / Jump_* / Blocking …），
##       骨骼为 KayKit 自有命名，故 M0 无需做动画重定向（见 assets_repo/SOURCES.md）。
##       模型自身朝向为 +Z（脚尖与披风两侧数据互证），Godot 约定 -Z 为前，
##       故场景内 Model 节点已烘焙 180° Y 旋转。
##
## 核心原则【锁定，GDD §3.3】：粘手只体现在表现层（加减速、动画、惯性），
##       绝不体现在判定层 —— 土狼时间与跳跃缓冲照留，判定永远宽容。

# ---------------------------------------------------------------- 模型与动画
@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer
@onready var collision: CollisionShape3D = $Collision

## 动画片段名（@export 便于策划换模型时直接改，无需改代码）。
@export_group("动画片段")
@export var clip_idle: StringName = &"Idle"
@export var clip_walk: StringName = &"Walking_A"
@export var clip_run: StringName = &"Running_A"
@export var clip_air_fall: StringName = &"Jump_Idle"
@export var clip_air_land: StringName = &"Jump_Land"
@export var clip_jump_start: StringName = &"Jump_Start"
@export var clip_guard: StringName = &"Blocking"
@export var clip_guard_hit: StringName = &"Block_Hit"
@export var clip_guard_break: StringName = &"Hit_B"
@export var clip_hurt: StringName = &"Hit_A"

## 地面移动动画混合：行走在中点，奔跑在末端（由 walk_speed / run_speed 驱动）。
@export_range(0.05, 0.95, 0.05) var walk_blend_point: float = 0.5

# ---------------------------------------------------------------- GDD §3.3 移动手感基础值
## ★ 2026-10-02 M0 试玩反馈调参（GDD §3.3 全表【暂定】，推翻条件「粘变成拖」已触发）：
##   只动地面移动四项：walk 2.5→4.0（普通移动提速；与奔跑的落差 2.4×→1.5×）、
##   accel 12→16、decel 24→30、turn 10→16（起停与转向更跟手，仍保留加减速的「粘手」表现层）。
##   run_speed 与全部滑翔专用参数**未动**，glide_speed = run_speed × 1.15 仍为 6.9；滑翔的
##   0.25s 展开、垂直钳制、俯冲/拉升机制不变。注：`accel_ground` 按 §3.3 现有公式也参与空中/
##   滑翔的水平响应，其水平加速度由 6.6 升至 8.8 m/s²，属本次地面调参的派生影响，待复试玩确认。
##   回退：把 walk / accel / decel / turn 四项基础值改回 2.5 / 12.0 / 24.0 / 10.0 = §3.3 v1 初值。
@export_group("GDD §3.3 基础值 · 位移")
## 有分量不笨重。
@export var gravity_base: float = 18.0
## 跳高 = v²/(2g) = 7.5²/36 ≈ 1.56m ≈ 1.6m。
@export var jump_velocity_base: float = 7.5
## 不按 Shift 的普通移动速度（试玩反馈：原 2.5 太慢）。
@export var walk_speed_base: float = 4.0
## Shift 冲刺满速。本次**未调**：不提高冲刺上限，同时保证滑翔基准速度不变。
@export var run_speed_base: float = 6.0
## 0→奔跑满速约 0.375s（6.0 / 16.0）、0→走速 0.25s；起步仍留「蹬地感」（粘手核心①）。
@export var accel_ground_base: float = 16.0
## 从奔跑满速刹停约 0.20s（6.0 / 30.0），停比启快（粘手核心①）。
@export var decel_ground_base: float = 30.0
## 空中加速度打五五折，起跳有承诺感（粘手核心②）。
@export var air_control_base: float = 0.55

@export_group("GDD §3.3 基础值 · 判定宽容（★ 判定层，只加不减）")
## 离开地面后仍可起跳的宽限。
@export var coyote_time_base: float = 0.12
## 落地前提前按跳的缓冲。
@export var jump_buffer_base: float = 0.12

@export_group("GDD §3.3 基础值 · 表现层")
## 朝向平滑转身速率（指数收敛，帧率无关）。试玩反馈「转向要更灵活」：10.0 → 16.0，
## 时间常数 0.10s → 0.0625s；仍是指数平滑、不瞬转（GDD §3.3 粘手留在表现层）。
@export var turn_smooth_base: float = 16.0
## 超过此落速 → 硬直 + 尘土粒子（粘手核心③）。
@export var landing_stiff_threshold_base: float = 12.0
## 蹲伏硬直时长。
@export var landing_stiff_time: float = 0.12
## 空中动画淡入速率。
@export var air_blend_speed: float = 12.0

@export_group("GDD §3.3 基础值 · 滑翔（GDD §3.2）")
## 披风展开过渡时长。进入与退出都是渐变，不瞬切。
@export var glide_enter_time_base: float = 0.25
## 滑翔时被钳制的缓慢落速。
@export var glide_fall_speed_base: float = -2.5
## 垂直速度向滑翔目标收敛的速率（俯冲 / 拉升共用）。
@export var glide_dive_accel_base: float = 8.0
## 满俯冲时的最大落速。
@export var dive_max_base: float = 12.0
## 拉升带来的垂直速度增量（由水平速度换来）。
@export var glide_lift_boost_base: float = 3.0
## 「水平移速略增」的倍率。GDD §3.2 只写了「略增」未给数值，此为 M0 初值（§3.3 全表【暂定】）。
@export var glide_speed_multiplier: float = 1.15
## 「俯冲换速度」：满俯冲时水平速度相对滑翔基准的增量比例。GDD 未给数值，M0 初值。
@export var glide_dive_speed_gain: float = 0.35
## 滑翔时身体前倾角（表现层占位；真正的滑翔姿态/披风动画留给后续里程碑）。
@export var glide_body_pitch: float = 0.45
## 俯冲时额外前倾角。
@export var glide_dive_pitch: float = 0.30
## 披风展开的最大横向缩放（表现层占位，用模型自带的 Rogue_Cape 网格）。
@export var glide_cape_spread: float = 1.9

@export_group("修正系数（GDD §11.2：基础值 × 修正系数，初始 1.0）")
@export var coefficients: MovementCoefficients

# ---------------------------------------------------------------- M1 战斗基础值（GDD §4）
## 全部是可调 @export，遵守 GDD §0.3 / §11.2；不新建战斗配置框架。
@export_group("M1 · 三段轻击（GDD §4.1）")
## 三段动作优先复用 KayKit 自带 1H 攻击动画；换模型时只改这里。
@export var attack_clips: Array[StringName] = [
	&"1H_Melee_Attack_Slice_Diagonal",
	&"1H_Melee_Attack_Slice_Horizontal",
	&"1H_Melee_Attack_Chop",
]
## 第一段基础伤害；实际伤害 = attack_damage × 对应倍率（1 : 1 : 1.5）。
@export var attack_damage: float = 10.0
## 三段伤害倍率。GDD §4.1 锁定比例 1 : 1 : 1.5。
@export var attack_damage_multipliers: Array[float] = [1.0, 1.0, 1.5]
## 动画整体播放倍速（GDD §4.6 表中「整体 1.1 倍速」的 M1 近似值）。
@export_range(0.5, 2.5, 0.05) var attack_anim_speed: float = 1.3
## 命中窗口占「本次攻击有效时长」的比例：从 WINDUP 结束到 RECOVERY 之前。
@export_range(0.0, 1.0, 0.01) var attack_hit_start_ratio: float = 0.38
@export_range(0.0, 1.0, 0.01) var attack_hit_end_ratio: float = 0.60
## 攻击判定盒中心（相对角色，前向为 -Z 方向的世界偏移）。
@export var attack_hitbox_reach: float = 1.05
@export var attack_hitbox_height: float = 0.95
@export var attack_hitbox_size: Vector3 = Vector3(1.6, 1.6, 2.0)
## 第三段小幅击退（m/s 初速）。0.5m / 0.1s 目标由目标自身的阻尼决定。
@export var attack_knockback: float = 5.0

@export_group("M1 · 软锁定（GDD §4.1）")
## 3m 内选择最近的敌对目标，攻击前摇中朝其转向。
@export var soft_lock_range: float = 3.0
@export var soft_lock_turn_speed: float = 24.0

@export_group("M1 · 长按防御与破防（GDD §4.2）")
## 正面防御角度：以角色战斗朝向为轴，左右各 guard_arc_deg/2。
@export var guard_arc_deg: float = 120.0
## 正面减伤 70%。
@export_range(0.0, 1.0) var guard_damage_reduction: float = 0.7
## 防御时移速 = 正常移速的 50%。
@export_range(0.1, 1.0) var guard_speed_multiplier: float = 0.5
## 防御时朝向追赶相机水平朝向的速率（避免后退时把背露给敌人）。
@export var guard_turn_speed: float = 14.0
## 隐藏防御耐久：上限 / 每次格挡累积 / 脱手后每秒恢复 / 恢复前延迟。
@export var guard_pressure_max: float = 100.0
@export var guard_pressure_per_block: float = 28.0
@export var guard_pressure_regen: float = 20.0
@export var guard_regen_delay: float = 0.8
## 破防后踉跄约 1s，期间不能防御、不能攻击。
@export var guard_break_duration: float = 1.0
## 防御姿态动画混合速率。
@export var guard_blend_speed: float = 14.0

@export_group("M1 · 弹反与反击强化（GDD §4.3 / §4.6）")
## 核心弹反窗口：0.2s，以「本次防御按下后、攻击命中时」的时长判断。
## ★ 不是「按住防御后的前 0.2s 免疫所有攻击」：0.2s 后仍处于防御，只算普通格挡。
@export var parry_window: float = 0.2
## 弹反成功后 1s 内下一击 ×2，命中才消耗。
@export var parry_counter_window: float = 1.0
@export var parry_counter_multiplier: float = 2.0
## 时间减速：0.1 倍速保持 0.25s，再用 0.15s 回弹（真实时间，不受 time_scale 影响）。
@export_range(0.01, 1.0) var parry_slowmo_scale: float = 0.1
@export var parry_slowmo_hold: float = 0.25
@export var parry_slowmo_recover: float = 0.15

@export_group("M1 · 生命与受击")
@export var max_health: float = 100.0
## 受击后的短暂无敌，避免同一动作多帧重复结算。
@export var hit_invuln_time: float = 0.35

@export_group("M1 · 装备挂点（占位视觉，GDD §8.2 / §8.3）")
## 防御时通过骨骼挂点显示一个占位小盾，让 120° 正面防御更可读。
## 换模型时若没有该骨骼会自动跳过，不影响任何战斗判定。
@export var show_guard_shield: bool = true
@export var guard_shield_bone: StringName = &"handslot.l"

# ---------------------------------------------------------------- 运行时状态
var input_enabled: bool = true
var input_dir: Vector2 = Vector2.ZERO
var run_held: bool = false
var jump_held: bool = false
## 滑翔的俯仰输入：+1 = 俯冲（机头朝下），-1 = 拉升。默认由相机俯仰角映射而来。
var glide_pitch_input: float = 0.0
var airborne: bool = false

var _jump_pressed: bool = false
var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _landing_stiff_timer: float = 0.0
var _airborne_weight: float = 0.0
var _airborne_target: float = 0.0
## 滑翔过渡权重 0→1：0.25s 披风展开，任何时刻都不瞬切（GDD §3.2）。
var _glide_blend: float = 0.0
## 披风是否已展开（闩锁；落地或松开跳跃才解除）。
var _glide_engaged: bool = false
var _anim_tree: AnimationTree
var _camera: Camera3D
var _cape: MeshInstance3D
var _cape_base_scale: Vector3 = Vector3.ONE
var _model_base_rotation: Vector3 = Vector3.ZERO
var _attack_anim_node: AnimationNodeAnimation
var _react_anim_node: AnimationNodeAnimation

signal jump_started
signal landed(fall_speed: float)
signal hard_landed(fall_speed: float)
signal glide_started
signal glide_ended

# ---------------------------------------------------------------- M1 战斗状态
enum CombatState { NORMAL, ATTACK, GUARD, GUARD_BROKEN }
enum AttackPhase { NONE, WINDUP, ACTIVE, RECOVERY }
enum HitResult { IGNORED, DAMAGE, BLOCK, PARRY }

signal attack_started(step: int)
signal attack_hit(target: Node, damage: float)
signal guard_started
signal guard_ended
signal guard_broken
signal guard_pressure_changed(ratio: float)
signal parried(source: Node)
signal player_damaged(amount: float, source: Node)
signal player_died
signal counter_ready

var _combat_state: CombatState = CombatState.NORMAL
var _attack_step: int = 0
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_time: float = 0.0
var _attack_length: float = 0.0
var _attack_queued: bool = false
var _attack_swing_played: bool = false
var _swing_hit_ids: Dictionary = {}
var _attack_pressed: bool = false
var _guard_pressed: bool = false
var _guard_released: bool = false
var _guard_held: bool = false
var _guard_time: float = 0.0
var _guard_pressure: float = 0.0
var _guard_regen_delay_left: float = 0.0
var _guard_break_timer: float = 0.0
var _guard_visual: float = 0.0
var _soft_lock_target: Node3D = null
var _soft_lock_yaw: float = 0.0
var _counter_timer: float = 0.0
var _invuln_timer: float = 0.0
var _slowmo_token: int = 0
var health: float = 0.0
var _dead: bool = false

## 兼容 M0 末尾保留的模板锚点语义（M1 真实实现见下方「M1 战斗」段）。
signal block_started
signal parry_started
var guarding: bool = false
var parry_active: bool = false

# ---------------------------------------------------------------- 参数（基础值 × 修正系数）
func gravity() -> float:
	return gravity_base * coefficients.gravity


func jump_velocity() -> float:
	return jump_velocity_base * coefficients.jump_velocity


func walk_speed() -> float:
	return walk_speed_base * coefficients.walk_speed


func run_speed() -> float:
	return run_speed_base * coefficients.run_speed


func accel_ground() -> float:
	return accel_ground_base * coefficients.accel_ground


func decel_ground() -> float:
	return decel_ground_base * coefficients.decel_ground


func air_control() -> float:
	return air_control_base * coefficients.air_control


## 判定宽容项有下限保护：系数再小也不许把土狼时间/跳跃缓冲压到 0（GDD §3.3【锁定】隔离原则）。
func coyote_time() -> float:
	return maxf(coyote_time_base * coefficients.coyote_time, 0.02)


func jump_buffer() -> float:
	return maxf(jump_buffer_base * coefficients.jump_buffer, 0.02)


func turn_smooth() -> float:
	return turn_smooth_base * coefficients.turn_smooth


func landing_stiff_threshold() -> float:
	return landing_stiff_threshold_base * coefficients.landing_stiff_threshold


func glide_enter_time() -> float:
	return maxf(glide_enter_time_base * coefficients.glide_enter_time, 0.01)


func glide_fall_speed() -> float:
	return glide_fall_speed_base * coefficients.glide_fall_speed


func glide_dive_accel() -> float:
	return glide_dive_accel_base * coefficients.glide_dive_accel


func dive_max() -> float:
	return dive_max_base * coefficients.dive_max


func glide_lift_boost() -> float:
	return glide_lift_boost_base * coefficients.glide_lift_boost


## 滑翔基准水平速度：run_speed × 「略增」倍率（GDD §3.2）。
func glide_speed() -> float:
	return run_speed() * glide_speed_multiplier


func _init() -> void:
	if coefficients == null:
		coefficients = MovementCoefficients.new()


func _ready() -> void:
	if coefficients == null:
		coefficients = MovementCoefficients.new()
	health = max_health
	animation_setup()
	_build_dust()
	_build_combat_feedback()
	_build_guard_shield()
	_cache_cape()
	_model_base_rotation = model.rotation
	_camera = get_viewport().get_camera_3d()


func _exit_tree() -> void:
	# 弹反慢动作是全局状态；玩家被释放时必须恢复，避免测试或重启场景卡在 0.1 倍速。
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	_read_input()
	_tick_timers(delta)
	_tick_combat(delta)

	var was_on_floor := is_on_floor()
	_update_glide_state(delta, was_on_floor)

	if not was_on_floor:
		if _glide_blend > 0.001:
			_apply_glide_vertical(delta)
		else:
			velocity.y -= gravity() * delta

	var wish := wish_direction()
	if _combat_locks_movement():
		wish = Vector3.ZERO
	_apply_horizontal(delta, wish, was_on_floor)
	_try_jump(was_on_floor)
	_rotate_toward(wish, delta)

	var fall_speed := maxf(0.0, -velocity.y)
	move_and_slide()

	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		_on_landed(fall_speed)
	if on_floor:
		_coyote_timer = coyote_time()
	airborne = not on_floor

	_update_animation(delta)
	_update_glide_visuals()
	_jump_pressed = false


# ---------------------------------------------------------------- 输入
func _read_input() -> void:
	if not input_enabled or _dead:
		return
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	run_held = Input.is_action_pressed("run")
	jump_held = Input.is_action_pressed("jump")
	if Input.is_action_just_pressed("jump"):
		_jump_pressed = true
	# GDD §3.1：鼠标左键 / X = 攻击；鼠标右键长按 / LB = 防御。
	# 这两个动作是模板已存在的 use_weapon_light / use_gadget_light，不新增输入映射。
	if Input.is_action_just_pressed("use_weapon_light"):
		_attack_pressed = true
	_guard_held = Input.is_action_pressed("use_gadget_light")
	if Input.is_action_just_pressed("use_gadget_light"):
		_guard_pressed = true
	if Input.is_action_just_released("use_gadget_light"):
		_guard_released = true
	# 滑翔俯仰：相机低头 = 俯冲，抬头 = 拉升（GDD §3.2 俯冲换速度 / 拉升耗速换高度）
	var cam := get_viewport().get_camera_3d()
	if cam is SpringCamera:
		glide_pitch_input = clampf(-(cam as SpringCamera).pitch / deg_to_rad(45.0), -1.0, 1.0)


## 供 headless 验收脚本注入「本帧按下跳跃」。
func request_jump() -> void:
	_jump_pressed = true


func request_jump_release() -> void:
	jump_held = false


func _tick_timers(delta: float) -> void:
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_landing_stiff_timer = maxf(0.0, _landing_stiff_timer - delta)
	if _jump_pressed:
		_jump_buffer_timer = jump_buffer()


## 相机相对的水平期望方向（GDD §3.1：WASD 相对相机）。
func wish_direction() -> Vector3:
	if input_dir.length_squared() < 0.0001:
		return Vector3.ZERO
	var b := _movement_basis()
	var dir := b.x * input_dir.x + b.z * input_dir.y
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()


func _movement_basis() -> Basis:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera != null and _camera is SpringCamera:
		return (_camera as SpringCamera).yaw_basis()
	if _camera != null:
		var fwd := -_camera.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length_squared() > 0.0001:
			return Basis.looking_at(fwd.normalized(), Vector3.UP)
	return global_transform.basis


# ---------------------------------------------------------------- 移动
func _apply_horizontal(delta: float, wish: Vector3, on_floor: bool) -> void:
	var rate: float
	var target := Vector3.ZERO

	if on_floor:
		# 硬直期间只允许减速（粘手核心③：落地要"沉"一下，但不能夺走判定宽容）
		var accelerating := wish != Vector3.ZERO and not _is_stiff()
		rate = accel_ground() if accelerating else decel_ground()
		var ground_speed := 0.0
		if accelerating:
			ground_speed = (run_speed() if run_held else walk_speed()) * _ground_speed_scale()
		target = wish * ground_speed
	elif _glide_blend > 0.001:
		# 滑翔：水平速度由俯仰决定（俯冲换速度、拉升耗速度），无输入时沿当前朝向继续滑
		rate = accel_ground() * air_control()
		var dir := wish
		if dir.length_squared() < 0.0001:
			dir = player_forward()
			dir.y = 0.0
			dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.ZERO
		var glide_target := dir * glide_horizontal_speed()
		# 过渡期与当前速度混合：0.25s 披风展开，不瞬切（GDD §3.2）
		target = Vector3(velocity.x, 0.0, velocity.z).lerp(glide_target, _glide_blend)
	else:
		rate = accel_ground() * air_control()
		var air_speed := 0.0
		if wish != Vector3.ZERO and not _is_stiff():
			air_speed = run_speed() if run_held else walk_speed()
		target = wish * air_speed

	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)


## 滑翔俯仰：+1 俯冲，-1 拉升。
func glide_pitch() -> float:
	return clampf(glide_pitch_input, -1.0, 1.0)


## 当前俯仰下的滑翔水平目标速度：俯冲加速，拉升则把速度换成高度。
func glide_horizontal_speed() -> float:
	var d := glide_pitch()
	var base := glide_speed() * (1.0 + maxf(0.0, d) * glide_dive_speed_gain)
	# 「拉升耗速度换高度」：拉起多少垂直增量，就付出等量的水平速度（能量直换，不引入新数值）
	return maxf(base - glide_lift_boost() * maxf(0.0, -d), glide_speed() * 0.4)


## 滑翔过渡权重与状态推进。
## 触发规则：滞空 + 按住跳跃 + 已过顶点（开始下坠）→ 展开披风；此后**闩锁**保持展开，
## 直到落地或松开跳跃。闩锁是必须的：拉升会让 vertical velocity 变正，
## 若每帧都用「正在下坠」重新判定，就会「一爬升就收回披风」，永远拉不起来。
func _update_glide_state(delta: float, on_floor: bool) -> void:
	if on_floor or not jump_held:
		_glide_engaged = false
	elif not _glide_engaged and velocity.y <= 0.0:
		_glide_engaged = true

	var rate := 1.0 / glide_enter_time()
	var before := _glide_blend
	_glide_blend = move_toward(_glide_blend, 1.0 if _glide_engaged else 0.0, rate * delta)
	if before <= 0.5 and _glide_blend > 0.5:
		glide_started.emit()
	elif before > 0.5 and _glide_blend <= 0.5:
		glide_ended.emit()


func _apply_glide_vertical(delta: float) -> void:
	var d := glide_pitch()
	var dive := maxf(0.0, d)
	var lift := maxf(0.0, -d)
	var target_y := lerpf(glide_fall_speed(), -dive_max(), dive) + glide_lift_boost() * lift
	# 过渡期保留一部分重力，避免「刚离地就飘住」；b=1 时重力完全交给滑翔钳制
	velocity.y -= gravity() * (1.0 - _glide_blend) * delta
	velocity.y = move_toward(velocity.y, target_y, glide_dive_accel() * _glide_blend * delta)


# ---------------------------------------------------------------- 滑翔表现层
func _cache_cape() -> void:
	_cape = model.find_child("Rogue_Cape", true, false) as MeshInstance3D
	if _cape != null:
		_cape_base_scale = _cape.scale


func _update_glide_visuals() -> void:
	var lean := glide_body_pitch * _glide_blend
	lean += glide_dive_pitch * _glide_blend * maxf(0.0, glide_pitch())
	model.rotation = Vector3(
		_model_base_rotation.x + lean, _model_base_rotation.y, _model_base_rotation.z
	)
	if _cape != null:
		var spread := lerpf(1.0, glide_cape_spread, _glide_blend)
		_cape.scale = Vector3(
			_cape_base_scale.x * spread,
			_cape_base_scale.y,
			_cape_base_scale.z * lerpf(1.0, 1.1, _glide_blend)
		)


func glide_blend() -> float:
	return _glide_blend


func is_gliding() -> bool:
	return _glide_blend > 0.5


func cape_scale() -> Vector3:
	return _cape.scale if _cape != null else Vector3.ONE


func _is_stiff() -> bool:
	return _landing_stiff_timer > 0.0


func _try_jump(on_floor: bool) -> void:
	if _jump_buffer_timer <= 0.0 or _is_stiff() or not _can_jump():
		return
	if not (on_floor or _coyote_timer > 0.0):
		return
	velocity.y = jump_velocity()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	if _anim_tree != null:
		_anim_tree.set("parameters/jump/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	jump_started.emit()


func _rotate_toward(wish: Vector3, delta: float) -> void:
	# 攻击：前摇阶段朝软锁定目标转；命中/收招阶段锁死朝向，保证判定与动画方向一致。
	if _combat_state == CombatState.ATTACK:
		if _attack_phase == AttackPhase.WINDUP:
			_update_soft_lock()
			if is_instance_valid(_soft_lock_target):
				_rotate_yaw_toward(_soft_lock_yaw, soft_lock_turn_speed, delta)
		return
	# 防御：角色战斗朝向跟随相机水平朝向，WASD 变成相对相机的移动；
	# 这样后退时不会把背露给敌人，正面 120° 也有一个稳定、可读的基准（GDD §4.2）。
	if _combat_state == CombatState.GUARD:
		_rotate_yaw_toward(_camera_combat_yaw(), guard_turn_speed, delta)
		return
	if _combat_state == CombatState.GUARD_BROKEN:
		return
	if wish.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-wish.x, -wish.z)
	_rotate_yaw_toward(target_yaw, turn_smooth(), delta)


func _rotate_yaw_toward(target_yaw: float, speed: float, delta: float) -> void:
	var t := clampf(1.0 - exp(-speed * delta), 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_yaw, t)


func _on_landed(fall_speed: float) -> void:
	landed.emit(fall_speed)
	if fall_speed >= landing_stiff_threshold():
		_landing_stiff_timer = landing_stiff_time
		hard_landed.emit(fall_speed)
		_emit_dust()


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func air_time_left() -> float:
	return _coyote_timer


func jump_buffer_left() -> float:
	return _jump_buffer_timer


func is_stiff() -> bool:
	return _is_stiff()


# ---------------------------------------------------------------- 落地尘土（GDD §3.3 粘手核心③）
var _dust: GPUParticles3D


func _build_dust() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 2.2
	mat.gravity = Vector3(0, -9.0, 0)
	mat.scale_min = 0.4
	mat.scale_max = 1.0

	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.88, 0.88, 0.84, 0.5)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = sm

	_dust = GPUParticles3D.new()
	_dust.name = "LandingDust"
	_dust.amount = 16
	_dust.lifetime = 0.5
	_dust.one_shot = true
	_dust.explosiveness = 0.95
	_dust.emitting = false
	_dust.process_material = mat
	_dust.draw_pass_1 = quad
	_dust.position = Vector3(0, 0.06, 0)
	add_child(_dust)


func _emit_dust() -> void:
	if _dust != null:
		_dust.restart()
		_dust.emitting = true


## 构建动画树：ground(Idle↔Walk↔Run) 与 air(Jump_Idle↔Jump_Land) 按滞空权重混合，
## 起跳再叠一层 Jump_Start 的单次播放。
## 采用代码构建而非 .tres：Godot 4.7.1 下手写 AnimationNodeBlendTree 资源易错，
## 且本树只需四个节点；可调数值一律走上面的 @export（GDD §0.3）。
func animation_setup() -> void:
	if anim_player == null:
		push_error("PrismaticPlayer: 找不到 %s/AnimationPlayer" % model.name)
		return

	var ground := AnimationNodeBlendSpace1D.new()
	ground.min_space = 0.0
	ground.max_space = 1.0
	ground.add_blend_point(_anim_node(clip_idle), 0.0, -1, "idle")
	ground.add_blend_point(_anim_node(clip_walk), walk_blend_point, -1, "walk")
	ground.add_blend_point(_anim_node(clip_run), 1.0, -1, "run")

	var air := AnimationNodeBlendSpace1D.new()
	air.min_space = 0.0
	air.max_space = 1.0
	air.add_blend_point(_anim_node(clip_air_fall), 0.0, -1, "fall")
	air.add_blend_point(_anim_node(clip_air_land), 1.0, -1, "land")

	var mix := AnimationNodeBlend2.new()
	var jump := AnimationNodeOneShot.new()

	# 起跳单次：补上模板 M0 遗留的 input 1（Jump_Start），否则 one-shot 没有可播放的动画。
	var jump_anim := AnimationNodeAnimation.new()
	jump_anim.animation = clip_jump_start

	# 三段攻击共用同一个 one-shot + 可动态替换的 AnimationNodeAnimation；切换时只改
	# animation 再 FIRE，动画与状态机时间基准统一由 _attack_length 控制。
	var attack_anim := AnimationNodeAnimation.new()
	var attack_speed := AnimationNodeTimeScale.new()
	var attack := AnimationNodeOneShot.new()
	attack.fadein_time = 0.08
	attack.fadeout_time = 0.12
	attack.autorestart = true

	var guard_anim := AnimationNodeAnimation.new()
	guard_anim.animation = clip_guard
	guard_anim.loop_mode = Animation.LOOP_LINEAR
	var guard := AnimationNodeBlend2.new()

	# 受击 / 格挡 / 破防的全身反应单次。
	var react_anim := AnimationNodeAnimation.new()
	var react := AnimationNodeOneShot.new()
	react.fadein_time = 0.05
	react.fadeout_time = 0.10
	react.autorestart = true

	var tree := AnimationNodeBlendTree.new()
	tree.add_node("ground", ground)
	tree.add_node("air", air)
	tree.add_node("air_mix", mix)
	tree.add_node("jump_anim", jump_anim)
	tree.add_node("jump", jump)
	tree.add_node("attack_anim", attack_anim)
	tree.add_node("attack_speed", attack_speed)
	tree.add_node("attack", attack)
	tree.add_node("guard_anim", guard_anim)
	tree.add_node("guard", guard)
	tree.add_node("react_anim", react_anim)
	tree.add_node("react", react)
	tree.connect_node("air_mix", 0, "ground")
	tree.connect_node("air_mix", 1, "air")
	tree.connect_node("jump", 0, "air_mix")
	tree.connect_node("jump", 1, "jump_anim")
	tree.connect_node("attack_speed", 0, "attack_anim")
	tree.connect_node("attack", 0, "jump")
	tree.connect_node("attack", 1, "attack_speed")
	tree.connect_node("guard", 0, "attack")
	tree.connect_node("guard", 1, "guard_anim")
	tree.connect_node("react", 0, "guard")
	tree.connect_node("react", 1, "react_anim")
	tree.connect_node("output", 0, "react")

	_attack_anim_node = attack_anim
	_react_anim_node = react_anim

	_anim_tree = AnimationTree.new()
	_anim_tree.name = "AnimTree"
	add_child(_anim_tree)
	_anim_tree.anim_player = _anim_tree.get_path_to(anim_player)
	_anim_tree.tree_root = tree
	_anim_tree.active = true

	set_ground_speed_ratio(0.0)
	set_airborne(false)
	set_air_phase(0.0)
	_anim_tree.set("parameters/guard/blend_amount", 0.0)
	_anim_tree.set("parameters/attack_speed/scale", attack_anim_speed)


func _anim_node(clip: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n


# ---------------------------------------------------------------- 动画接口（M0-4/M0-5 调用）
## 0 = 静止，walk_blend_point = 行走，1 = 奔跑。
func set_ground_speed_ratio(ratio: float) -> void:
	if _anim_tree == null:
		return
	_anim_tree.set("parameters/ground/blend_position", clampf(ratio, 0.0, 1.0))


## 落地/离地切换（目标权重；实际过渡在 _update_animation 里按 air_blend_speed 指数收敛）。
func set_airborne(is_airborne: bool) -> void:
	_airborne_target = 1.0 if is_airborne else 0.0


## 驱动动画权重：地面按水平速度比例混合 Idle↔Walk↔Run，滞空权重指数收敛。
func _update_animation(delta: float) -> void:
	if _anim_tree == null:
		return
	var speed := horizontal_speed()
	var ratio := 0.0
	var ws := walk_speed()
	var rs := run_speed()
	if speed <= ws:
		ratio = (speed / ws) * walk_blend_point if ws > 0.001 else 0.0
	else:
		var span := maxf(rs - ws, 0.001)
		ratio = walk_blend_point + clampf((speed - ws) / span, 0.0, 1.0) * (1.0 - walk_blend_point)
	set_ground_speed_ratio(ratio)

	var t := clampf(1.0 - exp(-air_blend_speed * delta), 0.0, 1.0)
	_airborne_weight = lerpf(_airborne_weight, _airborne_target, t)
	_anim_tree.set("parameters/air_mix/blend_amount", _airborne_weight)
	# 0 = 滞空循环（Jump_Idle），1 = 落地缓冲（Jump_Land）；硬直窗口就是落地缓冲。
	set_air_phase(1.0 if _is_stiff() else 0.0)

	# 防御姿态权重：0 = 移动/攻击，1 = 持盾防御。平滑过渡，避免一帧翻姿态。
	var guard_target := 1.0 if _combat_state == CombatState.GUARD else 0.0
	_guard_visual = move_toward(_guard_visual, guard_target, guard_blend_speed * delta)
	_anim_tree.set("parameters/guard/blend_amount", _guard_visual)
	if _guard_shield != null:
		_guard_shield.visible = _guard_visual > 0.04
		var shield_scale := lerpf(0.7, 1.0, _guard_visual)
		_guard_shield.scale = Vector3.ONE * shield_scale


func set_airborne_weight(weight: float) -> void:
	_airborne_target = clampf(weight, 0.0, 1.0)


## 滞空阶段：0 = 滞空循环，1 = 落地缓冲。
func set_air_phase(phase: float) -> void:
	if _anim_tree == null:
		return
	_anim_tree.set("parameters/air/blend_position", clampf(phase, 0.0, 1.0))


func play_jump_start() -> void:
	if _anim_tree != null:
		_anim_tree.set("parameters/jump/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func animation_tree() -> AnimationTree:
	return _anim_tree


# ---------------------------------------------------------------- 属性查询（供测试与 M1 使用）
## 角色的视觉前向（水平面投影）。KayKit GLB 原生朝 +Z（脚尖 / 手 / 披风三处数据互证），
## 场景里给 Model 烘焙了 180° Y 旋转，因此 basis.z 即模型面对的方向，且与玩家 -Z 一致。
## 滑翔时模型会前倾，故投影到水平面再归一化。
func model_forward() -> Vector3:
	var f := model.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD

## 玩家逻辑前向（Godot 约定：-Z 为前）。
func player_forward() -> Vector3:
	return -global_transform.basis.z


func bone_names() -> PackedStringArray:
	var sk := _find_skeleton(model)
	if sk == null:
		return PackedStringArray()
	var out := PackedStringArray()
	for i in sk.get_bone_count():
		out.append(sk.get_bone_name(i))
	return out


func has_clip(clip: StringName) -> bool:
	return anim_player != null and anim_player.has_animation(clip)


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null


# ================================================================ M1 战斗（GDD §4）
#
# 状态互斥关系（GDD §4.1~§4.4）：
#   NORMAL  --攻击键--> ATTACK --1/2/3 段结束--> NORMAL
#   NORMAL  --防御键按下--> GUARD --松开--> NORMAL
#   ATTACK(第三段 RECOVERY) --防御键--> GUARD（后摇取消）
#   GUARD --隐藏耐久耗尽--> GUARD_BROKEN（约 1s）--> NORMAL
#   ATTACK / GUARD / GUARD_BROKEN 期间不能互相正常嵌套；破防期间防御与攻击都拒绝。
#
# 弹反时间基准：受击结算时检查 `_guard_time`（本次防御按下后经过的时长）。
#   `_guard_time <= parry_window` 且来击在正面 120° 内、攻击 parryable → 弹反。
#   因此窗口天然对齐「攻击实际命中前的 0.2s」，而不是「按住防御的前 0.2s」：
#   按住防御超过 0.2s 后的命中只会普通格挡；命中后才按下的防御也不可能追溯成功。

const SFX_ATTACK_SWING := preload("res://audio/SoundFX/swish/swish_2.wav")
const SFX_GUARD_BLOCK := preload("res://audio/SoundFX/clang/clang_3.wav")
const SFX_GUARD_BREAK := preload("res://audio/SoundFX/clang/clang_4.wav")
const SFX_PARRY := preload("res://audio/SoundFX/clang/clang_1.wav")
const SFX_HURT := preload("res://audio/SoundFX/voice/voice_hurt_01.wav")
## 显式 preload，避免 headless 首次运行尚未生成 global_script_class_cache 时找不到类名。
const CombatHitScript := preload("res://combat/combat_hit.gd")

var _parry_ring: MeshInstance3D
var _parry_ring_mat: StandardMaterial3D
var _parry_tween: Tween
var _guard_shield: MeshInstance3D


# ---------------------------------------------------------------- 测试 / 输入注入
func request_attack() -> void:
	_attack_pressed = true


func request_guard_press() -> void:
	_guard_pressed = true
	_guard_held = true


func request_guard_release() -> void:
	_guard_released = true
	_guard_held = false


# ---------------------------------------------------------------- 每物理帧战斗推进
func _tick_combat(delta: float) -> void:
	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_counter_timer = maxf(0.0, _counter_timer - delta)
	if guarding:
		_guard_time += delta
	parry_active = guarding and _guard_time <= parry_window
	_tick_guard_pressure(delta)

	if _combat_state == CombatState.GUARD_BROKEN:
		_guard_break_timer = maxf(0.0, _guard_break_timer - delta)
		if _guard_break_timer <= 0.0:
			_combat_state = CombatState.NORMAL
			_guard_pressure = 0.0
			_guard_regen_delay_left = guard_regen_delay
			guard_pressure_changed.emit(0.0)

	if _dead:
		_attack_pressed = false
		_guard_pressed = false
		_guard_released = false
		if guarding:
			_end_guard()
		return

	if _guard_pressed:
		_handle_guard_press()
	if _guard_released:
		_handle_guard_release()
	if _attack_pressed:
		_handle_attack_press()
	_attack_pressed = false
	_guard_pressed = false
	_guard_released = false

	if _combat_state == CombatState.ATTACK:
		_tick_attack(delta)


func _tick_guard_pressure(delta: float) -> void:
	if guarding:
		_guard_regen_delay_left = maxf(_guard_regen_delay_left, 0.0)
		return
	_guard_regen_delay_left = maxf(0.0, _guard_regen_delay_left - delta)
	if _guard_regen_delay_left <= 0.0 and _guard_pressure > 0.0:
		_guard_pressure = maxf(0.0, _guard_pressure - guard_pressure_regen * delta)
		if _guard_pressure <= 0.0:
			guard_pressure_changed.emit(0.0)


# ---------------------------------------------------------------- 防御 / 破防（GDD §4.2）
func _handle_guard_press() -> void:
	if _dead or _combat_state == CombatState.GUARD_BROKEN:
		return
	if not is_on_floor():
		return
	if _combat_state == CombatState.ATTACK:
		# GDD §4.1：第三段攻击的后摇允许由防御取消；前两段不取消。
		if _attack_step >= attack_clips.size() and _attack_phase == AttackPhase.RECOVERY:
			_cancel_attack()
			_begin_guard()
		return
	if _combat_state == CombatState.GUARD:
		return
	_begin_guard()


func _handle_guard_release() -> void:
	if guarding:
		_end_guard()


func _begin_guard() -> void:
	if _dead or _combat_state == CombatState.GUARD_BROKEN:
		return
	if guarding:
		return
	guarding = true
	parry_active = true
	_combat_state = CombatState.GUARD
	_guard_time = 0.0
	_guard_regen_delay_left = guard_regen_delay
	guard_started.emit()


func _end_guard() -> void:
	if not guarding:
		return
	guarding = false
	parry_active = false
	_guard_time = 0.0
	if _combat_state == CombatState.GUARD:
		_combat_state = CombatState.NORMAL
	guard_ended.emit()


func _trigger_guard_break() -> void:
	if _combat_state == CombatState.GUARD_BROKEN:
		return
	_guard_pressure = guard_pressure_max
	_end_guard()
	_combat_state = CombatState.GUARD_BROKEN
	_guard_break_timer = guard_break_duration
	_guard_time = 0.0
	_guard_regen_delay_left = guard_regen_delay
	_play_react(clip_guard_break)
	_play_sfx(SFX_GUARD_BREAK, 0.9)
	if _camera is SpringCamera:
		(_camera as SpringCamera).add_trauma(0.5)
	guard_broken.emit()
	guard_pressure_changed.emit(1.0)
	print("[M1] 防御耐久耗尽 → 破防踉跄 %.2fs" % guard_break_duration)


# ---------------------------------------------------------------- 三段轻击（GDD §4.1）
func _handle_attack_press() -> void:
	if _dead or _combat_state == CombatState.GUARD_BROKEN:
		return
	if _combat_state == CombatState.GUARD:
		# GDD §4.2：防御状态下不能正常发动普通攻击。
		return
	if _combat_state == CombatState.ATTACK:
		if _attack_step < attack_clips.size():
			_attack_queued = true
		return
	if not is_on_floor():
		return
	_begin_attack(1)


func _begin_attack(step: int) -> void:
	if attack_clips.is_empty():
		return
	step = clampi(step, 1, attack_clips.size())
	_combat_state = CombatState.ATTACK
	_attack_step = step
	_attack_phase = AttackPhase.WINDUP
	_attack_time = 0.0
	_attack_queued = false
	_attack_swing_played = false
	_swing_hit_ids.clear()
	_update_soft_lock()

	var clip: StringName = attack_clips[step - 1]
	var anim := anim_player.get_animation(clip) if anim_player != null else null
	var clip_length := anim.length if anim != null else 0.8
	_attack_length = maxf(clip_length / maxf(attack_anim_speed, 0.05), 0.12)

	if _attack_anim_node != null:
		_attack_anim_node.animation = clip
	if _anim_tree != null:
		_anim_tree.set("parameters/attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	attack_started.emit(step)


func _tick_attack(delta: float) -> void:
	_attack_time += delta
	var ratio := _attack_time / maxf(_attack_length, 0.001)
	var start := clampf(attack_hit_start_ratio, 0.0, 1.0)
	var end := clampf(maxf(attack_hit_end_ratio, start), 0.0, 1.0)
	if ratio < start:
		_attack_phase = AttackPhase.WINDUP
		_update_soft_lock()
	elif ratio <= end:
		_attack_phase = AttackPhase.ACTIVE
		if not _attack_swing_played:
			_attack_swing_played = true
			_play_sfx(SFX_ATTACK_SWING, randf_range(0.95, 1.05))
		_check_attack_hits()
	else:
		_attack_phase = AttackPhase.RECOVERY

	if _attack_time >= _attack_length:
		_finish_attack()


func _finish_attack() -> void:
	if _attack_queued and _attack_step < attack_clips.size():
		_begin_attack(_attack_step + 1)
		return
	_cancel_attack(false)


func _cancel_attack(abort_anim: bool = true) -> void:
	_combat_state = CombatState.NORMAL
	_attack_step = 0
	_attack_phase = AttackPhase.NONE
	_attack_time = 0.0
	_attack_queued = false
	_swing_hit_ids.clear()
	if abort_anim and _anim_tree != null:
		_anim_tree.set("parameters/attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


func _update_soft_lock() -> void:
	_soft_lock_target = null
	var best_distance := soft_lock_range
	for n in get_tree().get_nodes_in_group("combat_target"):
		if not is_instance_valid(n) or not (n is Node3D):
			continue
		if n.has_method("is_alive") and not n.is_alive():
			continue
		var delta: Vector3 = (n as Node3D).global_position - global_position
		delta.y = 0.0
		var distance := delta.length()
		if distance < 0.01 or distance > best_distance:
			continue
		best_distance = distance
		_soft_lock_target = n as Node3D
		_soft_lock_yaw = atan2(-delta.x, -delta.z)


# ---------------------------------------------------------------- 命中判定与伤害（GDD §4.1/§4.4）
func _check_attack_hits() -> void:
	var space := get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = attack_hitbox_size
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	var center := global_position + player_forward() * attack_hitbox_reach + Vector3.UP * attack_hitbox_height
	params.transform = Transform3D(Basis(Vector3.UP, rotation.y), center)
	params.collision_mask = 1 << 2  # project.godot layer_3 = "Targets"
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [get_rid()]
	var results := space.intersect_shape(params, 8)
	for r in results:
		var target := r.get("collider") as Node
		if target == null or not is_instance_valid(target):
			continue
		if not target.has_method("receive_hit"):
			continue
		var id := target.get_instance_id()
		if _swing_hit_ids.has(id):
			continue
		_swing_hit_ids[id] = true

		var damage := attack_damage * _attack_damage_multiplier(_attack_step)
		var counter_used := false
		if _counter_timer > 0.0:
			damage *= parry_counter_multiplier
			_counter_timer = 0.0
			counter_used = true

		var hit = CombatHitScript.new(damage, self, true)
		hit.source_position = global_position
		hit.hit_position = (target as Node3D).global_position if target is Node3D else center
		hit.knockback = attack_knockback if _attack_step >= attack_clips.size() else 0.0
		hit.is_heavy = _attack_step >= attack_clips.size()
		target.receive_hit(hit)

		attack_hit.emit(target, damage)
		if _camera is SpringCamera:
			(_camera as SpringCamera).add_trauma(0.15)
		if counter_used:
			print("[M1] 反击强化消耗：本击伤害 ×%.1f = %.1f" % [parry_counter_multiplier, damage])
		print("[M1] 第 %d 段命中 %s，伤害 %.1f（击退 %.1f）" % [
			_attack_step, target.name, damage, hit.knockback,
		])


func _attack_damage_multiplier(step: int) -> float:
	if attack_damage_multipliers.is_empty():
		return 1.0
	var idx := clampi(step - 1, 0, attack_damage_multipliers.size() - 1)
	return attack_damage_multipliers[idx]


## 敌人/测试脚本调用：结算一次来击。返回 HitResult。
func receive_hit(hit) -> int:
	if _dead:
		return HitResult.IGNORED
	if _invuln_timer > 0.0:
		return HitResult.IGNORED

	var frontal := _is_in_guard_arc(hit.source_position)
	if guarding and _combat_state == CombatState.GUARD:
		if hit.parryable and frontal and _guard_time <= parry_window:
			_do_parry(hit)
			return HitResult.PARRY
		if frontal:
			_do_block(hit)
			return HitResult.BLOCK
	_do_damage(hit)
	return HitResult.DAMAGE


func _is_in_guard_arc(source_position: Vector3) -> bool:
	var to_source := source_position - global_position
	to_source.y = 0.0
	if to_source.length_squared() < 0.0001:
		return true
	var dot := player_forward().dot(to_source.normalized())
	return dot >= cos(deg_to_rad(guard_arc_deg * 0.5))


func _do_parry(hit) -> void:
	_counter_timer = parry_counter_window
	_invuln_timer = maxf(_invuln_timer, 0.15)
	parry_started.emit()
	parried.emit(hit.source)
	if is_instance_valid(hit.source) and hit.source.has_method("on_parried"):
		hit.source.on_parried()
	_play_sfx(SFX_PARRY, 1.0)
	_emit_parry_ring()
	_play_parry_slowmo()
	if _camera is SpringCamera:
		(_camera as SpringCamera).add_trauma(0.4)
	counter_ready.emit()
	print("[M1] 弹反成功！伤害归零；反击强化 %.1fs 内下一击 ×%.1f" % [
		parry_counter_window, parry_counter_multiplier,
	])


func _do_block(hit) -> void:
	var applied := maxf(hit.damage * (1.0 - clampf(guard_damage_reduction, 0.0, 1.0)), 0.0)
	health = maxf(health - applied, 0.0)
	block_started.emit()
	_play_react(clip_guard_hit)
	_play_sfx(SFX_GUARD_BLOCK, randf_range(0.95, 1.05))
	_guard_pressure += guard_pressure_per_block
	_guard_pressure = minf(_guard_pressure, guard_pressure_max)
	_guard_regen_delay_left = guard_regen_delay
	if _camera is SpringCamera:
		(_camera as SpringCamera).add_trauma(0.12)
	guard_pressure_changed.emit(guard_pressure_ratio())
	print("[M1] 正面格挡：伤害 %.1f → %.1f（减伤 %.0f%%），耐久 %.0f/%.0f" % [
		hit.damage, applied, guard_damage_reduction * 100.0, _guard_pressure, guard_pressure_max,
	])
	if health <= 0.0:
		_die()
	elif _guard_pressure >= guard_pressure_max:
		_trigger_guard_break()


func _do_damage(hit) -> void:
	health = maxf(health - hit.damage, 0.0)
	_invuln_timer = hit_invuln_time
	if _combat_state == CombatState.ATTACK:
		_cancel_attack()
	_play_react(clip_hurt)
	_play_sfx(SFX_HURT, randf_range(0.95, 1.05))
	if _camera is SpringCamera:
		(_camera as SpringCamera).add_trauma(0.3)
	player_damaged.emit(hit.damage, hit.source)
	print("[M1] 受击：伤害 %.1f，剩余生命 %.0f/%.0f" % [hit.damage, health, max_health])
	if health <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	health = 0.0
	guarding = false
	parry_active = false
	_cancel_attack(false)
	_combat_state = CombatState.NORMAL
	_play_react(&"Death_A")
	player_died.emit()


# ---------------------------------------------------------------- 弹反反馈（GDD §4.3 / §4.6）
func _build_combat_feedback() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.58
	torus.rings = 40
	torus.ring_segments = 8
	_parry_ring_mat = StandardMaterial3D.new()
	_parry_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_parry_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_parry_ring_mat.albedo_color = Color(1.0, 0.93, 0.62, 1.0)
	_parry_ring_mat.emission_enabled = true
	_parry_ring_mat.emission = Color(1.0, 0.85, 0.45)
	_parry_ring_mat.emission_energy_multiplier = 4.0
	_parry_ring_mat.no_depth_test = true
	_parry_ring = MeshInstance3D.new()
	_parry_ring.name = "ParryRing"
	_parry_ring.mesh = torus
	_parry_ring.material_override = _parry_ring_mat
	_parry_ring.position = Vector3(0, 0.12, 0)
	_parry_ring.visible = false
	add_child(_parry_ring)


func _emit_parry_ring() -> void:
	if _parry_ring == null:
		return
	if _parry_tween != null and _parry_tween.is_valid():
		_parry_tween.kill()
	_parry_ring.visible = true
	_parry_ring.scale = Vector3.ONE * 0.55
	_parry_ring_mat.albedo_color = Color(1.0, 0.93, 0.62, 1.0)
	_parry_tween = create_tween()
	_parry_tween.set_ignore_time_scale(true)
	_parry_tween.set_parallel(true)
	_parry_tween.tween_property(_parry_ring, "scale", Vector3.ONE * 3.2, 0.5)
	_parry_tween.tween_property(_parry_ring_mat, "albedo_color:a", 0.0, 0.5)
	_parry_tween.chain().tween_callback(_hide_parry_ring)


func _hide_parry_ring() -> void:
	if _parry_ring != null:
		_parry_ring.visible = false


## 左手骨骼挂点上的占位小盾：只用于 M1 防守姿态可读性，不参与任何命中判定。
## 若未来模型没有该骨骼，直接跳过；换装/换模型不需要改战斗代码（GDD §8.2）。
func _build_guard_shield() -> void:
	if not show_guard_shield:
		return
	var skeleton := _find_skeleton(model)
	if skeleton == null:
		return
	var bone := skeleton.find_bone(guard_shield_bone)
	if bone < 0:
		bone = skeleton.find_bone("hand.l")
	if bone < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "GuardShieldMount"
	attachment.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(attachment)

	var disc := CylinderMesh.new()
	disc.top_radius = 0.32
	disc.bottom_radius = 0.32
	disc.height = 0.055
	disc.radial_segments = 8
	disc.rings = 1

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.72, 0.86, 1.0)
	material.metallic = 0.55
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = Color(0.30, 0.46, 0.72)
	material.emission_energy_multiplier = 0.35

	_guard_shield = MeshInstance3D.new()
	_guard_shield.name = "GuardShield"
	_guard_shield.mesh = disc
	_guard_shield.material_override = material
	# 圆柱默认沿 Y；转 90° 让盘面朝前。相对手掌的偏移可按模型微调。
	_guard_shield.rotation_degrees = Vector3(90, 0, 0)
	_guard_shield.position = Vector3(0, 0.02, 0.02)
	_guard_shield.visible = false
	attachment.add_child(_guard_shield)


## 0.1 倍速保持 0.25s，再用 0.15s 回弹；全部按真实时间计时，不受 time_scale 影响。
func _play_parry_slowmo() -> void:
	_slowmo_token += 1
	var token := _slowmo_token
	Engine.time_scale = parry_slowmo_scale
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(parry_slowmo_hold * 1000.0):
		if token != _slowmo_token:
			return
		await get_tree().process_frame
	var recover_start := Time.get_ticks_msec()
	var recover_ms := maxi(1, int(parry_slowmo_recover * 1000.0))
	while Time.get_ticks_msec() - recover_start < recover_ms:
		if token != _slowmo_token:
			return
		var t := float(Time.get_ticks_msec() - recover_start) / float(recover_ms)
		Engine.time_scale = lerpf(parry_slowmo_scale, 1.0, clampf(t, 0.0, 1.0))
		await get_tree().process_frame
	if token == _slowmo_token:
		Engine.time_scale = 1.0


func _play_react(clip: StringName) -> void:
	if _anim_tree == null or _react_anim_node == null:
		return
	if anim_player != null and not anim_player.has_animation(clip):
		return
	_react_anim_node.animation = clip
	_anim_tree.set("parameters/react/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.unit_size = 8.0
	player.max_distance = 40.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# ---------------------------------------------------------------- 状态查询（HUD / 测试）
func combat_state() -> int:
	return _combat_state


func combat_state_name() -> String:
	match _combat_state:
		CombatState.ATTACK:
			return "ATTACK"
		CombatState.GUARD:
			return "GUARD"
		CombatState.GUARD_BROKEN:
			return "GUARD_BROKEN"
		_:
			return "NORMAL"


func attack_step() -> int:
	return _attack_step


func attack_phase() -> int:
	return _attack_phase


## 本次攻击的动画/状态总时长（秒），供 HUD 与自动测试读取。
func attack_duration() -> float:
	return _attack_length


func attack_phase_name() -> String:
	match _attack_phase:
		AttackPhase.WINDUP:
			return "WINDUP"
		AttackPhase.ACTIVE:
			return "ACTIVE"
		AttackPhase.RECOVERY:
			return "RECOVERY"
		_:
			return "NONE"


func is_attacking() -> bool:
	return _combat_state == CombatState.ATTACK


func is_guarding() -> bool:
	return guarding


func is_guard_broken() -> bool:
	return _combat_state == CombatState.GUARD_BROKEN


func guard_pressure() -> float:
	return _guard_pressure


func guard_pressure_ratio() -> float:
	return clampf(_guard_pressure / maxf(guard_pressure_max, 0.001), 0.0, 1.0)


func guard_time() -> float:
	return _guard_time


func guard_break_time_left() -> float:
	return _guard_break_timer


func counter_time_left() -> float:
	return _counter_timer


func health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)


func is_alive() -> bool:
	return not _dead


func soft_lock_target() -> Node3D:
	return _soft_lock_target


func parry_window_active() -> bool:
	return parry_active


# ---------------------------------------------------------------- 复位（训练场 / 自动测试）
## 复位战斗状态与生命；pos = Vector3.INF 时保持当前位置。
func reset_combat(pos: Vector3 = Vector3.INF) -> void:
	_slowmo_token += 1
	Engine.time_scale = 1.0
	_dead = false
	health = max_health
	_invuln_timer = 0.0
	_counter_timer = 0.0
	_guard_pressure = 0.0
	_guard_time = 0.0
	_guard_break_timer = 0.0
	_guard_regen_delay_left = 0.0
	_guard_held = false
	_attack_pressed = false
	_guard_pressed = false
	_guard_released = false
	_attack_queued = false
	_swing_hit_ids.clear()
	guarding = false
	parry_active = false
	_combat_state = CombatState.NORMAL
	_attack_step = 0
	_attack_phase = AttackPhase.NONE
	_attack_time = 0.0
	_guard_visual = 0.0
	velocity = Vector3.ZERO
	if pos != Vector3.INF:
		global_position = pos
	if _anim_tree != null:
		_anim_tree.set("parameters/attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_anim_tree.set("parameters/react/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_anim_tree.set("parameters/guard/blend_amount", 0.0)
	_hide_parry_ring()
	guard_pressure_changed.emit(0.0)


# ---------------------------------------------------------------- 兼容 M0 末尾的模板锚点
## 模板的 hit(who, by_what) 语义：弹反 > 格挡 > 吃伤害。M1 由 CombatHit 承载结算数据。
func hit(who: Node, by_what: Object) -> void:
	if by_what is RefCounted and by_what.get_script() == CombatHitScript:
		receive_hit(by_what)
		return
	var fallback = CombatHitScript.new(10.0, who, true)
	receive_hit(fallback)


func start_guard() -> void:
	request_guard_press()


func end_guard() -> void:
	request_guard_release()


func block() -> void:
	block_started.emit()


func parry() -> void:
	parry_started.emit()


# ---------------------------------------------------------------- 内部工具
func _ground_speed_scale() -> float:
	return guard_speed_multiplier if _combat_state == CombatState.GUARD else 1.0


func _combat_locks_movement() -> bool:
	return _dead or _combat_state == CombatState.ATTACK or _combat_state == CombatState.GUARD_BROKEN


func _can_jump() -> bool:
	return not _dead and _combat_state == CombatState.NORMAL


func _camera_combat_yaw() -> float:
	if _camera is SpringCamera:
		return (_camera as SpringCamera).yaw
	if _camera != null:
		var forward := -_camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.0001:
			return atan2(-forward.x, -forward.z)
	return rotation.y

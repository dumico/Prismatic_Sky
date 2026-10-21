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

signal jump_started
signal landed(fall_speed: float)
signal hard_landed(fall_speed: float)
signal glide_started
signal glide_ended

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
	animation_setup()
	_build_dust()
	_cache_cape()
	_model_base_rotation = model.rotation
	_camera = get_viewport().get_camera_3d()


func _physics_process(delta: float) -> void:
	_read_input()
	_tick_timers(delta)

	var was_on_floor := is_on_floor()
	_update_glide_state(delta, was_on_floor)

	if not was_on_floor:
		if _glide_blend > 0.001:
			_apply_glide_vertical(delta)
		else:
			velocity.y -= gravity() * delta

	var wish := wish_direction()
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
	if not input_enabled:
		return
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	run_held = Input.is_action_pressed("run")
	jump_held = Input.is_action_pressed("jump")
	if Input.is_action_just_pressed("jump"):
		_jump_pressed = true
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
			ground_speed = run_speed() if run_held else walk_speed()
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
	if _jump_buffer_timer <= 0.0 or _is_stiff():
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
	if wish.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-wish.x, -wish.z)
	var t := clampf(1.0 - exp(-turn_smooth() * delta), 0.0, 1.0)
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

	var tree := AnimationNodeBlendTree.new()
	tree.add_node("ground", ground)
	tree.add_node("air", air)
	tree.add_node("air_mix", mix)
	tree.add_node("jump", jump)
	tree.connect_node("air_mix", 0, "ground")
	tree.connect_node("air_mix", 1, "air")
	tree.connect_node("jump", 0, "air_mix")
	tree.connect_node("output", 0, "jump")

	_anim_tree = AnimationTree.new()
	_anim_tree.name = "AnimTree"
	add_child(_anim_tree)
	_anim_tree.anim_player = _anim_tree.get_path_to(anim_player)
	_anim_tree.tree_root = tree
	_anim_tree.active = true

	set_ground_speed_ratio(0.0)
	set_airborne(false)
	set_air_phase(0.0)


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


# ---------------------------------------------------------------- 格挡 / 弹反框架（保留自 Cat's 模板，M1 接线）
## 来源：Cat's Godot4 Modular Souls-like Template（The Unlicense）player/player_charbody3D.gd。
## M0 只保留信号与状态，不接输入、不做战斗数值（M0 禁区；GDD §8、§9）。
signal block_started
signal parry_started

## 完美弹反窗口内为 true；窗口时长由 GDD §4.3 在 M1 定为 0.2s，M0 不启用。
@export var parry_window: float = 0.2
var guarding: bool = false
var parry_active: bool = false


func start_guard() -> void:
	guarding = true
	parry_active = true
	await get_tree().create_timer(parry_window).timeout
	parry_active = false


func end_guard() -> void:
	guarding = false
	parry_active = false


## 受击入口：模板的 hit() 语义（弹反 > 格挡 > 吃伤害）。M1 接上伤害结算与动画。
func hit(_who: Node, _by_what: Object) -> void:
	if parry_active:
		parry()
	elif guarding:
		block()


func block() -> void:
	block_started.emit()


func parry() -> void:
	parry_started.emit()

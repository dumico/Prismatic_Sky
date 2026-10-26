extends Camera3D
class_name SpringCamera

## GDD §3.3 / §3.4：相机弹簧滞后（camera_stiffness 6.0）+ 跟随距离（cam_dist 4.5m），
## 战斗态把 cam_dist 收到 3.5m、FOV 收 5°（§3.3 表末行、§3.4 双状态手感）。
## M0 只做探索态；战斗态由 set_combat_state() 预留，M1 接战斗警戒圈（§3.4、§11.1）。

@export var target: Node3D

@export_group("GDD §3.3 基础值")
## 弹簧刚度（越大越紧跟）：位置按 1-exp(-stiffness*dt) 收敛，帧率无关。
@export var stiffness_base: float = 6.0
## 相机与目标的距离（米）。
@export var distance_base: float = 4.5
## 视线抬高（对准胸口而非脚底）。
@export var look_height_base: float = 1.25
## 相机相对目标的抬高。
@export var height_base: float = 0.35

@export_group("GDD §3.3 战斗态（M1 接线，M0 不触发）")
@export var combat_distance_base: float = 3.5
@export var combat_fov_delta: float = -5.0

@export_group("操作")
@export var mouse_sensitivity: float = 0.0025
@export var stick_sensitivity: float = 2.2
@export var pitch_min_deg: float = -70.0
@export var pitch_max_deg: float = 55.0
@export var capture_mouse: bool = true

@export_group("M1 镜头反馈（GDD §4.6；M2 再精调）")
## trauma 衰减速度（GDD §4.6 默认 1.2/s；M1 只做轻量位移抖动）。
@export var shake_decay: float = 1.2
## trauma=1 时的最大位移抖动（米）。
@export var shake_max_offset: float = 0.10

var trauma: float = 0.0

## 修正系数（GDD §11.2 同一套约定：未来技能/时装只改系数）。
@export var coefficients: MovementCoefficients

var yaw: float = 0.0
var pitch: float = -0.12
var combat_mode: bool = false

var _look_point: Vector3
var _ready_snapped: bool = false


func _init() -> void:
	if coefficients == null:
		coefficients = MovementCoefficients.new()


func distance() -> float:
	var d := combat_distance_base if combat_mode else distance_base
	return d * coefficients.cam_dist


func stiffness() -> float:
	return stiffness_base * coefficients.camera_stiffness


func _ready() -> void:
	if target == null and get_parent() is Node3D:
		target = get_parent()
	if capture_mouse and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	fov = 70.0
	if target != null:
		yaw = target.global_rotation.y
	snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= (event as InputEventMouseMotion).relative.x * mouse_sensitivity
		pitch -= (event as InputEventMouseMotion).relative.y * mouse_sensitivity
		pitch = clampf(pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length_squared() > 0.0:
		yaw -= stick.x * stick_sensitivity * delta
		pitch -= stick.y * stick_sensitivity * delta
		pitch = clampf(pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))


func _physics_process(delta: float) -> void:
	if target == null:
		return
	if not _ready_snapped:
		snap_to_target()
		return
	var t := 1.0 - exp(-stiffness() * delta)
	global_position = global_position.lerp(_desired_position(), t)
	var want_look := target.global_position + Vector3.UP * look_height_base
	_look_point = _look_point.lerp(want_look, t)
	if global_position.distance_squared_to(_look_point) > 0.0001:
		look_at(_look_point, Vector3.UP)
	_apply_shake(delta)


## trauma 制镜头反馈：值 0~1，按平方缩放位移，线性衰减。M1 只影响位置，不改朝向。
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _apply_shake(delta: float) -> void:
	if trauma <= 0.0:
		return
	var strength := trauma * trauma
	global_position += Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
	) * shake_max_offset * strength
	trauma = maxf(0.0, trauma - shake_decay * delta)


## 相机朝向（水平面），供玩家控制器做「相机相对移动」。
func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func snap_to_target() -> void:
	if target == null:
		return
	global_position = _desired_position()
	_look_point = target.global_position + Vector3.UP * look_height_base
	_ready_snapped = true
	if global_position.distance_squared_to(_look_point) > 0.0001:
		look_at(_look_point, Vector3.UP)


func set_combat_state(on: bool) -> void:
	combat_mode = on
	fov = 70.0 + (combat_fov_delta if on else 0.0)


func _desired_position() -> Vector3:
	var pivot := target.global_position + Vector3.UP * (look_height_base + height_base)
	var dir := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.BACK
	return pivot + dir * distance()

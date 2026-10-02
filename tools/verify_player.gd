extends SceneTree

## M0 玩家验收（随 M0-3 / M0-4 / M0-5 逐步扩展）
##   pwsh -File work/tools/godot.ps1 --headless --path . --script res://tools/verify_player.gd
## 退出码 0 = 全通过。
##
## 沙箱里没法用眼睛验收，所以这里用「注入输入 + 逐物理帧断言运动学结果」代替：
## 控制器暴露 input_enabled / input_dir / run_held / request_jump() 供测试注入。
## 物理步长 = project.godot 默认 60 Hz。

const PLAYER_SCENE := "res://player/prismatic_player.tscn"
const REQUIRED_CLIPS := [
	&"Idle", &"Walking_A", &"Running_A", &"Jump_Start", &"Jump_Idle", &"Jump_Land", &"Blocking",
]
const FPS := 60.0

var _fail := 0
var _checks := 0
var _world: Node3D
var _player: PrismaticPlayer


func _initialize() -> void:
	_run()


func _run() -> void:
	_world = Node3D.new()
	_world.name = "TestWorld"
	get_root().add_child(_world)
	_add_floor()

	var ps: PackedScene = load(PLAYER_SCENE)
	if ps == null:
		_bad("无法载入 %s" % PLAYER_SCENE)
		return _finish()
	_player = ps.instantiate()
	_player.input_enabled = false
	_world.add_child(_player)
	await process_frame
	await process_frame

	await _test_model_and_animation()
	await _test_movement_feel()
	await _test_jump_and_coyote()
	await _test_jump_buffer()
	await _test_hard_landing()
	await _test_air_control()
	await _test_glide()
	await _test_coefficients()
	await _test_camera()

	_finish()


# ================================================================ 测试夹具
func _add_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0, -0.5, 0)
	_world.add_child(body)


## 把玩家放回地面并清空状态。
func _reset(pos: Vector3 = Vector3(0, 0.02, 0)) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.input_dir = Vector2.ZERO
	_player.run_held = false
	_player.jump_held = false
	_player.request_jump_release()
	for i in 6:
		await physics_frame


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _ground_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


# ================================================================ M0-3：模型 / 骨骼 / 动画 / 碰撞
func _test_model_and_animation() -> void:
	_expect(_player is PrismaticPlayer, "根节点是 PrismaticPlayer (CharacterBody3D)")
	var model: Node3D = _player.get_node_or_null("Model")
	_expect(model != null, "存在 Model 实例（KayKit Adventurers）")

	var sk := _find_skeleton(model)
	_expect(sk != null, "Model 内含 Skeleton3D")
	if sk != null:
		_expect(sk.get_bone_count() >= 40, "骨骼数 >= 40（实际 %d）" % sk.get_bone_count())
		_expect(sk.find_bone("hips") >= 0 and sk.find_bone("head") >= 0, "KayKit 骨骼命名（hips/head）可用")

	var ap: AnimationPlayer = model.get_node_or_null("AnimationPlayer") if model else null
	_expect(ap != null, "Model 内含 AnimationPlayer")
	if ap != null:
		_expect(ap.get_animation_list().size() >= 70, "动画数 >= 70（实际 %d）" % ap.get_animation_list().size())
		for clip in REQUIRED_CLIPS:
			_expect(ap.has_animation(clip), "存在动画片段 %s" % clip)

	var col: CollisionShape3D = _player.get_node_or_null("Collision")
	_expect(col != null and col.shape is CapsuleShape3D, "存在胶囊碰撞体")
	if col != null and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		_expect(cap.height > 1.0 and cap.height < 2.2, "胶囊高度合理（%.2f）" % cap.height)
		_expect(absf(col.position.y - cap.height * 0.5) < 0.35, "碰撞体大致贴合角色（y=%.2f）" % col.position.y)

	if model != null:
		var f: Vector3 = _player.model_forward()
		var pf: Vector3 = _player.player_forward()
		_expect(f.dot(pf) > 0.99, "模型面向已对齐玩家前向（dot=%.3f）" % f.dot(pf))

	var tree: AnimationTree = _player.get_node_or_null("AnimTree")
	_expect(tree != null and tree.active, "AnimationTree 已构建并激活")
	if tree != null and tree.active:
		_expect(tree.tree_root is AnimationNodeBlendTree, "动画树根为 AnimationNodeBlendTree")
		for p in ["parameters/ground/blend_position", "parameters/air/blend_position", "parameters/air_mix/blend_amount"]:
			_expect(tree.get(p) != null, "参数可用：%s" % p)

	# 原地动画检查
	await _reset()
	var p0: Vector3 = _player.global_position
	if ap != null:
		ap.play(&"Running_A")
		await _steps(30)
		var moved := (_player.global_position - p0).length()
		_expect(moved < 0.05, "播放 Running_A 时角色无根位移（%.4f m，动画为原地动画）" % moved)


# ================================================================ M0-4：§3.3 移动手感
func _test_movement_feel() -> void:
	# 地面加速：0→满速应约 0.5s（run_speed 6.0 / accel_ground 12.0）
	await _reset()
	_player.input_dir = Vector2(0, -1)
	_player.run_held = true
	await _steps(30)
	var v30 := _ground_speed()
	_expect(absf(v30 - _player.run_speed()) < 0.25,
		"按住奔跑 0.5s 达到 run_speed（%.2f / %.2f）" % [v30, _player.run_speed()])

	# 地面减速：刹停应约 0.25s（6.0 / 24.0），且「停比启快」
	_player.input_dir = Vector2.ZERO
	_player.run_held = false
	await _steps(15)
	var v15 := _ground_speed()
	_expect(v15 < 0.25, "松开输入 0.25s 内刹停（余速 %.3f m/s）" % v15)
	_expect(_player.decel_ground() > _player.accel_ground(),
		"减速度 > 加速度（%.1f > %.1f，停比启快）" % [_player.decel_ground(), _player.accel_ground()])

	# 走路速度
	await _reset()
	_player.input_dir = Vector2(0, -1)
	_player.run_held = false
	await _steps(40)
	_expect(absf(_ground_speed() - _player.walk_speed()) < 0.15,
		"不按奔跑时稳定在 walk_speed（%.2f / %.2f）" % [_ground_speed(), _player.walk_speed()])

	# 转身：朝向应平滑转到移动方向（-Z），且不是一帧到位
	await _reset()
	_player.rotation.y = PI  # 背对目标方向
	_player.input_dir = Vector2(0, -1)
	await _steps(1)
	var after1 := absf(_player.rotation.y - PI)
	await _steps(40)
	var yaw := wrapf(_player.rotation.y, -PI, PI)
	_expect(after1 > 0.05, "转身不是一帧到位（1 帧后仍偏 %.3f rad）" % after1)
	_expect(absf(wrapf(yaw, -PI, PI)) < 0.15, "转身最终对准移动方向（yaw=%.3f）" % yaw)

	# 动画混合随速度变化
	var tree: AnimationTree = _player.get_node_or_null("AnimTree")
	if tree != null and tree.active:
		var b := float(tree.get("parameters/ground/blend_position"))
		_expect(b > 0.2, "行走时动画混合位置 > 0.2（实际 %.3f）" % b)

	await _reset()


func _test_jump_and_coyote() -> void:
	# 跳跃高度：v²/(2g) = 7.5²/36 ≈ 1.56m
	await _reset()
	var y0 := _player.global_position.y
	_player.request_jump()
	var peak := y0
	for i in 90:
		await physics_frame
		peak = maxf(peak, _player.global_position.y)
		if i > 6 and _player.is_on_floor():
			break
	var h := peak - y0
	_expect(absf(h - 1.56) < 0.25, "跳跃高度 ≈ 1.56m（实际 %.2f m）" % h)

	# 土狼时间：离地 0.05s 内仍可跳
	await _reset()
	await _steps(4)
	_player.global_position.y += 2.0
	await _steps(2)  # ≈0.033s 空中
	var coyote_ok := _player.air_time_left()
	_player.request_jump()
	await _steps(2)
	_expect(coyote_ok > 0.0 and _player.velocity.y > 0.0,
		"土狼时间内（余 %.3f s）仍可起跳" % coyote_ok)

	# 土狼时间：离地 0.2s 后不可跳
	await _reset()
	await _steps(4)
	_player.global_position.y += 6.0
	await _steps(12)  # 0.2s > 0.12s
	_player.velocity = Vector3.ZERO
	_player.request_jump()
	await _steps(2)
	_expect(_player.velocity.y <= 0.0, "超过土狼时间后无法起跳（velocity.y=%.2f）" % _player.velocity.y)

	# 不按住跳也只跳一次（无二段跳）
	await _reset()
	_player.request_jump()
	await _steps(10)
	var y_mid := _player.global_position.y
	_player.request_jump()
	await _steps(6)
	_expect(_player.global_position.y < y_mid + 0.6, "空中再次按跳不产生二段跳")


func _test_jump_buffer() -> void:
	# 落地前 0.075s 按跳 → 落地瞬间自动起跳
	await _reset()
	_player.global_position = Vector3(0, 0.3, 0)
	_player.velocity = Vector3(0, -4.0, 0)
	_player.request_jump()
	var jumped := false
	for i in 40:
		await physics_frame
		if _player.velocity.y > 1.0 and not _player.is_on_floor():
			jumped = true
			break
	_expect(jumped, "落地前按跳被缓冲，落地即起跳（跳跃缓冲 %.2fs）" % _player.jump_buffer())

	# 缓冲过期（> 0.12s）后不应起跳
	await _reset()
	_player.global_position = Vector3(0, 0.9, 0)
	_player.velocity = Vector3(0, -0.5, 0)
	_player.request_jump()
	await _steps(14)  # 缓冲过期
	var v_before := _player.velocity.y
	await _steps(4)
	_expect(_player.velocity.y <= maxf(v_before, 0.0) + 0.01, "缓冲过期后不再生效")


func _test_hard_landing() -> void:
	# 落速 > landing_stiff_threshold(12) → 0.12s 硬直 + 尘土
	await _reset()
	_player.global_position = Vector3(0, 6.0, 0)
	_player.velocity = Vector3.ZERO
	var stiff_seen := false
	var fall_speed := 0.0
	for i in 200:
		await physics_frame
		if _player.is_on_floor():
			stiff_seen = _player.is_stiff()
			break
		fall_speed = maxf(fall_speed, -_player.velocity.y)
	_expect(fall_speed >= _player.landing_stiff_threshold(),
		"从 6m 落下的落速 ≥ 硬直阈值（%.2f / %.2f m/s）" % [fall_speed, _player.landing_stiff_threshold()])
	_expect(stiff_seen, "重落地触发硬直（landing_stiff_time=%.2fs）" % _player.landing_stiff_time)
	var dust: GPUParticles3D = _player.get_node_or_null("LandingDust")
	_expect(dust != null, "存在落地尘土粒子节点")
	if dust != null:
		_expect(dust.emitting and dust.one_shot, "重落地时尘土粒子已触发")

	# 软着陆不触发硬直
	await _reset()
	_player.global_position = Vector3(0, 0.5, 0)
	_player.velocity = Vector3.ZERO
	var soft_stiff := false
	for i in 60:
		await physics_frame
		if _player.is_on_floor():
			soft_stiff = _player.is_stiff()
			break
	_expect(not soft_stiff, "轻落地不触发硬直")


func _test_air_control() -> void:
	await _reset()
	# 地面 6 帧（0.1s）的水平速度增量
	_player.input_dir = Vector2(0, -1)
	_player.run_held = true
	await _steps(6)
	var ground_gain := _ground_speed()

	# 空中同样 6 帧
	await _reset()
	_player.global_position = Vector3(0, 20.0, 0)
	_player.velocity = Vector3.ZERO
	await _steps(2)
	_player.input_dir = Vector2(0, -1)
	_player.run_held = true
	var v_before := _ground_speed()
	await _steps(6)
	var air_gain := _ground_speed() - v_before

	var ratio := air_gain / maxf(ground_gain, 0.001)
	_expect(absf(ratio - _player.air_control()) < 0.12,
		"空中加速度 ≈ 地面加速度 × air_control（%.2f vs %.2f）" % [ratio, _player.air_control()])

	# 空中输入也受目标速度约束，不会无限加速
	await _steps(120)
	_expect(_ground_speed() <= _player.run_speed() + 0.2,
		"空中水平速度不超过 run_speed（%.2f）" % _ground_speed())
	await _reset()


func _test_glide() -> void:
	# ---- 基础值（GDD §3.3 滑翔行）----
	_expect(absf(_player.glide_enter_time() - 0.25) < 0.001,
		"glide_enter_time = 0.25s（%.3f）" % _player.glide_enter_time())
	_expect(absf(_player.glide_fall_speed() - (-2.5)) < 0.001,
		"glide_fall_speed = -2.5（%.2f）" % _player.glide_fall_speed())
	_expect(absf(_player.glide_dive_accel() - 8.0) < 0.001, "glide_dive_accel = 8.0")
	_expect(absf(_player.dive_max() - 12.0) < 0.001, "dive_max = 12.0")
	_expect(absf(_player.glide_lift_boost() - 3.0) < 0.001, "glide_lift_boost = +3.0")

	# ---- 进入滑翔：0.25s 展开过渡，不瞬切 ----
	await _reset()
	_player.global_position = Vector3(0, 60.0, 0)
	_player.velocity = Vector3.ZERO
	_player.jump_held = true
	_player.glide_pitch_input = 0.0
	await _steps(2)  # 第 1 帧 was_on_floor 仍为真（上一步结果），第 2 帧才判定滞空
	var b0 := _player.glide_blend()
	await _steps(13)  # 合计 0.25s
	var b_mid := _player.glide_blend()
	_expect(b0 > 0.0 and b0 < 0.2,
		"展开从 0 起步，起步帧只到 %.3f（不是瞬切）" % b0)
	_expect(b_mid > 0.9 and b_mid <= 1.0, "约 0.25s 后展开完成（blend=%.3f）" % b_mid)
	_expect(_player.is_gliding(), "进入滑翔状态")
	# 垂直速度被钳到 glide_fall_speed
	await _steps(60)
	_expect(absf(_player.velocity.y - _player.glide_fall_speed()) < 0.35,
		"中性滑翔落速被钳到 %.2f（实际 %.2f）" % [_player.glide_fall_speed(), _player.velocity.y])

	# ---- 俯冲换速度：落速升到 dive_max，水平速度增加 ----
	_player.glide_pitch_input = 1.0
	await _steps(120)
	_expect(absf(_player.velocity.y - (-_player.dive_max())) < 0.6,
		"满俯冲落速趋近 dive_max（%.2f / %.2f）" % [_player.velocity.y, -_player.dive_max()])
	var dive_h := _ground_speed()
	_player.glide_pitch_input = 0.0
	await _steps(90)
	var neutral_h := _ground_speed()
	_expect(dive_h > neutral_h + 0.5,
		"俯冲换速度：俯冲水平速度 > 中性滑翔（%.2f > %.2f）" % [dive_h, neutral_h])

	# ---- 拉升耗速度换高度 ----
	_player.glide_pitch_input = -1.0
	var h_before := _ground_speed()
	await _steps(120)
	_expect(_player.velocity.y > 0.0,
		"拉升产生爬升（velocity.y=%.2f，目标 %.2f）" % [_player.velocity.y, _player.glide_fall_speed() + _player.glide_lift_boost()])
	_expect(_ground_speed() < h_before - 0.5,
		"拉升耗速度换高度：水平速度下降（%.2f → %.2f）" % [h_before, _ground_speed()])

	# ---- 表现层：身体前倾 + 披风展开 ----
	_expect(absf(_player.model.rotation.x) > 0.05, "滑翔时身体前倾（pitch=%.3f）" % _player.model.rotation.x)
	_expect(_player.cape_scale().x > 1.2, "披风随展开过渡放大（scale.x=%.2f）" % _player.cape_scale().x)

	# ---- 松开跳跃 → 退出滑翔，恢复正常重力 ----
	_player.jump_held = false
	_player.glide_pitch_input = 0.0
	await _steps(30)  # 0.25s 收回
	_expect(_player.glide_blend() < 0.05, "松开跳跃后 0.25s 内退出滑翔（blend=%.3f）" % _player.glide_blend())
	var vy0 := _player.velocity.y
	await _steps(10)
	_expect(_player.velocity.y < vy0 - 1.0,
		"退出滑翔后恢复重力下坠（%.2f → %.2f）" % [vy0, _player.velocity.y])
	_expect(absf(_player.model.rotation.x) < 0.05, "退出滑翔后身体姿态复位")

	# ---- 上升阶段不展开（必须过顶点）----
	await _reset()
	_player.global_position = Vector3(0, 30.0, 0)
	_player.velocity = Vector3(0, 6.0, 0)
	_player.jump_held = true
	await _steps(6)
	_expect(_player.glide_blend() <= 0.001, "上升阶段不进入滑翔（blend=%.3f）" % _player.glide_blend())

	# ---- 全局/居中：glide 参数也遵守「基础值 × 修正系数」----
	_player.coefficients.glide_fall_speed = 0.5
	_expect(absf(_player.glide_fall_speed() - (-1.25)) < 0.001,
		"glide_fall_speed = 基础值 × 系数（%.2f）" % _player.glide_fall_speed())
	_player.coefficients.glide_fall_speed = 1.0

	_player.jump_held = false
	await _reset()


func _test_coefficients() -> void:
	# GDD §3.3 / §11.2：参数 = 基础值 × 修正系数
	var base_run := _player.run_speed()
	var base_walk := _player.walk_speed()
	_player.coefficients.run_speed = 0.5
	_expect(absf(_player.run_speed() - base_run * 0.5) < 0.001,
		"run_speed = 基础值 × 系数（%.2f）" % _player.run_speed())
	_expect(absf(_player.walk_speed() - base_walk) < 0.001, "只改 run 系数不影响 walk_speed")

	# 判定宽容项有下限保护：系数归零也不许把土狼时间 / 跳跃缓冲压没
	_player.coefficients.coyote_time = 0.0
	_player.coefficients.jump_buffer = 0.0
	_expect(_player.coyote_time() >= 0.02, "土狼时间有下限保护（%.3f s）" % _player.coyote_time())
	_expect(_player.jump_buffer() >= 0.02, "跳跃缓冲有下限保护（%.3f s）" % _player.jump_buffer())

	_player.coefficients.run_speed = 1.0
	_player.coefficients.coyote_time = 1.0
	_player.coefficients.jump_buffer = 1.0
	_expect(absf(_player.run_speed() - base_run) < 0.001, "系数复位后回到基础值")


func _test_camera() -> void:
	var cam: SpringCamera = _player.get_node_or_null("SpringCamera")
	_expect(cam != null and cam is SpringCamera, "玩家场景内含弹簧相机")
	if cam == null:
		return
	_expect(absf(cam.distance() - 4.5) < 0.001, "探索态 cam_dist = 4.5m（%.2f）" % cam.distance())
	_expect(absf(cam.stiffness() - 6.0) < 0.001, "camera_stiffness = 6.0（%.2f）" % cam.stiffness())
	_expect(cam.target != null, "相机有跟随目标")
	# §3.3 表末行 / §3.4：战斗态 cam_dist→3.5m、FOV 收 5°
	var fov_explore := cam.fov
	cam.set_combat_state(true)
	_expect(absf(cam.distance() - 3.5) < 0.001, "战斗态 cam_dist = 3.5m（%.2f）" % cam.distance())
	_expect(absf(cam.fov - (fov_explore - 5.0)) < 0.001, "战斗态 FOV 收 5°（%.1f）" % cam.fov)
	cam.set_combat_state(false)
	_expect(absf(cam.distance() - 4.5) < 0.001, "退出战斗态距离复位")

	# 弹簧滞后：目标瞬移后相机不应同帧到位
	await _reset()
	cam.snap_to_target()
	var before := cam.global_position
	_player.global_position += Vector3(6, 0, 0)
	await _steps(1)
	var moved := (cam.global_position - before).length()
	_expect(moved > 0.0 and moved < 5.9, "相机弹簧滞后（1 帧只跟了 %.2f m / 6 m）" % moved)
	await _steps(90)
	var gap := (cam.global_position - cam._desired_position()).length()
	_expect(gap < 0.25, "弹簧最终收敛到目标位（残差 %.3f m）" % gap)


# ================================================================ 工具
func _find_skeleton(n: Node) -> Skeleton3D:
	if n == null:
		return null
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null


func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  ", msg)
	else:
		_fail += 1
		print("  FAIL  ", msg)


func _bad(msg: String) -> void:
	_checks += 1
	_fail += 1
	print("  FAIL  ", msg)


func _finish() -> void:
	print("VERIFY_PLAYER checks=%d fail=%d" % [_checks, _fail])
	if _fail == 0:
		print("VERIFY_PLAYER_ALL_PASS")
		quit(0)
	else:
		quit(1)

extends SceneTree

## M0-6 灰盒测试场景验收
##   pwsh -File work/tools/godot.ps1 --headless --path . --script res://tools/verify_greybox.gd
## 退出码 0 = 全通过。
##
## 做三件事：
##   1) 几何验收：平地 / 台阶（每级落差必须在 §3.3 的跳高之内）/ 12m 跳台落差；
##   2) 场景完整性：WorldEnvironment、定向光、玩家实例、主场景设定；
##   3) 端到端跑一遍：把玩家放上跳台走出去按住跳跃，验证真的能滑翔并滑出足够距离。

const SCENE := "res://levels/greybox_test.tscn"
const PLAYER_SCENE := "res://player/prismatic_player.tscn"

var _fail := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	# ---------- 主场景设定 ----------
	var main: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_expect(main == SCENE, "project.godot 主场景 = %s（实际 %s）" % [SCENE, main])

	var ps: PackedScene = load(SCENE)
	if ps == null:
		_bad("无法载入 %s" % SCENE)
		return _finish()

	var level: Node3D = ps.instantiate()
	get_root().add_child(level)
	await process_frame
	await physics_frame

	# ---------- 场景组成 ----------
	_expect(level.get_node_or_null("WorldEnvironment") != null, "存在 WorldEnvironment")
	var sun: DirectionalLight3D = level.get_node_or_null("Sun")
	_expect(sun != null, "存在定向光 Sun")
	if sun != null:
		var dir := -sun.global_transform.basis.z
		_expect(dir.y < -0.5, "定向光确实朝下照（dir=%.2f,%.2f,%.2f）" % [dir.x, dir.y, dir.z])
	var player: Node3D = level.get_node_or_null("Player")
	_expect(player != null, "存在玩家实例")

	# ---------- 几何：平地 ----------
	# 注意避开玩家出生点（(0,·,14) 上有玩家胶囊，射线会打到玩家）
	_expect(absf(_surface_height(level, Vector3(6, 30, 16))) < 0.05, "出生点旁边是 y=0 的平地")
	_expect(absf(_surface_height(level, Vector3(60, 30, 60))) < 0.05, "远处仍是平地（足够滑翔落点）")
	_expect(absf(_surface_height(level, Vector3(0, 30, -75))) < 0.05, "12m 跳台正前方 75m 处仍有地面")

	# ---------- 几何：高低台 ----------
	var step_tops: Array[float] = []
	for k in range(1, 11):
		var z := 6.0 - 3.0 * (k - 1)
		var top := _surface_height(level, Vector3(0, 40, z))
		step_tops.append(top)
		_expect(absf(top - 1.2 * k) < 0.06, "第 %d 级台阶面高 = %.1fm（实测 %.2f）" % [k, 1.2 * k, top])
	var max_rise := 0.0
	for i in range(1, step_tops.size()):
		max_rise = maxf(max_rise, step_tops[i] - step_tops[i - 1])
	_expect(max_rise <= 1.56 + 0.05,
		"相邻台阶落差 ≤ §3.3 跳高 1.56m（实际最大 %.2f）——台阶真的能爬" % max_rise)

	_expect(absf(_surface_height(level, Vector3(0, 40, -29)) - 12.0) < 0.06, "跳台面高 12.0m")
	_expect(absf(_surface_height(level, Vector3(14, 40, 2)) - 1.2) < 0.06, "1.2m 矮台")
	_expect(absf(_surface_height(level, Vector3(14, 40, -6)) - 2.4) < 0.06, "2.4m 中台")
	_expect(absf(_surface_height(level, Vector3(-15, 40, -6)) - 5.0) < 0.06, "5.0m 高台")
	_expect(absf(_surface_height(level, Vector3(20, 40, -16)) - 12.0) < 0.06, "12m 立柱")

	# ---------- 端到端：从 12m 跳台走出去滑翔 ----------
	await _test_glide_from_platform(level, player)

	level.queue_free()
	await process_frame
	_finish()


## 从高处放下一条射线，返回命中面的 y（没命中返回 -999）。
func _surface_height(level: Node3D, from: Vector3) -> float:
	var space := level.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -80, 0))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return float(hit.get("position", Vector3(0, -999, 0)).y) if not hit.is_empty() else -999.0


func _test_glide_from_platform(level: Node3D, player: Node3D) -> void:
	if player == null:
		return
	var p := player as PrismaticPlayer
	p.input_enabled = false
	# 站到跳台中央，朝 -Z 走出去（跳台前端在 z=-34）
	p.global_position = Vector3(0, 12.05, -29)
	p.velocity = Vector3.ZERO
	p.input_dir = Vector2.ZERO
	p.jump_held = false
	var grounded := false
	for i in 40:
		await physics_frame
		if p.is_on_floor():
			grounded = true
			break
	_expect(grounded, "玩家能站在 12m 跳台上")

	var start := p.global_position
	# 走出平台边缘
	p.input_dir = Vector2(0, -1)
	p.run_held = true
	var airborne_at := Vector3.ZERO
	var glide_start := -1.0
	var t := 0.0
	var glide_frames := 0
	var airborne_frame := -1
	var max_h_dist := 0.0
	var landed := false
	for i in 900:  # 最多 15 秒
		await physics_frame
		t += 1.0 / 60.0
		if p.is_on_floor():
			if airborne_frame >= 0:
				landed = true
				break
			continue
		if airborne_frame < 0:
			airborne_frame = i
			airborne_at = p.global_position
		# 刚离地就开始按住跳跃 → 过顶点后应自动展开滑翔
		p.jump_held = true
		if glide_start < 0.0 and p.is_gliding():
			glide_start = t
		if p.is_gliding():
			glide_frames += 1
			max_h_dist = maxf(max_h_dist, Vector2(p.global_position.x - airborne_at.x,
				p.global_position.z - airborne_at.z).length())

	_expect(glide_start > 0.0, "从跳台走落后自动进入滑翔（t=%.2fs）" % glide_start)
	_expect(glide_frames >= 120, "滑翔持续 ≥ 2s（实际 %.2fs）" % (glide_frames / 60.0))
	_expect(max_h_dist >= 15.0, "滑翔水平位移 ≥ 15m（实际 %.1fm）" % max_h_dist)
	_expect(landed, "最终落回地面（不会一直飘下去）")
	var drop := start.y - p.global_position.y
	_expect(drop > 10.0, "全程落差 > 10m（实际 %.1fm）" % drop)
	# 必须是自己降落到灰盒地面，而不是掉出世界被重生脚本送回来
	_expect(absf(p.global_position.y) < 1.0, "落点就在灰盒地面上（y=%.2f）" % p.global_position.y)
	_expect(p.global_position.z < -40.0, "落点在跳台前方（z=%.1f），滑翔确实滑出去了" % p.global_position.z)
	_expect(p.global_position.z > -110.0, "落点仍在地面范围内（z=%.1f，未掉出世界）" % p.global_position.z)

	# 回平地做一次手感回归：跑起来能达到 run_speed
	p.input_enabled = false
	p.global_position = Vector3(0, 0.2, 20)
	p.velocity = Vector3.ZERO
	p.jump_held = false
	p.input_dir = Vector2.ZERO
	for i in 6:
		await physics_frame
	p.input_dir = Vector2(0, -1)
	p.run_held = true
	for i in 30:
		await physics_frame
	var v := Vector2(p.velocity.x, p.velocity.z).length()
	_expect(absf(v - p.run_speed()) < 0.3, "平地上 0.5s 加速到 run_speed（%.2f）" % v)


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
	print("VERIFY_GREYBOX checks=%d fail=%d" % [_checks, _fail])
	if _fail == 0:
		print("VERIFY_GREYBOX_ALL_PASS")
		quit(0)
	else:
		quit(1)

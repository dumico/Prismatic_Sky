extends SceneTree

## M1 战斗自动验证（GDD §4 / §9 M1）
##   pwsh -File work/tools/godot.ps1 --headless --path . --script res://tools/verify_combat.gd
## 退出码 0 = 全通过。
##
## 覆盖：
##   A. 三段轻击：顺序、伤害 1:1:1.5、第三段击退、软锁定、收招恢复移动、第三段后摇防御取消；
##   B. 防御：正面 120°/70% 减伤、侧面与背后不减伤、移速 50%、防御中禁止攻击、连续格挡破防+1s 踉跄；
##   C. 弹反：0.2s 窗口（提前=格挡、迟到=吃伤害）、伤害归零、敌人 1.5s 硬直、
##      1s 内下一击 ×2 且只消费一次、0.1 倍速 0.25s 后恢复；
##   D. 训练场集成：玩家/木桩/守卫/HUD/相机战斗态。
##
## 说明：headless 无法验收「只听音效前奏就能弹反」；那一条必须由用户实机试玩。

const PLAYER_SCENE := "res://player/prismatic_player.tscn"
const DUMMY_SCENE := "res://enemy/training_dummy.tscn"
const ENEMY_SCENE := "res://enemy/training_enemy.tscn"
const TRAINING_SCENE := "res://levels/m1_combat_training.tscn"
const PRELUDE_PATH := "res://audio/SoundFX/combat/parry_prelude.wav"
const CombatHitScript := preload("res://combat/combat_hit.gd")

const RESULT_IGNORED := 0
const RESULT_DAMAGE := 1
const RESULT_BLOCK := 2
const RESULT_PARRY := 3

var _checks: int = 0
var _fail: int = 0
var _world: Node3D
var _player
var _dummy
var _enemy
var _attacker: Node3D
var _parried_count: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_world = Node3D.new()
	_world.name = "CombatTestWorld"
	get_root().add_child(_world)
	_add_floor()

	_player = load(PLAYER_SCENE).instantiate()
	_player.input_enabled = false
	_player.position = Vector3(0, 0.05, 0)
	_world.add_child(_player)

	_dummy = load(DUMMY_SCENE).instantiate()
	_dummy.position = Vector3(0, 0, -1.4)
	_world.add_child(_dummy)

	_enemy = load(ENEMY_SCENE).instantiate()
	_enemy.position = Vector3(10, 0, 10)
	_world.add_child(_enemy)

	_attacker = Node3D.new()
	_attacker.name = "TestAttacker"
	_attacker.position = Vector3(0, 0, -2)
	_world.add_child(_attacker)

	_player.parried.connect(func(_source): _parried_count += 1)

	await process_frame
	await physics_frame
	await physics_frame

	await _test_setup()
	await _test_animations()
	await _test_combo()
	await _test_guard()
	await _test_parry()
	await _test_training_scene()

	Engine.time_scale = 1.0
	_world.queue_free()
	await process_frame
	await _wait_real(0.6)  # 让伤害数字/弹反光圈的短 Tween 结束，避免退出时悬挂对象
	_finish()


# ================================================================ 夹具
func _add_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0, -0.5, 0)
	_world.add_child(body)


func _reset_all() -> void:
	Engine.time_scale = 1.0
	_enemy.set_physics_process(false)
	_enemy.reset_enemy()
	_enemy.global_position = Vector3(10, 0, 10)
	_player.reset_combat(Vector3(0, 0.05, 0))
	_player.rotation.y = 0.0
	_player.input_enabled = false
	_player.input_dir = Vector2.ZERO
	_player.run_held = false
	_player.jump_held = false
	_dummy.reset_dummy()
	_dummy.global_position = Vector3(0, 0, -1.4)
	_attacker.global_position = Vector3(0, 0, -2)
	_parried_count = 0
	for i in 6:
		await physics_frame


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func _wait_real(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await process_frame


func _speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _hit_player(damage: float, source_position: Vector3, source_node: Node = null) -> int:
	_attacker.global_position = source_position
	var source: Node = source_node if source_node != null else _attacker
	var hit = CombatHitScript.new(damage, source, true)
	hit.source_position = source_position
	return _player.receive_hit(hit)


# ================================================================ A. 三段轻击
func _test_setup() -> void:
	_expect(_player is Node3D, "玩家场景可实例化")
	_expect(_player.attack_clips.size() == 3, "配置了三段攻击动画")
	for clip in _player.attack_clips:
		_expect(_player.has_clip(clip), "存在攻击动画 %s" % clip)
	for clip in [&"Blocking", &"Block_Hit", &"Hit_A", &"Hit_B", &"Death_A"]:
		_expect(_player.has_clip(clip), "存在战斗动画 %s" % clip)
	_expect(_player.attack_damage_multipliers == [1.0, 1.0, 1.5],
		"三段基础伤害倍率 = 1 : 1 : 1.5")

	var tree = _player.get_node_or_null("AnimTree")
	_expect(tree != null and tree.active, "AnimationTree 已构建并激活")
	if tree != null and tree.active:
		for p in ["parameters/attack/request", "parameters/guard/blend_amount",
				"parameters/react/request", "parameters/attack_speed/scale"]:
			_expect(tree.get(p) != null, "战斗动画参数可用：%s" % p)

	_expect(_dummy.is_in_group("combat_target"), "木桩加入 combat_target 组")
	_expect(_enemy.is_in_group("combat_target"), "训练守卫加入 combat_target 组")
	var prelude = load(PRELUDE_PATH)
	_expect(prelude != null and prelude.get_length() > 0.5,
		"弹反前奏音效存在且时长 > 0.5s（%.2fs）" % (prelude.get_length() if prelude else 0.0))
	_expect(absf(_player.parry_window - 0.2) < 0.0001, "弹反窗口锁定为 0.2s")
	_expect(InputMap.has_action("use_weapon_light"), "存在攻击输入动作 use_weapon_light")
	_expect(InputMap.has_action("use_gadget_light"), "存在防御输入动作 use_gadget_light")
	var lmb := false
	for event in InputMap.action_get_events("use_weapon_light"):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			lmb = true
	var rmb := false
	for event in InputMap.action_get_events("use_gadget_light"):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			rmb = true
	_expect(lmb, "鼠标左键已绑定攻击")
	_expect(rmb, "鼠标右键已绑定防御")


func _test_animations() -> void:
	await _reset_all()
	_dummy.global_position = Vector3(8, 0, 8)
	var sk := _find_skeleton(_player)
	_expect(sk != null, "玩家模型内含 Skeleton3D")
	if sk == null:
		return
	var bone := sk.find_bone("hand.r")
	_expect(bone >= 0, "KayKit 右手骨骼 hand.r 可用")
	if bone < 0:
		return
	await _steps(10)
	var idle_pose := sk.get_bone_pose_rotation(bone)
	_player.request_attack()
	await _steps(20)
	var attack_pose := sk.get_bone_pose_rotation(bone)
	_expect(idle_pose.angle_to(attack_pose) > 0.15,
		"攻击动画实际驱动骨架（右手姿态变化 %.2f rad）" % idle_pose.angle_to(attack_pose))
	await _wait_until(func(): return _player.combat_state_name() == "NORMAL", 180)
	await _steps(25)
	idle_pose = sk.get_bone_pose_rotation(bone)

	var tree = _player.get_node_or_null("AnimTree")
	_player.request_guard_press()
	await _steps(16)
	_expect(_player.combat_state_name() == "GUARD", "防御姿态进入 GUARD")
	if tree:
		_expect(float(tree.get("parameters/guard/blend_amount")) > 0.5,
			"防御动画混合权重上升（%.2f）" % float(tree.get("parameters/guard/blend_amount")))
	var guard_pose := sk.get_bone_pose_rotation(bone)
	_expect(idle_pose.angle_to(guard_pose) > 0.03,
		"防御动画实际驱动骨架（右手姿态变化 %.2f rad）" % idle_pose.angle_to(guard_pose))
	_player.request_guard_release()
	await _steps(20)
	if tree:
		_expect(float(tree.get("parameters/guard/blend_amount")) < 0.15, "松开防御后姿态混合回落")
	_dummy.global_position = Vector3(0, 0, -1.4)


func _test_combo() -> void:
	await _reset_all()
	_player.rotation.y = PI  # 背对木桩，验证软锁定会转回来
	var tree = _player.get_node_or_null("AnimTree")

	_player.request_attack()
	await physics_frame
	_expect(_player.attack_step() == 1, "第一次攻击输入进入第 1 段")
	_expect(_player.attack_duration() > 0.4 and _player.attack_duration() < 1.2,
		"第 1 段时长合理（%.2fs）" % _player.attack_duration())
	var clips_seen: Array = [tree.tree_root.get_node("attack_anim").animation if tree else &""]

	_player.request_attack()  # 输入缓冲：第 2 段
	var got_step2: bool = await _wait_until(func(): return _player.attack_step() == 2, 150)
	_expect(got_step2, "连击输入缓冲衔接到第 2 段")
	if tree:
		clips_seen.append(tree.tree_root.get_node("attack_anim").animation)
	var got_hit1: bool = await _wait_until(func(): return _dummy.hit_count() >= 1, 150)
	_expect(got_hit1, "第 1 段产生真实命中")

	var to_dummy: Vector3 = _dummy.global_position - _player.global_position
	to_dummy.y = 0.0
	_expect(_player.player_forward().dot(to_dummy.normalized()) > 0.9,
		"软锁定把角色转向 3m 内最近目标（dot=%.3f）" % _player.player_forward().dot(to_dummy.normalized()))

	_player.request_attack()  # 输入缓冲：第 3 段
	var got_step3: bool = await _wait_until(func(): return _player.attack_step() == 3, 150)
	_expect(got_step3, "连击衔接到第 3 段")
	if tree:
		clips_seen.append(tree.tree_root.get_node("attack_anim").animation)
	_expect(clips_seen.size() == 3 and clips_seen[0] != clips_seen[1] and clips_seen[1] != clips_seen[2],
		"三段攻击使用可分辨的动画片段（%s）" % str(clips_seen))

	var pos_before: Vector3 = _dummy.global_position
	var got_hit3: bool = await _wait_until(func(): return _dummy.hit_count() >= 3, 180)
	_expect(got_hit3, "第 3 段产生真实命中")
	var log: Array = _dummy.damage_log
	_expect(log.size() == 3, "三次攻击各命中一次，没有重复结算（实际 %d 次）" % log.size())
	if log.size() >= 3:
		_expect(absf(log[0] - 10.0) < 0.01 and absf(log[1] - 10.0) < 0.01 and absf(log[2] - 15.0) < 0.01,
			"伤害比例 1 : 1 : 1.5（实际 %.1f / %.1f / %.1f）" % [log[0], log[1], log[2]])
	var knockback_speed := Vector2(_dummy.velocity.x, _dummy.velocity.z).length()
	await _steps(10)
	var moved: float = (_dummy.global_position - pos_before).length()
	_expect(knockback_speed > 2.0, "第 3 段给木桩施加击退速度（%.2f m/s）" % knockback_speed)
	_expect(moved > 0.15, "第 3 段产生可观察的位置击退（%.2fm）" % moved)

	var ended: bool = await _wait_until(func(): return _player.combat_state_name() == "NORMAL", 180)
	_expect(ended, "三段结束后回到 NORMAL，不卡在攻击状态")
	_expect(_player.attack_step() == 0, "连击计数复位")

	# 木桩已被第三段推开；挪开它，避免撞到角色影响移动恢复断言。
	_dummy.global_position = Vector3(8, 0, 8)
	_player.input_dir = Vector2(0, -1)
	await _steps(25)
	_expect(_speed() > 1.0, "攻击结束后恢复移动（%.2f m/s）" % _speed())
	_player.input_dir = Vector2.ZERO

	# 第三段后摇可由防御取消
	await _reset_all()
	_player.request_attack()
	await physics_frame
	_player.request_attack()
	await _wait_until(func(): return _player.attack_step() == 2, 150)
	_player.request_attack()
	await _wait_until(func(): return _player.attack_step() == 3, 150)
	var cancelled := false
	for i in 180:
		if _player.attack_step() == 3 and _player.attack_phase_name() == "RECOVERY":
			_player.request_guard_press()
			await physics_frame
			await physics_frame
			cancelled = _player.combat_state_name() == "GUARD" and _player.attack_step() == 0
			break
		await physics_frame
	_expect(cancelled, "第 3 段后摇可被防御取消并进入 GUARD")
	_player.request_guard_release()
	await _steps(2)

	# 连击结束后再次攻击从第 1 段重新开始
	await _reset_all()
	_player.request_attack()
	await physics_frame
	_expect(_player.attack_step() == 1, "新一轮攻击从第 1 段开始")


# ================================================================ B. 防御 / 破防
func _test_guard() -> void:
	await _reset_all()
	_player.request_guard_press()
	await _steps(20)
	_expect(_player.is_guarding() and _player.combat_state_name() == "GUARD", "长按防御进入 GUARD")
	_expect(_player.guard_time() > 0.2, "按住超过 0.2s（%.2fs），弹反窗口已关闭" % _player.guard_time())

	var r_front := _hit_player(20.0, Vector3(0, 0, -2))
	_expect(r_front == RESULT_BLOCK, "正面 0° 攻击被格挡")
	_expect(absf(_player.health - 94.0) < 0.01, "正面减伤 70%%（20 → %.1f）" % (100.0 - _player.health))
	_expect(absf(_player.guard_pressure() - 28.0) < 0.01, "格挡累积防御压力 28")

	# 50°（在 120° 弧内）仍减伤
	await _reset_all()
	_player.request_guard_press()
	await _steps(20)
	var r_inside := _hit_player(20.0, Vector3(sin(deg_to_rad(50)) * 2.0, 0, -cos(deg_to_rad(50)) * 2.0))
	_expect(r_inside == RESULT_BLOCK, "正面弧内 50° 攻击仍被格挡")

	# 70°（在 120° 弧外）吃满伤害
	await _reset_all()
	_player.request_guard_press()
	await _steps(20)
	var r_outside := _hit_player(20.0, Vector3(sin(deg_to_rad(70)) * 2.0, 0, -cos(deg_to_rad(70)) * 2.0))
	_expect(r_outside == RESULT_DAMAGE, "正面弧外 70° 攻击不被格挡")
	_expect(absf(_player.health - 80.0) < 0.01, "弧外攻击吃满 20 伤害（剩余 %.1f）" % _player.health)

	# 背后攻击吃满伤害
	await _reset_all()
	_player.request_guard_press()
	await _steps(20)
	var r_back := _hit_player(20.0, Vector3(0, 0, 2))
	_expect(r_back == RESULT_DAMAGE, "背后攻击不被正面防御减免")
	_expect(absf(_player.health - 80.0) < 0.01, "背后攻击吃满 20 伤害")

	# 防御时移速 50%
	await _reset_all()
	_dummy.global_position = Vector3(6, 0, 6)
	_player.request_guard_press()
	await _steps(4)
	_player.input_dir = Vector2(0, -1)
	await _steps(40)
	var guarded_speed := _speed()
	_expect(absf(guarded_speed - _player.walk_speed() * 0.5) < 0.2,
		"防御时移速 = 正常移速 50%%（%.2f / %.2f）" % [guarded_speed, _player.walk_speed()])
	_player.input_dir = Vector2.ZERO

	# 防御时不能普通攻击
	await _reset_all()
	_dummy.global_position = Vector3(0, 0, -1.4)
	_player.request_guard_press()
	await _steps(4)
	_player.request_attack()
	await _steps(12)
	_expect(_player.combat_state_name() == "GUARD" and _player.attack_step() == 0,
		"防御状态下攻击输入被拒绝")
	_expect(_dummy.hit_count() == 0, "防御状态不会产生攻击命中")
	_player.request_guard_release()
	await _steps(2)

	# 连续格挡 → 破防 → 约 1s 不能防御/攻击
	await _reset_all()
	_player.request_guard_press()
	await _steps(20)
	for i in 4:
		var r := _hit_player(20.0, Vector3(0, 0, -2))
		_expect(r == RESULT_BLOCK or (i == 3 and _player.is_guard_broken()),
			"第 %d 次格挡结算正常" % (i + 1))
		await physics_frame
	_expect(_player.is_guard_broken(), "连续格挡 4 次触发破防")
	_expect(not _player.is_guarding(), "破防后退出防御姿态")
	_expect(absf(_player.health - 76.0) < 0.01, "四次格挡各承受 30%% 伤害（剩余 %.1f）" % _player.health)
	_expect(_player.guard_break_time_left() > 0.8 and _player.guard_break_time_left() <= 1.0,
		"破防踉跄约 1s（剩余 %.2fs）" % _player.guard_break_time_left())

	_player.request_guard_press()
	await _steps(3)
	_expect(_player.is_guard_broken(), "破防期间继续按防御无效")
	_player.request_attack()
	await _steps(3)
	_expect(_player.attack_step() == 0, "破防期间不能普通攻击")
	var r_broken := _hit_player(20.0, Vector3(0, 0, -2))
	_expect(r_broken == RESULT_DAMAGE, "破防期间受击按正常伤害结算")
	await _steps(75)
	_expect(_player.combat_state_name() == "NORMAL", "约 1s 后破防状态结束")
	_expect(_player.guard_pressure() <= 0.01, "破防结束后防御耐久清零")
	_player.request_guard_press()
	await _steps(3)
	_expect(_player.combat_state_name() == "GUARD", "破防结束后可以重新防御")
	_player.request_guard_release()
	await _steps(2)


# ================================================================ C. 弹反 / 反击强化 / 时间减速
func _test_parry() -> void:
	# 成功弹反：0.15s 前按下防御（窗口内）
	await _reset_all()
	_enemy.reset_enemy()
	_enemy.global_position = Vector3(0, 0, -2)
	_player.request_guard_press()
	await _steps(9)
	_expect(_player.guard_time() < 0.2, "弹反输入时刻在 0.2s 窗口内（%.3fs）" % _player.guard_time())
	var r_parry := _hit_player(20.0, _enemy.global_position, _enemy)
	_expect(r_parry == RESULT_PARRY, "窗口内防御 + 正面可弹反攻击 → 弹反成功")
	_expect(absf(_player.health - 100.0) < 0.01, "弹反成功伤害归零（生命 %.1f）" % _player.health)
	_expect(_parried_count == 1, "弹反信号触发一次")
	_expect(_enemy.is_staggered(), "弹反使敌人进入硬直")
	_expect(_enemy.stagger_time_left() > 1.3, "敌人硬直约 1.5s（剩余 %.2fs）" % _enemy.stagger_time_left())
	_expect(_player.counter_time_left() > 0.8, "弹反后获得 1s 反击强化（剩余 %.2fs）" % _player.counter_time_left())
	_expect(Engine.time_scale < 0.5, "弹反触发时间减速（time_scale=%.2f）" % Engine.time_scale)
	# 把硬直中的守卫挪走，避免后续攻击同时命中守卫与木桩，干扰反击强化消费断言。
	_enemy.global_position = Vector3(10, 0, 10)
	await _wait_real(0.75)
	_expect(absf(Engine.time_scale - 1.0) < 0.01, "时间减速在约 0.4s 内恢复正常（%.2f）" % Engine.time_scale)

	# 1s 内下一击 ×2，且只消费一次
	_player.request_guard_release()
	await _steps(3)
	_dummy.reset_dummy()
	_dummy.global_position = Vector3(0, 0, -1.4)
	_player.request_attack()
	var got1: bool = await _wait_until(func(): return _dummy.hit_count() >= 1, 150)
	_expect(got1 and absf(_dummy.last_damage() - 20.0) < 0.01,
		"反击强化后下一击 ×2（10 → %.1f）" % _dummy.last_damage())
	await _wait_until(func(): return _player.combat_state_name() == "NORMAL", 180)
	_player.request_attack()
	var got2: bool = await _wait_until(func(): return _dummy.hit_count() >= 2, 150)
	_expect(got2 and absf(_dummy.last_damage() - 10.0) < 0.01,
		"强化只消费一次，下一击恢复 10（实际 %.1f）" % _dummy.last_damage())
	await _wait_until(func(): return _player.combat_state_name() == "NORMAL", 180)

	# 提前按 → 普通防御
	await _reset_all()
	_player.request_guard_press()
	await _steps(20)
	var r_early := _hit_player(20.0, Vector3(0, 0, -2))
	_expect(r_early == RESULT_BLOCK, "提前按（>0.2s）转为普通防御")
	_expect(absf(_player.health - 94.0) < 0.01, "提前按只承受 30%% 伤害（剩余 %.1f）" % _player.health)

	# 迟到按 → 本次命中已按正常受击结算，不可追溯弹反
	await _reset_all()
	var r_late := _hit_player(20.0, Vector3(0, 0, -2))
	_expect(r_late == RESULT_DAMAGE, "未防御时命中按正常受击结算")
	_expect(absf(_player.health - 80.0) < 0.01, "迟到输入前已吃满伤害（剩余 %.1f）" % _player.health)
	_player.request_guard_press()
	await _steps(3)
	_expect(_parried_count == 0, "命中后才按防御不会追溯为弹反")
	_expect(absf(_player.health - 80.0) < 0.01, "追溯弹反不会返还已结算伤害")
	_player.request_guard_release()
	await _steps(2)

	# 窗口边界：0.25s 后按 → 普通格挡
	await _reset_all()
	_player.request_guard_press()
	await _steps(16)
	var r_too_late := _hit_player(20.0, Vector3(0, 0, -2))
	_expect(r_too_late == RESULT_BLOCK, "超过 0.2s 后命中只算普通格挡")
	_expect(_player.health < 100.0 and _player.health > 90.0, "超窗命中承受 30% 伤害")

	# 训练守卫真实攻击链路：前奏 → 命中前 0.12s 按防御 → 弹反
	await _reset_all()
	_enemy.set_physics_process(true)
	_enemy.reset_enemy()
	_enemy.global_position = Vector3(0, 0, 0)
	_player.reset_combat(Vector3(0, 0.05, 2.0))
	_player.rotation.y = 0.0
	_dummy.global_position = Vector3(8, 0, 8)
	await _steps(4)
	var windup_seen: bool = await _wait_until(func(): return _enemy.state_name() == "WINDUP", 180)
	_expect(windup_seen, "训练守卫进入可读的前摇")
	_expect(_enemy.prelude_playing(), "守卫攻击播放统一低沉嗡鸣前奏")
	var pressed := false
	for i in 300:
		var tti: float = _enemy.time_to_impact()
		if tti >= 0.0 and tti <= 0.12:
			_player.request_guard_press()
			pressed = true
			break
		await physics_frame
	_expect(pressed, "在命中前 0.12s 按下防御")
	var integrated_parry := false
	for i in 180:
		if _enemy.is_staggered():
			integrated_parry = true
			break
		await physics_frame
	_expect(integrated_parry, "真实攻击链路可被弹反，敌人进入硬直")
	_expect(absf(_player.health - 100.0) < 0.01, "真实弹反链路伤害归零（生命 %.1f）" % _player.health)
	_enemy.set_physics_process(false)
	await _wait_real(0.7)


# ================================================================ D. 训练场集成
func _test_training_scene() -> void:
	var ps: PackedScene = load(TRAINING_SCENE)
	_expect(ps != null, "M1 训练场景可载入")
	if ps == null:
		return
	var level = ps.instantiate()
	get_root().add_child(level)
	await process_frame
	await physics_frame
	await physics_frame
	_expect(level.get_node_or_null("Player") != null, "训练场含玩家")
	_expect(level.get_node_or_null("TrainingDummy") != null, "训练场含木桩")
	_expect(level.get_node_or_null("TrainingEnemy") != null, "训练场含训练守卫")
	_expect(level.get_node_or_null("Hud") != null, "训练场含诊断 HUD")
	var scene_player = level.get_node_or_null("Player")
	if scene_player != null:
		_expect(scene_player.get_node_or_null("AnimTree") != null, "训练场玩家动画树已构建")
		_expect(scene_player.has_method("reset_combat"), "训练场玩家可重置")
	var cam = scene_player.get_node_or_null("SpringCamera") if scene_player else null
	if cam != null:
		_expect(cam.combat_mode, "靠近目标时相机切入战斗态（GDD §3.4）")
	level.queue_free()
	await process_frame


# ================================================================ 工具
func _find_skeleton(n: Node) -> Skeleton3D:
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


func _finish() -> void:
	print("VERIFY_COMBAT checks=%d fail=%d" % [_checks, _fail])
	if _fail == 0:
		print("VERIFY_COMBAT_ALL_PASS")
		quit(0)
	else:
		quit(1)

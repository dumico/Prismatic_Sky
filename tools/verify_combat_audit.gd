extends SceneTree

## Independent M1 regressions against the real training scene, animation tree,
## collision bodies and input map. No test doubles replace combat recipients.
const TRAINING := preload("res://levels/m1_combat_training.tscn")
const Hit := preload("res://combat/combat_hit.gd")
var checks := 0
var failures := 0
var level
var player
var dummy
var enemy
var hit_events := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _fresh()
	await _animation_lifecycle()
	await _fresh()
	await _held_guard()
	await _fresh()
	await _accepted_counter()
	await _fresh()
	await _reset_lifecycle()
	await _fresh()
	await _impact_geometry()
	await _fresh()
	await _player_wall()
	await _fresh()
	await _window_boundaries()
	await _fresh()
	await _real_enemy_timing()
	await _fresh()
	await _mapped_inputs()
	await _fresh()
	await _slowmo_lifecycle()
	if is_instance_valid(level):
		level.queue_free()
	await process_frame
	# Let the real SceneTreeTimer used by the death-reset regression expire.
	# It belongs to the tree even after its scene has been freed.
	await _real_wait(1.3)
	Engine.time_scale = 1.0
	print("VERIFY_COMBAT_AUDIT checks=%d fail=%d" % [checks, failures])
	if failures == 0:
		print("VERIFY_COMBAT_AUDIT_ALL_PASS")
	quit(0 if failures == 0 else 1)

func _fresh() -> void:
	Input.action_release("use_weapon_light")
	Input.action_release("use_gadget_light")
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	Engine.time_scale = 1.0
	level = TRAINING.instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	dummy = level.get_node("TrainingDummy")
	enemy = level.get_node("TrainingEnemy")
	player.input_enabled = false
	player.get_node("SpringCamera").capture_mouse = false
	enemy.set_physics_process(false)
	enemy.global_position = Vector3(15, 0, 15)
	dummy.global_position = Vector3(-15, 0, 15)
	player.reset_combat(Vector3(0, 0.05, 0))
	player.rotation.y = 0.0
	player.get_node("SpringCamera").yaw = 0.0
	player.parry_slowmo_scale = 1.0
	await _steps(8)

func _steps(count: int) -> void:
	for i in count:
		await physics_frame

func _until(predicate: Callable, frames := 240) -> bool:
	for i in frames:
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()

func _real_wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", description])

func _animation_lifecycle() -> void:
	player.request_attack()
	await _until(func(): return player.is_attacking())
	await _until(func(): return not player.is_attacking())
	var tree = player.animation_tree()
	await _steps(15)
	var repeated := false
	for i in 180:
		await physics_frame
		repeated = repeated or bool(tree.get("parameters/attack/active"))
	_expect(not repeated,
		"attack animation stops after the completed swing; no ghost repeat")
	player.receive_hit(Hit.new(10, enemy))
	await _steps(140)
	_expect(not bool(tree.get("parameters/react/active")),
		"hurt animation ends and releases the combat animation layer")

func _held_guard() -> void:
	player.request_attack()
	await _steps(4)
	player.request_guard_press()
	await _steps(90)
	_expect(player.is_guarding(), "held guard activates when attack recovery ends")
	_expect(player.guard_time() > 0.2,
		"deferred held guard does not create a fresh parry window")
	player.request_guard_release()
	await _steps(3)
	player.reset_combat()
	player.request_guard_press()
	await _steps(20)
	for i in 4:
		var hit = Hit.new(20, enemy, false)
		hit.source_position = player.global_position + Vector3.FORWARD * 2.0
		player.receive_hit(hit)
	_expect(player.is_guard_broken(), "four frontal blocks enter guard break")
	await _steps(66)
	_expect(player.is_guarding() and not player.parry_window_active(),
		"holding guard resumes after stagger, without a free renewed parry")

func _accepted_counter() -> void:
	dummy.global_position = Vector3(0, 0, -1.4)
	dummy.reset_delay = 10.0
	dummy.receive_hit(Hit.new(10000, player))
	enemy.global_position = Vector3(0, 0, -2)
	player.request_guard_press()
	await _steps(3)
	_expect(player.receive_hit(Hit.new(20, enemy)) == player.HitResult.PARRY,
		"real training enemy grants counter through a successful parry")
	player.request_guard_release()
	enemy.global_position = Vector3(15, 0, 15)
	await _steps(3)
	hit_events = 0
	player.attack_hit.connect(func(_target, _damage): hit_events += 1)
	player.request_attack()
	await _until(func(): return player.attack_phase_name() == "ACTIVE")
	await _steps(2)
	_expect(player.counter_time_left() > 0.0,
		"rejected hit on a broken target preserves the counter buff")
	_expect(hit_events == 0, "rejected collision emits no accepted-hit feedback")
	dummy.reset_dummy()
	await _steps(3)
	_expect(dummy.last_damage() == 20.0 and player.counter_time_left() == 0.0,
		"first accepted hit receives and consumes the counter exactly once")
	await _until(func(): return not player.is_attacking())
	await _steps(10)
	player.request_attack()
	await _until(func(): return dummy.hit_count() >= 2)
	_expect(dummy.last_damage() == 10.0, "next accepted attack has normal damage")

func _reset_lifecycle() -> void:
	dummy.reset_delay = 0.35
	dummy.receive_hit(Hit.new(10000, player))
	dummy.reset_dummy()
	dummy.receive_hit(Hit.new(10, player))
	await _real_wait(0.45)
	_expect(dummy.health == dummy.max_health - 10.0,
		"manual dummy reset invalidates the old automatic respawn")
	enemy.respawn_delay = 0.35
	enemy.receive_hit(Hit.new(10000, player))
	enemy.reset_enemy()
	enemy.receive_hit(Hit.new(10, player))
	await _real_wait(0.45)
	_expect(enemy.health == enemy.max_health - 10.0,
		"manual enemy reset invalidates the old death coroutine")
	player.receive_hit(Hit.new(10000, enemy))
	level.reset_training()
	player.health -= 10.0
	await _real_wait(1.35)
	_expect(player.health == player.max_health - 10.0,
		"R reset invalidates the pending player-death training reset")

func _impact_geometry() -> void:
	enemy.global_position = Vector3(0, 0, -2)
	enemy.rotation.y = PI
	player.global_position = Vector3(0, 8, 0)
	player.set_physics_process(false)
	var before: float = player.health
	enemy._impact()
	_expect(player.health == before,
		"melee attack cannot damage a player eight metres overhead")
	player.reset_combat(Vector3(0, 0.05, 0))
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.3)
	col.shape = box
	wall.add_child(col)
	level.add_child(wall)
	wall.global_position = Vector3(0, 1.0, -1)
	await _steps(3)
	before = player.health
	enemy._impact()
	_expect(player.health == before, "training attack is blocked by a solid world wall")
	wall.queue_free()
	await _steps(3)
	player.reset_combat(Vector3(0, 0.05, 0))
	before = player.health
	enemy._impact()
	_expect(player.health == before - enemy.attack_damage,
		"the same close-range unblocked attack still deals damage")
	player.set_physics_process(true)

func _window_boundaries() -> void:
	player.set_physics_process(false)
	enemy.global_position = Vector3(0, 0, -2)
	for hz in [30, 60, 120]:
		for offset in [-1, 0, 1]:
			player.reset_combat()
			player.request_guard_press()
			player._tick_combat(0.0)
			for frame in int(0.2 * hz) + offset:
				player._tick_combat(1.0 / hz)
			var result: int = player.receive_hit(Hit.new(20, enemy))
			var expected: int = player.HitResult.PARRY if offset <= 0 else player.HitResult.BLOCK
			_expect(result == expected, "parry boundary %d Hz, frame offset %+d" % [hz, offset])
	player.reset_combat()
	player.request_guard_press()
	player._tick_combat(0.0)
	player.receive_hit(Hit.new(20, enemy))
	player.set_physics_process(true)
	await _steps(65)
	_expect(player.counter_time_left() == 0.0, "unspent counter expires after its gameplay window")
	player.request_jump()
	player._glide_blend = 1.0
	player.reset_combat()
	_expect(not player._jump_pressed and not player.is_gliding() and player.jump_buffer_left() == 0.0,
		"training reset clears queued jump and glide state")
	player.set_physics_process(true)

func _player_wall() -> void:
	dummy.global_position = Vector3(0, 0, -1.4)
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.2)
	col.shape = box
	wall.add_child(col)
	level.add_child(wall)
	wall.global_position = Vector3(0, 1.0, -0.7)
	await _steps(3)
	player.request_attack()
	await _until(func(): return player.attack_phase_name() == "ACTIVE")
	await _steps(2)
	_expect(dummy.hit_count() == 0, "player melee cannot hit a target through a world wall")
	wall.queue_free()
	await _steps(3)
	_expect(dummy.hit_count() == 1, "removing the wall during the active window permits one real hit")

func _mapped_inputs() -> void:
	var x_button := false
	var lb_button := false
	for event in InputMap.action_get_events("use_weapon_light"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X:
			x_button = true
	for event in InputMap.action_get_events("use_gadget_light"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			lb_button = true
	_expect(x_button, "GDD controller X is mapped to attack")
	_expect(lb_button, "GDD controller LB is mapped to guard")
	player.input_enabled = true
	Input.action_press("use_gadget_light")
	Input.action_press("use_weapon_light")
	await _steps(3)
	_expect(player.is_guarding() and not player.is_attacking(),
		"real simultaneous attack and guard inputs prioritise guard")
	Input.action_release("use_weapon_light")
	Input.action_release("use_gadget_light")
	await _steps(3)
	_expect(not player.is_guarding(), "real guard release returns to normal")
	player.input_enabled = false

func _real_enemy_timing() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		player.reset_combat(Vector3(0, 0.05, 0))
		player.rotation.y = 0.0
		enemy.reset_enemy()
		enemy.global_position = Vector3(0, 0, -2)
		enemy.set_physics_process(true)
		var winding: bool = await _until(func(): return enemy.state == enemy.State.WINDUP)
		_expect(winding and enemy.prelude_playing(),
			"%d Hz: real enemy starts animation and audio prelude" % hz)
		var in_window: bool = await _until(func():
			return enemy.time_to_impact() >= 0.0 and enemy.time_to_impact() <= 0.12)
		if in_window:
			player.request_guard_press()
		var parried: bool = await _until(func(): return enemy.is_staggered())
		_expect(parried and player.health == player.max_health,
			"%d Hz: actual impact resolves to zero-damage parry" % hz)
		await _steps(int(1.35 * hz))
		_expect(enemy.is_staggered(), "%d Hz: enemy remains staggered at 1.35 gameplay seconds" % hz)
		await _steps(int(0.3 * hz))
		_expect(not enemy.is_staggered(), "%d Hz: enemy exits its 1.5s stagger" % hz)
		enemy.set_physics_process(false)
		player.request_guard_release()
		await _steps(2)
	Engine.physics_ticks_per_second = original_hz

func _slowmo_lifecycle() -> void:
	player.parry_slowmo_scale = 0.1
	player._play_parry_slowmo()
	await _real_wait(0.10)
	_expect(is_equal_approx(Engine.time_scale, 0.1), "slow motion holds at 0.1 during its 0.25s plateau")
	await _real_wait(0.20)
	_expect(Engine.time_scale > 0.1 and Engine.time_scale < 1.0,
		"slow motion smoothly recovers during the following 0.15s")
	await _real_wait(0.15)
	_expect(is_equal_approx(Engine.time_scale, 1.0), "slow motion ends by 0.45 real seconds")
	player._play_parry_slowmo()
	await _real_wait(0.06)
	player._play_parry_slowmo()
	await _real_wait(0.08)
	player.reset_combat()
	await _real_wait(0.45)
	_expect(is_equal_approx(Engine.time_scale, 1.0), "reset invalidates both overlapping slow-motion jobs")
	player._play_parry_slowmo()
	player.receive_hit(Hit.new(10000, enemy))
	await _real_wait(0.45)
	_expect(not player.is_alive() and is_equal_approx(Engine.time_scale, 1.0),
		"death cancels the slow-motion job and restores global time")
	player.reset_combat()
	player._play_parry_slowmo()
	player.queue_free()
	await process_frame
	_expect(is_equal_approx(Engine.time_scale, 1.0), "player removal restores global time scale")

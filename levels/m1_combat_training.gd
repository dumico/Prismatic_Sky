extends Node3D

## M1 战斗训练场（GDD §4 / §9 M1 验收）。
##
## 这不是正式关卡：一个木桩（三段连击/伤害比例/第三段击退/软锁定）、
## 一个训练守卫（正面防御/背后受击/防御耐久破防/前摇+音效前奏的可弹反攻击）、
## 一块平地和一个可隐藏的开发用诊断 HUD。
##
## 明确不做（M3 范畴）：正式暗影小卒/射手、巡逻 AI、掉落、关卡遭遇战。
## GDD §4.4：不显示红光，也不显示弹反精确时机；音效前奏 + 动作前摇是唯一提示。

var _player
var _dummy
var _enemy
var _camera

var _player_spawn: Vector3
var _player_spawn_yaw: float

var _hud_root: Control
var _hp_bar: ProgressBar
var _guard_bar: ProgressBar
var _hp_label: Label
var _guard_label: Label
var _state_label: Label
var _counter_label: Label
var _enemy_label: Label
var _debug_note: Label
var _hud_visible: bool = true
var _resetting: bool = false
var _reset_generation: int = 0


func _ready() -> void:
	_player = get_node_or_null("Player")
	_dummy = get_node_or_null("TrainingDummy")
	_enemy = get_node_or_null("TrainingEnemy")
	if _player == null or _dummy == null or _enemy == null:
		push_error("M1CombatTraining: 场景缺少 Player / TrainingDummy / TrainingEnemy")
		return
	_camera = _player.get_node_or_null("SpringCamera")
	_player_spawn = _player.global_position
	_player_spawn_yaw = _player.rotation.y
	_player.player_died.connect(_on_player_died)
	_build_hud()
	print("=== Prismatic_Sky M1 战斗训练场 ===")
	print("WASD 移动 / Shift 奔跑 / 空格跳跃")
	print("鼠标左键：三段轻击（连点）；鼠标右键长按：防御")
	print("守卫攻击有低沉嗡鸣前奏：在命中前按下右键=弹反；提前按=普通防御")
	print("R 重置训练 / F1 隐藏或显示诊断 HUD")
	print("目标：木桩试三连击与击退；守卫试正面防御、背后受击、连续格挡破防与弹反")


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.global_position.y < -12.0:
		reset_training()
		return
	_update_hud()
	_update_camera_combat_state()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_R:
		reset_training()
	elif key.keycode == KEY_F1:
		_hud_visible = not _hud_visible
		if _hud_root != null:
			_hud_root.visible = _hud_visible


func reset_training() -> void:
	if _resetting:
		return
	_resetting = true
	_reset_generation += 1
	Engine.time_scale = 1.0
	_player.reset_combat(_player_spawn)
	_player.rotation.y = _player_spawn_yaw
	_dummy.reset_dummy()
	_enemy.reset_enemy()
	if _camera != null and _camera.has_method("snap_to_target"):
		_camera.snap_to_target()
	print("[M1] 训练场已重置：玩家/木桩/守卫/防御耐久回到初始状态")
	_resetting = false


func _on_player_died() -> void:
	var generation := _reset_generation
	print("[M1] 玩家倒下，1.2s 后重置训练场")
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree() and generation == _reset_generation:
		reset_training()


func _update_camera_combat_state() -> void:
	if _camera == null or not _camera.has_method("set_combat_state"):
		return
	var close := false
	for target in [_dummy, _enemy]:
		if target != null and is_instance_valid(target):
			if target.has_method("is_alive") and not target.is_alive():
				continue
			if _player.global_position.distance_to(target.global_position) < 5.0:
				close = true
				break
	_camera.set_combat_state(close)


# ================================================================ HUD（开发用诊断，可 F1 隐藏）
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = 10
	add_child(layer)
	_hud_root = Control.new()
	_hud_root.name = "HudRoot"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud_root)

	var help_panel := _make_panel(Vector2(16, 16), Vector2(640, 190))
	_hud_root.add_child(help_panel)
	var help := Label.new()
	help.text = (
		"Prismatic Sky · M1 战斗训练\n"
		+ "WASD 移动 / Shift 奔跑 / 空格跳跃\n"
		+ "鼠标左键：三段轻击（连点）    鼠标右键长按：防御\n"
		+ "木桩：验证 1 : 1 : 1.5 伤害与第三段击退\n"
		+ "守卫：听低沉嗡鸣前奏，在命中前按下右键弹反；提前按=普通防御\n"
		+ "R 重置训练    F1 隐藏/显示本 HUD"
	)
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_color", Color(0.94, 0.95, 0.97))
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("outline_size", 4)
	help.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help.offset_left = 14
	help.offset_top = 10
	help.offset_right = -14
	help.offset_bottom = -10
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_panel.add_child(help)

	var status_panel := _make_panel(Vector2(16, 0), Vector2(460, 184))
	status_panel.anchor_top = 1.0
	status_panel.anchor_bottom = 1.0
	status_panel.offset_top = -200.0
	status_panel.offset_bottom = -16.0
	_hud_root.add_child(status_panel)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 10
	box.offset_right = -14
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 4)
	status_panel.add_child(box)

	_hp_label = _make_label("生命 100 / 100")
	box.add_child(_hp_label)
	_hp_bar = _make_bar(Color(0.72, 0.24, 0.24))
	box.add_child(_hp_bar)

	_guard_label = _make_label("防御耐久 0 / 100")
	box.add_child(_guard_label)
	_guard_bar = _make_bar(Color(0.36, 0.62, 0.88))
	box.add_child(_guard_bar)

	_state_label = _make_label("状态 NORMAL    连击 0")
	box.add_child(_state_label)
	_counter_label = _make_label("反击强化：未激活")
	_counter_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	box.add_child(_counter_label)
	_enemy_label = _make_label("训练守卫：IDLE")
	box.add_child(_enemy_label)
	_debug_note = _make_label("[调试 HUD] 不显示弹反精确时机")
	_debug_note.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	box.add_child(_debug_note)


func _make_panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = size
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.72)
	style.border_color = Color(0.45, 0.55, 0.68, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _make_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.11, 0.9)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _update_hud() -> void:
	if _hp_bar == null:
		return
	_hp_bar.value = _player.health_ratio() * 100.0
	_hp_label.text = "生命 %.0f / %.0f" % [_player.health, _player.max_health]
	_guard_bar.value = _player.guard_pressure_ratio() * 100.0
	_guard_label.text = "防御耐久 %.0f / %.0f（格挡累积，脱手恢复）" % [
		_player.guard_pressure(), _player.guard_pressure_max,
	]
	_state_label.text = "状态 %s    连击 %d    %s" % [
		_player.combat_state_name(), _player.attack_step(), _player.attack_phase_name(),
	]
	if _player.counter_time_left() > 0.0:
		_counter_label.text = "反击强化：%.2fs 内下一击 ×%.1f" % [
			_player.counter_time_left(), _player.parry_counter_multiplier,
		]
		_counter_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	else:
		_counter_label.text = "反击强化：未激活"
		_counter_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))

	if _player.is_guard_broken():
		_enemy_label.text = "训练守卫：%s    玩家破防！%.2fs" % [
			_enemy.state_name(), _player.guard_break_time_left(),
		]
	elif _enemy.is_staggered():
		_enemy_label.text = "训练守卫：硬直 %.2fs（可反击）" % _enemy.stagger_time_left()
	else:
		_enemy_label.text = "训练守卫：%s    生命 %.0f / %.0f" % [
			_enemy.state_name(), _enemy.health, _enemy.max_health,
		]

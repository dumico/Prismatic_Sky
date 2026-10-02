extends SceneTree

## M0 工程自检：遍历工程内所有 GDScript 与场景资源，逐一 load()，
## 捕获脚本编译错误与缺失依赖（ext_resource 找不到会在这里显形）。
##
## 运行：
##   pwsh -File work/tools/godot.ps1 --headless --path . --script res://tools/verify_project.gd
## 退出码：0 = 全部通过；1 = 存在失败项。

const SKIP_DIRS := ["assets_repo", "work", "outputs", ".godot", ".git"]

var _ok := 0
var _fail := 0
var _failed_paths: Array[String] = []
var _log: FileAccess


func _initialize() -> void:
	_log = FileAccess.open("user://verify_progress.txt", FileAccess.WRITE)
	var scripts: Array[String] = []
	var scenes: Array[String] = []
	_walk("res://", scripts, scenes)
	scripts.sort()
	scenes.sort()

	_note("VERIFY: %d 个脚本，%d 个场景" % [scripts.size(), scenes.size()])

	for p in scripts:
		_check(p, true)
	for p in scenes:
		_check(p, false)

	_note("VERIFY_RESULT ok=%d fail=%d" % [_ok, _fail])
	if _fail > 0:
		for p in _failed_paths:
			print("  FAILED: ", p)
		quit(1)
	else:
		print("VERIFY_ALL_PASS")
		quit(0)


func _note(msg: String) -> void:
	print(msg)
	if _log != null:
		_log.store_line(msg)
		_log.flush()


func _walk(dir_path: String, scripts: Array[String], scenes: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not SKIP_DIRS.has(name):
				_walk(full, scripts, scenes)
		else:
			if name.ends_with(".gd"):
				scripts.append(full)
			elif name.ends_with(".tscn"):
				scenes.append(full)
		name = d.get_next()
	d.list_dir_end()


func _check(path: String, is_script: bool) -> void:
	_note("CHECK %s" % path)
	# 注意：不要用 CACHE_MODE_IGNORE —— Godot 4.7.1 下重复 ignore-cache 载入带 class_name
	# 的 GDScript 会 signal 11（已用 tools/_probe_load.gd 最小复现）。
	var res := ResourceLoader.load(path)
	if res == null:
		_fail += 1
		_failed_paths.append(path)
		print("FAIL  ", path)
		return
	if is_script and not (res is GDScript):
		_fail += 1
		_failed_paths.append(path)
		print("FAIL(not GDScript) ", path)
		return
	if is_script:
		var gd := res as GDScript
		if not gd.can_instantiate():
			_fail += 1
			_failed_paths.append(path)
			print("FAIL(uninstantiable/编译错误) ", path)
			return
	_ok += 1

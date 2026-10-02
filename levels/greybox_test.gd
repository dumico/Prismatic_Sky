extends Node3D

## M0-6 灰盒测试场景（GDD §3.3、§9）
##
## 场景内容（全部为程序化灰盒，不含任何 §6 氛围美术资产；氛围是 M3 的事）：
##   · 平地      —— 100×100 的整块地面，供起步/刹停/转身手感验收
##   · 高低台    —— 10 级 1.2m 台阶（每级都在 §3.3 的 1.56m 跳高之内）直达 12m 跳台；
##                  另有 1.2m / 2.4m / 5.0m 三块独立方台与一根 12m 立柱
##   · 可滑翔落差 —— 12m 高的跳台，落差足够展开披风后滑出 ~30m（§3.2 俯冲/拉升都够空间）
##
## 操作（GDD §3.1【锁定】）：
##   WASD 移动 / Shift 奔跑 / 空格跳跃（空中按住空格 = 滑翔）/ 鼠标或右摇杆控制相机
##   滑翔中：相机低头 = 俯冲换速度，抬头 = 拉升耗速度换高度
##
## 本脚本只做两件事：打印操作说明、把掉出场景外的角色送回出生点（避免验收时卡死）。
## 不做任何 UI（M0 禁区；GDD §9）。

## 掉落低于此高度即送回出生点。
@export var respawn_height: float = -25.0
## 出生点（相对本场景）。
@export var spawn_point: Vector3 = Vector3(0, 0.1, 14)

var _player: Node3D


func _ready() -> void:
	_player = get_node_or_null("Player")
	if _player == null:
		for n in get_tree().get_nodes_in_group("player"):
			_player = n
			break
	if _player == null:
		push_warning("GreyboxTest: 场景里找不到玩家节点")
		return
	_player.global_position = spawn_point
	print("=== Prismatic_Sky M0 灰盒测试场 ===")
	print("WASD 移动 / Shift 奔跑 / 空格跳跃")
	print("空中按住空格 = 滑翔；滑翔中相机低头 = 俯冲，抬头 = 拉升")
	print("鼠标（或右摇杆）控制相机；Esc 退出")
	print("目标：跑上 10 级台阶到 12m 跳台，跳下去试试滑翔手感")


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if _player.global_position.y < respawn_height:
		_respawn()


func _respawn() -> void:
	_player.global_position = spawn_point
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	print("掉出场景，已送回出生点 ", spawn_point)

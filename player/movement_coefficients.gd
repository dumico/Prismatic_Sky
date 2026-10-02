extends Resource
class_name MovementCoefficients

## GDD §3.3 / §11.2：**所有移动手感参数 = 基础值 × 修正系数（初始 1.0）**。
##
## 基础值写在 PrismaticPlayer 的 @export 里（策划拖数值调手感）；
## 本资源只放**系数**，供未来的技能 / 时装 / 道具按比例放大或缩小某一项
## （例如「滑翔披风」把 glide_fall_speed 系数改成 0.75），
## 从而不必改移动代码、也不必复制一份基础值。全部默认 1.0 = 与 §3.3 v1 表完全一致。

@export_group("位移")
@export var gravity := 1.0
@export var jump_velocity := 1.0
@export var walk_speed := 1.0
@export var run_speed := 1.0
@export var accel_ground := 1.0
@export var decel_ground := 1.0
@export var air_control := 1.0

@export_group("判定宽容（★ 永不低于 1.0 的兜底见 PrismaticPlayer）")
@export var coyote_time := 1.0
@export var jump_buffer := 1.0

@export_group("表现层")
@export var turn_smooth := 1.0
@export var landing_stiff_threshold := 1.0

@export_group("滑翔（M0-5）")
@export var glide_enter_time := 1.0
@export var glide_fall_speed := 1.0
@export var glide_dive_accel := 1.0
@export var dive_max := 1.0
@export var glide_lift_boost := 1.0

@export_group("相机")
@export var camera_stiffness := 1.0
@export var cam_dist := 1.0

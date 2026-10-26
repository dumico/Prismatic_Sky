# DECISIONS.md —— Prismatic_Sky 一次性架构确认

> **本文件的性质**：这里只登记**已经做过、且可由存活文件或 GDD 复核**的一次性架构确认。
> 日常实现细节不写在这里（GDD §0.3：一次对话只做一个模块，任务卡片见 `TASKS.md`）。
>
> **关于历史的如实声明【重要】**：本项目 M0 阶段原有的**逐步提交历史已不可用**。
> 跨盘迁移事故中工程根目录的普通文件与原 Git 元数据一并丢失——存活的 `.git` 目录是**空目录**，
> 不含任何 object / ref / HEAD，无法恢复任何历史提交、提交信息或时间线。
> 因此当前仓库是**在 C 盘临时恢复区重新初始化 Git 后的单次新基线**，
> 提交 `[M0] Recovered baseline after relocation`。
> **这不是历史延续**：新基线之前没有可追溯的提交，旧 M0 的分步 commit 记录无法重建，也不得声称其存在。

---

## 1. 引擎与技术栈【锁定】

| 项 | 决定 | 依据 |
|---|---|---|
| 引擎 | Godot **4.7.1.stable.official.a13da4feb** | GDD §8「M0 导入成功后锁定版本号，全项目不再升级」 |
| 语言 | GDScript（不引入 C#/GDExtension） | GDD §8「Godot 4.x（GDScript）」 |
| 渲染 | `renderer/rendering_method="mobile"`，`mobile="gl_compatibility"` | 模板原值，`assets_repo/SOURCES.md` 已登记 |

- 版本号锁定值另存于根目录 `GODOT_VERSION.txt`；本机引擎路径见 `GODOT_PATH.txt`。
- 复核证据：`assets_repo/SOURCES.md`「模板与 Godot 版本」条；迁移前日志 `work/logs/final_*.log` 头部版本串；
  本次恢复跑通的导入/验证日志 `work/logs/recover_*.log`。

## 2. 起点：Cat's 模板【暂定，附推翻条件】

- **决定**：以 **Cat's Godot4 Modular Souls-like Template**（The Unlicense / CC0 意图）为工程起点，
  保留其移动、相机、格挡弹反框架、敌人状态机、音频系统与工具脚本；删除 demo 关与 Demo 不需要的系统。
- **推翻条件**（GDD §7 台账原文）：与 Godot 版本不兼容，或 M1 改造成本 > 2 模块。
- **复核证据**：`work/tools/m0_2_import.py`（导入与删减脚本，含 `COPY_DIRS` / `DELETE_DIRS` / `COPY_FILES` 清单）；
  存活目录结构与脚本 `class_name` 清单（`.godot/global_script_class_cache.cfg`）；
  `assets_repo/templates/Cats-Godot4-Modular-Souls-like-Template/`。
- 根目录 `project.godot` 即由该模板 `project.godot` 改写而来（改写方式与 `m0_2_import.py` 完全一致）。
- 模板自带 `LICENSE` 已随恢复放回根目录。

## 3. 场景即模块【锁定】

- **决定**：玩家、每种敌人、Boss、祭坛**各是一个独立 `.tscn`**，由场景拼装而非脚本硬造节点。
- **依据**：GDD §8「场景即模块」；§11.2「新场景 = 场景即模块 .tscn 拼装」。
- **复核证据**：存活场景 `player/prismatic_player.tscn`、`player/player_charbody3d.tscn`、
  `cameras/follow_cam/follow_cam.tscn`、`cameras/area_cam/area_cam.tscn`、`enemy/*.tscn`、
  `levels/greybox_test.tscn`（M0 灰盒测试场，当前 `main_scene`）。

## 4. Autoload 只放三个：GameState / EventBus / AudioManager【锁定】

- **决定**：Autoload 全局单例**只允许**三个——`GameState`、`EventBus`、`AudioManager`；不得随意增设。
- **依据**：GDD §8「Autoload 只放三个」；§5「碎片事件走全局信号（EventBus）」。
- **M0 落地状态（已核实，非推测）**：**M0 存活文件中这三个单例并不存在**——
  33 个存活脚本里没有 `GameState` / `EventBus` / `AudioManager` 的任何定义或引用，
  本次重建的 `project.godot` 也**没有** `[autoload]` 段。
  即：该约定是**架构上限**，M0 阶段尚未落地，属 M1 及之后的任务。
  （把不存在的脚本写进 `[autoload]` 会导致启动报错，故恢复时**刻意不添加**。）
- **待复核**：三个单例的具体落地时点与拆分粒度，待 M1 任务卡片确定。

## 5. 信号驱动【锁定】

- **决定**：伤害、拾取、死亡等一律走 `signal`，**不写死节点路径**。
- **依据**：GDD §8「信号驱动」；§11.1 只预留"锚点"（信号、系数、文件夹约定）。
- **复核证据**：存活脚本中的 `signal` 声明与 `connect` 用法，例如
  `player/player_charbody3D.gd` 的 `health_received`、`item_change_ended`，
  以及 `utility scripts/signal_caller.gd`、`utility scripts/signal_switch.gd`。

## 6. 数值资源化 / @export【锁定】

- **决定**：敌人属性、手感参数用**自定义 `Resource` 或 `@export`**，调手感由策划在编辑器里拖数值完成。
- **依据**：GDD §0.3「数值一律做成 Godot 编辑器导出变量（@export）」；§8「数值资源化」。
- **复核证据**：`player/movement_coefficients.gd`（`class_name MovementCoefficients extends Resource`，
  逐项系数默认 1.0）；`player/prismatic_player.gd` 的 `@export` 基础值；
  `player/equipment_system/equipment/equipment_resource.gd`（`EquipmentResource`）。
- **配套约定**（GDD §3.3 / §11.2）：**所有手感参数 = 基础值 × 修正系数（初始 1.0）**，
  未来技能/时装/道具只改系数，不改基础值、不改移动代码。

## 7. 防过度工程化【锁定】

- **决定**：**第一次出现直接写，第二次出现复制改，第三次出现才抽象成框架**。
- **依据**：GDD §8「防过度工程化纪律」；§10.1「凡是模板已有系统只调参不重写」。
- **本次恢复的遵守方式**：只补回迁移丢失的根目录文件，**不重构、不抽象、不新增系统**。

---

## 8. 恢复期新增的两处判断（本次独有，非历史决定）

> 这两条是"文件已丢失、必须重建"时的处置，登记以免日后误认为是原设计。

1. **`project.godot` 的输入映射为重建件**
   - 以模板 `project.godot` 的 `[input]` 段**原样保留**为底；
   - **新增 `run` 动作**（Shift 物理键码 4194325 + 手柄轴 5）：存活脚本 `player/prismatic_player.gd`
     第 250 行读取 `Input.is_action_pressed("run")`，而模板**没有** `run` 动作，缺它则奔跑失效；
   - **给 `jump` 追加 Space**（物理键码 32，保留模板原有的 F 与手柄 A）：
     依据 GDD §3.1【锁定】「空格 / A = 跳跃」，且存活 `levels/greybox_test.gd` 打印的操作说明即「空格跳跃」。
   - **待复核**：原 `project.godot` 的完整事件列表（丢失），除上述两处外其余绑定沿用模板原值，
     具体手感应以策划试玩后的实际手感为准。
2. **根目录文件清单的来源**
   - 丢失文件的**存在性**由 `.godot/editor/filesystem_cache10` 的 `res://` 根段记录复原
     （`BLOCKERS.md` / `DECISIONS.md` / `GODOT_PATH.txt` / `GODOT_VERSION.txt` / `icon.png` /
     设计文档 / `TASKS.md`），`LICENSE` 由 `m0_2_import.py` 的 `COPY_FILES` 证实；
     而 `project.godot`、`.gitignore` 是 Godot/Git 的隐含文件、不进该缓存，按工具链约定补回。
   - `icon.png` 的恢复是**逐字节可验证**的：其 MD5 `d270a3c425fefea64e41d99e2a7314cf`
     与 `.godot/imported/icon.png-*.md5` 内记录的 `source_md5` 完全一致。

---

## 9. 仍然"待复核"的清单（不得编造）

| 项 | 为什么待复核 |
|---|---|
| 旧 M0 的逐步提交历史（提交数、提交信息、时间线） | `.git` 为空目录，元数据已丢失，**不可恢复** |
| 原 `project.godot` 的完整设置项与输入事件细节 | 文件丢失；除上表可验证部分外按模板重建 |
| `GameState` / `EventBus` / `AudioManager` 的落地时点与接口 | M0 未实现，属 M1 任务 |
| 其余被删减的根目录小文件是否还有遗漏 | 仅能以 `filesystem_cache10` 与导入脚本为证，二者之外无法穷举 |
| 迁移前 `.godot/` 缓存与当前重建结果是否逐项一致 | 已通过导入(仅 icon.png 重导)与三项验证间接确认，未逐字节比对 |

---

## 10. D 盘迁移完成记录（2026-10-02；不重评架构）

恢复基线 `b14f615e7f5531c17389b726eda7153e2bdcb6af` 先在 C 盘临时恢复区创建，再以 Git 归档与 bundle 导入 `D:\GameProjects\Prismatic_Sky`。D 盘提交与 C 盘一致，Godot 4.7.1 主场景启动及工程完整性校验通过。原 M0 分步历史仍不可用；本条仅记录迁移，不修改上文一次性架构决定。C 盘临时副本在策划验收前暂作回退。D 盘 DS shell 沙箱仍有目录 ACL 限制，未改变 ACL。

## 11. M0 地面移动调参记录（2026-10-21；参数决定，非架构变更）

- **依据**：GDD §3.3 移动手感参数表 v1 为【暂定】，推翻条件“M0 试玩后策划感到‘粘’变成了‘拖’”已由人类试玩反馈触发；反馈为普通移动太慢、Shift 与普通移动速度差过大、地面起停/转向不够灵活。按 §0.2，【暂定】项可在条件触发后替换。
- **决定**：`walk_speed_base` 2.5→4.0，`accel_ground_base` 12.0→16.0，`decel_ground_base` 24.0→30.0，`turn_smooth_base` 10.0→16.0；`run_speed_base` 保持 6.0（不提高冲刺上限）。
- **结果**：普通/Shift 速度差 2.4×→1.5×；0→走速 0.25s、0→跑速 0.375s、跑速刹停 0.20s；转向时间常数 0.10s→0.0625s。全部仍是 `@export` 基础值，继续遵守“基础值 × 修正系数”（§3.3 / §11.2）。
- **未改 / 未偏离**：§3.2 滑翔专用参数与机制、§3.1 操作、战斗数值、敌人、UI、存档、资源、模型；未引入插件或新功能；未偏离任何【锁定】项，故不开 BLOCKERS。
- **派生影响**：`accel_ground` 按 §3.3 现有公式同时参与空中/滑翔水平响应，滑翔水平加速度由 6.6 升至 8.8 m/s²；`glide_speed` 6.9、0.25s 展开、−2.5 落速、俯冲/拉升不变，待复试玩确认可接受。
- **回退**：四项基础值改回 2.5 / 12.0 / 24.0 / 10.0，或 `git revert d745f6d`；不涉及场景、资源或存档。
- **模型边界**：当前 KayKit Adventurers 只作技术验证，本轮不替换。未来角色气质方向为《光·遇》式温柔简洁，具体美术设计未定稿。

## 12. M1 战斗骨架实现决定（2026-10-26；实现级，不改变 §1~§7 架构）

- **复用 M0 玩家控制器**：战斗状态机直接扩展 `player/prismatic_player.gd`，不复活模板遗留的
  `player_charbody3D.gd` / `player_anim_tree.gd`。理由：M0 已由用户验收；模板树依赖
  `minnyquinn` 骨骼与 `MeleeLib.res`，整体替换会破坏 M0 的移动/滑翔/相机，违反“保护 M0”。
- **状态机直接写**：玩家内用 `enum CombatState { NORMAL, ATTACK, GUARD, GUARD_BROKEN }`
  + `enum AttackPhase` + `@export` 参数实现三连击/防御/破防/弹反互斥；不新建通用状态机框架
  （GDD §8 防过度工程化）。
- **真实命中检测**：攻击 active 窗口内用 `PhysicsShapeQueryParameters3D.intersect_shape`
  查询 `project.godot` layer 3 = `Targets` 的实体；一次挥击用 `instance_id` 去重。
  伤害由 `combat/combat_hit.gd` 承载，目标实现 `receive_hit()`；不按动画播放完成无条件扣血。
- **弹反时间基准**：受击结算时读取 `_guard_time`（本次防御按下后经过的时长），
  `_guard_time <= parry_window(0.2)` 且来击在正面 120° 内、`parryable` 才成功。
  因此窗口对齐“攻击实际命中前的 0.2s”：按住超过 0.2s 只普通格挡；命中后才按不会追溯成功。
- **防御朝向**：防御期间角色朝向平滑跟随相机水平朝向，WASD 相对相机移动；120° 判定以
  角色当前战斗朝向为基准（不是相机瞬时朝向）。理由：避免后退时把背露给敌人，并给玩家
  一个稳定可读的防御基准（GDD §4.2）。
- **训练对象独立**：新增 `enemy/training_dummy.tscn` 与 `enemy/training_enemy.tscn`，
  不复用模板 `enemy_base_root_motion.tscn`（后者依赖 `minnyquinn`、导航与完整状态机，
  M1 改造成本不必要）。训练守卫是临时验证对象，不是 M3 的正式敌人/AI。
- **基础反馈范围**：M1 只做低沉嗡鸣前奏、清脆弹反音效、Torus 光圈、camera trauma、
  0.1 倍速 0.25s + 0.15s 回弹；帧冻结、粒子、混音、精细震屏按 GDD §4.6 留 M2。
- **前奏音效为程序化占位**：`audio/SoundFX/combat/parry_prelude.wav` 由本地脚本合成
  （0.72s 低频渐起），非联网下载；M2 替换正式音效。生成脚本留在被 gitignore 的 `work/`，
  WAV 与 `.import` 入库。
- **盾牌占位**：程序化八边形圆盘挂在 `handslot.l` 骨骼，仅防御时显示；若换模型没有该骨骼，
  自动回退 `hand.l` 或跳过。任何命中判定都不读取盾牌网格（GDD §8.2 未来换装）。
- **M1 场景独立**：新增 `levels/m1_combat_training.tscn`；`main_scene` 仍保持
  `greybox_test.tscn`，保证 M0 回归与 `verify_greybox.gd` 的主场景断言不被破坏。
- **不新增 Autoload / 输入映射**：复用模板已有 `use_weapon_light`（鼠标左键）与
  `use_gadget_light`（鼠标右键），不引入 GameState/EventBus/AudioManager。
- **验证门禁**：新增 `tools/verify_combat.gd`（107 项）；M0 三项验证继续作为每轮回归门禁。

---

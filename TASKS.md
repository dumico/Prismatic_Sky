# TASKS.md —— Prismatic_Sky 任务与里程碑状态

> 母文档：`Prismatic_Sky_设计文档_v0.2.md`（GDD v0.2，唯一权威规格，已放回仓库根目录）。
> 任务卡片模板见 GDD §9；架构一次性确认见 `DECISIONS.md`；当前阻塞见 `BLOCKERS.md`。
>
> **M0 状态更新（2026-10-26）**：M0 已由用户人工确认试玩通过。本轮 M1 不重复要求 M0 验收；
> M0 的验证记录保留在下方历史段落中，不改写。

---

## ⚠️ 关于历史的如实声明（先读这一段）

本次是**跨盘迁移事故后的恢复**，不是正常开发推进：

- 事故中工程**根目录普通文件**（`project.godot`、`GODOT_PATH.txt`、`GODOT_VERSION.txt`、`.gitignore`、
  `TASKS.md`、`DECISIONS.md`、`BLOCKERS.md`、`icon.png`、`LICENSE`）与**原 Git 元数据**一并丢失；
- 存活的 `.git` 是**空目录**，无任何 object / ref / HEAD——**M0 原有的逐步提交历史不可恢复**；
- 现在是**在 C 盘临时恢复区重新初始化 Git 后的一次性新基线**：
  `[M0] Recovered baseline after relocation`。
  **不得描述为历史延续**：此提交之前没有可追溯记录，旧 M0 的分步 commit 无法重建。

**好消息**：M0 的**实质成果全部存活**——场景、脚本、资源、工具、`.godot/` 导入缓存都在，
本次只补回丢失的根目录文件，并已**跑通全部验证**（见下）。工程可用。

---

## 当前状态

**M0 工程奠基 —— ✅ 已由用户人工确认试玩通过（2026-10-26）。**
**M1 战斗骨架 —— 实现与技术审计完成，待用户人工试玩验收（未进入 M2）。**

> 2026-10-26 Codex 独立审计：基于 DPH `52ffaa0` 修复六类可复现问题；本轮回归为
> 58 / 83 / 34 / 108 / 52 全通过，并实际完成窗口中的三连击、防御、弹反与反击验证。
> 审计分支 `audit/m1-combat-core`，详细证据、保留的表现限制与操作见 `M1_CODEX_AUDIT.md`。
> 下方 DPH 实现期日志和统计保留为历史，不改写为审计结果；主观听声与手感验收仍由用户完成。

| 项 | 状态 |
|---|---|
| M0 场景 / 脚本 / 资源 / 工具 | ✅ 存活未损（33 脚本、16 场景，逐一 `load()` 通过） |
| 根目录配置文件 | ✅ 已按存活证据重建（清单来源见 `DECISIONS.md` §8） |
| Godot 导入 | ✅ 干净通过（仅 `icon.png` 重新导入） |
| 三项验证脚本 | ✅ 迁移恢复 49 / 78 / 34；试玩调参后 49 / 83 / 34，全绿 |
| 短时主场景启动 | ✅ 通过 |
| **C 盘临时恢复区 Git 新基线** | ✅ 单个提交 `[M0] Recovered baseline after relocation` |
| **D 盘正式目录 `D:\GameProjects\Prismatic_Sky`** | ✅ 已迁移；Git b14f615 与恢复基线一致，Godot 主场景启动与工程完整性校验通过 |
| **M0 地面移动反馈调参** | ✅ 用户已人工验收通过（2026-10-26）；walk/accel/decel/turn 调参有效，三项验证 + 短时主场景通过 |

> 更新：D 盘正式迁移已完成并验证。C 盘临时恢复区暂作回退副本；D 盘 DS shell 沙箱权限问题仍需在后续开发前处理，未修改目录 ACL。

---

## M1 战斗骨架（2026-10-26）—— 自动测试完成，待人工验收

**状态：✅ 三连击 / 防御 / 弹反 / 训练场已实现并通过自动验证；⏳ 待用户实际试玩验收。未进入 M2。**
详细操作、架构、Codex 审计交接与 M2 观察见 [`M1_HANDOFF.md`](M1_HANDOFF.md)。

| 子模块 | 状态 | 说明 |
|---|---|---|
| 三段轻击 | ✅ | 1 : 1 : 1.5、第三段击退、3m 软锁定、第三段后摇可防御取消 |
| 长按防御 | ✅ | 正面 120° / 减伤 70% / 移速 50% / 防御中禁攻 / 背侧不减伤 |
| 隐藏防御耐久 | ✅ | 连续格挡累积，满值破防 1s，期间禁防禁攻，脱手延迟恢复 |
| 弹反 | ✅ | 0.2s 命中前窗口、伤害归零、敌人硬直 1.5s、1s 内下一击 ×2 只消费一次 |
| 弹反反馈 | ✅（M1 基础） | 低沉嗡鸣前奏、清脆音效、地面光圈、0.1 倍速 0.25s + 0.15s 回弹、相机 trauma |
| 训练场 | ✅ | 木桩（三段/伤害/击退/软锁）+ 训练守卫（防御/背击/破防/弹反）+ 诊断 HUD |
| M0 回归 | ✅ | 移动/跳跃/滑翔/相机/灰盒场景三项验证全绿 |

### 实际自动测试结果

| 验证 | 命令 | 结果 | 证据 |
|---|---|---|---|
| 工程完整性 | `res://tools/verify_project.gd` | `ok=57 fail=0`，`VERIFY_ALL_PASS` | `verification/m1/verify_project.log` |
| 玩家 / 移动手感 | `res://tools/verify_player.gd` | `checks=83 fail=0`，`VERIFY_PLAYER_ALL_PASS` | `verification/m1/verify_player.log` |
| 灰盒 / 滑翔 | `res://tools/verify_greybox.gd` | `checks=34 fail=0`，`VERIFY_GREYBOX_ALL_PASS` | `verification/m1/verify_greybox.log` |
| M1 战斗 | `res://tools/verify_combat.gd` | `checks=107 fail=0`，`VERIFY_COMBAT_ALL_PASS` | `verification/m1/verify_combat.log` |
| M1 场景窗口启动 | 窗口运行 + 实际截图（本地 `work/` 脚本，不入库） | 退出码 0；1280×720 实拍 | `verification/m1/m1_scene.png` 等 |
| M0 灰盒窗口启动 | `godot --path . --quit-after 240` | 退出码 0 | `verification/m1/greybox_boot.log` |

> 自动测试使用真实 Godot 4.7.1 执行，注入输入并逐物理帧断言；不是静态检查或伪造日志。
> 截图由实际窗口渲染 `get_viewport().get_texture().get_image()` 保存，非合成图。

### 仍需用户人工验收（AI 不代判）

1. **最重要**：不看画面，只听守卫攻击的低沉嗡鸣前奏与节奏，尝试并逐渐学会弹反。
2. 三段攻击的节奏、第三段击退幅度、软锁定转向是否自然。
3. 正面防御的 120° 体感、背后受击是否明确；盾牌在第三人称背面被身体遮挡，是否影响判断。
4. 连续格挡 4 次破防的阈值（28×4）与 1s 踉跄是否合适。
5. 弹反的 0.1 倍速 0.25s、光圈、镜头反馈是否过强/过弱。
6. 训练守卫前摇 0.9s、前奏 0.72s、攻击间隔 1.1s 的节奏是否适合学习。
7. M0 灰盒场景跑跳滑翔是否仍正常（自动回归已过，手感仍需人判）。

### 已知限制（不冒充完成）

- 训练守卫是临时对象，不是 M3 的完整暗影小卒/射手，不含巡逻、追击、多招、掉落。
- 三段攻击的命中窗口按动画时长比例（0.38~0.60）估算，未逐帧对齐 KayKit 动画接触帧；M2 可做帧冻结/接触帧校准。
- 弹反光圈是简单 TorusMesh，不是 GPUParticles3D 粒子；M2 再做粒子与混音。
- 帧冻结（0.06s/0.10s）与完整震屏调校按 GDD §4.6 留到 M2；M1 只做基础时间减速/震动。
- 训练 HUD 显示防御耐久与敌人状态，属开发诊断；正式玩法不应显示，F1 可隐藏。
- 守卫盾牌是骨骼挂点上的程序化占位件，从默认第三人称背面会被角色身体遮挡。
- 自动测试不验证“好听/好手感/音效可辨”，这些必须人工试玩。

### 留给 M2 的观察（详见 M1_HANDOFF.md §H）

- KayKit 的 `Blocking` 姿态原本为持盾设计，无盾时略像蹲伏；占位盾已改善正面可读性。
- Attack 动画 clip 长度约 1.0s，M1 用 1.3× TimeScale 压到约 0.77s；接触帧仍建议在 M2 用动画事件校准。
- 当前 AnimationTree 由 `prismatic_player.gd` 代码构建，Skeleton3D/AnimationPlayer 路径绑定在 `Model/AnimationPlayer`；换模型需核对骨骼名与 AnimationPlayer 路径。
- 未来换装可复用 `handslot.l` 盾牌挂点与 `hand.r`/`handslot.r` 武器挂点；战斗判定不依赖网格外观。

---

## 运行入口

引擎路径记录于根目录 `GODOT_PATH.txt`。正式引擎：
`D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe`（Godot **4.7.1.stable.official.a13da4feb**，§8 已锁定）。

> 2026-10-26 注：当前 checkout 中 `work/tools/godot.ps1` 与 `work/godot-portable/` 不存在
> （`work/` 被 gitignore，属迁移恢复期临时件）。M1 起直接调用 `GODOT_PATH.txt` 的正式引擎；
> M1 的实测命令与证据见 `verification/m1/README.md`。

迁移恢复期使用工作区内的便携引擎（self-contained，同目录有 `_sc_` 标记），经封装脚本调用：

```powershell
# 0) 导入（仅资源变动时需要）
pwsh -File work/tools/godot.ps1 --headless --path . --import

# 1) 策划试玩（有窗口，进灰盒测试场）
pwsh -File work/tools/godot.ps1 --path .

# 2) 无头验证三件套
pwsh -File work/tools/godot.ps1 --headless --path . --script res://tools/verify_project.gd
pwsh -File work/tools/godot.ps1 --headless --path . --script res://tools/verify_player.gd
pwsh -File work/tools/godot.ps1 --headless --path . --script res://tools/verify_greybox.gd
```

- `main_scene` = `res://levels/greybox_test.tscn`（M0 灰盒测试场）。
- 操作（GDD §3.1【锁定】）：**WASD 移动 / Shift 奔跑 / 空格跳跃（空中按住空格 = 滑翔）/
  鼠标控制相机（滑翔中低头 = 俯冲、抬头 = 拉升）/ Esc 退出**。
- 场景内容：100×100 平地、10 级 1.2m 台阶直达 12m 跳台、1.2/2.4/5.0m 独立方台、12m 立柱。
  场景内**无任何 UI**（遵守 M0 禁区）。

---

## 验证结果（2026-10-02 迁移恢复 / 2026-10-21 调参复核，C 盘临时工作区）

引擎在长时启动时输出一条环境级噪声
`ERROR: Failed to read the root certificate store` —— 迁移**之前**的日志同样存在，
与资源/迁移无关，**非回归**。

| 验证 | 命令 | 结果 |
|---|---|---|
| 工程完整性 | `tools/verify_project.gd` | `ok=49 fail=0`，`VERIFY_ALL_PASS`（33 脚本 + 16 场景全部可载入、无缺失依赖） |
| 玩家与 §3.3 手感参数 | `tools/verify_player.gd` | 迁移恢复 `checks=78 fail=0`；调参后 `checks=83 fail=0`，均 `VERIFY_PLAYER_ALL_PASS` |
| 灰盒场景与端到端滑翔 | `tools/verify_greybox.gd` | `checks=34 fail=0`，`VERIFY_GREYBOX_ALL_PASS` |
| 输入映射（重建件复核） | 临时探针，已删除 | `ok=true`：`run`=Shift+手柄轴5；`jump`=F+**Space**；`move_*`/`ui_cancel` 齐备 |
| 短时主场景 | `--quit-after 300` | 退出码 0，正常打印灰盒操作说明 |

与迁移前日志（`work/logs/final_project.log` / `final_player.log` / `final_greybox.log`）逐项吻合，
说明**迁移未破坏任何 M0 逻辑**。恢复期日志：`work/logs/recover_*.log`。

关键手感项实测（对应 GDD §3.2 / §3.3）：

- 跳跃高度 1.63m（目标 ≈1.56m）；土狼时间 0.12s、跳跃缓冲 0.12s 生效且带 0.02s 下限保护；
- 调参后 0.375s 加速到 `run_speed` 6.00、0.25s 内达到 `walk_speed` 4.00；0.20s 内刹停（减速 30.0 > 加速 16.0，"停比启快"）；迁移时初值为 0.5s / 0.25s / 12.0 / 24.0；
- 空中加速度 = 地面 × `air_control`(0.55)；不产生二段跳；
- 落速 ≥12 m/s 触发 0.12s 落地硬直 + 尘土粒子，轻落地不触发；
- 滑翔：0.25s 披风展开过渡（非瞬切）、`glide_fall_speed` −2.5、满俯冲趋近 `dive_max` −12.0、
  俯冲水平增速（9.31 > 6.90）、拉升耗速换高度（6.90 → 3.90）；
- 弹簧相机：探索态 4.5m / 战斗态 3.5m + FOV 收 5°，1 帧滞后 0.57m，最终收敛残差 0.001m；
- 端到端：从 12m 跳台走落自动进入滑翔，滑翔 3.03s、水平位移 22.8m，稳定落回地面。

---

## 需要策划试玩的手感项目（AI 不代判，等试玩数据）

以下均为 GDD 标注的【暂定】项，**必须**由策划在引擎内试玩判定；除本轮已由人类试玩反馈明确授权的 §3.3 地面四项（walk / accel / decel / turn）外，AI 不擅自改数值。

1. **滑翔手感**（§3.2 推翻条件：M0 试玩后手感不佳 → 降级为缓降或改二段跳）
   —— 重点体感"俯冲换速度 / 拉升耗速度"的灵魂机制是否成立，0.25s 披风展开是否够顺。本轮未改滑翔专用参数与机制（`accel_ground` 的派生水平响应变化见调参记录）。
2. **粘手 vs 拖沓**（§3.3 推翻条件：策划感到"粘"变成了"拖"）
   —— 本轮已按反馈把 `walk_speed` 2.5→4.0、`accel_ground` 12→16、`decel_ground` 24→30、`turn_smooth` 10→16；复试玩重点确认是否仍有拖沓、Shift 1.5× 落差是否合适，`air_control` 0.55 的起跳承诺感是否保留。
3. **落地的份量**：`landing_stiff_threshold` 12 m/s + 0.12s 蹲伏硬直是否硌手或太软。
4. **跳高与台阶节奏**：1.56m 跳高配 10 级 1.2m 台阶，跑上去是否顺畅、是否想跳。
5. **相机语言**：`camera_stiffness` 6.0 / `cam_dist` 4.5m 的弹簧滞后是否"电影感"而非"晕"；
   战斗态拉近到 3.5m + FOV 收 5° 的呼吸感（§3.4 双状态手感）。
6. **判定宽容度**：0.12s 土狼时间与 0.12s 跳跃缓冲是否够宽容（§3.3：判定必须宽容，粘手只在表现层）。
7. **按键手感**：`run` 动作是恢复期重建件，Shift 奔跑 + Space 跳跃的实际手感需实机确认。

**调参方式**（GDD §0.3、§10.1）：由策划在编辑器里拖 `player/prismatic_player.gd` 的 `@export` 基础值，
或改 `MovementCoefficients` 系数（默认 1.0），**不需要 AI 轮次、不写代码**。

---

## 恢复期做了什么 / 刻意没做什么

**做了**（只补迁移丢失项）：放回 GDD 并通读；按 `.godot/editor/filesystem_cache10` 与
`work/tools/m0_2_import.py` 的证据重建根目录文件；以存活模板重建 `project.godot`（`main_scene` 指向灰盒场景）；
跑通导入 + 三项验证 + 短时主场景；重新初始化 Git 并提交单个新基线。

**刻意没做**（遵守 GDD §0.4 与 M0 禁区）：

- ❌ 未联网下载或替换任何资源（§0.4 闸口：资源缺失必须报告等审批，不得私自替换）；
- ❌ 未引入新插件；
- ❌ 未重写、审查或"顺手优化"任何 M0 游戏模块；
- ❌ 未触碰战斗数值、UI、敌人、存档（M0 禁区；评分/UI 属 M1+）；
- ❌ 未新增 Autoload——`GameState`/`EventBus`/`AudioManager` 在 M0 并不存在，写进 `[autoload]` 会启动报错；
- ❌ 未对 D 盘执行 shell、未改其 ACL。

---

## 后续（交回 Codex / 策划）

### M0 试玩反馈调参（2026-10-02 反馈 / 2026-10-21 完成）

**状态：阶段完成，待验收。**

人类试玩反馈：滑翔手感保留；普通移动太慢，Shift 与普通移动的速度差过大，地面起停/转向要更灵活。当前角色模型仅作技术验证，本轮不替换，也不定稿具体美术；未来角色气质方向记录为《光·遇》式温柔简洁。

GDD 依据：§3.3 移动手感参数表 v1 为【暂定】，推翻条件“M0 试玩后策划感到‘粘’变成了‘拖’”已由本轮反馈触发，故按 §0.2 调参；§3.2 滑翔专用参数与机制未触碰（仅 `accel_ground` 的派生水平响应变化，见下），§3.1 操作与 §3.3 隔离原则为【锁定】且未偏离，因此无需 BLOCKERS。

| 参数（@export 基础值） | 调前 | 调后 | 理由 |
|---|---:|---:|---|
| `walk_speed_base` | 2.5 | **4.0** | 普通移动提速 60%；与冲刺的落差 2.4×→1.5× |
| `run_speed_base` | 6.0 | **6.0（未动）** | 不提高冲刺上限；保留 Shift 1.5× 的可感知提升；`glide_speed` 仍 6.9 |
| `accel_ground_base` | 12.0 | **16.0** | 0→走速 0.25s、0→跑速 0.375s；起步更跟手，但仍保留加速过程 |
| `decel_ground_base` | 24.0 | **30.0** | 跑速刹停 0.20s；停比启快，起停更利落 |
| `turn_smooth_base` | 10.0 | **16.0** | 时间常数 0.10s→0.0625s；转向更灵活但仍指数平滑、不瞬转 |
| `gravity` / `jump_velocity` / `air_control` / 落地硬直 / 相机 / 全部滑翔专用参数 | 原值 | **未动** | 判定宽容、滑翔机制与镜头语言不属本次反馈范围 |

- **设计理由**：普通移动从“拖”回到可用步速，同时用 1.5× 的 Shift 落差保留“切换奔跑”的可感知收益；起步/刹停/转向仍在表现层平滑（§3.3“粘手不粘判定”），没有改土狼时间、跳跃缓冲等判定宽容项。
- **边界说明**：`accel_ground` 按 §3.3 现有公式也参与空中/滑翔的水平响应，滑翔水平加速度 6.6→8.8 m/s²；滑翔速度 6.9、0.25s 展开、−2.5 落速、俯冲/拉升机制均未改，复试玩确认该派生影响可接受。
- **回退方式**：把 `player/prismatic_player.gd` 的 `walk_speed_base` / `accel_ground_base` / `decel_ground_base` / `turn_smooth_base` 改回 `2.5 / 12.0 / 24.0 / 10.0` 即回到 §3.3 v1 初值；`run_speed_base` 一直为 6.0。也可 `git revert d745f6d`（地面参数提交）及本次验收记录提交。无需改场景/资源，无存档或迁移成本。
- **角色模型**：本轮不改 `.glb`、材质、骨骼或动画；KayKit Adventurers 仅作技术验证。未来美术方向仅为“《光·遇》式温柔简洁”的气质约束，具体设计不定稿。

| 验证 | 命令 | 结果 |
|---|---|---|
| 工程完整性 | `tools/verify_project.gd` | `ok=49 fail=0`，`VERIFY_ALL_PASS` |
| 玩家与地面调参 | `tools/verify_player.gd` | `checks=83 fail=0`，`VERIFY_PLAYER_ALL_PASS`（含 walk≥3.5、速度差 1.25~1.75×、run≤6.0、0.25s 起步、0.20s 刹停、0.15s 转向断言） |
| 灰盒与端到端滑翔 | `tools/verify_greybox.gd` | `checks=34 fail=0`，`VERIFY_GREYBOX_ALL_PASS` |
| 短时主场景 | `--quit-after 300` | 退出码 0，正常打印灰盒操作说明 |

> 唯一 ERROR 仍是环境级 `Failed to read the root certificate store`，迁移前日志同样存在（BLOCKERS B4），非回归。日志：`work/logs/tune3_verify_*.log`、`work/logs/tune3_boot_main_scene.log`。

| 内容 | 负责人 | 状态 | 验收结果 |
|---|---|---|---|
| 地面普通移动偏慢、Shift 速度落差明显、起停和转向需要更灵活；保持滑翔机制，现有角色模型仅作技术验证 | DS | **阶段完成，待验收** | 参数已调整；三项验证 + 短时主场景通过；待策划在 D 盘复试玩确认手感 |


1. **[Codex]** D 盘迁移与验证已完成；C 盘临时副本暂作回退。
2. **[策划]** 按上面 7 项做 M0 手感试玩验收（§9 M0 验收：角色在测试场景跑跳滑翔，"粘手感"成立）；其中第 2 项已按本轮反馈调参，需重点复核；
3. **[策划]** 试玩后按 §0.2 决策分级制修订 GDD，再进 M1 战斗骨架（三连击 / 防御 / 0.2s 弹反）。

---

## D 盘正式迁移结果（2026-10-02）

- 正式工程：D:\GameProjects\Prismatic_Sky；C 盘临时恢复区保留为回退副本，暂不删除。
- Git 恢复基线：`b14f615e7f5531c17389b726eda7153e2bdcb6af`，D 盘与 C 盘提交一致；旧 M0 逐步提交历史仍不可用。
- 已将恢复基线中的 339 个受 Git 管理的文件导入 D 盘；现存大型资源目录保留。D 盘 Git 工作树迁移后干净。
- D 盘便携 Godot 4.7.1 主场景无界面启动退出码 0；`verify_project.gd` 结果 `ok=49 fail=0`、`VERIFY_ALL_PASS`。C 盘恢复期的玩家与灰盒验证结果见上文。
- 本次只迁移与验证，不修改游戏玩法。§3.2、§3.3 的主观手感仍由策划在 Godot 中试玩验收。
- 后续 DS 直接在 D 盘启动 shell 仍受 Windows ACL 沙箱问题影响；自动审批拒绝了递归授予 WriteOwner。未绕过该拒绝，后续处理需单独决定。

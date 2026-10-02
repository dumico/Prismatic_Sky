# TASKS.md —— Prismatic_Sky 任务与里程碑状态

> 母文档：`Prismatic_Sky_设计文档_v0.2.md`（GDD v0.2，唯一权威规格，已放回仓库根目录）。
> 任务卡片模板见 GDD §9；架构一次性确认见 `DECISIONS.md`；当前阻塞见 `BLOCKERS.md`。

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

**M0 工程奠基 —— D 盘正式迁移完成，待策划试玩验收。**

| 项 | 状态 |
|---|---|
| M0 场景 / 脚本 / 资源 / 工具 | ✅ 存活未损（33 脚本、16 场景，逐一 `load()` 通过） |
| 根目录配置文件 | ✅ 已按存活证据重建（清单来源见 `DECISIONS.md` §8） |
| Godot 导入 | ✅ 干净通过（仅 `icon.png` 重新导入） |
| 三项验证脚本 | ✅ 全绿（49 / 78 / 34，与迁移前日志计数逐项吻合） |
| 短时主场景启动 | ✅ 通过 |
| **C 盘临时恢复区 Git 新基线** | ✅ 单个提交 `[M0] Recovered baseline after relocation` |
| **D 盘正式目录 `D:\GameProjects\Prismatic_Sky`** | ✅ 已迁移；Git b14f615 与恢复基线一致，Godot 主场景启动与工程完整性校验通过 |

> 更新：D 盘正式迁移已完成并验证。C 盘临时恢复区暂作回退副本；D 盘 DS shell 沙箱权限问题仍需在后续开发前处理，未修改目录 ACL。

---

## 运行入口

引擎路径记录于根目录 `GODOT_PATH.txt`。正式引擎：
`D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe`（Godot **4.7.1.stable.official.a13da4feb**，§8 已锁定）。

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

## 验证结果（2026-10-02，C 盘临时恢复区）

引擎在长时启动时输出一条环境级噪声
`ERROR: Failed to read the root certificate store` —— 迁移**之前**的日志同样存在，
与资源/迁移无关，**非回归**。

| 验证 | 命令 | 结果 |
|---|---|---|
| 工程完整性 | `tools/verify_project.gd` | `ok=49 fail=0`，`VERIFY_ALL_PASS`（33 脚本 + 16 场景全部可载入、无缺失依赖） |
| 玩家与 §3.3 手感参数 | `tools/verify_player.gd` | `checks=78 fail=0`，`VERIFY_PLAYER_ALL_PASS` |
| 灰盒场景与端到端滑翔 | `tools/verify_greybox.gd` | `checks=34 fail=0`，`VERIFY_GREYBOX_ALL_PASS` |
| 输入映射（重建件复核） | 临时探针，已删除 | `ok=true`：`run`=Shift+手柄轴5；`jump`=F+**Space**；`move_*`/`ui_cancel` 齐备 |
| 短时主场景 | `--quit-after 300` | 退出码 0，正常打印灰盒操作说明 |

与迁移前日志（`work/logs/final_project.log` / `final_player.log` / `final_greybox.log`）逐项吻合，
说明**迁移未破坏任何 M0 逻辑**。恢复期日志：`work/logs/recover_*.log`。

关键手感项实测（对应 GDD §3.2 / §3.3）：

- 跳跃高度 1.63m（目标 ≈1.56m）；土狼时间 0.12s、跳跃缓冲 0.12s 生效且带 0.02s 下限保护；
- 0.5s 加速到 `run_speed` 6.00；0.25s 内刹停（减速 24.0 > 加速 12.0，"停比启快"）；
- 空中加速度 = 地面 × `air_control`(0.55)；不产生二段跳；
- 落速 ≥12 m/s 触发 0.12s 落地硬直 + 尘土粒子，轻落地不触发；
- 滑翔：0.25s 披风展开过渡（非瞬切）、`glide_fall_speed` −2.5、满俯冲趋近 `dive_max` −12.0、
  俯冲水平增速（9.31 > 6.90）、拉升耗速换高度（6.90 → 3.90）；
- 弹簧相机：探索态 4.5m / 战斗态 3.5m + FOV 收 5°，1 帧滞后 0.57m，最终收敛残差 0.001m；
- 端到端：从 12m 跳台走落自动进入滑翔，滑翔 3.03s、水平位移 22.8m，稳定落回地面。

---

## 需要策划试玩的手感项目（AI 不代判，等试玩数据）

以下均为 GDD 标注的【暂定】项，**必须**由策划在引擎内试玩判定；AI 不擅自改数值。

1. **滑翔手感**（§3.2 推翻条件：M0 试玩后手感不佳 → 降级为缓降或改二段跳）
   —— 重点体感"俯冲换速度 / 拉升耗速度"的灵魂机制是否成立，0.25s 披风展开是否够顺。
2. **粘手 vs 拖沓**（§3.3 推翻条件：策划感到"粘"变成了"拖"）
   —— `accel_ground` 12.0（起步蹬地感）、`decel_ground` 24.0、`air_control` 0.55 的起跳承诺感。
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

### M0 试玩反馈调参（2026-10-02）

| 内容 | 负责人 | 状态 | 验收结果 |
|---|---|---|---|
| 地面普通移动偏慢、Shift 速度落差明显、起停和转向需要更灵活；保持滑翔机制，现有角色模型仅作技术验证 | DS | 待执行 | 待策划在 D 盘复试玩验收；DS 完成时标记“阶段完成，待验收” |


1. **[Codex]** D 盘迁移与验证已完成；C 盘临时副本暂作回退。
2. **[策划]** 按上面 7 项做 M0 手感试玩验收（§9 M0 验收：角色在测试场景跑跳滑翔，"粘手感"成立）；
3. **[策划]** 试玩后按 §0.2 决策分级制修订 GDD，再进 M1 战斗骨架（三连击 / 防御 / 0.2s 弹反）。

---

## D 盘正式迁移结果（2026-10-02）

- 正式工程：D:\GameProjects\Prismatic_Sky；C 盘临时恢复区保留为回退副本，暂不删除。
- Git 恢复基线：`b14f615e7f5531c17389b726eda7153e2bdcb6af`，D 盘与 C 盘提交一致；旧 M0 逐步提交历史仍不可用。
- 已将恢复基线中的 339 个受 Git 管理的文件导入 D 盘；现存大型资源目录保留。D 盘 Git 工作树迁移后干净。
- D 盘便携 Godot 4.7.1 主场景无界面启动退出码 0；`verify_project.gd` 结果 `ok=49 fail=0`、`VERIFY_ALL_PASS`。C 盘恢复期的玩家与灰盒验证结果见上文。
- 本次只迁移与验证，不修改游戏玩法。§3.2、§3.3 的主观手感仍由策划在 Godot 中试玩验收。
- 后续 DS 直接在 D 盘启动 shell 仍受 Windows ACL 沙箱问题影响；自动审批拒绝了递归授予 WriteOwner。未绕过该拒绝，后续处理需单独决定。

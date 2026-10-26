# M1 战斗骨架 · 开发 / 试玩 / 审计交接

> 分支：`feature/m1-combat-core`（从 `main` 的 M0 验收提交 `04664fe` 创建）
> 主场景仍是 M0 灰盒：`res://levels/greybox_test.tscn`（未改动，保证 M0 回归）。
> M1 训练场：`res://levels/m1_combat_training.tscn`
> 状态：**自动验证完成；待用户人工试玩验收。未进入 M2。**
> GDD：`Prismatic_Sky_设计文档_v0.2.md` §4.1~§4.6、§9 M1。

---

## 1. 范围

**已实现**

- 三段轻击：1 : 1 : 1.5、第三段小幅击退、3m 软锁定、第三段后摇可防御取消。
- 长按防御：正面 120° 减伤 70%、移速 50%、防御中禁攻、背后/弧外不减伤。
- 隐藏防御耐久：连续格挡累积，满值破防 1s；破防期间禁防禁攻；脱手延迟恢复。
- 弹反：命中前 0.2s 窗口、伤害归零、敌人硬直 1.5s、1s 内下一击 ×2 且只消费一次；
  0.1 倍速 0.25s + 0.15s 回弹；低沉嗡鸣前奏、清脆音效、地面光圈、相机 trauma。
- 训练场：木桩 + 训练守卫 + 诊断 HUD + R 重置。
- 自动验证：`verify_combat.gd` 107 项；M0 三项回归全绿。

**明确没做（M2/M3 范畴）**

- 帧冻结、命中粒子、正式混音、精细震屏、动画接触帧逐帧校准。
- 完整暗影小卒/射手、巡逻/追击/多招 AI、掉落、关卡遭遇战、Boss。
- 换装/时装/乐器/家园；正式 UI/HUD 设计。
- 红光提示：**未启用**（GDD §4.4 锁定）。

---

## 2. 如何运行

引擎（见根目录 `GODOT_PATH.txt`）：

```text
D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe
```

**方式 A：Godot 编辑器**

1. 打开 `D:\GameProjects\Prismatic_Sky\project.godot`。
2. 在 FileSystem 中双击 `levels/m1_combat_training.tscn`，按 F6 运行当前场景。
3. 主场景 `F5` 仍是 M0 灰盒。

**方式 B：命令行直接进 M1 训练场**

```powershell
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --path . res://levels/m1_combat_training.tscn
```

**自动测试（实际执行命令）**

```powershell
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --headless --path . --script res://tools/verify_project.gd
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --headless --path . --script res://tools/verify_player.gd
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --headless --path . --script res://tools/verify_greybox.gd
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --headless --path . --script res://tools/verify_combat.gd
```

---

## 3. 操作键位

| 输入 | 动作 |
|---|---|
| WASD / 左摇杆 | 移动（相对相机） |
| Shift / RT | 奔跑 |
| 空格 / A | 跳跃；空中按住 = 滑翔（M0 原样） |
| 鼠标 / 右摇杆 | 相机 |
| **鼠标左键 / X** | **攻击；连点触发三段轻击** |
| **鼠标右键长按 / LB** | **防御；命中前 0.2s 按下 = 弹反** |
| **R** | **重置训练场（玩家/木桩/守卫/耐久）** |
| **F1** | **隐藏/显示诊断 HUD** |

> 防御时角色朝向跟随相机水平朝向，WASD 变为相对相机的移动。要测试“背后受击”，
> 把相机转到背对守卫后再按住右键（角色会朝相机方向防御），让守卫从背后命中。

---

## 4. 十项人工验收与预期

| # | 操作 | 预期 |
|---|---|---|
| 1 | 从出生点走近木桩/守卫 | 相机在目标 5m 内切入战斗态（3.5m / FOV 收 5°） |
| 2 | 对木桩连点左键 3 次 | HUD 连击 1→2→3；三段使用不同 KayKit 1H 攻击动画；无卡死 |
| 3 | 观察第三段 | 伤害 10 / 10 / 15；木桩被推约 0.5m；HUD 显示 `击退!` |
| 4 | 面对守卫长按右键 | HUD `GUARD`；正面受击只掉 6（20 的 30%），耐久 +28 |
| 5 | 把相机转到背对守卫后防御，让守卫命中 | 背后攻击吃满 20，不减伤 |
| 6 | 连续正面格挡 4 次 | 第 4 次后破防：HUD 显示破防、角色踉跄约 1s；期间不能防御/攻击 |
| 7 | 听守卫攻击的低沉嗡鸣，在命中前按下右键 | 清脆弹反音效 + 地面光圈 + 0.1 倍速 0.25s；守卫 1.5s 硬直 |
| 8 | 弹反后 1s 内攻击守卫 | 第一击伤害 20（×2），之后恢复 10；HUD 反击强化倒计时 |
| 9 | 松开右键 / 移动 | 退出 GUARD，恢复正常移动速度 |
| 10 | 回到 `greybox_test.tscn`（F5） | M0 跑、跳、滑翔、相机仍正常 |

**最重要的主观验收**：不看画面，只听嗡鸣前奏与节奏，逐渐学会在命中前按防御。
自动测试只能验证判定与状态，不能代替这条人工验收。

**训练守卫节奏**：前摇/命中 0.9s、收招 0.8s、攻击间隔 1.1s；前奏 0.72s，结尾留有约 0.18s
静默再命中。它不显示红光，也不显示精确弹反时机。

**破防初值**：耐久上限 100、每次格挡 +28、脱手 0.8s 后以 20/s 恢复；第 4 次格挡破防。
这些都在 `prismatic_player.gd` 的 `@export` 里，可直接在编辑器调。

---

## 5. 架构说明

### 5.1 三连击状态

`PrismaticPlayer` 内：

```
NORMAL --攻击键--> ATTACK(step 1..3)
ATTACK(step1/2 结束，有缓冲) --> 下一段
ATTACK(step3 RECOVERY) --防御键--> GUARD
ATTACK(结束/无缓冲) --> NORMAL
```

- 攻击输入在 ATTACK 中只写入 `_attack_queued`，到当前段结束才进入下一段；不会因为连点产生
  无限连击或状态卡死。
- 每段时长 = `AnimationPlayer.get_animation(clip).length / attack_anim_speed`（默认 1.3×，
  约 0.77s）；命中窗口 = 时长的 0.38~0.60，和动画播放共用同一时间基准。
- 命中窗口内做物理 shape query；每次挥击用 `instance_id` 去重，单次攻击不会重复扣血。
- 第三段 `hit.knockback = 5.0`，目标自行阻尼，约 0.5m 位移。
- 软锁定在 3m 内选最近的 `combat_target`，只在攻击前摇转向；不改变相机/移动/滑翔。

### 5.2 防御与破防

- `GUARD` 状态：移速 ×0.5，不能攻击；朝向跟随相机水平朝向。
- 受击时以玩家当前战斗朝向判断 120° 正面弧；只对正面来击应用 70% 减伤。
- 每次正面格挡累积 28 压力；满 100 触发 `GUARD_BROKEN`：退出防御、1s 不能防御/攻击、
  移速受限（移动锁定 + 减速）、播放 `Hit_B` 反应；结束后压力清零。
- 脱手 0.8s 后以 20/s 恢复；按住防御时不恢复。
- 背后/弧外来击不减免，也不累积防御压力。

### 5.3 弹反时间窗口

关键：**不是“按住防御的前 0.2s 免疫所有攻击”**。

```gdscript
# 受击结算时：
if guarding and frontal and hit.parryable and _guard_time <= 0.2:
    -> PARRY
elif guarding and frontal:
    -> BLOCK (30% damage)
else:
    -> DAMAGE (100%)
```

`_guard_time` 是“本次防御按下后经过的时长”。所以：

- 攻击命中前 ≤0.2s 按下 → 弹反；
- 提前按住 >0.2s → 普通格挡；
- 命中后才按 → 本次已经按正常受击结算，不能追溯；
- 松开再按会重置窗口，可以再次弹反。

训练守卫在命中前 0.9s 起播统一低频前奏（0.72s），命中时刻由 `impact_time=0.9` 明确给出；
没有红光提示。

### 5.4 伤害与命中事件

- `combat/combat_hit.gd`（`CombatHit`）承载：damage / source / source_position / parryable /
  knockback / is_heavy。
- 玩家攻击：`PhysicsShapeQueryParameters3D.intersect_shape` → layer 3 `Targets` 的实体 →
  `target.receive_hit(hit)`。
- 敌人攻击：`TrainingEnemy._impact()` 构造 `CombatHit` → `player.receive_hit(hit)`。
- 玩家结算：PARRY → 伤害 0、敌人 `on_parried()`、反击强化；BLOCK → 30% 伤害 + 压力；
  DAMAGE → 全额伤害 + 受击反应 + 0.35s 无敌。
- 反击强化：`_counter_timer=1.0`；下一次**实际命中**时 ×2 并清零；未命中不消耗。

### 5.5 KayKit 骨架与动画

- 玩家模型仍是 M0 的 `Rogue_Hooded.glb`；`AnimationPlayer` 在 `Model/AnimationPlayer`。
- AnimationTree 由代码构建（M0 做法），M1 增加：
  - `attack_anim`（动态替换 clip）+ `attack_speed`（TimeScale=1.3）+ `attack`（OneShot）；
  - `guard_anim`（`Blocking`，循环）+ `guard`（Blend2，权重 `_guard_visual`）；
  - `react_anim` + `react`（OneShot，用于 Block_Hit / Hit_A / Hit_B / Death_A）。
- 三段使用 `1H_Melee_Attack_Slice_Diagonal` / `Slice_Horizontal` / `Chop`，均在 GLB 内。
- 盾牌是 `CylinderMesh` 占位件，通过 `BoneAttachment3D` 挂到 `handslot.l`；换模型无此骨骼时
  回退 `hand.l` 或跳过。命中判定完全不读取盾牌网格。

---

## 6. 主要文件

| 文件 | 用途 |
|---|---|
| `combat/combat_hit.gd` | `CombatHit` 数据（伤害/来源/可弹反/击退） |
| `player/prismatic_player.gd` | M0 控制器 + M1 三连击/防御/破防/弹反/受击/软锁定/反馈 |
| `player/spring_camera.gd` | 增加 trauma 镜头位移（M0 参数未改） |
| `enemy/training_dummy.gd/.tscn` | 木桩：HP/伤害数字/击退/复位 |
| `enemy/training_enemy.gd/.tscn` | 训练守卫：前摇+前奏+命中判定+被弹反硬直 |
| `levels/m1_combat_training.gd/.tscn` | M1 训练场、诊断 HUD、R/F1、相机战斗态 |
| `tools/verify_combat.gd` | M1 自动验证（107 项） |
| `audio/SoundFX/combat/parry_prelude.wav(.import)` | 程序化占位低频前奏（0.72s） |
| `verification/m1/` | 实际测试日志、窗口截图、说明 |
| `M1_HANDOFF.md` | 本文件 |

---

## 7. 自动测试结果（实际执行）

| 验证 | 结果 | 证据 |
|---|---|---|
| `verify_project.gd` | `ok=57 fail=0`，`VERIFY_ALL_PASS` | `verification/m1/verify_project.log` |
| `verify_player.gd` | `checks=83 fail=0`，`VERIFY_PLAYER_ALL_PASS` | `verification/m1/verify_player.log` |
| `verify_greybox.gd` | `checks=34 fail=0`，`VERIFY_GREYBOX_ALL_PASS` | `verification/m1/verify_greybox.log` |
| `verify_combat.gd` | `checks=107 fail=0`，`VERIFY_COMBAT_ALL_PASS` | `verification/m1/verify_combat.log` |
| M1 窗口启动 + 截图 | 退出码 0，1280×720 实拍 | `verification/m1/m1_*.png` |
| M0 灰盒窗口启动 | `--quit-after 240` 退出码 0 | `verification/m1/greybox_boot.log` |

`verify_combat.gd` 覆盖：三段顺序/伤害比例/击退/软锁/恢复移动/第三段取消、正面 120° 内外与
背后、移速 50%、防御禁攻、四连格挡破防/禁防禁攻、弹反窗口内/超窗/提前/迟到、伤害归零、
敌人 1.5s 硬直、反击 ×2 只消费一次、时间减速恢复、真实敌人攻击链路的弹反、训练场景完整性、
攻击/防御动画实际驱动骨架、输入映射。

**未执行/不能由自动测试代替**：音效是否好听、盲听弹反、手感、镜头眩晕、难度/节奏。

---

## 8. Codex 审计交接

优先看：

1. `player/prismatic_player.gd` 的 `_tick_combat` / `_handle_*` / `receive_hit`：
   - 防御键与攻击键同帧、第三段 RECOVERY 取消、破防与格挡同帧结算、受击打断攻击；
   - `_attack_queued` 是否可能在异常输入下产生第 4 段或卡死；
   - `_guard_time` 在重置/破防/松开时是否正确清零。
2. 弹反时间语义：`_guard_time <= parry_window` 是否严格对应“命中前 0.2s”，以及无敌帧
   `_invuln_timer` 是否会吞掉本应结算的弹反。
3. `Engine.time_scale`：嵌套弹反、场景重置、玩家释放、测试退出是否都能回到 1.0。
4. 命中检测：layer 3 / mask / box 偏移 / 单次挥击去重；是否可能命中世界或玩家自己。
5. `TrainingEnemy`：`on_parried` 与玩家 `_do_parry` 的耦合、死亡/复位竞态、前奏播放/停止。
6. 训练场重置：R、玩家死亡、木桩破碎、守卫死亡自动复位之间是否竞态。
7. M0 回归：`verify_player` / `verify_greybox` 通过，但代码触碰了动画树（补了 Jump_Start
   的 one-shot input 1）与相机（新增 trauma，占位默认 0）；请确认没有行为回归。
8. 可读性：HUD 是否泄漏弹反精确时机；场景是否出现红光（应无）；前奏是否统一。

**已知缺陷/限制**

- 三段命中窗口按动画时长比例估算，未逐帧对齐接触帧；M2 用动画事件校准。
- 盾牌从默认第三人称背面会被身体遮挡（正面可见）；不影响判定。
- 弹反光圈是简单 Torus，不是粒子；帧冻结/正式混音未做。
- 训练守卫是临时对象，不是 M3 AI；攻击只有一招。
- `verify_combat` 依赖 60Hz 物理与时间容差；极慢机器上可能需放宽。
- 自动测试不评估音效、手感、可读性。

---

## 9. 留给 M2 的观察

- **KayKit 动画**：1H 攻击 clip 约 1.0s，M1 用 1.3× TimeScale 压到 0.77s；实际接触帧与
  `attack_hit_start_ratio=0.38` 只是近似，M2 建议在 AnimationPlayer 上打命中事件/接触帧。
  `Blocking` 是持盾姿态，无盾时略像蹲伏；M1 已用骨骼挂点占位盾改善正面可读性。
- **Skeleton3D / AnimationTree 耦合**：动画树由 `prismatic_player.gd` 代码构建，绑定
  `Model/AnimationPlayer`；换模型必须核对 AnimationPlayer 路径、骨骼名（当前 `hand.r`、
  `handslot.l`）和模型朝向（当前 GLB 原生 +Z，场景烘焙 180°）。建议 M2 把动画树抽成
  `.tres` 或明确一个 `CharacterRig` 适配层，但不要为此重写 M0。
- **换装/换模型**：战斗逻辑不依赖网格外观；武器/盾牌通过 BoneAttachment3D。未来时装应只换
  Mesh/Material、保留骨骼与挂点名，或提供名字映射。命中盒是逻辑 Box，不绑定武器长度。
- **反馈**：M2 逐项补 §4.6 帧冻结、命中粒子、弹反粒子、混音、trauma 曲线；当前 0.1×/0.25s
  时间减速与简单光圈已可辨认。
- **相机**：当前 trauma 只做位置抖动；M2 再做衰减/幂次/战斗态切换细节。
- **可读性底线**：不启用红光；如果未来做休闲模式，按 GDD §4.4 预留开关，不要默认开启。

---

## 10. Git / 环境

- 功能分支：`feature/m1-combat-core`。
- `main` 未合并；M1 分支推送后由 Codex/主机 1 审查。
- **推送状态**：2026-10-26 两次 `git push` 均因本机到 github.com:443 网络阻断失败
  （`Connection was reset` / `Could not connect to server`，TCP 443 不可达），**不是认证问题**。
  未修改 remote/认证/代理；分支完整保存在本地，网络恢复后可直接推送。详见 `BLOCKERS.md` B7。
- 本轮未执行破坏性 Git 操作（无 reset/clean/force push/历史重写）。
- 本机环境：默认 workspace-write 沙箱下 `pwsh` 无法启动（`0xC0000142`）；本轮在用户切换的
  full access 下执行 Git/Godot，未修改 ACL、认证或系统配置。详见 `BLOCKERS.md` B6。

# M1 验证证据（实际执行）

- 执行时间：2026-10-26（Asia/Shanghai）
- 引擎：Godot `4.7.1.stable.official.a13da4feb`（`D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe`）
- 分支：`feature/m1-combat-core`
- 本目录内容全部来自实际运行；没有伪造截图或把未执行测试标为通过。

## 无头自动测试

命令（在工作区根目录执行）：

```powershell
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --headless --path . --script res://tools/verify_project.gd
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --headless --path . --script res://tools/verify_player.gd
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --headless --path . --script res://tools/verify_greybox.gd
& 'D:\04_Tools_Auxiliary\Game_Auxiliary\Godot\godot.exe' --headless --path . --script res://tools/verify_combat.gd
```

| 日志 | 结果 | 退出码 |
|---|---|---|
| `verify_project.log` | `ok=57 fail=0`，`VERIFY_ALL_PASS` | 0 |
| `verify_player.log` | `checks=83 fail=0`，`VERIFY_PLAYER_ALL_PASS` | 0 |
| `verify_greybox.log` | `checks=34 fail=0`，`VERIFY_GREYBOX_ALL_PASS` | 0 |
| `verify_combat.log` | `checks=107 fail=0`，`VERIFY_COMBAT_ALL_PASS` | 0 |

M0 三项回归均与 M0 基线一致（`49→57` 是新增 M1 脚本/场景后的工程完整性计数，不是失败；
玩家 83、灰盒 34 与 M0 验收记录相同）。

## 窗口运行证据

| 文件 | 说明 |
|---|---|
| `m1_scene.png` | M1 训练场实际窗口截图（1280×720，出生点视角） |
| `m1_attack.png` | 第 1 段攻击 ACTIVE 帧，HUD 显示 `ATTACK 连击 1 ACTIVE` |
| `m1_guard_front.png` | 正面视角的防御姿态（骨骼挂点占位盾可见） |
| `m1_parry_front.png` | 弹反成功瞬间：光圈、HUD 反击强化、GUARD 状态 |
| `greybox_boot.log` | M0 主场景窗口启动 `--quit-after 240`，退出码 0 |

窗口截图由本轮本地 `work/capture_m1*.gd` 通过
`get_viewport().get_texture().get_image().save_png()` 实际渲染保存，不是合成图。
`work/` 是被 gitignore 的临时目录，生成脚本不入库；图片证据已入库。

## 环境说明

- 本轮默认 `workspace-write` 沙箱下 `pwsh` 无法启动（`0xC0000142`），在用户切换的 full access
  下执行；未修改 ACL、Git 认证或系统配置。详见 `BLOCKERS.md` B6。
- 自动测试覆盖判定、状态、伤害、动画驱动、输入映射与训练场完整性；**不覆盖**音效是否好听、
  盲听弹反、手感、镜头眩晕等主观项。这些必须由用户实机验收。

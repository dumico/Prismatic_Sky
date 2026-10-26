# M1 Codex 独立审计证据

审计原始提交：`52ffaa025d9d9b9f37a983fc594451e16c36823d`。
修复提交：`d296518bc09faaec339cc149b9874fde07ba6238`。
结论、修复与人工操作见根目录 `M1_CODEX_AUDIT.md`。

- `baseline/`：独立复跑 DPH 交付时的四项原测试，以及原代码上的 14 个失败断言。
- `additional_occlusion_repro.log`：进一步确认玩家也能隔墙命中的复现日志；不冒充最终结果。
- `final/`：最终导入、58/83/34/108/52 验证和 M0 主场景启动日志。
- `windowed.log`：最终真实窗口鼠标事件→三连击/防御/弹反/反击的日志，以及骨架挂点和可见附件清单。
- `windowed/`：真实 viewport PNG、实际游戏 Master 混音的短 WAV 片段。
- `windowed_probe.gd.txt`：运行时探针原文；文件后缀和 `.gdignore` 防止诊断证据被当作游戏资源导入。

复跑窗口探针：复制 `.gd.txt` 到项目 ignored `work/codex-m1-audit/windowed_probe.gd`，以锁定引擎执行：

```powershell
godot_console.exe --path D:\GameProjects\Prismatic_Sky --script res://work/codex-m1-audit/windowed_probe.gd
```

截图是自动操作的实际运行证据，音频是游戏混音采样，均不代替用户盲听、手感或硬件手柄验收。

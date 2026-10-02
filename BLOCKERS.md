# BLOCKERS.md —— Prismatic_Sky 当前阻塞

**M0 迁移与自动校验无阻塞，待策划试玩验收。** D 盘正式工程已验证；后续 DS 直接在 D 盘执行 shell 的权限问题见 B5。

---

## B1 —— 已解除：Godot 无头调用受沙箱限制

- **现象**：编辑器/无头调用依赖 `APPDATA` 与编辑器数据目录，直接调用会写到工作区之外。
- **解除方式**：工作区内便携引擎副本 `work/godot-portable/`，同目录放空文件 `_sc_` 启用 Godot 官方
  self-contained 模式（编辑器数据落 `work/godot-portable/editor_data/`），并在子进程内把 `APPDATA`
  指向 `work/appdata/`（工程 `user://` 落盘在工作区内）。
- **约束**：两者**都只在本次子进程生效**，不改任何系统/全局配置、不关闭任何校验。调用封装：`work/tools/godot.ps1`。
- **状态**：✅ 已解除，本次导入与三项验证均走该入口。

## B2 —— 已解除：资源采集期的 TLS 证书校验

- **现象**：迁移前 M0-1 采集资源时，默认 Git/网络栈无法完成 TLS 校验。
- **解除方式**：改用本机 Python + OpenSSL 3.0 TLS 完成采集，**证书校验保持开启**；模板另经
  `git -c http.sslBackend=openssl clone` 复核，**未改动任何系统级 Git 配置**。
- **状态**：✅ 已解除。台账见 `assets_repo/SOURCES.md`。**本次恢复全程未联网、未下载资源**（GDD §0.4）。

## B3 —— 已知且不可逆：原 Git 元数据丢失

- **现象**：跨盘迁移事故后，工程根目录普通文件与原 Git 元数据丢失；存活的 `.git` 是**空目录**，
  无 object / ref / HEAD。
- **影响**：**M0 原有逐步提交历史不可恢复**，旧 commit 数、提交信息、时间线均无从重建。
- **处置**：在 C 盘临时恢复区**重新初始化 Git**，提交单个明确标注的新基线
  `[M0] Recovered baseline after relocation`；`TASKS.md` / `DECISIONS.md` 已如实声明
  "不是历史延续"，不得声称旧历史仍在。
- **状态**：⚠️ 已接受为既成事实，**不构成开发阻塞**（M0 实质成果全部存活）。**不可修复**，仅需知情。

## B4 —— 环境级噪声（非阻塞，勿误判为回归）

- **现象**：Godot 长时启动输出
  `ERROR: Failed to read the root certificate store. at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)`。
- **判定**：迁移**之前**的日志（`work/logs/final_*.log`）同样存在该条；工程不依赖根证书。
- **状态**：✅ 非回归、非阻塞。

## B5 —— 后续开发操作限制：D 盘 DS shell 沙箱无法初始化\n\n- **现象**：DeepSeek Harness 在 `D:\GameProjects\Prismatic_Sky` 使用 workspace-write 时，Windows 报 `SetNamedSecurityInfoW failed (Win32 5)`。\n- **当前处置**：M0 已在 C 盘临时恢复区完成并复制、验证到 D 盘。自动审批拒绝了递归授予 WriteOwner；未绕过，也未修改 D 盘目录 ACL。\n- **影响**：不影响已迁移的游戏工程或策划在 D 盘 Godot 试玩；会影响未来让 DS 直接在 D 盘执行 shell。后续开发可继续使用 C 盘临时恢复区并在阶段完成后同步，或由用户明确批准更窄的目录权限方案。\n- **状态**：⏳ M1 前需确定执行方式；非 M0 试玩阻塞。\n
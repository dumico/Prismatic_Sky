# BLOCKERS.md —— Prismatic_Sky 当前阻塞

**M0 已由用户人工验收通过；M1 实现与技术审计完成，待用户人工试玩验收。**
本轮 Codex 未发现仍未解决的 P0/P1；保留的表现限制、验证边界和远程交付见 `M1_CODEX_AUDIT.md`。
D 盘正式工程的 shell 执行方式见 B5/B6。

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

## B5 —— 后续开发操作限制：D 盘 DS shell 沙箱无法初始化

- **现象**：DeepSeek Harness 在 `D:\GameProjects\Prismatic_Sky` 使用 workspace-write 时，Windows 报 `SetNamedSecurityInfoW failed (Win32 5)`。
- **当前处置**：M0 已在 C 盘临时恢复区完成并复制、验证到 D 盘。自动审批拒绝了递归授予 WriteOwner；未绕过，也未修改 D 盘目录 ACL。
- **影响**：不影响已迁移的游戏工程或策划在 D 盘 Godot 试玩；会影响未来让 DS 直接在 D 盘执行 shell。后续开发可继续使用 C 盘临时恢复区并在阶段完成后同步，或由用户明确批准更窄的目录权限方案。
- **状态**：⏳ 环境级；M1 另行采用 B6 方式执行，非试玩阻塞。

## B6 —— M1 本轮 shell 执行方式（已绕过，非游戏阻塞）

- **现象**：2026-10-26 本轮开始时，默认 workspace-write 沙箱下 `pwsh` 无法启动
  （退出码 `0xC0000142`，Windows `STATUS_DLL_INIT_FAILED`）；`git`/Godot 因此无法在受限 shell 中运行。
  这与 B5 的 `SetNamedSecurityInfoW` 现象不同，属本机 DSH 沙箱/进程初始化问题。
- **处置**：用户将本会话切换为 full access（并关闭审批提示）；M1 的 Git、Godot 无头验证与窗口截图
  均在该模式下执行。**未修改 ACL、未修改 Git 认证、未修改系统配置。**
- **影响**：只影响后续在本机执行 DSH shell 的方式；不影响游戏工程、Godot 4.7.1 或人工试玩。
- **状态**：⏳ 环境级、非 M1 阻塞。下一轮若仍受限，需保持 full access 或另行修复 DSH 沙箱。

## B7 —— M1 分支未能推送 GitHub（网络阻断，非代码/身份问题）

- **现象**：2026-10-26 执行 `git push -u origin feature/m1-combat-core` 两次，均报
  `fatal: unable to access 'https://github.com/dumico/Prismatic_Sky.git/': Recv failure: Connection was reset`；
  `git ls-remote origin` 报 `Failed to connect to github.com:443 after 21044 ms: Could not connect to server`；
  `Test-NetConnection github.com -Port 443` 返回 False。
- **已排除**：不是认证失败（未出现 401/403）、不是本地 Git 损坏（提交与工作区正常）、
  无 HTTP(S)_PROXY/ALL_PROXY，WinHTTP 为 Direct access，Git 无 http.proxy 配置。
- **处置**：**未修改 remote、认证、代理或系统配置**，未强制推送。M1 分支已完整提交在本地；
  `main` 未合并。
- **影响**：主机 1 / Codex 暂时无法从 GitHub 拉取 M1 分支。网络恢复后直接
  `git push -u origin feature/m1-combat-core` 即可；也可先通过本地打包/bundle 交接。
- **状态**：⏳ 未解除；属本轮 GitHub 交付阻塞，不影响本地工程与人工试玩。

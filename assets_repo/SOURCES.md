# assets_repo 资源来源与许可证台账

> 依 GDD §7「所有资源先下载到本地 `/assets_repo/` 再开工」与 M0-1「按职责分目录，记录来源/许可证」。
> 采集方式见 `DECISIONS.md` / `BLOCKERS.md`（B1 解封：本机 Python 3.14 + OpenSSL 3.0 TLS，证书校验保持开启；
> 模板另经 `git -c http.sslBackend=openssl clone` 复核，未改动任何系统级 Git 配置）。
> 每个资源按「职责」定义，满足职责描述的新资源均可替换（GDD §7）。

| 职责 | 选型 | 许可证 | 仓库内路径 | 字节数 | SHA256 |
|---|---|---|---|---|---|
| 战斗模板（格挡/弹反/敌人AI/动画框架） | [Cat's Godot4 Modular Souls-like Template](https://github.com/catprisbrey/Cats-Godot4-Modular-Souls-like-Template) | The Unlicense (CC0 意图) | `cats-godot4-modular-souls-like-template-main.zip` | 50395995 | `87b409e68824747ed662735ecf3486464f624017742128b56c5bb9e6f38df393` |
| 玩家模型（人形低模、骨骼通用） | [KayKit Adventurers 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) | CC0 1.0 | `kaykit-character-pack-adventures-1.0-main.zip` | 6141833 | `e19176d799036452bc783c00dd1036e158c66c5a43b7285ccbfea3466d6f57bf` |
| 敌人模型（非人形、可“暗影化”） | [KayKit Skeletons 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) | CC0 1.0 | `kaykit-character-pack-skeletons-1.0-main.zip` | 6658096 | `bb666ec30ff243f54cffdd936fcceeb5c68cdb424d230fe637b7bfd756c0c8e6` |
| 场景件 | [KayKit Dungeon Remastered 1.0](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0) | CC0 1.0 | `kaykit-dungeon-remastered-1.0-main.zip` | 6312130 | `8e92aa460f5be4252dff0cf030f92846ab74b875ce4756076ecce75b5d0c9bee` |
| 场景件 | [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) | CC0 1.0 | `kenney_nature-kit.zip` | 10537521 | `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d` |
| UI | [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | CC0 1.0 | `kenney_ui-pack.zip` | 1229750 | `a8a14a234911eb648c062622915c93e79e94e97cb7f9f375a70f6617f1174318` |
| 天空（HDRI + 自写云层 Shader） | [Poly Haven — sunflowers_puresky (2k HDR)](https://polyhaven.com/a/sunflowers_puresky) | CC0 1.0 | `sunflowers_puresky_2k.hdr` | 5658712 | `430861cb722951c1eeff3b3c5762e7e73a610fcffc4186b5d828c5e7557fe1b4` |
| 相机（可选插件） | [Phantom Camera](https://github.com/ramokz/phantom-camera) | MIT | `phantom-camera-main.zip` | 836800 | `292b69ac0b66614b567b405d8dbd6674d0b302a369a25a902a1e2db101248a6b` |
| 动画补充（近战连招、移动） | [Quaternius Universal Animation Library [Standard]](https://quaternius.itch.io/universal-animation-library) | CC0 1.0 | `quaternius_universal-animation-library_standard.zip` | 15904933 | `cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724` |

## 解压后落点

| 职责目录 | 内容 |
|---|---|
| `templates/Cats-Godot4-Modular-Souls-like-Template/` | Cat's 模板完整工程（The Unlicense） |
| `characters/KayKit-Adventurers-1.0/` | KayKit Adventurers：Barbarian / Knight / Mage / Rogue / Rogue_Hooded（CC0） |
| `characters/KayKit-Skeletons-1.0/` | KayKit Skeletons：Mage / Minion / Rogue / Warrior（CC0） |
| `animations/Quaternius-UniversalAnimationLibrary/` | UAL1 Standard（Unity / Unreal-Godot 两套，含 `_RM` 根运动版，CC0） |
| `environment/KayKit-Dungeon-Remastered-1.0/` | KayKit Dungeon Remastered 200+ 场景件（CC0） |
| `environment/Kenney-Nature-Kit/` | Kenney Nature Kit（CC0） |
| `environment/hdri/sunflowers_puresky_2k.hdr` | Poly Haven HDRI，2K HDR（CC0） |
| `ui/Kenney-UI-Pack/` | Kenney UI Pack（CC0） |
| `addons/phantom-camera/` | Phantom Camera（MIT，GDD §7 标为「可选插件」） |

## 已核实的两条关键事实

1. **KayKit 角色包自带完整动画**：`Knight.glb` 等文件内嵌 76 条动画（`Idle` / `Walking_A~C` /
   `Running_A~B` / `Jump_Start` / `Jump_Idle` / `Jump_Land` / `Jump_Full_Long` / `Blocking` /
   `Dodge_*` …），骨骼为 KayKit 自有命名（`hips/spine/chest/upperleg.l/…`）。
   因此 M0-3「必要动画重定向」在 M0 范围内**无需执行**：玩家模型自带所需移动/跳跃/格挡动画。
   UAL 留在 `animations/` 作为 §7 台账登记近战连招补充；若 M1 需要 UAL 独有动画
   （如 `Sprint_Loop`、`Sword_Attack`），须在本骨架上做重定向（UAL 骨骼为 `pelvis/spine_01/thigh_l/…`，与 KayKit 不同名）。
2. **模板与 Godot 版本**：Cat's 模板 `project.godot` 标注 `config/features=("4.2", "GL Compatibility")`，
   渲染方式为 `mobile` / `gl_compatibility`；本机引擎为 `4.7.1.stable.official.a13da4feb`（M0-2 导入后锁定）。

# STS2 多角色 Mod 工作台（通用框架）

这是「Slay the Spire 2」多角色 mod 的**通用框架仓库**：只放**跨角色共用**的文档与工具，
不包含任何角色内容。每个角色是工作区里一个**独立仓库**，互不干扰。

## 仓库内容

| 目录 | 内容 |
|---|---|
| `docs/` | 通用文档：协作约定（`agent-workflow.md`）、卡牌/遗物设计表格式（`card-spec-format.md`、`relic-spec-format.md`）、踩坑记录（`pitfalls.md`）、mod 工具链审计（`modding-toolchain-audit.md`）、Spine 3.8→4.2 转换（`spine-conversion.md`） |
| `tools/` | 共享工具：编译部署（`build/apply/deploy.ps1`）、打包（`package.ps1`）、设计表校验（`cardspec.py`、`card_ids.py`、`power_ids.py`）、素材派生（`prepare_icons.py`、`prepare_vfx.py`、`prepare_relic_outlines.py`）、工坊同步（`sync_workshop.py`）等 |

工具通过**角色参数**选择目标，脚本本身不含任何角色名：

```powershell
powershell -File tools\build.ps1 -Character saria
powershell -File tools\package.ps1 -Character saria
python tools\cardspec.py -c saria
```

- Python：`-c` / `--character`（默认读环境变量 `STS2_CHARACTER`，否则 `saria`）
- PowerShell：`-Character`
- 共用的路径解析在 `tools/_charpaths.py` 与 `tools/_charpaths.ps1`。

## 工作区布局

```
STS2/                       本仓库（框架）
├─ docs/                    通用文档
├─ tools/                   共享工具
├─ <角色名>/                 每个角色一个独立仓库，例如：
│  ├─ saria/                ← 角色 A（工程 + 资源 + 专属文档）
│  └─ talulah/              ← 角色 B（同构的空骨架）
├─ dist/                    构建产物（不入任何仓库）
│  ├─ <角色名>/              可直接放进游戏 mods 的目录
│  ├─ <角色名>-<version>.zip
│  └─ workshop/<角色名>/      工坊工作区（封面、文案、上传配置）
└─ reference-vanilla/       从游戏导出的原版参考素材（不入库）
```

单个角色仓库的结构：

```
<角色名>/
├─ mods-src/<角色名>/       工程：src / assets / design / lib / csproj / mod_manifest.json
├─ resources/               美术与 Spine 素材（只入库派生/压缩后的自制素材）
├─ docs/                    该角色专属文档（补丁清单、发版流程等）
├─ .gitignore
└─ README.md
```

## 环境要求

- **.NET 9 SDK**（编译 mod）
- 游戏 **Slay the Spire 2**（`Sts2GameDir` 默认 `D:\SteamLibrary\steamapps\common\Slay the Spire 2`，可用 `-p:Sts2GameDir=` 或环境变量覆盖）
- Python 3.10+ 与 **Pillow**（仅素材派生脚本需要，解释器可用 `STS2_PYTHON` 指定）
- 运行游戏需要 **BaseLib**（Steam 创意工坊依赖）

## 许可

代码与文档以 [MIT](LICENSE) 发布。

游戏本体与任何取自游戏的素材版权归 Mega Crit 所有，本框架不包含此类素材。

# 踩坑记录与开发小贴士

> 这里放「每次都被同一件事坑一次」的经验：游戏侧的行为、mod 加载的硬限制、以及本项目工具链的怪癖。
> 本仓库会维护**多个角色 mod**，下面的经验对每个角色 mod 通用；文中出现的资源路径、贴图名、
> 控制台前缀等只作**示例**，按当前角色名替换即可。
> 所有工具都在工作区根的 `tools/`（用 `-c` / `-Character` 指定角色）；`resources/...` 指该角色仓库的资源目录。
> 排查问题时先看这里；新踩的坑请按同样的格式补一条（**现象 → 原因 → 做法**）。

---

## 1. 卡牌标签（CardTag）

**现象**：原版遗物/效果对本仓库角色 mod 的牌不起作用（示例：「树叶药膏」只扣血、不变化卡牌；潘多拉之盒无效果）。

**原因**：原版是按 `CardTag` 找牌的，不是按牌名。角色 mod 自带的 `打击`/`防御` 如果一开始没打标签，
`Tags.Contains(CardTag.Strike)` 永远为 false。

**做法**：

```csharp
protected override HashSet<CardTag> CanonicalTags => new HashSet<CardTag> { CardTag.Strike };
```

- 名字/定位是「打击」的牌 → `CardTag.Strike`；「防御」→ `CardTag.Defend`；
- 角色 mod 里所有这类基础牌都要覆盖，不要只改一两张（示例：打击、防御，以及名字含「打击」「防御」的变体牌）；
- 新增卡牌时，**如果名字含打击/防御、或会被原版按标签检索**，记得补标签；
- 别把 `CardTag` 当行为开关用（原版注释明确：标签只是元数据，行为交给关键词）。

## 2. 属性 getter 会被内联，补丁打不上

**现象**：给 `CardModel.Portrait`、`EnergyIconHelper.GetPrefix`、`RelicModel.Icon` 之类打 Harmony 补丁，日志完全没有输出。

**原因**：这些都是极小的属性 getter，游戏程序集编译时被**内联**进调用方，运行时根本不存在那次调用。

**做法**：改为补**消费方的方法**（`NCard.UpdatePortrait`、`NCard.Reload`、`NRelic.Reload`、`EnergyIconsFormatter` 的输出等），或在节点层直接换贴图。**属性 getter 只能当兜底，不能当主方案。**

## 3. 反射前先确认是字段还是属性

**现象**：`AccessTools.Field(typeof(NRelic), "Icon")` 返回 null，补丁静默不生效；或者整个补丁类初始化就抛异常（日志 `type initializer threw`）。

**原因**：`NRelic.Icon` 是**属性**（`public TextureRect Icon { get; private set; }`），不是字段；而 `AccessTools.FieldRefAccess<T, object>` 用在**枚举字段**（如 `_iconSize`）上会在静态构造阶段失败，整个类都不可用。

**做法**：

- 先用公开属性/方法；必须反射时用 `AccessTools.Field/Property`（返回 null 而不是炸）；
- 不要在静态字段初始化器里做 `FieldRefAccess`，避免一处失败拖垮整个补丁类。

## 4. 换 VFX 贴图：注意 `Sprite2D` 和异步方法

**现象**：状态「层数变化时的闪光」一直显示占位图，其它两种飘字却正常。

**原因**：三个 VFX 类字段类型不一致 —— `NPowerAppliedVfx._icon` / `NPowerRemovedVfx._sprite` 是 `TextureRect`，而 **`NPowerFlashVfx._sprite` 是 `Sprite2D`**。只写 `is TextureRect` 就会静默跳过。

**做法**：`switch` 同时处理 `TextureRect` 与 `Sprite2D`。另外这些类的方法都是 `private async Task StartVfx()`：贴图赋值在**第一个 await 之前**，所以 Harmony **后置补丁**能覆盖到（补丁作用在状态机启动器上，赋值已同步执行完）。

## 5. mod 的 PCK 里的贴图**加载不了**

**现象**：`ResourceLoader.Exists("res://<角色名>/images/...png")` 为 `true`，但 `ResourceLoader.Load<Texture2D>` 返回 `null` → 卡面全部显示“这里有一个bug”。

**原因**：PCK 里的贴图需要 `.ctex` + import remap，而 remap 指向游戏自己的 `res://.godot/imported/`，mod 打不进去。

**做法**：**所有图片走散文件**（`mods/<角色名>/images/...`），运行时 `Image.LoadPngFromBuffer` + `ImageTexture`；PCK 只放本地化 JSON 与 Spine。若某个属性必须返回 `res://` 路径（如 `CustomPortraitPath`），先探测能否 `Load`，不能就回退原版并打日志。

## 6. 虚拟 `res://` 路径：`TakeOverPath` 的三个坑

**做法回顾**：运行时贴图 `tex.TakeOverPath("res://...png")` 后，`ResourceLoader.Load` 会命中缓存，可用于 `[img]` 内联图标。

坑 1：**一个 Resource 只能占住一个路径**。对同一张贴图连续 `TakeOverPath` 两次只保留最后一个（曾导致 `text=False packed=True`）。→ 每条路径各建一张贴图。

坑 2：**`[img]` 按贴图原始像素渲染**。注册 148×148 会让正文里出现巨图。→ 正文那条路径单独注册 24×24。

坑 3：**虚拟路径绝不能进 `PreloadManager`**。`ModelDb.AllCardPools` 的 `EnergyIconPath` 会被预加载，虚拟路径会抛 `AssetLoadException`，房间加载中断（表现为**开局卡在涅奥对话、点不动**）。→ `EnergyColorName` 必须保持真实色名（如 `ironclad`），虚拟路径只用于正文内联。

## 7. 能量图标相关的连锁规则

- `EnergyColorName` 改动会牵动 `EnergyIconPath` → 预加载 → 见 §6 坑 3；
- `EnergyIconsFormatter` 生成的是 `[img]res://images/packed/sprite_fonts/<prefix>_energy_icon.png[/img]`；
- `GetPrefix` 会被内联（§2），所以最终方案是在 `NCard.UpdateVisuals` 后**直接改描述文本**，把原版色名的 `ironclad_energy_icon.png` 换成自己注册过的 `<角色名>_energy_icon.png`；
- 改文本时优先 `MegaRichTextLabel.SetTextAutoSize()`，直接赋 `Text` 会绕过字号自适应。

## 8. 描述里的动态数值

- 数值占位用 `{Damage:diff()}` / `{Amount}`，**数字需要 `[blue]`**（原版范式）；
- 运行时拼出来的字符串**也要自己加 `[blue]`**（示例：某张牌描述末尾动态追加的「（下回合获得 n 层护盾）」这类句子）；
- 只在战斗中显示的整段文字：放进 `AddExtraArgsToDescription` 注入的变量里，**换行放在变量值开头**，否则非战斗时会多出一个空行（描述模板里的固定 `\n` 会留下来）；
- 任何「X 值」的预览都要走 `Hook.ModifyXValue(CombatState, card, energy)`，这样修改 X 的遗物（如化合物X）才会体现在提示里；硬编码「当前能量」会和真实结算不一致。

## 9. 设计表工具（tools/）

- **`cardspec.py`**：`--pending` 看待办、全量跑校验。它会检查「描述里的 `{Var}` 必须是本类声明过的变量」，运行时注入的变量（由 `AddExtraArgsToDescription` 之类注入的）要加在 `VAR_INJECTED` 白名单里。
- **`tag_implemented.py`**：把 待实装/待修改 改成 已实装 并**丢弃括号里的指令性备注**。括号可能**嵌套**（例：`（…（仅限战斗中）…）`），旧正则会在内层括号提前收尾、把半句话留在备注里 —— 现用括号配对扫描。
- 备注只写「已实装」，不要把给智能体的长指令留在表里。

## 10. 打包与资源

- `tools/package.ps1` 按**顺序**拷贝图片：先原图兜底，再 `resources/png/derived/` 覆盖（哈希表无序会导致派生图被原图覆盖）；
- 派生图由脚本生成：`prepare_icons.py`（头像/地图标记）、`prepare_vfx.py`（特效贴图规范化文件名）、`prepare_relic_outlines.py`（遗物剪影 = 小图 alpha 膨胀 2px）；
- 每个角色 mod 的发布内容在 `dist/<角色名>/`；`dist/workshop/<角色名>/content/` 是它的副本，**不入库**，发版前手动覆盖；
- 卡图数量多时统一用压缩版（`cards-little`），原图仅本地保留，不要一起打包。

## 11. 工坊（Steam Workshop）

- 官方上传器 `ModUploader.exe`（`tools/sts2-mod-uploader/`，不入库），用法 `ModUploader.exe upload -w <workspace>`；
- 它**没有语言参数**：只写 Steam 的**默认语言槽**（Steam 视为 english）。当前把**简体中文**放默认槽，其它语言在网页条目里加；
- 上传器读取的 `workshop.json` 由 `tools/sync_workshop.py` 从 `steam/<lang>/` 生成（`--lang`，默认 zh_cn）；
- 封面 `image.png` 必须 **< 1 MB**；实际展示：列表缩略图 **1:1（322×322）**、详情页 **16:9（637×358）**，两者都只加黑边不裁切；
- `dependencies` 填**工坊 ID**（例如通用前置库 BaseLib 的条目 ID，按工坊页面上的实际数字填写）；
- **没有「上传工坊」的明确指令时一律不上传**（见 `agent-workflow.md` §14）。

## 12. 环境与流程

- 推 GitHub：优先**直连**；代理偶尔 TLS 握手失败（`SSL_ERROR_SYSCALL`），直连通常可用；token 用一次就清空并提醒撤销；
- 部署 dll 需要写游戏目录，沙箱为 workspace-write 时会被拒；
- 游戏目录里的文件复制用 PowerShell（python 写游戏目录会 `PermissionError`）；
- 改完 dll 必须**重启游戏**；日志在 `%APPDATA%\SlayTheSpire2\logs\godot.log`，按 `[<角色前缀>]` 过滤；
- 调试入口：MCP bridge（`bridge_get_full_state` / `bridge_console` / `bridge_capture_screenshot`）；控制台添加自定义内容用 `<角色前缀>-<大写蛇形>` 的 ID 形式（示例：`relic add EXAMPLE-WORK_BADGE`）；
- 设计表是唯一事实来源：先改表、再改代码、再 `cardspec` 校验、最后 `tag_implemented`。

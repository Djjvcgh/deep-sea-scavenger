# V0.5 参考清单与整理说明

> 本文件说明参考来源、已核实内容、以及需要用户手动补充的截图清单。
> 依据任务第八节资源策略：**不把任何官方游戏截图 / 宣传图 / UI 成品复制进仓库**，
> 参考目录只存放：来源链接、文字风格拆解、自制的色板样张（palette swatch）。

## 一、已在线核实的参考（2026-10-25 抓取）

| 来源 | URL | 已核实内容 |
| --- | --- | --- |
| DREDGE 官网 | https://www.dredge.game/ | 「有阴暗底流的钓鱼冒险」定位；媒体称"最吓人的钓鱼游戏"；125+ 深海生物、沉船打捞"珍玩"主题；恐惧靠环境与未知传递而非血腥 |
| DAVE THE DIVER Steam | https://store.steampowered.com/app/1868140/ | 官方自述"像素 + 3D 混合画面呈现惊艳水下景色"；蓝洞场景 200+ 生物；氧气管理要求场景**高可读性**（玩家必须快速解析环境） |
| Dead Cells Steam | https://store.steampowered.com/app/588650/ | 2D 像素横版、Dark Fantasy、Atmospheric 标签；"迷宫般的关卡充满变化"（Kotaku）；血迹会留在地面/墙面 → 环境状态可视化的思路 |
| SteamWorld Dig 2 Steam | https://store.steampowered.com/app/571310/ | "色彩丰富的 2D 平台"、steampunk 标签；"遍布宝藏、秘密与陷阱的鲜活世界"；钩锁/喷射等移动升级 → 探索工具驱动地形引导 |
| Kenney Fish Pack | https://kenney.nl/assets（本地已有） | **CC0**（License.txt 已核对），可商用，建议署名 Kenney |

> Steam 页面本身不含具体配色/描边参数。各游戏的**具体配色、房间层次手法**以下方"人工参考图清单"为准——需要看图确认，不能凭文案臆造。

## 二、本地已有合法素材（许可已核对）

- `assets/sprites/kenney_fish/` —— Kenney Fish Pack 2.0，**CC0**。
  可用：海草 a-d、礁岩 a/b、气泡 a-c、鱼群、背景岩石/海草。
- `assets/icons/items/*.png` —— 本项目原创（`tests/gen_icons.gd` 程序绘制），无版权问题。
- `tools/asset_eval/` —— 同一 Kenney 包的评估副本（含 Vector/Double 变体），CC0。

## 三、候选外部素材来源（引入前必须核对许可）

| 来源 | URL | 预期用途 | 许可状态 |
| --- | --- | --- | --- |
| Game-icons.net | https://game-icons.net/ | HUD 小图标（心/脚蹼/钱袋） | CC-BY 3.0，需署名；**未引入前不得直接打包** |
| Kenney 全站 | https://kenney.nl/assets | 通用像素件 | 多数 CC0，逐包核对 |
| itch.io underwater pixel art | https://itch.io/game-assets/tag-pixel-art/tag-underwater | 沉船结构件 | 逐条目核对，多数非商用需购买 |
| OpenGameArt | https://opengameart.org/ | 备选 | 逐条目核对（CC0 / CC-BY / GPL 混杂，GPL 慎用） |

## 四、需要用户手动放入的参考图清单（可选，用于后续阶段校准）

放入 `docs/references/style/`（场景氛围）与 `docs/references/ui/`（界面）。
这些图**仅作为开发期目视参考，不进入游戏资源、不参与打包**。

| 文件名（建议） | 内容 | 用途 | 来源 |
| --- | --- | --- | --- |
| `style/dredge_night_sea.png` | DREDGE 夜航海面截图 | 深海黑蓝 + 冷色恐惧氛围校准 | dredge.game press kit |
| `style/dredge_inventory.png` | DREDGE 背包/物品网格截图 | 宝物展示的价值感（描边、底色、稀有度分层） | 同上 |
| `style/dredge_wreck_dredge.png` | DREDGE 捞起沉船遗物画面 | "捞起高价值物"的奖励反馈 | 同上 |
| `style/dave_shallow_reef.png` | DAVE THE DIVER 浅海珊瑚区 | 水下色彩层次与能见度渐变 | Steam 商店图 |
| `style/dave_deep_dark.png` | DAVE 深海区 | 深处变暗 + 发光生物引导 | 同上 |
| `style/deadcells_prison.png` | Dead Cells 囚牢 biome | 区域身份：墙材质 + 主色 + 光源三件套 | Steam 商店图 |
| `style/deadcells_room_depth.png` | Dead Cells 任意房间 | 前/中/后景三层组织与剪影可读性 | 同上 |
| `style/swd2_cave_secret.png` | SteamWorld Dig 2 洞穴 | 秘密房间的视觉暗示（裂缝、异色矿石） | Steam 商店图 |
| `style/swd2_tunnel_light.png` | SWD2 隧道照明 | 引导性光源（出口方向感） | 同上 |
| `ui/dave_hud.png` | DAVE 的氧气/背包 HUD | 上下文化 HUD 布局 | 游戏内截图 |
| `ui/deadcells_hud.png` | Dead Cells HUD | 极简 HUD + 数字字体风格 | 游戏内截图 |
| `ui/dredge_storage_ui.png` | DREDGE 库存界面 | 网格紧凑度与稀有度边框 | 游戏内截图 |
| `assets/kenney_pixel_platformer.png` | Kenney pixel platformer 预览 | 通用像素件比例参考 | kenney.nl |

## 五、本次实现采用的替代方案

在参考截图缺位的情况下，V0.5 样板房的风格锚点为：

1. **配色**：本文件同目录 `palette_v05.png`（自制色板样张，原创，无版权问题）。
2. **结构**：真实木船横向结构（壳板 / 船肋 / 横梁 / 货件）为骨架，参照公开的船舶剖面常识组织，不依赖任何单一游戏截图。
3. **可读性原则**：从 DAVE（能见度渐变、剪影清晰）与 Dead Cells（前中后景三层、区域三件套）提炼的文字原则，落在 `docs/art_direction/v05_visual_direction.md`。
4. **素材**：全部由 `tests/gen_scenery_v05.gd` 程序化绘制原创像素贴图 + 已核实 CC0 的 Kenney 件。

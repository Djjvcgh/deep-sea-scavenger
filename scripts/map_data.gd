class_name MapData
## 海底地图静态数据：地形 / 宝物点 / 鲨鱼巡逻 / 撤离区 / 玩家出生点。
## 世界坐标：x 0..5120，y 0..1024（y 向下）。撤离点在左侧岸边。

const WORLD_WIDTH := 5120.0
const WORLD_HEIGHT := 1024.0
const FLOOR_Y := 950.0          # B/C 区海床顶
const SHALLOW_FLOOR_Y := 800.0  # A 区浅滩海床顶

const PLAYER_SPAWN := Vector2(200, 480)
const EXTRACT_RECT := Rect2(60, 60, 260, 360)

## 区域按 x 划分
const ZONE_A_END := 1700.0
const ZONE_B_END := 3400.0


static func zone_at(x: float) -> String:
	if x < ZONE_A_END:
		return "A"
	elif x < ZONE_B_END:
		return "B"
	return "C"


static func zone_name(zone: String) -> String:
	match zone:
		"A": return "区域 A · 近岸浅滩"
		"B": return "区域 B · 沉船区域"
		"C": return "区域 C · 深层洞穴"
	return ""


## 实体地形：[x, y, w, h, kind]  kind: rock(岩石) sand(海床) wreck(沉船木)
const SOLID_RECTS := [
	# 世界边界（顶部在水面之上，左右封闭）
	[-120, -200, 5240, 200, "rock"],
	[-120, 0, 120, 1400, "rock"],
	[5120, 0, 120, 1400, "rock"],
	# 海床：A 区浅滩抬高，B/C 区更深
	[-120, 800, 1820, 400, "sand"],
	[1700, 950, 3540, 300, "sand"],
	# A 区岩石
	[420, 660, 130, 140, "rock"],
	[760, 690, 100, 110, "rock"],
	[1150, 640, 90, 160, "rock"],
	[1500, 700, 120, 100, "rock"],
	# B 区沉船残骸与礁石
	[1800, 860, 120, 90, "rock"],
	[2250, 700, 550, 250, "wreck"],
	[2150, 540, 700, 60, "wreck"],
	[2900, 150, 50, 550, "wreck"],
	[2000, 820, 40, 130, "wreck"],
	[2050, 800, 40, 150, "wreck"],
	[3300, 840, 140, 110, "rock"],
	# C 区洞穴岩体
	[3500, -200, 1620, 720, "rock"],
	[3950, 520, 90, 260, "rock"],
	[4300, 520, 80, 200, "rock"],
	[4550, 650, 250, 300, "rock"],
]

## 装饰（无碰撞）：[x, y, w, h, kind]  kind: coral seaweed
const DECOR_RECTS := [
	[300, 750, 26, 50, "seaweed"],
	[620, 770, 22, 30, "seaweed"],
	[980, 780, 28, 20, "coral"],
	[1240, 760, 24, 40, "seaweed"],
	[1420, 770, 26, 30, "coral"],
	[1620, 760, 22, 40, "seaweed"],
	[1900, 900, 26, 50, "seaweed"],
	[2450, 905, 28, 45, "seaweed"],
	[3050, 910, 24, 40, "coral"],
	[3350, 900, 26, 50, "seaweed"],
	[3650, 900, 26, 50, "seaweed"],
	[4200, 905, 24, 45, "coral"],
	[4900, 910, 26, 40, "seaweed"],
	[5060, 905, 24, 45, "seaweed"],
]

## 宝物生成点（共14个），开始下潜时按区域激活部分
const CHEST_SPOTS := [
	# A 区 ×5
	Vector2(350, 730), Vector2(700, 720), Vector2(1000, 740),
	Vector2(1300, 740), Vector2(1650, 690),
	# B 区 ×5
	Vector2(1950, 880), Vector2(2350, 630), Vector2(2700, 500),
	Vector2(3050, 880), Vector2(3250, 700),
	# C 区 ×4
	Vector2(3600, 850), Vector2(4100, 860), Vector2(4450, 850),
	Vector2(4950, 860),
]

## 鲨鱼巡逻配置：[min_x, max_x, y]
const SHARK_PATROLS := [
	[1850.0, 2450.0, 500.0],
	[2850.0, 3350.0, 750.0],
	[3550.0, 4250.0, 800.0],
	[4400.0, 5050.0, 780.0],
]

## 光柱（浅海氛围）：[x, w]
const LIGHT_SHAFTS := [
	[150, 90], [420, 60], [760, 100], [1100, 70], [1500, 90],
]

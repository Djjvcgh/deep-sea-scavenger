class_name MapData
## 海底地图数据：共享骨架 + 每区域多套手工布局变体。
## 每次下潜用随机种子（"海况"）为三个区域各抽一套变体，兼顾复玩性与可控性。
## 所有变体保证三条通道贯通（机器人试玩与真人共用）：
##   L1 底层爬行道 y840-950 (x2850-5120)   L2 下潜斜线 (2850,480)→(3245,900)
##   L3 上层航道 y460-530 (x1700-2900)

const WORLD_WIDTH := 5120.0
const WORLD_HEIGHT := 1024.0

const PLAYER_SPAWN := Vector2(200, 480)
const EXTRACT_RECT := Rect2(60, 60, 260, 360)

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


## 所有变体共享的骨架：左右封壁、海床、区域C洞穴顶盖
const SHARED_SOLIDS := [
	[-120, 0, 120, 1400, "rock"],
	[5120, 0, 120, 1400, "rock"],
	[-120, 800, 1820, 400, "sand"],
	[1700, 950, 3540, 300, "sand"],
	[3500, -200, 1620, 720, "rock"],
]

## 变体字段：name(展示名) / solids / chests / patrols（世界坐标）
const ZONE_VARIANTS := {
	"A": [
		{
			"name": "礁石群",
			"solids": [[420, 660, 130, 140, "rock"], [760, 690, 100, 110, "rock"],
				[1150, 640, 90, 160, "rock"], [1500, 700, 120, 100, "rock"]],
			"chests": [Vector2(350, 730), Vector2(700, 720), Vector2(1000, 740),
				Vector2(1300, 740), Vector2(1650, 690)],
			"patrols": [],
		},
		{
			"name": "乱石阵",
			"solids": [[350, 670, 110, 130, "rock"], [620, 700, 90, 100, "rock"],
				[950, 650, 70, 150, "rock"], [1080, 700, 110, 100, "rock"],
				[1420, 660, 80, 140, "rock"]],
			"chests": [Vector2(500, 740), Vector2(820, 730), Vector2(1250, 740),
				Vector2(1350, 690), Vector2(1600, 720)],
			"patrols": [],
		},
		{
			"name": "开阔沙丘",
			"solids": [[550, 690, 120, 110, "rock"], [1000, 720, 80, 80, "rock"]],
			"chests": [Vector2(300, 720), Vector2(750, 740), Vector2(1150, 740),
				Vector2(1400, 730), Vector2(1650, 700)],
			"patrols": [],
		},
		{
			"name": "沉船残骸带",
			"solids": [[900, 700, 200, 100, "wreck"], [400, 680, 90, 120, "rock"],
				[1350, 690, 90, 100, "rock"]],
			"chests": [Vector2(300, 730), Vector2(650, 720), Vector2(1180, 740),
				Vector2(1520, 730), Vector2(1650, 690)],
			"patrols": [],
		},
		{
			"name": "礁柱峡谷",
			"solids": [[600, 600, 80, 200, "rock"], [1000, 560, 90, 240, "rock"],
				[1400, 620, 80, 180, "rock"]],
			"chests": [Vector2(350, 730), Vector2(800, 740), Vector2(1200, 740),
				Vector2(1300, 690), Vector2(1650, 700)],
			"patrols": [],
		},
	],
	"B": [
		{
			"name": "沉船残骸",
			"solids": [[2250, 700, 550, 250, "wreck"], [2150, 540, 350, 60, "wreck"],
				[2900, 150, 50, 280, "wreck"], [2020, 700, 50, 90, "wreck"],
				[1985, 640, 70, 70, "rock"], [2350, 260, 80, 80, "rock"],
				[2740, 240, 70, 70, "rock"], [1800, 860, 120, 90, "rock"],
				[3300, 780, 140, 70, "rock"]],
			"chests": [Vector2(1950, 880), Vector2(2350, 630), Vector2(2700, 500),
				Vector2(3050, 880), Vector2(3250, 880)],
			"patrols": [[1850.0, 2350.0, 400.0], [2850.0, 3350.0, 660.0]],
		},
		{
			"name": "双桅废墟",
			"solids": [[2400, 720, 430, 230, "wreck"], [2350, 560, 500, 60, "wreck"],
				[2600, 180, 45, 260, "wreck"], [3050, 200, 45, 300, "wreck"],
				[1850, 700, 90, 140, "rock"], [3260, 690, 80, 80, "rock"]],
			"chests": [Vector2(1950, 880), Vector2(2250, 620), Vector2(2700, 480),
				Vector2(3000, 880), Vector2(3300, 880)],
			"patrols": [[1800.0, 2300.0, 420.0], [2900.0, 3350.0, 620.0]],
		},
		{
			"name": "尖塔礁林",
			"solids": [[2000, 600, 70, 350, "rock"], [2200, 540, 80, 410, "rock"],
				[2500, 560, 70, 390, "rock"], [2720, 600, 80, 350, "rock"],
				[2100, 300, 80, 80, "rock"], [2900, 220, 90, 90, "rock"],
				[3050, 150, 45, 280, "wreck"]],
			"chests": [Vector2(1950, 880), Vector2(2320, 880), Vector2(2650, 500),
				Vector2(3050, 880), Vector2(3300, 860)],
			"patrols": [[1800.0, 2300.0, 400.0], [2900.0, 3350.0, 600.0]],
		},
		{
			"name": "沉没货舱",
			"solids": [[1900, 750, 300, 200, "wreck"], [2350, 650, 120, 300, "rock"],
				[2600, 700, 100, 250, "rock"], [1850, 540, 300, 50, "wreck"],
				[3100, 180, 45, 320, "wreck"], [3250, 520, 80, 80, "rock"]],
			"chests": [Vector2(2250, 880), Vector2(2250, 600), Vector2(2700, 500),
				Vector2(3050, 880), Vector2(3300, 880)],
			"patrols": [[1850.0, 2350.0, 420.0], [2900.0, 3350.0, 640.0]],
		},
		{
			"name": "沉船坟场",
			"solids": [[1800, 780, 250, 170, "wreck"], [2500, 760, 280, 190, "wreck"],
				[2150, 150, 45, 290, "wreck"], [2700, 150, 45, 240, "wreck"],
				[1950, 650, 70, 300, "rock"], [3050, 300, 90, 90, "rock"],
				[3350, 690, 70, 140, "rock"]],
			"chests": [Vector2(2100, 880), Vector2(2400, 620), Vector2(2750, 500),
				Vector2(3050, 880), Vector2(3250, 880)],
			"patrols": [[2320.0, 2800.0, 430.0], [2900.0, 3350.0, 620.0]],
		},
	],
	"C": [
		{
			"name": "悬挑岩窟",
			"solids": [[3950, 520, 90, 260, "rock"], [4300, 520, 80, 200, "rock"],
				[4550, 650, 250, 180, "rock"], [3540, 770, 60, 90, "rock"]],
			"chests": [Vector2(3510, 850), Vector2(4000, 860), Vector2(4450, 870),
				Vector2(4700, 900)],
			"patrols": [[3650.0, 4250.0, 800.0], [4430.0, 5050.0, 600.0]],
		},
		{
			"name": "石柱迷宫",
			"solids": [[3690, 620, 70, 200, "rock"], [3900, 520, 60, 180, "rock"],
				[4150, 560, 80, 240, "rock"], [4400, 540, 70, 160, "rock"],
				[4650, 640, 220, 160, "rock"]],
			"chests": [Vector2(3550, 880), Vector2(4000, 880), Vector2(4450, 870),
				Vector2(4830, 880)],
			"patrols": [[3800.0, 4250.0, 820.0], [4500.0, 5050.0, 580.0]],
		},
		{
			"name": "深渊窄廊",
			"solids": [[3650, 520, 140, 240, "rock"], [3900, 600, 120, 160, "rock"],
				[4200, 520, 90, 240, "rock"]],
			"chests": [Vector2(3520, 880), Vector2(3900, 880), Vector2(4170, 880),
				Vector2(4830, 880)],
			"patrols": [[3700.0, 4300.0, 800.0], [4620.0, 5050.0, 600.0]],
		},
		{
			"name": "石林回廊",
			"solids": [[3700, 520, 80, 240, "rock"], [4100, 540, 80, 200, "rock"],
				[4500, 520, 90, 260, "rock"], [3950, 520, 60, 140, "rock"],
				[4700, 650, 240, 160, "rock"]],
			"chests": [Vector2(3600, 880), Vector2(4000, 880), Vector2(4350, 860),
				Vector2(4900, 870)],
			"patrols": [[3700.0, 4300.0, 800.0], [4650.0, 5050.0, 600.0]],
		},
		{
			"name": "深渊裂谷",
			"solids": [[4200, 520, 120, 280, "rock"], [4550, 640, 80, 140, "rock"],
				[4900, 640, 80, 140, "rock"], [3650, 520, 80, 150, "rock"]],
			"chests": [Vector2(3700, 880), Vector2(4100, 880), Vector2(4500, 870),
				Vector2(4950, 870)],
			"patrols": [[3500.0, 4000.0, 700.0], [4400.0, 5050.0, 600.0]],
		},
	],
}

## 光柱（浅海氛围）：[x, w]
const LIGHT_SHAFTS := [
	[150, 90], [420, 60], [760, 100], [1100, 70], [1500, 90],
]


## 共享骨架 + 指定变体的完整实体地形
static func variant_solids(zone: String, index: int) -> Array:
	var v: Dictionary = ZONE_VARIANTS[zone][index]
	return SHARED_SOLIDS + v["solids"]


## 圆形区域是否与任何实体保持距离（用于通道与校验）
static func circle_clear(p: Vector2, radius: float, solids: Array) -> bool:
	for r in solids:
		var rect := Rect2(r[0], r[1], r[2], r[3])
		var closest := Vector2(
			clampf(p.x, rect.position.x, rect.end.x),
			clampf(p.y, rect.position.y, rect.end.y))
		if closest.distance_to(p) < radius:
			return false
	return true


## 三条安全通道的采样点 [位置, 半径]，供自动化校验所有变体
static func lane_samples() -> Array:
	var pts: Array = []
	for x in range(2900, 5051, 50):        # L1 底层爬行道
		pts.append([Vector2(x, 895), 30.0])
	for i in range(11):                    # L2 下潜斜线
		var t := i / 10.0
		pts.append([Vector2(2850 + 395.0 * t, 480 + 420.0 * t), 40.0])
	for x in range(1720, 2881, 40):        # L3 上层航道
		pts.append([Vector2(x, 495), 36.0])
	return pts

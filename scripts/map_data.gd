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
			"solids": [[2700, 870, 90, 80, "wreck"], [2150, 540, 350, 60, "wreck"],
				[2900, 150, 50, 280, "wreck"], [2020, 700, 50, 90, "wreck"],
				[1985, 640, 70, 70, "rock"], [2350, 260, 80, 80, "rock"],
				[2740, 240, 70, 70, "rock"], [1800, 860, 120, 90, "rock"],
				[3300, 780, 140, 70, "rock"]],
			"chests": [Vector2(1950, 880), Vector2(2350, 630), Vector2(2700, 500),
				Vector2(3050, 880), Vector2(3250, 880)],
			"patrols": [[1850.0, 2350.0, 400.0], [2850.0, 3350.0, 660.0]],
			"wreck_anchors": [{"x": 2360.0, "kinds": ["merchant", "pirate", "ritual"]}],
		},
		{
			"name": "双桅废墟",
			"solids": [[2650, 560, 200, 60, "wreck"],
				[2600, 180, 45, 260, "wreck"], [3050, 200, 45, 300, "wreck"],
				[1850, 700, 90, 140, "rock"], [3260, 690, 80, 80, "rock"]],
			"chests": [Vector2(1950, 880), Vector2(2250, 620), Vector2(2700, 480),
				Vector2(3000, 880), Vector2(3300, 880)],
			"patrols": [[1800.0, 2300.0, 420.0], [2900.0, 3350.0, 620.0]],
			"wreck_anchors": [{"x": 2425.0, "kinds": ["merchant", "pirate", "ritual"]}],
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
			"solids": [[1800, 780, 250, 170, "wreck"],
				[2150, 150, 45, 290, "wreck"], [2700, 150, 45, 240, "wreck"],
				[1950, 650, 70, 300, "rock"], [3050, 300, 90, 90, "rock"],
				[3350, 690, 70, 140, "rock"]],
			"chests": [Vector2(2100, 880), Vector2(2400, 620), Vector2(2750, 500),
				Vector2(3050, 880), Vector2(3250, 880)],
			"patrols": [[2320.0, 2800.0, 430.0], [2900.0, 3350.0, 620.0]],
			"wreck_anchors": [{"x": 2570.0, "kinds": ["merchant", "pirate", "ritual"]}],
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
			"wreck_anchors": [{"x": 4520.0, "kinds": ["merchant"]}],
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


## ---- V0.4 可探索沉船遗址 ----
## 模板坐标相对锚点（锚点 = 船体中线与海床顶的交点）。rects 形成封闭船体：
## 底板 / 两舷（带 58px 侧舱门 y-84..-26，底层爬行道可从船内穿过）/ 甲板（留 ≥46px 入舱口）/ 桅杆。
## spots 为舱内容器点（相对锚点）。
const WRECK_TEMPLATES := {
	"merchant": {
		"name": "普通商船",
		"rects": [
			[-230, -14, 460, 14],
			[-236, -110, 18, 26], [-236, -26, 18, 12],
			[218, -110, 18, 26], [218, -26, 18, 12],
			[-236, -126, 170, 16], [-20, -126, 230, 16], [-60, -220, 14, 94],
		],
		"entrance": [-66.0, -20.0],
		"spots": [Vector2(-120, -44), Vector2(110, -44)],
		"interior": Rect2(-218, -110, 436, 96),
	},
	"pirate": {
		"name": "海盗船",
		"rects": [
			[-280, -14, 560, 14],
			[-286, -120, 18, 36], [-286, -26, 18, 12],
			[268, -120, 18, 36], [268, -26, 18, 12],
			[-286, -136, 190, 16], [-50, -136, 240, 16], [-30, -240, 16, 104],
			[40, -64, 16, 50],
		],
		"entrance": [-96.0, -50.0],
		"spots": [Vector2(-150, -44), Vector2(180, -44)],
		"interior": Rect2(-268, -120, 536, 106),
		"captain_room": Rect2(56, -120, 212, 106),
	},
	"ritual": {
		"name": "祭祀船",
		"rects": [
			[-210, -14, 420, 14],
			[-216, -116, 18, 32], [-216, -26, 18, 12],
			[198, -116, 18, 32], [198, -26, 18, 12],
			[-216, -132, 140, 16], [-30, -132, 210, 16], [-70, -226, 14, 94],
			[-45, -60, 90, 46],
		],
		"entrance": [-76.0, -30.0],
		"spots": [Vector2(0, -92)],
		"interior": Rect2(-198, -116, 396, 102),
	},
}

## 沉船稀有度权重（普通商船 / 海盗船 / 祭祀船），锚点激活时按此选型
const WRECK_KIND_WEIGHTS := {"merchant": 0.6, "pirate": 0.3, "ritual": 0.1}

## 每个锚点激活为沉船的概率
const WRECK_ANCHOR_CHANCE := 0.8

## 海床顶 y（沉船锚点所在），B/C 一致
const WRECK_FLOOR_Y := 950.0


## ---- V0.4 可探索洞穴 ----
## 两类形态：floor 海床岩洞（锚点=洞口地面中心，y=0 海床顶）；hang 深渊悬洞
## （锚点=区域C巨型岩体底面 y=520 的挂点，洞体向下悬挑，顶盖即岩体）。
## rects 形成遮挡腔体；spots 为洞内宝箱点；door_y 为入洞口高度区间（校验用）。
const CAVE_TEMPLATES := {
	"shelter": {
		"name": "藏身岩洞", "mode": "floor",
		"rects": [[26, -140, 30, 140], [-140, -166, 196, 26], [-140, -140, 30, 80]],
		"spots": [], "interior": Rect2(-80, -140, 106, 140),
	},
	"treasure": {
		"name": "隐藏洞穴", "mode": "floor",
		"rects": [[40, -170, 30, 170], [-150, -196, 220, 26], [-150, -170, 30, 100]],
		"spots": [Vector2(-70, -30)], "interior": Rect2(-110, -170, 150, 170),
	},
	"danger": {
		"name": "深海危险洞穴", "mode": "floor",
		"rects": [[60, -210, 34, 210], [-180, -236, 274, 26], [-180, -210, 34, 130]],
		"spots": [Vector2(-30, -30)], "interior": Rect2(-146, -210, 206, 210),
	},
	"hang_shelter": {
		"name": "悬空藏身龛", "mode": "hang",
		"rects": [[40, 0, 30, 150], [-90, 0, 30, 100]],
		"spots": [], "interior": Rect2(-60, 0, 100, 150),
	},
	"hang_treasure": {
		"name": "悬空宝藏龛", "mode": "hang",
		"rects": [[50, 0, 30, 180], [-110, 0, 30, 120], [-20, 150, 40, 30]],
		"spots": [Vector2(-30, 70)], "interior": Rect2(-80, 0, 130, 180),
	},
	"hang_danger": {
		"name": "深渊危险洞穴", "mode": "hang",
		"rects": [[60, 0, 34, 210], [-130, 0, 34, 130], [-20, 150, 50, 60]],
		"spots": [Vector2(-45, 90)], "interior": Rect2(-96, 0, 156, 210),
	},
}

## 洞穴类型权重；floor 模式下 danger 更稀有
const CAVE_KIND_WEIGHTS := {
	"floor": {"shelter": 0.45, "treasure": 0.35, "danger": 0.20},
	"hang": {"hang_shelter": 0.40, "hang_treasure": 0.35, "hang_danger": 0.25},
}

## 深渊悬洞挂面：区域C岩体 [3500,-200,1620,720] 的底缘
const HANG_SURFACE_Y := 520.0
const HANG_X_RANGE := [3580.0, 5020.0]
## 海床洞穴的候选区间（A 海床宝箱过密通常放不下，靠拒绝采样兜底）
const FLOOR_CAVE_ZONES := {
	"A": {"floor_y": 800.0, "x_range": [140.0, 1560.0]},
	"B": {"floor_y": 950.0, "x_range": [1800.0, 2820.0]},
}


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

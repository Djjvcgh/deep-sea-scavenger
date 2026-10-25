class_name WorldLayout
## 每潜世界布局（V0.4.1）：区域排布方式 + 种子化骨架。
## 横向布局：A 左 → B 中 → C 右，巨岩形状每潜不同（西缘/底缘/倒垂岩柱）。
## 纵向布局：上下划分——A 上层阳光带 / B 中层搁架 / C 深渊湖底，搁架段隙每潜不同。
## 布局字典是所有生成器的唯一几何依据：区域判定、通道样本、骨架实体、
## 洞穴锚面、内容布置计划、Boss 巢穴、明暗方向。

const MapDataRes := preload("res://scripts/map_data.gd")

const WALLS := [
	[-120, 0, 120, 1400, "rock"], [5120, 0, 120, 1400, "rock"]]


static func roll_kind(rng: RandomNumberGenerator) -> String:
	return "vertical" if rng.randf() < 0.45 else "horizontal"


static func build(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	if kind == "vertical":
		return _build_vertical(rng)
	return _build_horizontal(rng)


## 区域判定：横带按 x 阈值，纵带按 y 阈值。
static func zone_at(layout: Dictionary, p: Vector2) -> String:
	var key := "y" if layout["zone_kind"] == "y" else "x"
	var v: float = p.y if key == "y" else p.x
	var t: Array = layout["thresholds"]
	if v < float(t[0]):
		return "A"
	elif v < float(t[1]):
		return "B"
	return "C"


static func zone_name(layout: Dictionary, zone: String) -> String:
	return String(layout["zone_names"][zone])


## ---------------- 横向布局（A 左 → B 中 → C 右） ----------------

static func _build_horizontal(rng: RandomNumberGenerator) -> Dictionary:
	# 巨岩骨架：西缘 / 底缘高度按种子变化，附加 1~2 根倒垂岩柱
	var wx := rng.randf_range(3400.0, 3560.0)
	var by := rng.randf_range(500.0, 560.0)
	var massif: Array = [[wx, -200.0, 5120.0 - wx, by + 200.0, "rock"]]
	for i in rng.randi_range(1, 2):
		var px := rng.randf_range(wx + 300.0, 4820.0)
		var pw := rng.randf_range(60.0, 100.0)
		var pd := rng.randf_range(60.0, 110.0)
		massif.append([px, by, pw, pd, "rock"])

	return {
		"kind": "horizontal",
		"name": "横列海域",
		"zone_kind": "x",
		"thresholds": [1700.0, 3400.0],
		"zone_names": {"A": "区域 A · 近岸浅滩", "B": "区域 B · 沉船区域", "C": "区域 C · 深层洞穴"},
		"variants": MapDataRes.ZONE_VARIANTS,
		"shared_solids": {
			"*": WALLS + [[-120, 800, 1820, 400, "sand"], [1700, 950, 3540, 300, "sand"]] + massif,
		},
		"lanes": MapDataRes.lane_samples(),
		"cave_floor_zones": [
			{"zone": "A", "floor_y": 800.0, "x_range": [140.0, 1560.0]},
			{"zone": "B", "floor_y": 950.0, "x_range": [1800.0, 2820.0]},
		],
		"hang": {"surface_y": by, "x_range": [wx + 150.0, 4950.0]},
		"feature_plan": MapDataRes.TERRAIN_FEATURE_PLAN + [
			{"zone": "A", "mode": "floor", "anchor_y": 800.0, "kinds": ["terrace"],
				"count": [1, 2], "x_range": [520.0, 1350.0]},
			{"zone": "B", "mode": "floor", "anchor_y": 950.0, "kinds": ["terrace"],
				"count": [1, 2], "x_range": [1950.0, 2450.0]},
			{"zone": "A", "mode": "wall_w", "anchor_y": 0.0, "kinds": ["outcrop_west"],
				"count": [0, 1], "x_range": [0.0, 0.0]},
			{"zone": "C", "mode": "wall_e", "anchor_y": 0.0, "kinds": ["outcrop_east"],
				"count": [0, 1], "x_range": [5120.0, 5120.0]},
		],
		"container_spawns": [
			{"zone": "A", "floor_y": 800.0, "x_range": [110.0, 1640.0], "count": 6},
			{"zone": "B", "floor_y": 950.0, "x_range": [1760.0, 3340.0], "count": 5},
			{"zone": "C", "floor_y": 950.0, "x_range": [3530.0, 5070.0], "count": 4},
		],
		"decor_spawns": [
			{"zone": "A", "floor_y": 800.0, "x_range": [80.0, 1650.0], "count": 9},
			{"zone": "B", "floor_y": 950.0, "x_range": [1750.0, 3350.0], "count": 7},
			{"zone": "C", "floor_y": 950.0, "x_range": [3520.0, 5080.0], "count": 5},
		],
		"school_ranges": [[300.0, 1600.0, 220.0, 760.0], [1800.0, 3300.0, 220.0, 760.0],
			[1800.0, 3300.0, 220.0, 760.0], [3550.0, 5000.0, 220.0, 760.0],
			[3550.0, 5000.0, 220.0, 760.0]],
		"boss_region": Rect2(3620, 560, 1430, 320),
		"darkness_axis": "x",
		"silhouette": true,
	}


## ---------------- 纵向布局（A 上层 / B 中层搁架 / C 深渊湖底） ----------------

static func _build_vertical(rng: RandomNumberGenerator) -> Dictionary:
	# 中层搁架：顶面固定 560（沉船锚点依赖）。主跨 1380-3290 保持完整（锚位下方必有实体），
	# 两端各留一段可断开的缺口（种子决定是否断开与宽度）；底缘即悬洞挂面。
	var segments: Array = []
	var shelf_bottom := 700.0
	segments.append([1380.0, 560.0, 1910.0, 140.0, "rock"])
	var seg_x := 1150.0
	var seg_w := rng.randf_range(120.0, 200.0)
	if rng.randf() < 0.7:
		segments.append([seg_x, 560.0, seg_w, 140.0, "rock"])
	var east_x := rng.randf_range(3300.0, 3400.0)
	if rng.randf() < 0.7:
		segments.append([east_x, 560.0, 3450.0 - east_x, 140.0, "rock"])

	return {
		"kind": "vertical",
		"name": "纵深层海域",
		"zone_kind": "y",
		"thresholds": [340.0, 640.0],
		"zone_names": {"A": "区域 A · 上层阳光带", "B": "区域 B · 中层搁架", "C": "区域 C · 深渊湖底"},
		"variants": MapDataRes.VERTICAL_VARIANTS,
		"shared_solids": {
			"*": WALLS + [[-120, 950, 5240, 300, "sand"]] + segments,
		},
		"lanes": _vertical_lanes(),
		"cave_floor_zones": [
			{"zone": "C", "floor_y": 950.0, "x_range": [1100.0, 2820.0]},
		],
		"hang": {"surface_y": shelf_bottom, "x_range": [1400.0, 3250.0]},
		"feature_plan": [
			{"zone": "C", "mode": "floor", "anchor_y": 950.0, "kinds": ["dune_high", "rock_spire"],
				"count": [1, 2], "x_range": [1150.0, 2780.0]},
			{"zone": "C", "mode": "floor", "anchor_y": 950.0, "kinds": ["dune_low"],
				"count": [1, 2], "x_range": [2950.0, 4900.0]},
			{"zone": "B", "mode": "floor", "anchor_y": 560.0, "kinds": ["dune_high", "rock_spire"],
				"count": [1, 2], "x_range": [1250.0, 3330.0]},
			{"zone": "A", "mode": "wall_w", "anchor_y": 0.0, "kinds": ["outcrop_west"],
				"count": [0, 1], "x_range": [0.0, 0.0]},
			{"zone": "C", "mode": "wall_e", "anchor_y": 0.0, "kinds": ["outcrop_east"],
				"count": [0, 1], "x_range": [5120.0, 5120.0]},
		],
		"container_spawns": [
			{"zone": "C", "floor_y": 950.0, "x_range": [150.0, 4900.0], "count": 7},
			{"zone": "B", "floor_y": 560.0, "x_range": [1250.0, 3350.0], "count": 5},
		],
		"decor_spawns": [
			{"zone": "C", "floor_y": 950.0, "x_range": [150.0, 4900.0], "count": 8},
			{"zone": "B", "floor_y": 560.0, "x_range": [1250.0, 3350.0], "count": 4},
		],
		"school_ranges": [[200.0, 4900.0, 120.0, 300.0], [200.0, 4900.0, 380.0, 540.0],
			[200.0, 4900.0, 380.0, 540.0], [200.0, 4900.0, 680.0, 880.0],
			[200.0, 4900.0, 680.0, 880.0]],
		"boss_region": Rect2(700, 650, 4200, 250),
		"darkness_axis": "y",
		"silhouette": false,
	}


## 纵向布局的三条安全通道：西侧下潜竖井 / 湖底爬行道（东段）/ 东侧返回竖井。
static func _vertical_lanes() -> Array:
	var lanes: Array = []
	for y in range(120, 881, 60):
		lanes.append([Vector2(300, y), 30.0])
	for y in range(120, 881, 60):
		lanes.append([Vector2(4800, y), 30.0])
	for x in range(2900, 5001, 50):
		lanes.append([Vector2(x, 895), 30.0])
	return lanes

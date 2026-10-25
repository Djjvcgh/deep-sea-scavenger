class_name TerrainGen
## 每潜地形模块的种子化生成（沙丘 / 岩塔 / 石拱 / 沙脊 / 沙阶 / 墙垛 / 倒悬岩簇）。
## 在沉船与洞穴之后生成，避开一切已放结构——只填充剩余空间，失败即跳过（模块是可选装饰）。
## 这一层让每次下潜的海床结构肉眼可见地不同；候选区间与通道由布局提供。

const MapDataRes := preload("res://scripts/map_data.gd")
const WreckGenRes := preload("res://scripts/wreck_gen.gd")

const CLEARANCE := 20.0
## 特征之间的最小间距
const FEATURE_GAP := 30.0
## 与沉船/洞穴保持的距离
const STRUCT_GAP := 40.0
## 出生点安全半径
const SPAWN_CLEAR := 130.0


## 返回特征列表：{kind, zone, mode, anchor, rects: Array[Rect2]}
static func generate(rng: RandomNumberGenerator, chosen: Dictionary, wreck_rects: Array,
		cave_rects: Array, layout: Dictionary) -> Array:
	var out: Array = []
	var placed: Array = []
	for plan in layout["feature_plan"]:
		var count := rng.randi_range(plan["count"][0], plan["count"][1])
		var placed_count := 0
		var tries := 0
		while placed_count < count and tries < 40:
			tries += 1
			var kind := String(_weighted(rng, plan["kinds"]))
			var anchor := Vector2(rng.randf_range(plan["x_range"][0], plan["x_range"][1]),
				float(plan["anchor_y"]))
			var feature := {
				"kind": kind, "zone": plan["zone"], "mode": plan["mode"], "anchor": anchor,
				"rects": _world_rects(MapDataRes.TERRAIN_TEMPLATES[kind], anchor),
			}
			if not placement_ok(feature, chosen, wreck_rects, cave_rects, placed, layout):
				continue
			out.append(feature)
			placed.append_array(feature["rects"])
			placed_count += 1
	return out


static func _weighted(rng: RandomNumberGenerator, kinds: Array) -> String:
	return String(kinds[rng.randi_range(0, kinds.size() - 1)])


static func _world_rects(tpl: Dictionary, anchor: Vector2) -> Array:
	var out: Array = []
	for r in tpl["rects"]:
		out.append(Rect2(anchor.x + r[0], anchor.y + r[1], r[2], r[3]))
	return out


## 布置合法性（生成与自动化测试共用）：不压实体/通道/宝箱点、不穿巡逻带、
## 避开沉船与洞穴、避开出生点与撤离区、与已放特征保持间距。
## 依附面豁免按 mode：floor 贴海床（跳 sand）、hang 挂岩体底、wall 贴墙。
static func placement_ok(feature: Dictionary, chosen: Dictionary, wreck_rects: Array,
		cave_rects: Array, placed: Array, layout: Dictionary) -> bool:
	var zone: String = feature["zone"]
	var anchor: Vector2 = feature["anchor"]
	var kind: String = feature["kind"]
	var mode: String = feature["mode"]
	var solids: Array = layout["shared_solids"]["*"] + layout["shared_solids"].get(zone, []) \
		+ MapDataRes.variant_solids_of(layout, zone, chosen[zone]["index"])
	for wr in feature["rects"]:
		# 1) 与已有实体保持间隙（依附面豁免见下）
		for r in solids:
			if r[4] == "sand":
				continue
			var srect := Rect2(r[0], r[1], r[2], r[3])
			if _attached(mode, anchor, srect):
				continue
			if (wr as Rect2).intersects(srect.grow(CLEARANCE)):
				return false
		# 2) 安全通道：玩家胶囊通行盒不被截断
		for sample in layout.get("lanes", MapDataRes.lane_samples()):
			var pass_box := Rect2(sample[0].x - WreckGenRes.PASS_BOX_SIZE.x * 0.5,
				sample[0].y - WreckGenRes.PASS_BOX_SIZE.y * 0.5,
				WreckGenRes.PASS_BOX_SIZE.x, WreckGenRes.PASS_BOX_SIZE.y)
			if (wr as Rect2).intersects(pass_box):
				return false
		# 3) 不压宝箱点
		for cs in chosen[zone]["variant"]["chests"]:
			if WreckGenRes._circle_vs_rect(cs, 70.0, wr):
				return false
		# 4) 巡逻带不穿地形模块
		for p in chosen[zone]["variant"]["patrols"]:
			var band := Rect2(p[0] - 30, p[2] - 16, p[1] - p[0] + 60, 32)
			if band.intersects(wr):
				return false
		# 5) 避开沉船与洞穴
		for other in wreck_rects:
			if (wr as Rect2).grow(STRUCT_GAP).intersects(other):
				return false
		for other in cave_rects:
			if (wr as Rect2).grow(STRUCT_GAP).intersects(other):
				return false
		# 6) 避开出生点与撤离区
		if _circle_vs_rect(MapDataRes.PLAYER_SPAWN, SPAWN_CLEAR, wr):
			return false
		if (wr as Rect2).intersects(MapDataRes.EXTRACT_RECT.grow(40.0)):
			return false
		# 7) 特征之间保持间距
		for other in placed:
			if (wr as Rect2).grow(FEATURE_GAP).intersects(other):
				return false
	return true


## 特征是否依附在该实体表面（贴着生成是正确姿态，不算冲突）。
static func _attached(mode: String, anchor: Vector2, srect: Rect2) -> bool:
	match mode:
		"hang":
			return srect.end.y <= anchor.y + 2.0
		"wall_w":
			return srect.end.x <= anchor.x + 2.0
		"wall_e":
			return srect.position.x >= anchor.x - 2.0
	return false


static func _circle_vs_rect(p: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(p.x, rect.position.x, rect.end.x),
		clampf(p.y, rect.position.y, rect.end.y))
	return closest.distance_to(p) < radius

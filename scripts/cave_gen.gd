class_name CaveGen
## 可探索洞穴的种子化生成（拒绝采样）。
## 每次下潜 2~4 处：海床岩洞 / 深渊悬洞，几何（锚面与候选区间）由布局提供。
## 合法性：不压实体 / 不堵通道与舱门 / 不压宝箱点与沉船 / 不穿巡逻带 / 腔体敞开。

const MapDataRes := preload("res://scripts/map_data.gd")
const WreckGenRes := preload("res://scripts/wreck_gen.gd")

const CLEARANCE := 20.0
## 每次下潜的洞穴数量区间（含两形态）
const COUNT_RANGE := [2, 4]
## 形态选择权重：有悬洞锚面的布局以悬洞为主
const MODE_WEIGHTS := {"floor": 0.35, "hang": 0.65}


static func generate(rng: RandomNumberGenerator, chosen: Dictionary, wreck_rects: Array,
		layout: Dictionary, min_count := 2, force_kind := "") -> Array:
	var out: Array = []
	var placed_rects: Array = []
	for w in wreck_rects:
		placed_rects.append(w)
	if force_kind != "":
		var forced := _place_forced(rng, chosen, force_kind, layout, placed_rects)
		if not forced.is_empty():
			out.append(forced)
			placed_rects.append_array(forced["rects"])
	var target := maxi(rng.randi_range(COUNT_RANGE[0], COUNT_RANGE[1]), min_count)
	for attempt in 80:
		if out.size() >= target:
			break
		var cave := _place_one(rng, chosen, layout, placed_rects)
		if cave.is_empty():
			continue
		out.append(cave)
		placed_rects.append_array(cave["rects"])
	return out


## Boss 潜伏点保底：随机尝试保持位置多样性，失败后确定性扫掠——只要存在合法位置就必放。
static func _place_forced(rng: RandomNumberGenerator, chosen: Dictionary, kind: String,
		layout: Dictionary, placed_rects: Array) -> Dictionary:
	var forced := _place_kind(rng, chosen, kind, layout, placed_rects, 24)
	if forced.is_empty() and kind == "danger":
		forced = _place_kind(rng, chosen, "hang_danger", layout, placed_rects, 24)
	if forced.is_empty():
		forced = _sweep_place(chosen, kind, layout, placed_rects)
	if forced.is_empty() and kind == "danger":
		forced = _sweep_place(chosen, "hang_danger", layout, placed_rects)
	return forced


static func _place_one(rng: RandomNumberGenerator, chosen: Dictionary, layout: Dictionary,
		placed_rects: Array) -> Dictionary:
	var mode := _weighted_mode(rng)
	var kind := String(_weighted(rng, MapDataRes.CAVE_KIND_WEIGHTS[mode]))
	return _place_kind(rng, chosen, kind, layout, placed_rects)


static func _place_kind(rng: RandomNumberGenerator, chosen: Dictionary, kind: String,
		layout: Dictionary, placed_rects: Array, attempts := 14) -> Dictionary:
	var mode: String = MapDataRes.CAVE_TEMPLATES[kind]["mode"]
	var tpl: Dictionary = MapDataRes.CAVE_TEMPLATES[kind]
	for attempt in attempts:
		var spot := _pick_spot(rng, chosen, layout, mode)
		if spot.is_empty():
			continue
		var anchor: Vector2 = Vector2(rng.randf_range(spot["x_range"][0], spot["x_range"][1]), float(spot["anchor_y"]))
		var rects := _world_rects(tpl, anchor)
		if not _placement_ok(rects, anchor, tpl, spot["solids"], spot["chests"],
				spot["patrols"], placed_rects, layout):
			continue
		return _make_cave(kind, mode, spot["zone"], anchor)
	return {}


## 按固定步长扫掠全部候选区间，返回第一个合法位置（确定性）。
static func _sweep_place(chosen: Dictionary, kind: String, layout: Dictionary,
		placed_rects: Array) -> Dictionary:
	var tpl: Dictionary = MapDataRes.CAVE_TEMPLATES[kind]
	var mode: String = tpl["mode"]
	var spots := _candidate_spots(chosen, layout, mode)
	for spot in spots:
		var x: float = spot["x_range"][0]
		while x <= float(spot["x_range"][1]):
			var anchor := Vector2(x, float(spot["anchor_y"]))
			if _placement_ok(_world_rects(tpl, anchor), anchor, tpl, spot["solids"],
					spot["chests"], spot["patrols"], placed_rects, layout):
				return _make_cave(kind, mode, spot["zone"], anchor)
			x += 20.0
	return {}


## 候选锚位：hang 模式用布局挂面；floor 模式在布局海床锚位中随机挑选。
static func _pick_spot(rng: RandomNumberGenerator, chosen: Dictionary, layout: Dictionary,
		mode: String) -> Dictionary:
	var spots := _candidate_spots(chosen, layout, mode)
	if spots.is_empty():
		return {}
	return spots[rng.randi_range(0, spots.size() - 1)]


static func _candidate_spots(chosen: Dictionary, layout: Dictionary, mode: String) -> Array:
	var out: Array = []
	if mode == "hang":
		var hang: Dictionary = layout["hang"]
		var zone: String = "C"
		out.append({
			"zone": zone, "anchor_y": float(hang["surface_y"]), "x_range": hang["x_range"],
			"solids": _zone_solids(chosen, layout, zone),
			"chests": chosen[zone]["variant"]["chests"],
			"patrols": chosen[zone]["variant"]["patrols"],
		})
	else:
		for cfg in layout["cave_floor_zones"]:
			var zone: String = cfg["zone"]
			out.append({
				"zone": zone, "anchor_y": float(cfg["floor_y"]), "x_range": cfg["x_range"],
				"solids": _zone_solids(chosen, layout, zone),
				"chests": chosen[zone]["variant"]["chests"],
				"patrols": chosen[zone]["variant"]["patrols"],
			})
	return out


## 区域基础实体 = 布局骨架（墙/海床/巨岩/搁架）+ 该区变体实体。
static func _zone_solids(chosen: Dictionary, layout: Dictionary, zone: String) -> Array:
	return layout["shared_solids"]["*"] + layout["shared_solids"].get(zone, []) \
		+ MapDataRes.variant_solids_of(layout, zone, chosen[zone]["index"])


static func _weighted_mode(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	var acc := 0.0
	for k in MODE_WEIGHTS:
		acc += float(MODE_WEIGHTS[k])
		if r <= acc:
			return k
	return "hang"


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	var acc := 0.0
	for k in weights:
		acc += float(weights[k])
		if r <= acc:
			return k
	return weights.keys().back()


static func _world_rects(tpl: Dictionary, anchor: Vector2) -> Array:
	var out: Array = []
	for r in tpl["rects"]:
		out.append(Rect2(anchor.x + r[0], anchor.y + r[1], r[2], r[3]))
	return out


static func _make_cave(kind: String, mode: String, zone: String, anchor: Vector2) -> Dictionary:
	var tpl: Dictionary = MapDataRes.CAVE_TEMPLATES[kind]
	var cave := {
		"kind": kind, "mode": mode, "zone": zone, "anchor": anchor,
		"rects": _world_rects(tpl, anchor), "spots": [],
		"interior": WreckGenRes._offset_rect(tpl["interior"], anchor),
	}
	for s in tpl["spots"]:
		cave["spots"].append(anchor + s)
	return cave


static func _placement_ok(rects: Array, anchor: Vector2, tpl: Dictionary, solids: Array,
		chest_spots: Array, patrols: Array, placed_rects: Array, layout: Dictionary) -> bool:
	# 腔体内部必须完全敞开：实体与已放结构不得伸进洞内（内缩 6px 容许墙面贴合）
	var interior_world: Rect2 = WreckGenRes._offset_rect(tpl["interior"], anchor).grow(-6.0)
	for r in solids:
		if r[4] == "sand":
			continue
		if Rect2(r[0], r[1], r[2], r[3]).intersects(interior_world):
			return false
	for other in placed_rects:
		if (other as Rect2).intersects(interior_world):
			return false
	for wr in rects:
		# 1) 与已有实体保持间隙；海床 sand 除外（沉船底板贴着海床是正确姿态）
		for r in solids:
			if r[4] == "sand":
				continue
			var srect := Rect2(r[0], r[1], r[2], r[3])
			if tpl["mode"] == "hang" and srect.end.y <= anchor.y + 2.0:
				continue
			if (wr as Rect2).intersects(srect.grow(CLEARANCE)):
				return false
		# 2) 安全通道：玩家胶囊通行盒不被洞体截断
		for sample in layout.get("lanes", MapDataRes.lane_samples()):
			var pass_box := Rect2(sample[0].x - WreckGenRes.PASS_BOX_SIZE.x * 0.5,
				sample[0].y - WreckGenRes.PASS_BOX_SIZE.y * 0.5,
				WreckGenRes.PASS_BOX_SIZE.x, WreckGenRes.PASS_BOX_SIZE.y)
			if (wr as Rect2).intersects(pass_box):
				return false
		# 3) 不压海底宝箱点
		for cs in chest_spots:
			if WreckGenRes._circle_vs_rect(cs, 70.0, wr):
				return false
		# 4) 巡逻带不穿洞体（鲨鱼贴着洞口巡过才有趣）
		for p in patrols:
			var band := Rect2(p[0] - 30, p[2] - 16, p[1] - p[0] + 60, 32)
			if band.intersects(wr):
				return false
		# 5) 与已放沉船/洞穴保持间隙
		for other in placed_rects:
			if (wr as Rect2).grow(CLEARANCE).intersects(other):
				return false
	# 6) 洞内宝箱点不与洞体重叠、位于腔体内
	for s in tpl["spots"]:
		var spot: Vector2 = anchor + s
		if not (tpl["interior"] as Rect2).has_point(s):
			return false
		for wr in rects:
			if WreckGenRes._circle_vs_rect(spot, 24.0, wr):
				return false
	return true

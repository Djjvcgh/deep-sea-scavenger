class_name CaveGen
## 可探索洞穴的种子化生成（拒绝采样）。
## 每次下潜 2~4 处：海床岩洞落在 A/B 海床空位，深渊悬洞挂在区域C岩体底缘。
## 合法性：不压实体 / 不堵通道与舱门 / 不压宝箱点与沉船 / 不穿巡逻带。

const MapDataRes := preload("res://scripts/map_data.gd")
const WreckGenRes := preload("res://scripts/wreck_gen.gd")

const CLEARANCE := 20.0
## 每次下潜的洞穴数量区间（含两形态）
const COUNT_RANGE := [2, 4]
## 形态选择权重：C 区空间充裕，悬洞为主
const MODE_WEIGHTS := {"floor": 0.35, "hang": 0.65}


## 生成洞穴。min_count 用于洞穴主题保底；force_kind 用于保证危险洞穴存在。
static func generate(rng: RandomNumberGenerator, chosen: Dictionary, wreck_rects: Array,
		min_count := 2, force_kind := "") -> Array:
	var out: Array = []
	var placed_rects: Array = []
	for w in wreck_rects:
		placed_rects.append(w)
	if force_kind != "":
		var forced := _place_forced(rng, chosen, force_kind, placed_rects)
		if not forced.is_empty():
			out.append(forced)
			placed_rects.append_array(forced["rects"])
	var target := maxi(rng.randi_range(COUNT_RANGE[0], COUNT_RANGE[1]), min_count)
	for attempt in 80:
		if out.size() >= target:
			break
		var cave := _place_one(rng, chosen, placed_rects)
		if cave.is_empty():
			continue
		out.append(cave)
		placed_rects.append_array(cave["rects"])
	return out


static func _place_one(rng: RandomNumberGenerator, chosen: Dictionary,
		placed_rects: Array) -> Dictionary:
	var mode := _weighted_mode(rng)
	var kind := String(_weighted(rng, MapDataRes.CAVE_KIND_WEIGHTS[mode]))
	return _place_kind(rng, chosen, kind, placed_rects)


static func _place_kind(rng: RandomNumberGenerator, chosen: Dictionary, kind: String,
		placed_rects: Array, attempts := 14) -> Dictionary:
	var mode: String = MapDataRes.CAVE_TEMPLATES[kind]["mode"]
	var tpl: Dictionary = MapDataRes.CAVE_TEMPLATES[kind]
	for attempt in attempts:
		var anchor: Vector2
		var solids: Array
		var chest_spots: Array
		var patrols: Array
		var zone: String
		if mode == "hang":
			zone = "C"
			anchor = Vector2(rng.randf_range(MapDataRes.HANG_X_RANGE[0], MapDataRes.HANG_X_RANGE[1]),
				MapDataRes.HANG_SURFACE_Y)
			solids = MapDataRes.variant_solids("C", chosen["C"]["index"])
			chest_spots = chosen["C"]["variant"]["chests"]
			patrols = chosen["C"]["variant"]["patrols"]
		else:
			zone = "A" if rng.randf() < 0.25 else "B"
			var info: Dictionary = MapDataRes.FLOOR_CAVE_ZONES[zone]
			anchor = Vector2(rng.randf_range(info["x_range"][0], info["x_range"][1]), info["floor_y"])
			solids = MapDataRes.variant_solids(zone, chosen[zone]["index"])
			chest_spots = chosen[zone]["variant"]["chests"]
			patrols = chosen[zone]["variant"]["patrols"]
		var rects := _world_rects(tpl, anchor)
		if not _placement_ok(rects, anchor, tpl, solids, chest_spots, patrols, placed_rects):
			continue
		return _make_cave(kind, mode, zone, anchor)
	return {}


## Boss 潜伏点保底：随机尝试保持位置多样性，失败后确定性扫掠——只要存在合法位置就必放。
static func _place_forced(rng: RandomNumberGenerator, chosen: Dictionary, kind: String,
		placed_rects: Array) -> Dictionary:
	var forced := _place_kind(rng, chosen, kind, placed_rects, 24)
	if forced.is_empty() and kind == "danger":
		forced = _place_kind(rng, chosen, "hang_danger", placed_rects, 24)
	if forced.is_empty():
		forced = _sweep_place(chosen, kind, placed_rects)
	if forced.is_empty() and kind == "danger":
		forced = _sweep_place(chosen, "hang_danger", placed_rects)
	return forced


## 按固定步长扫掠全部候选区间，返回第一个合法位置（确定性）。
static func _sweep_place(chosen: Dictionary, kind: String, placed_rects: Array) -> Dictionary:
	var tpl: Dictionary = MapDataRes.CAVE_TEMPLATES[kind]
	var ranges: Array = []
	if tpl["mode"] == "hang":
		ranges.append(["C", MapDataRes.HANG_X_RANGE, MapDataRes.HANG_SURFACE_Y])
	else:
		ranges.append(["B", MapDataRes.FLOOR_CAVE_ZONES["B"]["x_range"],
			MapDataRes.FLOOR_CAVE_ZONES["B"]["floor_y"]])
		ranges.append(["A", MapDataRes.FLOOR_CAVE_ZONES["A"]["x_range"],
			MapDataRes.FLOOR_CAVE_ZONES["A"]["floor_y"]])
	for r in ranges:
		var zone: String = r[0]
		var solids: Array = MapDataRes.variant_solids(zone, chosen[zone]["index"])
		var chest_spots: Array = chosen[zone]["variant"]["chests"]
		var patrols: Array = chosen[zone]["variant"]["patrols"]
		var x: float = r[1][0]
		while x <= float(r[1][1]):
			var anchor := Vector2(x, float(r[2]))
			if _placement_ok(_world_rects(tpl, anchor), anchor, tpl, solids,
					chest_spots, patrols, placed_rects):
				return _make_cave(kind, String(tpl["mode"]), zone, anchor)
			x += 20.0
	return {}


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


static func _placement_ok(rects: Array, anchor: Vector2, tpl: Dictionary, solids: Array,
		chest_spots: Array, patrols: Array, placed_rects: Array) -> bool:
	# 腔体内部必须完全敞开：实体与已放结构不得伸进洞内（内缩 6px 容许墙面贴合）
	var interior_world: Rect2 = WreckGenRes._offset_rect(tpl["interior"], anchor).grow(-6.0)
	for r in solids:
		if r[4] == "sand":
			continue
		var srect0 := Rect2(r[0], r[1], r[2], r[3])
		if tpl["mode"] == "hang" and srect0.end.y <= anchor.y + 2.0:
			continue
		if srect0.intersects(interior_world):
			return false
	for other in placed_rects:
		if (other as Rect2).intersects(interior_world):
			return false
	for wr in rects:
		# 1) 与已有实体保持间隙；依附面除外（海床 sand / 悬洞挂面上方的岩体）
		for r in solids:
			if r[4] == "sand":
				continue
			var srect := Rect2(r[0], r[1], r[2], r[3])
			if tpl["mode"] == "hang" and srect.end.y <= anchor.y + 2.0:
				continue
			if (wr as Rect2).intersects(srect.grow(CLEARANCE)):
				return false
		# 2) 三条安全通道的胶囊通行盒不被洞体截断
		for sample in MapDataRes.lane_samples():
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

class_name WreckGen
## 可探索沉船的种子化生成。
## 沉船锚点由地图变体数据手工指定（"手工模块 + 随机种子"），每次下潜按种子
## 决定锚点是否激活与船型；合法性由 run_tests 对全部变体锚点做校验兜底。

const MapDataRes := preload("res://scripts/map_data.gd")

## 沉船外扩安全间隙（船体与岩石/宝箱点等的最小间距）
const CLEARANCE := 20.0
## 玩家胶囊通行盒（含 2px 余量）：通道/舱门按此判定
const PASS_BOX_SIZE := Vector2(28, 34)


## 从已选变体生成沉船列表。rng 为已注入种子的随机数流。
## 返回：{kind, zone, anchor: Vector2, rects: Array[Rect2], spots: Array[Vector2],
##        interior: Rect2, captain_room: Rect2(可选)}
static func generate(rng: RandomNumberGenerator, chosen: Dictionary) -> Array:
	var out: Array = []
	for zone in ["B", "C"]:
		var variant: Dictionary = chosen[zone]["variant"]
		for anchor_cfg in variant.get("wreck_anchors", []):
			if rng.randf() >= MapDataRes.WRECK_ANCHOR_CHANCE:
				continue
			var kind := _pick_kind(rng, anchor_cfg["kinds"])
			out.append(_build(kind, zone, Vector2(anchor_cfg["x"], MapDataRes.WRECK_FLOOR_Y)))
	return out


static func _pick_kind(rng: RandomNumberGenerator, kinds: Array) -> String:
	var total := 0.0
	for k in kinds:
		total += float(MapDataRes.WRECK_KIND_WEIGHTS[k])
	var r := rng.randf() * total
	var acc := 0.0
	for k in kinds:
		acc += float(MapDataRes.WRECK_KIND_WEIGHTS[k])
		if r <= acc:
			return k
	return String(kinds.back())


static func _build(kind: String, zone: String, anchor: Vector2) -> Dictionary:
	var tpl: Dictionary = MapDataRes.WRECK_TEMPLATES[kind]
	var wreck := {
		"kind": kind, "zone": zone, "anchor": anchor,
		"rects": _world_rects(tpl, anchor), "spots": [],
		"interior": _offset_rect(tpl["interior"], anchor),
	}
	for s in tpl["spots"]:
		wreck["spots"].append(anchor + s)
	if tpl.has("captain_room"):
		wreck["captain_room"] = _offset_rect(tpl["captain_room"], anchor)
	return wreck


static func _world_rects(tpl: Dictionary, anchor: Vector2) -> Array:
	var out: Array = []
	for r in tpl["rects"]:
		out.append(Rect2(anchor.x + r[0], anchor.y + r[1], r[2], r[3]))
	return out


static func _offset_rect(r: Rect2, anchor: Vector2) -> Rect2:
	return Rect2(r.position + anchor, r.size)


## 布置合法性校验（run_tests 与生成共用）。
## rects 为沉船船体（世界坐标），base_solids/chest_spots/patrols 为所在变体数据。
static func placement_ok(rects: Array, base_solids: Array, chest_spots: Array,
		patrols: Array) -> bool:
	# 1) 与已有非海床实体保持安全间隙（沉船底板贴着海床是正确姿态）
	for wr in rects:
		for r in base_solids:
			if r[4] == "sand":
				continue
			var rect := Rect2(r[0], r[1], r[2], r[3]).grow(CLEARANCE)
			if (wr as Rect2).intersects(rect):
				return false
	# 2) 三条安全通道：玩家胶囊通行盒不被船体截断（侧舱门保证可从船内穿过）
	for sample in MapDataRes.lane_samples():
		var pass_box := Rect2(sample[0].x - PASS_BOX_SIZE.x * 0.5,
			sample[0].y - PASS_BOX_SIZE.y * 0.5, PASS_BOX_SIZE.x, PASS_BOX_SIZE.y)
		for wr in rects:
			if (wr as Rect2).intersects(pass_box):
				return false
	# 3) 不压海底宝箱点
	for cs in chest_spots:
		for wr in rects:
			if _circle_vs_rect(cs, 70.0, wr):
				return false
	# 4) 巡逻带不穿船体
	for p in patrols:
		var band := Rect2(p[0] - 30, p[2] - 16, p[1] - p[0] + 60, 32)
		for wr in rects:
			if band.intersects(wr):
				return false
	return true


static func _circle_vs_rect(p: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(p.x, rect.position.x, rect.end.x),
		clampf(p.y, rect.position.y, rect.end.y))
	return closest.distance_to(p) < radius

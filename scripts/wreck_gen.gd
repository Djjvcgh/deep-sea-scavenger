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
static func generate(rng: RandomNumberGenerator, chosen: Dictionary, layout: Dictionary) -> Array:
	var out: Array = []
	for zone in ["B", "C"]:
		var anchors: Array = chosen[zone]["variant"].get("wreck_anchors", [])
		if anchors.is_empty():
			continue
		if rng.randf() >= MapDataRes.WRECK_ANCHOR_CHANCE:
			continue
		# 同一变体的多个锚点互斥：每潜至多一艘沉船占据该变体的锚位
		var cfg: Dictionary = anchors[rng.randi_range(0, anchors.size() - 1)]
		var kind := _pick_kind(rng, cfg["kinds"])
		var wreck := _build_validated(rng, kind, zone, float(cfg["x"]),
			float(cfg.get("floor_y", MapDataRes.WRECK_FLOOR_Y)), chosen, layout)
		if not wreck.is_empty():
			out.append(wreck)
	return out


## 锚点左右小幅抖动增加位置随机性；抖动位置非法则回退原锚点（锚点本身已离线校验）。
static func _build_validated(rng: RandomNumberGenerator, kind: String, zone: String,
		base_x: float, floor_y: float, chosen: Dictionary, layout: Dictionary) -> Dictionary:
	var solids: Array = ground_filter(_base_solids(zone, chosen, layout), floor_y)
	var chests: Array = chosen[zone]["variant"]["chests"]
	var patrols: Array = chosen[zone]["variant"]["patrols"]
	var offsets := [rng.randf_range(-50.0, 50.0), 0.0]
	for off in offsets:
		var anchor := Vector2(base_x + off, floor_y)
		var wreck := _build(kind, zone, anchor)
		if placement_ok(wreck["rects"], solids, chests, patrols,
				wreck["interior"], layout):
			return wreck
	return {}


## 区域基础实体 = 布局骨架（墙/海床/巨岩/搁架）+ 该区变体实体。
static func _base_solids(zone: String, chosen: Dictionary, layout: Dictionary) -> Array:
	return layout["shared_solids"]["*"] + layout["shared_solids"].get(zone, []) \
		+ MapDataRes.variant_solids_of(layout, zone, chosen[zone]["index"])


## 地面过滤：去掉顶面与锚位地面齐平的实体（海床/搁架）——沉船立在它们上是正确姿态。
static func ground_filter(solids: Array, floor_y: float) -> Array:
	var out: Array = []
	for r in solids:
		var rect := Rect2(r[0], r[1], r[2], r[3])
		if rect.position.y >= floor_y - 2.0 and rect.position.y <= floor_y + 20.0:
			continue
		out.append(r)
	return out


## 沉船主题强制激活一个锚点（保证幽灵船长有触发点）；无可用锚点时返回空。
static func force_one(rng: RandomNumberGenerator, chosen: Dictionary, layout: Dictionary) -> Dictionary:
	for zone in ["B", "C"]:
		var anchors: Array = chosen[zone]["variant"].get("wreck_anchors", [])
		if anchors.is_empty():
			continue
		var cfg: Dictionary = anchors[rng.randi_range(0, anchors.size() - 1)]
		var kind := _pick_kind(rng, cfg["kinds"])
		return _build_validated(rng, kind, zone, float(cfg["x"]),
			float(cfg.get("floor_y", MapDataRes.WRECK_FLOOR_Y)), chosen, layout)
	return {}


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
## rects 为沉船船体（世界坐标），base_solids/chest_spots/patrols 为所在布局与变体数据；
## interior 为舱内水域（世界坐标），传入时要求其完全敞开。
static func placement_ok(rects: Array, base_solids: Array, chest_spots: Array,
		patrols: Array, interior := Rect2(), layout: Dictionary = {}) -> bool:
	# 舱内水域必须敞开（沉船是空心壳体，实体不得伸进舱内）
	if interior.size.x > 0.0:
		var interior_check := interior.grow(-6.0)
		for r in base_solids:
			if r[4] == "sand":
				continue
			if Rect2(r[0], r[1], r[2], r[3]).intersects(interior_check):
				return false
	# 1) 与已有非海床实体保持安全间隙（沉船底板贴着海床是正确姿态）
	for wr in rects:
		for r in base_solids:
			if r[4] == "sand":
				continue
			var rect := Rect2(r[0], r[1], r[2], r[3]).grow(CLEARANCE)
			if (wr as Rect2).intersects(rect):
				return false
	# 2) 安全通道：玩家胶囊通行盒不被船体截断（侧舱门保证可从船内穿过）
	var lanes: Array = layout.get("lanes", MapDataRes.lane_samples())
	for sample in lanes:
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

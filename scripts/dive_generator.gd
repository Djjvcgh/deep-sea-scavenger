class_name DiveGenerator
## 单次下潜的世界生成管线（场景与自动化测试共用同一条路径）。
## 全部消费同一条已注入种子的随机数流：变体选择（含主题重抽）→ 沉船 → 洞穴 → 地形模块。
## 同一海况种子必然得到同一张地图。

const MapDataRes := preload("res://scripts/map_data.gd")
const WreckGenRes := preload("res://scripts/wreck_gen.gd")
const CaveGenRes := preload("res://scripts/cave_gen.gd")
const TerrainGenRes := preload("res://scripts/terrain_gen.gd")


## 依据主题抽取三区变体（变体集来自布局）；沉船/洞穴主题在缺少触发空间时按种子重抽对应区域变体。
static func choose_variants(rng: RandomNumberGenerator, theme: String, layout: Dictionary) -> Dictionary:
	var chosen := {}
	for zone in ["A", "B", "C"]:
		var idx := rng.randi_range(0, layout["variants"][zone].size() - 1)
		chosen[zone] = {"index": idx, "variant": layout["variants"][zone][idx]}
	if theme == "wreck":
		for attempt in 6:
			if not chosen["B"]["variant"].get("wreck_anchors", []).is_empty():
				break
			var bidx := rng.randi_range(0, MapDataRes.ZONE_VARIANTS["B"].size() - 1)
			chosen["B"] = {"index": bidx, "variant": MapDataRes.ZONE_VARIANTS["B"][bidx]}
	if theme == "cave":
		for attempt in 8:
			if not chosen["C"]["variant"].get("no_hang", false):
				break
			var cidx := rng.randi_range(0, MapDataRes.ZONE_VARIANTS["C"].size() - 1)
			chosen["C"] = {"index": cidx, "variant": MapDataRes.ZONE_VARIANTS["C"][cidx]}
	return chosen


## 生成一整局的可探索内容（不含色调等纯视觉层）。
static func generate_world(rng: RandomNumberGenerator, theme: String, layout: Dictionary) -> Dictionary:
	var chosen := choose_variants(rng, theme, layout)

	var wrecks: Array = WreckGenRes.generate(rng, chosen, layout)
	if theme == "wreck" and wrecks.is_empty():
		var forced: Dictionary = WreckGenRes.force_one(rng, chosen, layout)
		if not forced.is_empty():
			wrecks.append(forced)
	var wreck_rects: Array = []
	for w in wrecks:
		wreck_rects.append_array(w["rects"])

	var caves: Array = CaveGenRes.generate(rng, chosen, wreck_rects, layout,
		3 if theme == "cave" else 2, "danger" if theme == "cave" else "")
	var cave_rects: Array = []
	for c in caves:
		cave_rects.append_array(c["rects"])

	var features: Array = TerrainGenRes.generate(rng, chosen, wreck_rects, cave_rects, layout)

	return {"chosen": chosen, "wrecks": wrecks, "caves": caves, "features": features}

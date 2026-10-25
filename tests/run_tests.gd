extends SceneTree
## 自动化检查入口：godot --headless -s res://tests/run_tests.gd
## 每个测试函数返回失败数，最后以退出码报告结果。

var failures := 0


func _initialize() -> void:
	print("=== 深海摸金 自动化检查 ===")
	_ensure_autoloads()
	failures += _test_scripts_parse()
	failures += _test_item_db()
	failures += _test_balance()
	failures += _test_game_state()
	failures += _test_save_roundtrip()
	failures += _test_map_data()
	failures += _test_icons()
	failures += _test_wrecks()
	failures += _test_caves()
	failures += _test_world_generation()
	failures += _test_loot_randomness()
	_print_result()
	quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [通过] " + msg)
	else:
		failures += 1
		print("  [失败] " + msg)


func _print_result() -> void:
	if failures == 0:
		print("=== 全部通过 ===")
	else:
		print("=== 共 %d 项失败 ===" % failures)


## -s 脚本模式下 autoload 可能未注册，手动补齐，保证场景可实例化。
func _ensure_autoloads() -> void:
	var names := {"GameState": "game_state.gd", "SaveManager": "save_manager.gd", "Sfx": "sfx.gd"}
	for n in names:
		if not root.has_node(n):
			var node: Node = (load("res://scripts/" + names[n])).new()
			node.name = n
			root.add_child(node)


func _test_scripts_parse() -> int:
	print("[脚本解析]")
	var bad := 0
	for path in _list_scripts("res://scripts"):
		var s = load(path)
		if s == null or not s.can_instantiate():
			print("  [失败] 无法加载 " + path)
			bad += 1
	_check(bad == 0, "scripts/ 下所有 GDScript 可解析加载")
	return bad


func _list_scripts(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if dir.current_is_dir():
			out.append_array(_list_scripts(p))
		elif f.ends_with(".gd"):
			out.append(p)
		f = dir.get_next()
	return out


func _test_item_db() -> int:
	print("[数据表]")
	var T = ItemDB.TREASURES
	_check(ItemDB.QUALITIES["worn"]["mult"] == 0.6 and ItemDB.QUALITIES["standard"]["mult"] == 1.0
		and ItemDB.QUALITIES["fine"]["mult"] == 1.4 and ItemDB.QUALITIES["pristine"]["mult"] == 2.0,
		"品质倍率 0.6/1.0/1.4/2.0")
	_check(T["old_coin"]["value"] == 10 and T["pearl"]["value"] == 18, "新低阶宝物 旧硬币10/珍珠18")
	_check(T["bronze_coins"]["value"] == 25 and T["bronze_coins"]["slots"] == 1
		and is_equal_approx(T["bronze_coins"]["search_time"], 1.5), "古铜币包 25/1格/1.5s")
	_check(T["silver_platter"]["value"] == 70 and T["silver_platter"]["slots"] == 2, "银质餐盘 70/2格")
	_check(T["gold_cup"]["value"] == 140 and T["gold_cup"]["slots"] == 3, "沉船金杯 140/3格")
	_check(T["cursed_idol"]["value"] == 280 and T["cursed_idol"]["slots"] == 5, "诅咒神像 280/5格")
	_check(ItemDB.MATERIALS["wood"]["price"] == 100
		and ItemDB.MATERIALS["iron"]["price"] == 180
		and ItemDB.MATERIALS["canvas"]["price"] == 160
		and ItemDB.MATERIALS["leather"]["price"] == 120, "物资价格 100/180/160/120")
	_check(is_equal_approx(ItemDB.MATERIAL_SELL_RATE, 0.8), "材料回售 8 折")
	_check(ItemDB.BAG_TIERS.size() == 3 and ItemDB.BAG_TIERS[0]["capacity"] == 8
		and ItemDB.BAG_TIERS[1]["capacity"] == 10 and ItemDB.BAG_TIERS[2]["capacity"] == 12,
		"背包档位 8/10/12")
	_check(ItemDB.CONTAINERS["chest"]["search_time"] == 3.0
		and ItemDB.CONTAINERS["shell"]["search_time"] == 1.2
		and ItemDB.CONTAINERS["trash_bag"]["search_time"] == 2.0
		and ItemDB.CONTAINERS["cache"]["search_time"] == 2.0, "容器搜索时长定义完整")
	_check(ItemDB.UPGRADES["fins"]["cost"] == 160
		and ItemDB.UPGRADES["amulet"]["cost"] == 220
		and not ItemDB.UPGRADES.has("bag"), "升级表：脚蹼/护符（背包已改为打造）")
	_check(ItemDB.BOAT_REQUIREMENT["wood"] == 2 and ItemDB.BOAT_REQUIREMENT["iron"] == 1
		and ItemDB.BOAT_REQUIREMENT["canvas"] == 1, "造船需求 木2/铁1/帆1")
	_check(ItemDB.HARPOON_CRAFT["iron"] == 2 and ItemDB.HARPOON_CRAFT["wood"] == 1,
		"鱼叉打造需求 铁2/木1")
	_check(ItemDB.SHARK_DROP == "leather", "鲨鱼掉落皮革")
	for entry in ItemDB.BOSS_LOOT:
		if entry.has("id"):
			_check_quiet(T.has(entry["id"]), "巨影掉落宝物 %s 存在" % entry["id"])
			_check_quiet(ItemDB.QUALITIES.has(entry["quality"]), "巨影掉落品质 %s 有效" % entry["quality"])
		elif entry.has("mat"):
			_check_quiet(ItemDB.MATERIALS.has(entry["mat"]), "巨影掉落材料 %s 存在" % entry["mat"])
	_check(quiet_fail == 0, "巨影掉落表合法")
	# 各区域权重合计为1
	for zone in ItemDB.ZONE_WEIGHTS:
		var total := 0.0
		for id in ItemDB.ZONE_WEIGHTS[zone]:
			_check_quiet(T.has(id), "区域%s权重引用的宝物 %s 存在" % [zone, id])
			total += ItemDB.ZONE_WEIGHTS[zone][id]
		_check(is_equal_approx(total, 1.0), "区域%s 权重合计=1" % zone)
	return 0


var quiet_fail := 0
func _check_quiet(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		quiet_fail += 1
		print("  [失败] " + msg)


func _test_balance() -> int:
	print("[数值配置]")
	_check(Balance.SPRINT_SPEED > Balance.SWIM_SPEED, "冲刺速度大于游泳速度")
	_check(Balance.DRAIN_SPRINT > Balance.DRAIN_SWIM
		and Balance.DRAIN_SWIM > Balance.DRAIN_IDLE, "体力消耗：冲刺>游泳>停留")
	_check(is_equal_approx(Balance.SHARK_DETECT_RANGE * Balance.SHARK_DETECT_CURSE_MULT, 270.0),
		"诅咒感知范围 = 270")
	_check(Balance.MAX_HP == 3 and Balance.INVINCIBLE_TIME == 2.0, "生命3 / 无敌2秒")
	_check(is_equal_approx(Balance.SURFACE_REGEN, 8.0) and is_equal_approx(Balance.BREATH_DEPTH, 70.0),
		"换气参数：恢复 8/秒 · 贴水面 70px 内")
	return 0


func _test_game_state() -> int:
	print("[全局状态]")
	var gs = root.get_node("GameState")
	gs.reset_defaults()

	# 物品条目与品质估值
	_check(gs.add_dive_item("gold_cup", "worn") and gs.value_of(gs.dive_bag[0]) == 84,
		"破损金杯估值 84")
	_check(gs.add_dive_item("silver_platter", "standard") and gs.value_of(gs.dive_bag[1]) == 70,
		"标准银盘估值 70")
	_check(gs.add_dive_item("silver_platter", "fine") and gs.value_of(gs.dive_bag[2]) == 98,
		"精良银盘估值 98")
	_check(gs.bag_used_slots() == 7, "占格按类型计算（3+2+2）")
	_check(gs.add_dive_item("pearl") and gs.bag_used_slots() == 8, "第4件恰好装满8格")
	_check(not gs.add_dive_item("old_coin"), "8格满后拒绝拾取")

	# 背包档位与打造
	gs.reset_defaults()
	_check(gs.bag_capacity() == 8, "默认背包 8 格")
	gs.materials["leather"] = 1
	_check(not gs.craft_bag(), "材料不足不能打造")
	gs.materials["leather"] = 2
	_check(gs.craft_bag() and gs.bag_capacity() == 10, "皮革背包打造成功（10格）")
	gs.materials["leather"] = 2
	gs.materials["iron"] = 1
	_check(gs.craft_bag() and gs.bag_capacity() == 12, "加固背包打造成功（12格）")
	_check(not gs.craft_bag(), "已是最高档不能再打造")

	# 容量与负重（12格档位）
	_check(gs.add_dive_item("gold_cup") and gs.add_dive_item("gold_cup")
		and gs.add_dive_item("gold_cup") and gs.add_dive_item("silver_platter"), "装下 3金杯+1银盘")
	_check(gs.bag_used_slots() == 11, "占用 11 格")
	_check(not gs.add_dive_item("silver_platter"), "12格装不下第5件")
	_check(is_equal_approx(gs.weight_speed_mult(), 0.9), "负重速度×0.9")
	_check(is_equal_approx(gs.weight_drain_mult(), 1.2), "负重消耗×1.2")

	# 诅咒
	gs.reset_defaults()
	_check(not gs.has_curse_idol(), "初始无诅咒")
	gs.add_dive_item("cursed_idol", "fine")
	_check(gs.has_curse_idol(), "携带神像触发诅咒")

	# 失败掉落与找回
	gs.reset_defaults()
	gs.add_dive_item("gold_cup", "pristine")
	gs.add_dive_item("pearl")
	gs.end_dive(false, Vector2(4000, 800))
	_check(gs.dive_bag.is_empty(), "失败后临时背包清空")
	_check(gs.lost_cache["items"].size() == 2 and gs.lost_cache["x"] == 4000.0, "战利品进入遗落物缓存")
	gs.add_dive_item("silver_platter")
	gs.end_dive(false, Vector2(4500, 850))
	_check(gs.lost_cache["items"].size() == 3 and gs.lost_cache["x"] == 4500.0,
		"再次失败合并到新掉落点")
	var taken: Dictionary = gs.take_from_cache(0)
	_check(taken["id"] == "gold_cup" and taken["quality"] == "pristine", "从缓存取回完好金杯")
	_check(gs.lost_cache["items"].size() == 2, "缓存剩余 2 件")
	gs.restore_to_cache([taken])
	_check(gs.lost_cache["items"].size() == 3, "未带走条目放回缓存")
	gs.end_dive(true)
	_check(gs.lost_cache["items"].size() == 3, "成功撤离不影响遗落物缓存")

	# 交易（按品质）
	gs.reset_defaults()
	gs.credits = 0
	gs.island_stock = [
		{"id": "gold_cup", "quality": "fine"}, {"id": "gold_cup", "quality": "worn"},
		{"id": "pearl", "quality": "standard"}]
	_check(gs.sell_one(0) and gs.credits == 196, "按下标出售精良金杯 +196")
	_check(gs.sell_all_of("gold_cup") == 84, "按类型全部出售（剩余破损金杯）+84")
	_check(gs.sell_all_of("gold_cup") == 0 and gs.credits == 280, "无库存时出售返回 0")
	_check(gs.island_stock.size() == 1, "库存只剩珍珠")
	_check(not gs.sell_one(5), "非法下标拒绝")

	# 材料回售
	gs.materials["leather"] = 2
	_check(gs.sell_material("leather") and gs.credits == 280 + 96, "回售皮革 +96（8折）")
	_check(gs.materials["leather"] == 1, "回售后材料减少")
	gs.materials["leather"] = 0
	_check(not gs.sell_material("leather"), "无材料不能回售")
	_check(gs.credits >= 0, "交易额度永不为负")

	# 升级（脚蹼/护符）
	gs.credits = 160
	_check(gs.buy_upgrade("fins") and is_equal_approx(gs.speed_mult(), 1.2), "购买脚蹼生效")
	_check(not gs.buy_upgrade("fins"), "已升级不能重复购买")
	_check(gs.credits == 0, "扣费正确")

	# 造船
	gs.reset_defaults()
	gs.materials = {"wood": 3, "iron": 1, "canvas": 1, "leather": 0}
	_check(gs.invest_material("wood", 5) == 2, "投入木材最多按需求2")
	_check(gs.invest_material("iron", 1) == 1 and gs.invest_material("canvas", 1) == 1,
		"投入铁件与帆布")
	_check(gs.boat_completed and is_equal_approx(gs.boat_progress(), 1.0), "材料齐全造船完成")
	_check(gs.invest_material("wood", 1) == 0, "造船完成后不能再投入")

	# 鱼叉打造
	gs.reset_defaults()
	_check(not gs.has_harpoon, "初始无鱼叉")
	gs.materials["iron"] = 1
	_check(not gs.craft_harpoon(), "材料不足不能打造鱼叉")
	gs.materials["iron"] = 2
	gs.materials["wood"] = 1
	_check(gs.craft_harpoon() and gs.has_harpoon, "鱼叉打造成功")
	_check(not gs.craft_harpoon(), "鱼叉只能打造一次")
	_check(gs.materials["iron"] == 0 and gs.materials["wood"] == 0, "打造扣减材料")
	return 0


func _test_save_roundtrip() -> int:
	print("[存档]")
	var gs = root.get_node("GameState")
	var sm = root.get_node("SaveManager")
	sm.set("save_path", "user://test_save.json")
	if FileAccess.file_exists(sm.get("save_path")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.get("save_path")))

	_check(sm.load_game().is_empty(), "无存档时返回空")
	gs.reset_defaults()
	gs.credits = 333
	gs.island_stock = [{"id": "gold_cup", "quality": "fine"}, {"id": "pearl", "quality": "worn"}]
	gs.materials = {"wood": 2, "iron": 0, "canvas": 1, "leather": 1}
	gs.bag_tier = 1
	gs.upgrades = {"fins": false, "amulet": true}
	gs.boat_invested = {"wood": 1, "iron": 0, "canvas": 0}
	gs.has_harpoon = true
	gs.lost_cache = {"x": 4200.0, "y": 860.0, "items": [{"id": "silver_platter", "quality": "standard"}]}
	_check(sm.save_game(gs.serialize()), "存档写入成功")

	gs.reset_defaults()
	gs.apply_save(sm.load_game())
	_check(gs.credits == 333 and gs.island_stock.size() == 2
		and gs.island_stock[0]["quality"] == "fine", "额度与库存（含品质）读档正确")
	_check(gs.bag_tier == 1 and gs.bag_capacity() == 10, "背包档位读档正确")
	_check(gs.upgrades["amulet"] and not gs.upgrades["fins"], "升级状态读档正确")
	_check(gs.lost_cache["items"].size() == 1 and gs.lost_cache["x"] == 4200.0, "遗落物缓存读档正确")
	_check(gs.has_harpoon, "鱼叉拥有状态读档正确")

	# v1 旧存档迁移：字符串物品 + 扩容背包升级
	var path: String = sm.get("save_path")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"version": 1, "credits": 50,
		"island_stock": ["gold_cup", "bad_id"],
		"materials": {"wood": 1}, "upgrades": {"bag": true},
		"boat_invested": {}, "boat_completed": false,
	}))
	f.close()
	gs.reset_defaults()
	gs.apply_save(sm.load_game())
	_check(gs.bag_tier == 2 and gs.bag_capacity() == 12, "v1 扩容升级迁移为背包档位2（12格）")
	_check(gs.island_stock.size() == 1 and gs.island_stock[0] == {"id": "gold_cup", "quality": "standard"},
		"v1 字符串物品迁移为标准品质，非法 id 被忽略")

	# 损坏存档
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string("{{{不是json")
	f2.close()
	_check(sm.load_game().is_empty(), "损坏存档按无存档处理")
	var f3 := FileAccess.open(path, FileAccess.WRITE)
	f3.store_string("{\"credits\": \"abc\", \"island_stock\": [\"bad_id\", {\"id\": \"gold_cup\"}]}")
	f3.close()
	gs.reset_defaults()
	gs.apply_save(sm.load_game())
	_check(gs.credits == 0 and gs.island_stock.size() == 1
		and gs.island_stock[0]["quality"] == "standard", "非法字段被安全忽略")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return 0


func _test_map_data() -> int:
	print("[地图数据：变体校验]")
	var expected_counts := {"A": 5, "B": 5, "C": 4}
	var variant_count := 0
	for zone in ["A", "B", "C"]:
		var variants: Array = MapData.ZONE_VARIANTS[zone]
		variant_count += variants.size()
		for vi in variants.size():
			var v: Dictionary = variants[vi]
			var tag: String = "%s%d(%s)" % [zone, vi, v["name"]]
			var solids: Array = MapData.SHARED_SOLIDS + v["solids"]

			# 宝物点数量与位置合法性
			_check(v["chests"].size() == expected_counts[zone], "%s 宝物点 %d 个" % [tag, expected_counts[zone]])
			var chest_fail := 0
			for spot in v["chests"]:
				for r in solids:
					var rect := Rect2(r[0] - 16, r[1] - 16, r[2] + 32, r[3] + 32)
					if rect.has_point(spot):
						_check_quiet(false, "%s 宝物点 %s 落在实体 %s 内" % [tag, spot, r])
						chest_fail += 1
			_check(chest_fail == 0, "%s 所有宝物点位于开阔水域" % tag)

			# 巡逻带：区间有效且不与实体重叠（鲨鱼身体约 58x20）
			var patrol_fail := 0
			for p in v["patrols"]:
				if p[1] <= p[0]:
					_check_quiet(false, "%s 巡逻区间无效 %s" % [tag, p])
					patrol_fail += 1
				var band := Rect2(p[0] - 30, p[2] - 16, p[1] - p[0] + 60, 32)
				for r in solids:
					var rect := Rect2(r[0], r[1], r[2], r[3])
					if band.intersects(rect):
						_check_quiet(false, "%s 巡逻带 %s 穿过实体 %s" % [tag, p, r])
						patrol_fail += 1
			_check(patrol_fail == 0, "%s 巡逻带不穿墙" % tag)

			# 三条安全通道（L1 底层爬行道 / L2 下潜斜线 / L3 上层航道）
			var lane_fail := 0
			for sample in MapData.lane_samples():
				if not MapData.circle_clear(sample[0], sample[1], solids):
					_check_quiet(false, "%s 通道被实体阻挡：点 %s" % [tag, sample[0]])
					lane_fail += 1
			_check(lane_fail == 0, "%s 三条安全通道贯通" % tag)

	_check(variant_count == 15, "共 15 套布局变体（3 区域 × 5）")
	_check(quiet_fail == 0, "变体数据全部合法")
	return 0


func _test_icons() -> int:
	print("[物品图标]")
	var bad := 0
	for id in ItemDB.TREASURES:
		if not _icon_ok(id):
			_check_quiet(false, "宝物 %s 图标缺失或尺寸不对（%s）" % [id, ItemDB.icon_path(id)])
			bad += 1
	for id in ItemDB.MATERIALS:
		if not _icon_ok(id):
			_check_quiet(false, "材料 %s 图标缺失或尺寸不对（%s）" % [id, ItemDB.icon_path(id)])
			bad += 1
	_check(bad == 0, "全部宝物与材料都有 64×64 图标")
	return 0


func _icon_ok(id: String) -> bool:
	var path: String = ItemDB.icon_path(id)
	if not FileAccess.file_exists(path):
		return false
	var tex: Texture2D = load(path)
	return tex != null and tex.get_width() == 64 and tex.get_height() == 64


func _test_wrecks() -> int:
	print("[随机沉船]")
	var WreckGenC = load("res://scripts/wreck_gen.gd")
	# 模板结构不变量：甲板入舱口与两舷侧舱门均可通行（玩家胶囊 24×34）
	for kind in MapData.WRECK_TEMPLATES:
		var tpl: Dictionary = MapData.WRECK_TEMPLATES[kind]
		var rects: Array = tpl["rects"]
		var entrance: Array = tpl["entrance"]
		var gap: float = float(entrance[1]) - float(entrance[0])
		_check(gap >= 46.0, "%s 甲板入舱口宽 %dpx ≥ 46" % [kind, int(gap)])
		var cx: float = (float(entrance[0]) + float(entrance[1])) * 0.5
		var interior: Rect2 = tpl["interior"]
		var blocked := false
		for r in rects:
			var rect := Rect2(r[0], r[1], r[2], r[3])
			if cx > rect.position.x and cx < rect.end.x and rect.end.y <= interior.position.y + 1.0:
				blocked = true
		_check(not blocked, "%s 入舱口垂直可达舱内" % kind)
		# 侧舱门：两舷中线处的胶囊盒不被船体截断
		var min_x := 99999.0
		var max_x := -99999.0
		for r in rects:
			min_x = minf(min_x, r[0])
			max_x = maxf(max_x, r[0] + r[2])
		var door_fail := 0
		for wall_cx in [min_x + 9.0, max_x - 9.0]:
			var pass_box := Rect2(wall_cx - 14.0, -72.0, 28.0, 34.0)
			for r in rects:
				if pass_box.intersects(Rect2(r[0], r[1], r[2], r[3])):
					_check_quiet(false, "%s 侧舱门 x=%.0f 被船体 %s 截断" % [kind, wall_cx, r])
					door_fail += 1
		_check(door_fail == 0, "%s 两舷侧舱门可通行" % kind)
		var spot_fail := 0
		for spot in tpl["spots"]:
			for r in rects:
				if WreckGenC._circle_vs_rect(Vector2(spot.x, spot.y), 24.0,
						Rect2(r[0], r[1], r[2], r[3])):
					_check_quiet(false, "%s 容器点 %s 撞到船体 %s" % [kind, spot, r])
					spot_fail += 1
		_check(spot_fail == 0, "%s 舱内容器点不与船体重叠" % kind)

	# 全部变体锚点合法性：不压实体 / 通道胶囊盒贯通 / 不压宝箱点 / 不穿巡逻带
	var anchor_zone_count := 0
	var anchor_fail := 0
	for zone in ["B", "C"]:
		for vi in MapData.ZONE_VARIANTS[zone].size():
			var v: Dictionary = MapData.ZONE_VARIANTS[zone][vi]
			var solids: Array = MapData.SHARED_SOLIDS + v["solids"]
			for anchor_cfg in v.get("wreck_anchors", []):
				anchor_zone_count += 1
				for kind in anchor_cfg["kinds"]:
					var tpl: Dictionary = MapData.WRECK_TEMPLATES[kind]
					var anchor := Vector2(anchor_cfg["x"], MapData.WRECK_FLOOR_Y)
					var rects: Array = WreckGenC._world_rects(tpl, anchor)
					var tag: String = "%s%d(%s)@%.0f %s" % [zone, vi, v["name"], anchor_cfg["x"], kind]
					if not WreckGenC.placement_ok(rects, solids, v["chests"], v["patrols"],
							WreckGenC._offset_rect(tpl["interior"], anchor)):
						_check_quiet(false, "锚点非法：%s" % tag)
						anchor_fail += 1
				# 锚点自带容器点不与变体宝箱点重叠
				for kind in anchor_cfg["kinds"]:
					for s in MapData.WRECK_TEMPLATES[kind]["spots"]:
						for cs in v["chests"]:
							if anchor_cfg["x"] + s.x > cs.x - 70.0 and anchor_cfg["x"] + s.x < cs.x + 70.0 \
									and MapData.WRECK_FLOOR_Y + s.y > cs.y - 70.0 \
									and MapData.WRECK_FLOOR_Y + s.y < cs.y + 70.0:
								_check_quiet(false, "锚点容器点撞宝箱点：%s%d %s" % [zone, vi, kind])
								anchor_fail += 1
	_check(anchor_fail == 0, "%d 个变体锚点全部合法" % anchor_zone_count)
	_check(anchor_zone_count == 7, "共 7 个沉船锚点（B0×2/B1×2/B4×2/C2×1）")

	# 200 种子：确定性 + 类型分布
	var total := 0
	var kind_seen := {}
	var nondet := 0
	for seed_i in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var chosen := {}
		for zone in ["A", "B", "C"]:
			chosen[zone] = {"index": rng.randi_range(0, MapData.ZONE_VARIANTS[zone].size() - 1)}
		for zone in ["A", "B", "C"]:
			chosen[zone]["variant"] = MapData.ZONE_VARIANTS[zone][chosen[zone]["index"]]
		var wrecks: Array = WreckGenC.generate(rng, chosen)
		total += wrecks.size()
		for w in wrecks:
			kind_seen[w["kind"]] = true
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = seed_i
		var chosen2 := {}
		for zone in ["A", "B", "C"]:
			chosen2[zone] = {"index": rng2.randi_range(0, MapData.ZONE_VARIANTS[zone].size() - 1)}
		for zone in ["A", "B", "C"]:
			chosen2[zone]["variant"] = MapData.ZONE_VARIANTS[zone][chosen2[zone]["index"]]
		var wrecks2: Array = WreckGenC.generate(rng2, chosen2)
		if wrecks2.size() != wrecks.size():
			nondet += 1
		else:
			for wi in wrecks.size():
				if wrecks[wi]["anchor"] != wrecks2[wi]["anchor"] or wrecks[wi]["kind"] != wrecks2[wi]["kind"]:
					nondet += 1
	_check(nondet == 0, "同种子生成结果可复现")
	_check(kind_seen.size() == 3, "三种沉船类型都出现过（实际 %d 种）" % kind_seen.size())
	_check(total > 80, "200 局共生成 %d 艘沉船（激活率合理）" % total)
	return 0


func _test_caves() -> int:
	print("[随机洞穴]")
	var CaveGenC = load("res://scripts/cave_gen.gd")
	var WreckGenC = load("res://scripts/wreck_gen.gd")
	# 模板结构不变量：腔体非空；宝箱点在腔体内且不撞洞体；
	# 海床洞穴腔体直达地面（可走出）；悬洞洞体全部挂在挂面之下
	for kind in MapData.CAVE_TEMPLATES:
		var tpl: Dictionary = MapData.CAVE_TEMPLATES[kind]
		var interior: Rect2 = tpl["interior"]
		_check(interior.size.x > 0 and interior.size.y > 0, "%s 腔体非空" % kind)
		var spot_fail := 0
		for s in tpl["spots"]:
			if not interior.has_point(s):
				_check_quiet(false, "%s 宝箱点 %s 不在腔体内" % [kind, s])
				spot_fail += 1
			for r in tpl["rects"]:
				if WreckGenC._circle_vs_rect(s, 24.0, Rect2(r[0], r[1], r[2], r[3])):
					_check_quiet(false, "%s 宝箱点 %s 撞洞体 %s" % [kind, s, r])
					spot_fail += 1
		_check(spot_fail == 0, "%s 洞内宝箱点合法" % kind)
		if tpl["mode"] == "floor":
			_check(is_equal_approx(interior.end.y, 0.0), "%s 腔体直达海床（可进出）" % kind)
		else:
			var above := 0
			for r in tpl["rects"]:
				if r[1] < 0.0:
					above += 1
			_check(above == 0, "%s 洞体全部位于挂面之下" % kind)

	# 200 种子：生成 2~4 处并逐洞校验合法性（含与沉船的互避）
	var total := 0
	var kinds_seen := {}
	var invalid := 0
	var sparse := 0
	for seed_i in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var chosen := {}
		for zone in ["A", "B", "C"]:
			var idx := rng.randi_range(0, MapData.ZONE_VARIANTS[zone].size() - 1)
			chosen[zone] = {"index": idx, "variant": MapData.ZONE_VARIANTS[zone][idx]}
		var wrecks: Array = WreckGenC.generate(rng, chosen)
		var caves: Array = CaveGenC.generate(rng, chosen, _wreck_rect_list(wrecks))
		total += caves.size()
		if caves.size() < 2:
			sparse += 1
		if caves.is_empty():
			invalid += 1
		for ci in caves.size():
			var cave: Dictionary = caves[ci]
			kinds_seen[cave["kind"]] = true
			var others: Array = _wreck_rect_list(wrecks)
			for cj in caves.size():
				if cj != ci:
					others.append_array(caves[cj]["rects"])
			var tpl: Dictionary = MapData.CAVE_TEMPLATES[cave["kind"]]
			var zone: String = cave["zone"]
			var v: Dictionary = chosen[zone]["variant"]
			if not CaveGenC._placement_ok(cave["rects"], cave["anchor"], tpl,
					MapData.variant_solids(zone, chosen[zone]["index"]),
					v["chests"], v["patrols"], others):
				_check_quiet(false, "洞穴非法：种子%d %s@%s" % [seed_i, cave["kind"], cave["anchor"]])
				invalid += 1
	_check(invalid == 0, "200 种子洞穴全部合法且每局 ≥1 处（异常 %d）" % invalid)
	_check(sparse <= 10, "洞穴 ≥2 处的种子占绝大多数（不足 %d 局 ≤10）" % sparse)
	_check(total >= 500, "200 局共 %d 处洞穴（平均 ≥2.5）" % total)
	_check(kinds_seen.size() >= 4, "洞穴类型覆盖 ≥4 种（实际 %d 种）" % kinds_seen.size())
	return 0


func _wreck_rect_list(wrecks: Array) -> Array:
	var out: Array = []
	for w in wrecks:
		out.append_array(w["rects"])
	return out


func _test_world_generation() -> int:
	print("[整局生成校验：主题+沉船+洞穴+地形模块+Boss巢穴]")
	var DiveGenC = load("res://scripts/dive_generator.gd")
	var TerrainGenC = load("res://scripts/terrain_gen.gd")
	var extract: Rect2 = MapData.EXTRACT_RECT.grow(40.0)
	var themes := {}
	var bad := 0
	var nondet := 0
	var wreck_theme_ok := 0
	var cave_theme_ok := 0
	var wreck_theme_count := 0
	var cave_theme_count := 0
	var feature_count := 0
	for seed_i in 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		# 与场景 _roll_layout 一致的抽取顺序：主题 → 9次色调 → 生成管线
		var r := rng.randf()
		var theme := "abyss"
		if r <= float(MapData.DIVE_THEME_WEIGHTS["wreck"]):
			theme = "wreck"
		elif r <= float(MapData.DIVE_THEME_WEIGHTS["wreck"] + MapData.DIVE_THEME_WEIGHTS["cave"]):
			theme = "cave"
		themes[theme] = true
		for i in 9:
			rng.randf()
		var world: Dictionary = DiveGenC.generate_world(rng, theme)
		var chosen: Dictionary = world["chosen"]
		var wrecks: Array = world["wrecks"]
		var caves: Array = world["caves"]
		var features: Array = world["features"]
		feature_count += features.size()
		if theme == "wreck":
			wreck_theme_count += 1
			if not wrecks.is_empty():
				wreck_theme_ok += 1
		if theme == "cave":
			cave_theme_count += 1
			for c in caves:
				if c["kind"] in ["danger", "hang_danger"]:
					cave_theme_ok += 1
					break
		# 地形模块：独立复核全部合法性（与沉船/洞穴互避、通道、宝箱点、巡逻带、出生点/撤离区）
		var wreck_rects: Array = []
		for w in wrecks:
			wreck_rects.append_array(w["rects"])
		var cave_rects: Array = []
		for c in caves:
			cave_rects.append_array(c["rects"])
		for fi in features.size():
			var f: Dictionary = features[fi]
			var others: Array = []
			for fj in features.size():
				if fj != fi:
					others.append_array(features[fj]["rects"])
			if not TerrainGenC.placement_ok(f, chosen, wreck_rects, cave_rects, others):
				_check_quiet(false, "种子%d 地形模块非法 %s@%s" % [seed_i, f["kind"], f["anchor"]])
				bad += 1
			if extract.intersects(_footprint_rect(f["rects"])):
				_check_quiet(false, "种子%d 地形模块压到撤离区" % seed_i)
				bad += 1
		# Boss 触发区/巢穴中心必须是开阔水域（Boss 不出生在墙体里）
		for w in wrecks:
			var center: Vector2 = (w["interior"] as Rect2).get_center()
			if not MapData.circle_clear(center, 12.0,
					MapData.variant_solids(w["zone"], chosen[w["zone"]]["index"])):
				_check_quiet(false, "种子%d 沉船舱内中心撞到地形 %s" % [seed_i, center])
				bad += 1
		for c in caves:
			var ccenter: Vector2 = (c["interior"] as Rect2).get_center()
			if not MapData.circle_clear(ccenter, 12.0,
					MapData.variant_solids(c["zone"], chosen[c["zone"]]["index"])):
				_check_quiet(false, "种子%d 洞穴腔体中心撞到地形 %s" % [seed_i, ccenter])
				bad += 1
		# 同种子整局可复现
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = seed_i
		rng2.randf()
		for i in 9:
			rng2.randf()
		var world2: Dictionary = DiveGenC.generate_world(rng2, theme)
		if world2["wrecks"].size() != wrecks.size() or world2["caves"].size() != caves.size() 				or world2["features"].size() != features.size():
			nondet += 1
		else:
			for fi in features.size():
				if world2["features"][fi]["anchor"] != features[fi]["anchor"]:
					nondet += 1
			for wi in wrecks.size():
				if world2["wrecks"][wi]["anchor"] != wrecks[wi]["anchor"]:
					nondet += 1
	_check(bad == 0, "100 局：地形模块/巢穴/撤离区全部合法（异常 %d）" % bad)
	_check(nondet == 0, "同种子整局生成可复现（异常 %d）" % nondet)
	_check(themes.size() == 3, "三种海域主题都出现（实际 %d）" % themes.size())
	_check(wreck_theme_count == 0 or wreck_theme_ok == wreck_theme_count,
		"沉船主题必有沉船（%d/%d 局）" % [wreck_theme_ok, wreck_theme_count])
	_check(cave_theme_count == 0 or cave_theme_ok == cave_theme_count,
		"洞穴主题必有危险洞穴（%d/%d 局）" % [cave_theme_ok, cave_theme_count])
	_check(feature_count >= 400, "100 局共 %d 个地形模块（平均 ≥4）" % feature_count)
	return 0


func _footprint_rect(rects: Array) -> Rect2:
	var out: Rect2 = rects[0]
	for r in rects:
		out = out.merge(r)
	return out


func _test_loot_randomness() -> int:
	print("[掉落随机性]")
	var scene = load("res://scenes/underwater.tscn").instantiate()
	root.add_child(scene)
	var qualities := {}
	var type_seen := {}
	for i in 150:
		for entry in scene._roll_chest_loot("C"):
			qualities[entry["quality"]] = qualities.get(entry["quality"], 0) + 1
			type_seen[entry["id"]] = true
	scene.queue_free()
	_check(qualities.size() >= 3, "150 件 C 区掉落覆盖 ≥3 种品质（实际 %d）" % qualities.size())
	_check(qualities.get("pristine", 0) > 0, "出现完美品质")
	_check(qualities.get("standard", 0) > 0, "出现标准品质")
	_check(type_seen.size() >= 2, "掉落类型多样（实际 %d 种）" % type_seen.size())

	# 沉船掉落池：id/品质合法，船长室必出罗盘或六分仪
	var pool_bad := 0
	for pool_key in ItemDB.WRECK_LOOT:
		var cfg: Dictionary = ItemDB.WRECK_LOOT[pool_key]
		for id in cfg["pool"]:
			if not ItemDB.TREASURES.has(id):
				_check_quiet(false, "沉船池 %s 引用不存在的宝物 %s" % [pool_key, id])
				pool_bad += 1
		if cfg.has("bonus_pool"):
			for id in cfg["bonus_pool"]:
				if not ItemDB.TREASURES.has(id):
					_check_quiet(false, "沉船池 %s 加成引用不存在的宝物 %s" % [pool_key, id])
					pool_bad += 1
	_check(pool_bad == 0, "沉船掉落池引用合法")
	var captain_seen := {}
	for i in 60:
		for entry in scene._roll_wreck_loot("pirate_captain", Vector2.ZERO):
			captain_seen[entry["id"]] = true
	_check(captain_seen.has("captain_compass") and captain_seen.has("gold_sextant"),
		"船长室 60 次掉落覆盖罗盘与六分仪（实际 %d 种）" % captain_seen.size())
	return 0

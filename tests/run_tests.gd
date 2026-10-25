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
	return 0

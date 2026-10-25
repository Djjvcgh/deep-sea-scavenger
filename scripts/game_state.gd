extends Node
## 全局状态（autoload: GameState）。
## 永久进度：交易额度 / 岛上库存 / 材料 / 背包档位 / 升级 / 造船 / 遗落物缓存。
## 单次下潜临时数据：dive_bag（不写入存档，撤离成功才转入永久库存）。
## 物品条目统一为 {"id": String, "quality": String}；材料条目为材料数量。
## 只负责数据与规则，不直接操作 UI；UI 通过信号刷新。

signal credits_changed(value: int)
signal island_stock_changed
signal materials_changed
signal upgrades_changed
signal bag_tier_changed
signal boat_changed
signal dive_bag_changed
signal boat_completed_signal

const ItemDBRes := preload("res://scripts/item_db.gd")

# ---- 永久进度 ----
var credits := 0
var island_stock: Array = []            # 岛上待出售宝物 [{"id","quality"}]
var materials := {"wood": 0, "iron": 0, "canvas": 0, "leather": 0}
var upgrades := {"fins": false, "amulet": false}
var bag_tier := 0                        # 背包档位（ItemDB.BAG_TIERS 下标）
var boat_invested := {"wood": 0, "iron": 0, "canvas": 0}
var boat_completed := false
var lost_cache := {}                     # 死亡掉落 {"x","y","items":[{id,quality}]}
var cache_found_seen := false            # 本次下潜是否提示过遗落物

# ---- 单次下潜临时数据 ----
var dive_bag: Array = []                 # 本次潜水携带 [{"id","quality"}]
var dive_start_msec := 0


func reset_defaults() -> void:
	credits = 0
	island_stock = []
	materials = {"wood": 0, "iron": 0, "canvas": 0, "leather": 0}
	upgrades = {"fins": false, "amulet": false}
	bag_tier = 0
	boat_invested = {"wood": 0, "iron": 0, "canvas": 0}
	boat_completed = false
	lost_cache = {}
	cache_found_seen = false
	dive_bag = []


# ---------------- 存档 ----------------

func serialize() -> Dictionary:
	return {
		"version": 2,
		"credits": credits,
		"island_stock": island_stock.duplicate(true),
		"materials": materials.duplicate(),
		"upgrades": upgrades.duplicate(),
		"bag_tier": bag_tier,
		"boat_invested": boat_invested.duplicate(),
		"boat_completed": boat_completed,
		"lost_cache": lost_cache.duplicate(true),
	}


func apply_save(data: Dictionary) -> void:
	# 对缺失、损坏、类型不符的字段做安全处理；v1 存档（纯字符串物品、bag升级）自动迁移。
	reset_defaults()
	credits = maxi(0, int(data.get("credits", 0)))

	var ver := int(data.get("version", 1))
	var stock = data.get("island_stock", [])
	if stock is Array:
		for entry in stock:
			var converted := _convert_entry(entry)
			if not converted.is_empty():
				island_stock.append(converted)

	_apply_dict(data.get("materials", {}), materials, false)
	_apply_dict(data.get("boat_invested", {}), boat_invested, false)
	var up = data.get("upgrades", {})
	if up is Dictionary:
		for k in upgrades.keys():
			upgrades[k] = bool(up.get(k, false))
		# v1：扩容背包升级 → 背包档位 2（12格）
		if ver < 2 and bool(up.get("bag", false)):
			bag_tier = 2
	if data.has("bag_tier"):
		bag_tier = clampi(int(data.get("bag_tier", 0)), 0, ItemDBRes.BAG_TIERS.size() - 1)
	boat_completed = bool(data.get("boat_completed", false))

	var cache = data.get("lost_cache", {})
	if cache is Dictionary and cache.has("items") and cache["items"] is Array:
		var items: Array = []
		for entry in cache["items"]:
			var converted := _convert_entry(entry)
			if not converted.is_empty():
				items.append(converted)
		if not items.is_empty():
			lost_cache = {
				"x": float(cache.get("x", 0.0)), "y": float(cache.get("y", 0.0)),
				"items": items,
			}


## 物品条目兼容：v1 字符串 → v2 字典；非法 id 返回空字典
func _convert_entry(entry: Variant) -> Dictionary:
	if entry is String and ItemDBRes.TREASURES.has(entry):
		return {"id": entry, "quality": "standard"}
	if entry is Dictionary and ItemDBRes.TREASURES.has(str(entry.get("id", ""))):
		var q := str(entry.get("quality", "standard"))
		if not ItemDBRes.QUALITIES.has(q):
			q = "standard"
		return {"id": str(entry["id"]), "quality": q}
	return {}


func _apply_dict(src: Variant, dst: Dictionary, as_bool: bool) -> void:
	if src is Dictionary:
		for k in dst.keys():
			if src.has(k):
				dst[k] = maxi(0, int(src[k])) if not as_bool else bool(src[k])


# ---------------- 装备与派生数值 ----------------

func max_stamina() -> float:
	return 125.0 if upgrades["amulet"] else 100.0


func bag_capacity() -> int:
	return int(ItemDBRes.BAG_TIERS[bag_tier]["capacity"])


func speed_mult() -> float:
	return 1.2 if upgrades["fins"] else 1.0


## 实例估值 = 基础价值 × 品质倍率
func value_of(entry: Dictionary) -> int:
	var base := int(ItemDBRes.TREASURES[entry["id"]]["value"])
	var mult := float(ItemDBRes.QUALITIES[entry["quality"]]["mult"])
	return int(round(base * mult))


func bag_used_slots() -> int:
	var used := 0
	for entry in dive_bag:
		used += int(ItemDBRes.TREASURES[entry["id"]]["slots"])
	return used


func bag_free_slots() -> int:
	return bag_capacity() - bag_used_slots()


func can_carry(slots: int) -> bool:
	return bag_used_slots() + slots <= bag_capacity()


func weight_speed_mult() -> float:
	return 0.9 if bag_used_slots() >= 6 else 1.0


func weight_drain_mult() -> float:
	return 1.2 if bag_used_slots() >= 6 else 1.0


func has_curse_idol() -> bool:
	for entry in dive_bag:
		if entry["id"] == "cursed_idol":
			return true
	return false


func dive_total_value() -> int:
	var total := 0
	for entry in dive_bag:
		total += value_of(entry)
	return total


## 按 id+品质 分组（商人/结算展示用）：{key: {"id","quality","count","value"}}
func group_entries(entries: Array) -> Dictionary:
	var groups := {}
	for entry in entries:
		var key := "%s|%s" % [entry["id"], entry["quality"]]
		if not groups.has(key):
			groups[key] = {"id": entry["id"], "quality": entry["quality"],
				"count": 0, "value": value_of(entry)}
		groups[key]["count"] += 1
	return groups


# ---------------- 下潜临时背包 ----------------

func add_dive_item(id: String, quality := "standard") -> bool:
	if not ItemDBRes.TREASURES.has(id) or not ItemDBRes.QUALITIES.has(quality):
		return false
	if not can_carry(int(ItemDBRes.TREASURES[id]["slots"])):
		return false
	dive_bag.append({"id": id, "quality": quality})
	dive_bag_changed.emit()
	return true


func remove_dive_item_at(index: int) -> bool:
	if index < 0 or index >= dive_bag.size():
		return false
	dive_bag.remove_at(index)
	dive_bag_changed.emit()
	return true


func start_dive() -> void:
	dive_bag = []
	cache_found_seen = false
	dive_start_msec = Time.get_ticks_msec()
	dive_bag_changed.emit()


## 结束下潜：成功 → 宝物入库；失败 → dive_bag 与旧遗落物合并到掉落点（可找回）。
func end_dive(success: bool, drop_pos := Vector2.INF) -> void:
	if success:
		island_stock.append_array(dive_bag)
		island_stock_changed.emit()
	elif not dive_bag.is_empty():
		var items: Array = lost_cache.get("items", []) + dive_bag
		var pos := drop_pos if drop_pos != Vector2.INF else Vector2(lost_cache.get("x", 200.0), lost_cache.get("y", 500.0))
		lost_cache = {"x": pos.x, "y": pos.y, "items": items}
	dive_bag = []
	dive_bag_changed.emit()


## 从遗落物缓存中移取一件（拾取面板用），返回条目；缓存清空时重置位置。
func take_from_cache(index: int) -> Dictionary:
	var items: Array = lost_cache.get("items", [])
	if index < 0 or index >= items.size():
		return {}
	var entry: Dictionary = items[index]
	items.remove_at(index)
	if items.is_empty():
		lost_cache = {}
	else:
		lost_cache["items"] = items
	return entry


## 拾取面板关闭时把未取走的条目放回缓存。
func restore_to_cache(entries: Array) -> void:
	if entries.is_empty():
		return
	if lost_cache.is_empty() or not lost_cache.has("items"):
		push_warning("遗落物缓存不存在，无法放回 %d 件物品" % entries.size())
		return
	lost_cache["items"] = lost_cache.get("items", []) + entries


# ---------------- 经济行为 ----------------

func buy_upgrade(id: String) -> bool:
	if not ItemDBRes.UPGRADES.has(id) or upgrades[id]:
		return false
	var cost := int(ItemDBRes.UPGRADES[id]["cost"])
	if credits < cost:
		return false
	credits -= cost
	upgrades[id] = true
	credits_changed.emit(credits)
	upgrades_changed.emit()
	return true


## 打造下一档背包；成功返回 true。
func craft_bag() -> bool:
	var next := bag_tier + 1
	if next >= ItemDBRes.BAG_TIERS.size():
		return false
	var cost: Dictionary = ItemDBRes.BAG_TIERS[next]["cost"]
	for mat in cost:
		if materials[mat] < int(cost[mat]):
			return false
	for mat in cost:
		materials[mat] -= int(cost[mat])
	bag_tier = next
	materials_changed.emit()
	bag_tier_changed.emit()
	return true


## 按下标出售一件岛上库存
func sell_one(index: int) -> bool:
	if index < 0 or index >= island_stock.size():
		return false
	var entry: Dictionary = island_stock[index]
	credits += value_of(entry)
	island_stock.remove_at(index)
	island_stock_changed.emit()
	credits_changed.emit(credits)
	return true


## 出售某 id 的全部品质库存，返回所得额度
func sell_all_of(id: String) -> int:
	var total := 0
	var kept: Array = []
	for entry in island_stock:
		if entry["id"] == id:
			total += value_of(entry)
		else:
			kept.append(entry)
	if total > 0:
		island_stock = kept
		credits += total
		island_stock_changed.emit()
		credits_changed.emit(credits)
	return total


func buy_material(id: String) -> bool:
	if not ItemDBRes.MATERIALS.has(id):
		return false
	var price := int(ItemDBRes.MATERIALS[id]["price"])
	if credits < price:
		return false
	credits -= price
	materials[id] += 1
	credits_changed.emit(credits)
	materials_changed.emit()
	return true


## 材料回售（物物交换，按比例折损）
func sell_material(id: String) -> bool:
	if not ItemDBRes.MATERIALS.has(id) or materials[id] <= 0:
		return false
	var gain := int(floor(int(ItemDBRes.MATERIALS[id]["price"]) * ItemDBRes.MATERIAL_SELL_RATE))
	materials[id] -= 1
	credits += gain
	materials_changed.emit()
	credits_changed.emit(credits)
	return true


func sell_material_gain(id: String) -> int:
	return int(floor(int(ItemDBRes.MATERIALS[id]["price"]) * ItemDBRes.MATERIAL_SELL_RATE))


func invest_material(id: String, amount: int) -> int:
	if boat_completed or not ItemDBRes.MATERIALS.has(id) or amount <= 0:
		return 0
	var missing: int = int(ItemDBRes.BOAT_REQUIREMENT[id]) - int(boat_invested[id])
	var moved := mini(mini(amount, materials[id]), maxi(0, missing))
	if moved <= 0:
		return 0
	materials[id] -= moved
	boat_invested[id] += moved
	materials_changed.emit()
	boat_changed.emit()
	if _boat_done():
		boat_completed = true
		boat_completed_signal.emit()
		boat_changed.emit()
	return moved


func _boat_done() -> bool:
	for id in ItemDBRes.BOAT_REQUIREMENT:
		if boat_invested[id] < int(ItemDBRes.BOAT_REQUIREMENT[id]):
			return false
	return true


func boat_progress() -> float:
	var need := 0
	var got := 0
	for id in ItemDBRes.BOAT_REQUIREMENT:
		need += int(ItemDBRes.BOAT_REQUIREMENT[id])
		got += mini(int(boat_invested[id]), int(ItemDBRes.BOAT_REQUIREMENT[id]))
	return float(got) / float(need) if need > 0 else 0.0

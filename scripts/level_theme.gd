class_name LevelTheme
## 正式关卡美术模块系统（V0.5-4）。
## 把黑潮号测试关卡验证过的视觉方向提炼为可复用模块：
##   · 区域主题：A=浅海 / B=沉船 / C=洞穴·深层
##   · 房间类型 → 美术主题映射（decorate_room）
##   · 碰撞矩形铺装（paint_solid）：逻辑块不再以纯色形式可见
## 规范见 docs/art_direction/formal_level_art_bible.md。
## 所有函数为静态；parent 为场景根（Node2D）。

const SCN := "res://assets/scenery/blacktide/"
const KEN := "res://assets/sprites/kenney_fish/"

# ---- 调色板（palette_v05，见 v05_visual_direction.md） ----
const C_WOOD := Color("6B4A2A")
const C_SILT := Color("3E5568")
const C_GOLD := Color("F2C53D")
const C_TEAL := Color("66F0D9")
const C_RED := Color("C43B30")

## 区域 → 美术主题（浅海 / 沉船 / 洞穴·深层）。
static func zone_theme(zone: String) -> String:
	match zone:
		"A":
			return "shallow"
		"B":
			return "wreck"
	return "deep"


## 房间/实体类型 → 美术主题（任务六映射表，真实用于生成流程）。
## kind 取值：wreck_gen 的 merchant/pirate/ritual；cave_gen 的 shelter/treasure/danger
## （含 hang_ 前缀）；地形实体 sand/rock/cave/wreck/dirt；空字符串 = 开阔区。
static func room_theme(kind: String, zone := "A", rect := Rect2()) -> String:
	if kind.begins_with("hang_"):
		kind = kind.substr(5)
	match kind:
		"merchant":
			return "wreck_storage"
		"pirate":
			return "captain_room" if rect.size.x < 260.0 else "wreck_storage"
		"ritual":
			return "ritual_shrine"
		"shelter":
			return "cave_hideout"
		"treasure":
			return "cave_treasure"
		"danger":
			return "cave_danger"
		"":
			return zone_theme(zone)
		_:
			# 未列出的实体类型按区域主题兜底
			return zone_theme(zone)


# ---------------- 基础绘制 ----------------

static func sprite(parent: Node2D, name: String, pos: Vector2, z: int,
		scale := 2.0, tint := Color.WHITE, rot := 0.0,
		flip_v := false, folder := SCN) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(folder + name + ".png")
	s.position = pos
	s.scale = Vector2(scale, -scale if flip_v else scale)
	s.rotation = rot
	s.z_index = z
	s.modulate = tint
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	return s


## 以固定尺寸贴图平铺覆盖矩形（带规律破损变体，避免无意义重复平铺）。
static func tile(parent: Node2D, name: String, alt_name: String, rect: Rect2,
		tint: Color, z := 0, seed := 0) -> void:
	var tex: Texture2D = load(SCN + name + ".png")
	var tw := float(tex.get_width()) * 2.0
	var th := float(tex.get_height()) * 2.0
	var iy := 0
	var y := rect.position.y
	while y < rect.end.y:
		var ix := 0
		var x := rect.position.x
		while x < rect.end.x:
			var damaged := alt_name != "" and (ix * 7 + iy * 3 + seed) % 6 == 0
			sprite(parent, alt_name if damaged else name,
				Vector2(x + tw * 0.5, y + th * 0.5), z, 2.0, tint)
			x += tw
			ix += 1
		y += th
		iy += 1


static func glow(parent: Node2D, pos: Vector2, rx: float, ry: float,
		color: Color, z := 1) -> Polygon2D:
	var g := Polygon2D.new()
	g.polygon = ellipse(rx, ry, 16)
	g.position = pos
	g.color = color
	g.z_index = z
	parent.add_child(g)
	return g


static func ellipse(rx: float, ry: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func hash01(a: int, b := 0) -> float:
	return fposmod(sin(float(a * 127 + b * 311)) * 43758.5453, 1.0)


static func motes(parent: Node2D, pos: Vector2, extents: Vector2,
		amount: int, color: Color) -> void:
	var m := CPUParticles2D.new()
	m.position = pos
	m.z_index = 3
	m.emitting = true
	m.amount = amount
	m.lifetime = 6.0
	m.preprocess = 4.0
	m.texture = load(SCN + "mote.png")
	m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	m.scale_amount_min = 0.35
	m.scale_amount_max = 0.8
	m.color = color
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.emission_rect_extents = extents
	m.direction = Vector2(0.12, -1)
	m.spread = 14
	m.initial_velocity_min = 2.0
	m.initial_velocity_max = 5.0
	m.gravity = Vector2(0, -1.2)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.0), color,
		Color(color.r, color.g, color.b, color.a * 0.7), Color(color.r, color.g, color.b, 0.0)])
	m.color_ramp = ramp
	parent.add_child(m)


# ---------------- 碰撞矩形铺装（kind → 外观） ----------------

## tints 可传海况色：{"sand": Color, "rock": Color}
static func paint_solid(parent: Node2D, rect: Rect2, kind: String,
		tints := {}, seed := 0) -> void:
	match kind:
		"sand":
			var tint: Color = tints.get("sand", Color.WHITE)
			var row := 0
			var y := rect.position.y
			while y < rect.end.y:
				var dim := 1.0 - 0.08 * row
				var x := rect.position.x
				while x < rect.end.x:
					sprite(parent, "sand_tile", Vector2(x + 96.0, y + 22.0), 0, 2.0,
						Color(tint.r * dim, tint.g * dim, tint.b * minf(1.0, dim + 0.02)))
					x += 192.0
				y += 44.0
				row += 1
		"cave":
			tile(parent, "cave_wall", "", rect, Color(0.92, 0.96, 1.0), 0, seed)
		"wreck":
			tile(parent, "hull_wall_a", "hull_wall_b", rect,
				Color(0.86, 0.82, 0.78) * (tints.get("rock", Color.WHITE) as Color), 0, seed)
		"rock", "dirt", _:
			# 岩体：深缝底色 + 巨石网格（含异化变体概率）
			var fill := Polygon2D.new()
			fill.polygon = PackedVector2Array([
				rect.position, rect.position + Vector2(rect.size.x, 0),
				rect.end, rect.position + Vector2(0, rect.size.y)])
			fill.color = Color("101B26") * (tints.get("rock", Color.WHITE) as Color)
			fill.z_index = 0
			parent.add_child(fill)
			var corrupt: bool = tints.get("corrupt", false)
			var tint: Color = tints.get("rock", Color.WHITE)
			var cy := rect.position.y
			var jy := 0
			while cy < rect.end.y:
				var cx := rect.position.x
				var jx := 0
				while cx < rect.end.x:
					var h1 := hash01(seed, jx * 31 + jy)
					var h2 := hash01(seed + 7, jx + jy * 17)
					var name := "rock_b" if h2 < 0.45 else "rock_a"
					if corrupt and h1 > 0.72:
						name = "corrupt_rock"
					var s := sprite(parent, name,
						Vector2(cx + 74.0 + (h1 - 0.5) * 34.0, cy + 52.0 + (h2 - 0.5) * 22.0),
						0, 2.0 + h1 * 0.7, tint)
					s.flip_h = h1 > 0.5
					cx += 150.0
					jx += 1
				cy += 108.0
				jy += 1


# ---------------- 房间装饰（room_theme → 模块组合） ----------------

## rect 为房间内部矩形；rng 为关卡种子随机源（同种子同图）。
static func decorate_room(parent: Node2D, theme: String, rect: Rect2,
		rng: RandomNumberGenerator) -> void:
	match theme:
		"wreck_storage":
			_wreck_storage(parent, rect, rng)
		"captain_room":
			_captain_room(parent, rect, rng)
		"ritual_shrine":
			_ritual_shrine(parent, rect, rng)
		"cave_hideout":
			_cave_room(parent, rect, rng, Color(0.5, 0.9, 0.8, 0.5), 4)
		"cave_treasure":
			_cave_room(parent, rect, rng, Color(0.4, 0.95, 0.85, 0.6), 6)
		"cave_danger":
			_cave_room(parent, rect, rng, Color(0.85, 0.35, 0.5, 0.5), 3)
		"shallow":
			_shallow_open(parent, rect, rng)
		"deep":
			_deep_hazard(parent, rect, rng)
		"wreck":
			# 沉船区域的开阔段：散布残骸件
			_scatter(parent, rect, rng, ["wreck_debris", "barrel", "rope_coil"], 2, 2)


## 沉船货舱：背板 + 船肋 + 货件 + 灯。
static func _wreck_storage(parent: Node2D, rect: Rect2, rng: RandomNumberGenerator) -> void:
	tile(parent, "hull_wall_a", "hull_wall_b", rect, Color(0.5, 0.53, 0.58), 0, int(rect.position.x))
	var rib_n := maxi(2, int(rect.size.x / 220.0))
	for i in rib_n:
		var x := rect.position.x + 60.0 + i * (rect.size.x - 120.0) / maxf(1.0, rib_n - 1.0)
		sprite(parent, "hull_rib", Vector2(x, rect.get_center().y), 1, 2.0,
			Color.WHITE, (hash01(i, 3) - 0.5) * 0.1)
	var floor_y := rect.end.y
	for i in 3:
		var x := rect.position.x + 40.0 + hash01(i, 11) * (rect.size.x - 80.0)
		match i % 3:
			0:
				sprite(parent, "barrel", Vector2(x, floor_y - 30.0), 2)
			1:
				sprite(parent, "crate", Vector2(x, floor_y - 24.0), 2, 1.9,
					Color(0.98, 0.94, 0.88), (hash01(i, 5) - 0.5) * 0.2)
			2:
				sprite(parent, "rope_coil", Vector2(x, floor_y - 14.0), 2)
	sprite(parent, "lantern", Vector2(rect.position.x + 36.0, rect.position.y + 22.0), 2)
	glow(parent, Vector2(rect.position.x + 36.0, rect.position.y + 30.0), 40.0, 22.0,
		Color(1.0, 0.72, 0.3, 0.15), 1)
	motes(parent, rect.get_center(), rect.size * 0.4, 14, Color(0.72, 0.85, 0.84, 0.32))


## 船长室：书桌 + 神龛 + 金光焦点。
static func _captain_room(parent: Node2D, rect: Rect2, rng: RandomNumberGenerator) -> void:
	tile(parent, "hull_wall_a", "", rect, Color(0.5, 0.53, 0.58), 0, int(rect.position.x))
	sprite(parent, "hull_rib", Vector2(rect.position.x + 24.0, rect.get_center().y), 1)
	sprite(parent, "hull_rib", Vector2(rect.end.x - 24.0, rect.get_center().y), 1, 2.0, Color.WHITE, 0.05)
	sprite(parent, "desk", Vector2(rect.position.x + 46.0, rect.end.y - 34.0), 2)
	sprite(parent, "shrine", Vector2(rect.end.x - 34.0, rect.end.y - 38.0), 2)
	glow(parent, Vector2(rect.end.x - 34.0, rect.end.y - 46.0), 18.0, 12.0,
		Color(0.4, 0.95, 0.85, 0.16), 1)
	sprite(parent, "gold_pile", Vector2(rect.get_center().x + 20.0, rect.end.y - 12.0), 2, 1.4)
	sprite(parent, "lantern", Vector2(rect.get_center().x, rect.position.y + 20.0), 2)
	glow(parent, Vector2(rect.get_center().x, rect.position.y + 28.0), 44.0, 24.0,
		Color(1.0, 0.72, 0.3, 0.16), 1)
	motes(parent, rect.get_center(), rect.size * 0.4, 12, Color(0.78, 0.88, 0.86, 0.32))


## 祭祀舱：神龛 + 青绿烛光 + 遗骨。
static func _ritual_shrine(parent: Node2D, rect: Rect2, rng: RandomNumberGenerator) -> void:
	tile(parent, "hull_wall_a", "", rect, Color(0.44, 0.47, 0.52), 0, int(rect.position.x))
	var cx := rect.get_center().x
	sprite(parent, "shrine", Vector2(cx, rect.end.y - 38.0), 2, 2.4)
	glow(parent, Vector2(cx, rect.end.y - 52.0), 26.0, 16.0, Color(0.4, 0.95, 0.85, 0.18), 1)
	sprite(parent, "fishbone", Vector2(rect.position.x + 34.0, rect.end.y - 10.0), 2)
	sprite(parent, "fishbone", Vector2(rect.end.x - 40.0, rect.end.y - 8.0), 2, 1.4)
	motes(parent, rect.get_center(), rect.size * 0.4, 12, Color(0.5, 0.9, 0.84, 0.3))


## 洞穴：岩壁感 + 发光藻（数量/亮度按子类型）+ 黑海草（危险型）。
static func _cave_room(parent: Node2D, rect: Rect2, rng: RandomNumberGenerator,
		glow_color: Color, algae_n: int) -> void:
	var dark := Polygon2D.new()
	dark.polygon = PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.end, rect.position + Vector2(0, rect.size.y)])
	dark.color = Color(0.02, 0.04, 0.06, 0.35)
	dark.z_index = 1
	parent.add_child(dark)
	for i in algae_n:
		var x := rect.position.x + 18.0 + hash01(i, 21) * (rect.size.x - 36.0)
		var top: bool = hash01(i, 22) > 0.5
		sprite(parent, "glow_algae",
			Vector2(x, rect.position.y + 10.0 if top else rect.end.y - 12.0), 2, 2.0,
			Color.WHITE, 0.0, top)
		glow(parent, Vector2(x, rect.position.y + 8.0 if top else rect.end.y - 20.0),
			14.0, 10.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.12), 1)
	if glow_color.r > 0.7:
		# 危险洞穴：黑海草 + 遗骨
		sprite(parent, "seaweed_black", Vector2(rect.position.x + 20.0, rect.end.y - 14.0), 2)
		sprite(parent, "fishbone", Vector2(rect.end.x - 30.0, rect.end.y - 8.0), 2, 1.6)
	motes(parent, rect.get_center(), rect.size * 0.4, 8,
		Color(glow_color.r, glow_color.g, glow_color.b, 0.26))


## 浅海开阔区：珊瑚 + Kenney 海草 + 小残骸。
static func _shallow_open(parent: Node2D, rect: Rect2, rng: RandomNumberGenerator) -> void:
	var flora := ["seaweed_green_a", "seaweed_green_c", "seaweed_pink_a",
		"seaweed_orange_b", "seaweed_grass_a"]
	for i in 5:
		var x := rect.position.x + 30.0 + hash01(i, 31) * (rect.size.x - 60.0)
		var name: String = flora[rng.randi_range(0, flora.size() - 1)]
		sprite(parent, name, Vector2(x, rect.end.y - 26.0), -8, 1.4, Color(0.95, 0.97, 1.0),
			0.0, false, KEN)
	for i in 2:
		var x := rect.position.x + 60.0 + hash01(i, 41) * (rect.size.x - 120.0)
		sprite(parent, "coral_a" if i % 2 == 0 else "coral_b", Vector2(x, rect.end.y - 24.0), 1, 2.0)
	if hash01(int(rect.position.x), 51) > 0.5:
		sprite(parent, "wreck_debris",
			Vector2(rect.get_center().x, rect.end.y - 16.0), 1, 2.0)


## 深层危险区：异化岩 + 黑海草 + 祭坛 + 紫晕。
static func _deep_hazard(parent: Node2D, rect: Rect2, rng: RandomNumberGenerator) -> void:
	for i in 2:
		var x := rect.position.x + 50.0 + hash01(i, 61) * (rect.size.x - 100.0)
		sprite(parent, "corrupt_rock", Vector2(x, rect.end.y - 26.0), 1, 2.0 + hash01(i, 62))
		glow(parent, Vector2(x, rect.end.y - 40.0), 18.0, 12.0,
			Color(0.7, 0.36, 0.84, 0.1), 1)
	for i in 3:
		var x := rect.position.x + 30.0 + hash01(i, 63) * (rect.size.x - 60.0)
		sprite(parent, "seaweed_black", Vector2(x, rect.end.y - 14.0), 1)
	if rect.size.x > 380.0:
		var ax := rect.get_center().x
		sprite(parent, "altar", Vector2(ax, rect.end.y - 20.0), 2, 2.0)
		glow(parent, Vector2(ax, rect.end.y - 34.0), 22.0, 14.0,
			Color(0.85, 0.3, 0.4, 0.12), 1)
	motes(parent, rect.get_center(), rect.size * 0.4, 10, Color(0.6, 0.45, 0.8, 0.24))


## 通用散布（name 池 + 数量），落地在矩形底边。
static func _scatter(parent: Node2D, rect: Rect2, rng: RandomNumberGenerator,
		names: Array, count: int, seed := 0) -> void:
	for i in count:
		var x := rect.position.x + 30.0 + hash01(i, seed + 71) * (rect.size.x - 60.0)
		var name: String = names[rng.randi_range(0, names.size() - 1)]
		sprite(parent, name, Vector2(x, rect.end.y - 18.0), 1)


# ---------------- 岛上基地模块 ----------------

## 栈桥（下潜点）：甲板条 + 桩柱 + 浮标 + 缆绳。
static func island_pier(parent: Node2D, x0: float, x1: float, deck_y: float) -> void:
	var x := x0
	while x < x1:
		sprite(parent, "deck_plank", Vector2(x + 96.0, deck_y + 20.0), 1, 2.0,
			Color(1.02, 0.97, 0.9))
		x += 192.0
	var post_n := maxi(2, int((x1 - x0) / 130.0))
	for i in post_n:
		sprite(parent, "pier_post", Vector2(x0 + 40.0 + i * (x1 - x0 - 80.0) / maxf(1.0, post_n - 1.0),
			deck_y + 52.0), 1)


## 商人区：摊位 + 货箱 + 灯。
static func island_merchant(parent: Node2D, pos: Vector2) -> void:
	sprite(parent, "tent_stall", pos + Vector2(0, -30.0), 2)
	sprite(parent, "crate", pos + Vector2(-58.0, -22.0), 1, 1.8)
	sprite(parent, "barrel", pos + Vector2(58.0, -24.0), 1)
	glow(parent, pos + Vector2(0, -26.0), 40.0, 22.0, Color(1.0, 0.82, 0.5, 0.13), 2)


## 工作区：工作台 + 柴堆 + 货箱 + 炉火光。
static func island_workshop(parent: Node2D, pos: Vector2) -> void:
	sprite(parent, "workbench", pos + Vector2(0, -22.0), 2)
	sprite(parent, "wood_pile", pos + Vector2(-64.0, -12.0), 1)
	sprite(parent, "crate", pos + Vector2(64.0, -22.0), 1, 1.8)
	glow(parent, pos + Vector2(20.0, -30.0), 26.0, 14.0, Color(1.0, 0.6, 0.3, 0.14), 2)


## 船坞：滑道 + 桩柱 + 桶绳。
static func island_dock(parent: Node2D, pos: Vector2) -> void:
	sprite(parent, "pier_post", pos + Vector2(-74.0, 10.0), 1)
	sprite(parent, "pier_post", pos + Vector2(74.0, 10.0), 1)
	sprite(parent, "barrel", pos + Vector2(-52.0, -24.0), 1)
	sprite(parent, "rope_coil", pos + Vector2(56.0, -14.0), 1)
	sprite(parent, "wood_pile", pos + Vector2(-90.0, -12.0), 1, 1.4)


## 营火：石圈柴堆 + 暖光（flame 为返回的火苗节点，场景自行脉冲）。
static func island_campfire(parent: Node2D, pos: Vector2) -> Polygon2D:
	sprite(parent, "campfire", pos, 1)
	var flame := Polygon2D.new()
	flame.polygon = PackedVector2Array([
		Vector2(0, -14), Vector2(5, -6), Vector2(0, -1), Vector2(-5, -6)])
	flame.position = pos + Vector2(0, -8)
	flame.color = Color(1.0, 0.72, 0.25, 0.9)
	flame.z_index = 2
	parent.add_child(flame)
	glow(parent, pos + Vector2(0, -8), 34.0, 20.0, Color(1.0, 0.62, 0.25, 0.16), 2)
	return flame

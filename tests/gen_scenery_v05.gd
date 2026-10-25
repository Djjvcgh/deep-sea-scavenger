extends SceneTree
## V0.5 场景像素贴图生成器（原创程序绘制，无第三方素材）。
## godot --headless -s res://tests/gen_scenery_v05.gd
## 输出（可重复运行，幂等覆盖）：
##   res://assets/scenery/blacktide/*.png  半分辨率贴图，场景内 ×2 + NEAREST 渲染
##   res://assets/icons/hud/*.png          HUD 小图标 12×12，1:1 使用
##   docs/references/style/palette_v05.png 色板样张（自制，见 v05_visual_direction.md）
## 规格、配色依据：docs/art_direction/v05_visual_direction.md

const OUT := "res://assets/scenery/blacktide"
const OUT_HUD := "res://assets/icons/hud"
const OUT_PAL := "res://docs/references/style/palette_v05.png"

# ---- 调色板（palette_v05） ----
const WOOD := Color("6B4A2A")
const WOOD_D := Color("4A3320")
const WOOD_DD := Color("3A2717")
const WOOD_L := Color("8A6538")
const WOOD_LL := Color("A5763F")
const SILT := Color("3E5568")
const SILT_D := Color("2A3B4A")
const SILT_L := Color("5A7186")
const GOLD := Color("F2C53D")
const GOLD_D := Color("C99420")
const GOLD_L := Color("FFE08A")
const TEAL := Color("66F0D9")
const TEAL_D := Color("3FBFAE")
const WATER := Color("2E7A8A")
const WATER_D := Color("123641")
const RED := Color("C43B30")
const RED_L := Color("E05A4E")
const METAL := Color("3A3F46")
const METAL_L := Color("6A7280")
const DARK := Color("1B1410")
const NIGHT := Color("10161E")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(OUT_HUD)
	DirAccess.make_dir_recursive_absolute("res://docs/references/style")
	_hull_wall(false, "hull_wall_a")
	_hull_wall(true, "hull_wall_b")
	_rib()
	_beam()
	_barrel(false, "barrel")
	_barrel(true, "barrel_open")
	_crate()
	_rope_coil()
	_rope_hang()
	_seaweed()
	_sediment(44, 12, "sediment_a")
	_sediment(36, 9, "sediment_b")
	_porthole()
	_lantern()
	_desk()
	_shrine()
	_winch()
	_chest(false, "chest_closed")
	_chest(true, "chest_open")
	_shelf()
	_mote()
	_hud_heart()
	_hud_bolt()
	_hud_bag()
	_hud_coin()
	_hud_timer()
	_hud_warn()
	_palette()
	# ---- 纠偏阶段：全船结构件 / 环境件 / UI 木纹面板 ----
	_deck_plank()
	_hull_bow()
	_hull_stern()
	_mast()
	_spar()
	_railing()
	_hatch_coaming()
	_door_frame()
	_boiler()
	_pipe()
	_hatch_grate()
	_debris_pile()
	_rock(76, 56, "rock_a")
	_rock(56, 42, "rock_b")
	_sand_tile()
	_buoy()
	_gold_pile()
	_fishbone()
	_net()
	_wood_panel()
	_far_rock()
	# ---- 正式关卡模块：岛屿 / 浅海 / 洞穴 / 深层 ----
	_palm()
	_grass_tuft()
	_grass_edge()
	_tent_stall()
	_workbench()
	_signpost()
	_campfire()
	_cave_wall()
	_glow_algae()
	_coral(0)
	_coral(1)
	_corrupt_rock()
	_altar()
	_seaweed_black()
	_wreck_debris()
	_pier_post()
	_wood_pile()
	# ---- 角色帧动画：潜水员（游/走）与鲨鱼 ----
	for i in 4:
		_diver_swim(i)
		_diver_walk(i)
		_shark_swim(i)
	print("场景贴图生成完成：%s / %s" % [OUT, OUT_HUD])
	quit(0)


# ---------------- 基础工具 ----------------

func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func _rng(name: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(name)
	return r


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in h:
		for xx in w:
			_px(img, x + xx, y + yy, c)


func _jit(c: Color, r: RandomNumberGenerator, amt := 0.04) -> Color:
	return Color(
		clampf(c.r + r.randf_range(-amt, amt), 0.0, 1.0),
		clampf(c.g + r.randf_range(-amt, amt), 0.0, 1.0),
		clampf(c.b + r.randf_range(-amt, amt), 0.0, 1.0), c.a)


func _save(img: Image, name: String, dir := OUT) -> void:
	img.save_png("%s/%s.png" % [dir, name])


## 1px 深色外描边（DAVE 式剪影可读性）。
func _outline(img: Image, col := DARK) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			solid[y * w + x] = 1 if img.get_pixel(x, y).a > 0.5 else 0
	for y in h:
		for x in w:
			if solid[y * w + x]:
				continue
			var near := (x > 0 and solid[y * w + x - 1]) \
				or (x < w - 1 and solid[y * w + x + 1]) \
				or (y > 0 and solid[(y - 1) * w + x]) \
				or (y < h - 1 and solid[(y + 1) * w + x])
			if near:
				img.set_pixel(x, y, col)


## 木纹噪点：底色抖动 + 短横向暗纹。
func _grain(img: Image, r: RandomNumberGenerator, base: Color,
		x0: int, y0: int, w: int, h: int, density := 0.05) -> void:
	for y in h:
		for x in w:
			_px(img, x0 + x, y0 + y, _jit(base, r))
	var n := int(w * h * density)
	for i in n:
		var gx := x0 + r.randi_range(0, w - 1)
		var gy := y0 + r.randi_range(0, h - 1)
		var len := r.randi_range(2, 5)
		for j in len:
			_px(img, gx + j, gy, base.darkened(0.2))


func _barnacles(img: Image, r: RandomNumberGenerator, x: int, y: int, n := 4) -> void:
	for i in n:
		var bx := x + r.randi_range(-2, 3)
		var by := y + r.randi_range(-1, 2)
		_px(img, bx, by, SILT)
		_px(img, bx + 1, by, SILT)
		_px(img, bx, by + 1, SILT_D)
		_px(img, bx, by - 1, SILT_L)


# ---------------- 船壳板墙（平铺件，不带外描边） ----------------

func _hull_wall(damaged: bool, name: String) -> void:
	var img := _img(96, 16)
	var r := _rng(name)
	const ROW_H := 8
	for row in 2:
		var y0 := row * ROW_H
		var shade := WOOD if row == 0 else WOOD_D
		_grain(img, r, shade, 0, y0, 96, ROW_H, 0.04)
		# 板缝 + 上缘受光
		for x in 96:
			_px(img, x, y0, shade.darkened(0.38))
			_px(img, x, y0 + 1, shade.lightened(0.14))
		# 错缝竖接 + 钉子
		var joint := (row * 7 + 3) % 13
		while joint < 96:
			for yy in ROW_H:
				_px(img, joint, y0 + yy, shade.darkened(0.32))
			_px(img, joint - 1, y0 + 3, DARK)
			_px(img, joint + 1, y0 + 3, DARK)
			_px(img, joint - 1, y0 + ROW_H - 3, DARK)
			_px(img, joint + 1, y0 + ROW_H - 3, DARK)
			joint += 13
	if damaged:
		# 破洞：露出舱外深黑（不规则锯齿边缘）
		var hx := 52
		var edge := [3, 5, 4, 7, 5, 8, 6, 4, 6, 3]
		for y in 10:
			var half: int = edge[y]
			for x in half * 2:
				_px(img, hx + x - half, 3 + y, NIGHT if y > 1 else DARK)
		for i in 5:
			_px(img, hx + r.randi_range(-8, 8), 2 + r.randi_range(0, 2), WOOD_D)
	_barnacles(img, r, 12, 13)
	_barnacles(img, r, 78, 2)
	_save(img, name)


# ---------------- 船肋（竖向结构件） ----------------

func _rib() -> void:
	var img := _img(18, 92)
	var r := _rng("rib")
	_grain(img, r, WOOD_D, 4, 2, 10, 82, 0.03)
	for stave in [4, 8, 12]:
		for y in range(2, 84):
			_px(img, stave, y, WOOD_DD)
	# 顶部收窄盖板
	_grain(img, r, WOOD_L, 5, 0, 8, 2, 0.03)
	# 底部展宽法兰
	_grain(img, r, WOOD_D, 2, 84, 14, 6, 0.03)
	for x in 16:
		_px(img, x + 1, 89, WOOD_DD)
	# 锚栓
	for by in [12, 44, 76]:
		_rect(img, 7, by, 3, 3, METAL)
		_px(img, 7, by, METAL_L)
		_px(img, 9, by + 2, Color(0, 0, 0, 0.35))
	_barnacles(img, r, 13, 78, 3)
	_outline(img)
	_save(img, "hull_rib")


# ---------------- 断裂横梁 ----------------

func _beam() -> void:
	var img := _img(144, 14)
	var r := _rng("beam")
	_grain(img, r, WOOD_D, 1, 3, 128, 8, 0.05)
	for x in 128:
		_px(img, x + 1, 3, WOOD_L)
		_px(img, x + 1, 10, WOOD_DD)
	# 捆扎缆绳
	for wx in [40, 78]:
		for y in range(2, 11):
			for x in 6:
				_px(img, wx + x, y, Color("5C4428") if (x + y) % 3 else Color("8A6B45"))
	# 断口：锯齿边缘 + 亮色木茬
	var jag: Array = [0, 5, 2, 8, 1, 7, 3, 9, 2]
	for y in range(2, 11):
		var end_x: int = 120 + int(jag[(y - 2) % jag.size()])
		for x in range(end_x, 144):
			_px(img, x, y, Color(0, 0, 0, 0))
		_px(img, end_x - 1, y, WOOD_DD)
		if y % 2 == 0:
			_px(img, end_x - 1, y, WOOD_L)
			_px(img, end_x - 2, y, WOOD_L)
	for i in 4:
		_px(img, 130 + r.randi_range(0, 6), 2 + r.randi_range(0, 2), WOOD_L)
	_outline(img)
	_save(img, "beam_broken")


# ---------------- 木桶 ----------------

func _barrel(open: bool, name: String) -> void:
	var img := _img(26, 30)
	var r := _rng(name)
	var cx := 13
	for i in 24:
		var y := 3 + i
		var t := float(i) / 23.0
		var half := int(round(7.5 + 3.5 * sin(t * PI)))
		for x in range(cx - half, cx + half + 1):
			_px(img, x, y, _jit(WOOD, r))
		# 桶板竖缝
		for x in range(cx - half + 3, cx + half, 4):
			_px(img, x, y, WOOD_DD)
		# 受光侧
		if half >= 8:
			_px(img, cx - half + 1, y, WOOD_L)
	# 金属箍
	for hy in [7, 14, 21]:
		for x in range(2, 24):
			if img.get_pixel(x, hy).a > 0.5:
				_px(img, x, hy, METAL)
				_px(img, x, hy - 1, METAL_L)
	if open:
		# 敞口：桶内黑洞 + 金光
		for y in range(3, 9):
			for x in range(7, 20):
				if img.get_pixel(x, y).a > 0.5:
					_px(img, x, y, NIGHT)
		for i in 5:
			_px(img, 9 + r.randi_range(0, 8), 8, GOLD if i % 2 else GOLD_L)
		# 破板
		for y in range(3, 7):
			for x in range(17, 21):
				_px(img, x, y, Color(0, 0, 0, 0))
	else:
		# 桶盖
		for x in range(6, 21):
			_px(img, x, 3, WOOD_LL)
			_px(img, x, 4, WOOD_D)
	_barnacles(img, r, 21, 18)
	_outline(img)
	_save(img, name)


# ---------------- 货箱 ----------------

func _crate() -> void:
	var img := _img(28, 24)
	var r := _rng("crate")
	_grain(img, r, WOOD, 2, 2, 24, 20, 0.03)
	# 边框板
	for x in 24:
		_px(img, x + 2, 2, WOOD_L)
		_px(img, x + 2, 21, WOOD_DD)
	for y in 20:
		_px(img, 2, y + 2, WOOD_D)
		_px(img, 25, y + 2, WOOD_D)
	# 交叉加固条（X 形）
	for t in 18:
		_px(img, 5 + t, 4 + t, WOOD_DD)
		_px(img, 23 - t, 4 + t, WOOD_DD)
	# 角钉
	for c in [[3, 3], [24, 3], [3, 20], [24, 20]]:
		_px(img, c[0], c[1], DARK)
		_px(img, c[0] - 1, c[1], METAL_L)
	_outline(img)
	_save(img, "crate")


# ---------------- 缆绳 ----------------

func _rope_coil() -> void:
	var img := _img(28, 14)
	var r := _rng("rope_coil")
	var cx := 12
	for cy in [9]:
		for ring in 3:
			var rad := 4.0 + ring * 2.6
			var prev := Vector2.ZERO
			for i in 26:
				var a := TAU * i / 26.0
				var p := Vector2(round(cx + cos(a) * rad), round(cy + sin(a) * rad * 0.55))
				if p != prev:
					_px(img, int(p.x), int(p.y), Color("8A6B45") if i % 2 else Color("5C4428"))
					prev = p
	# 绳头甩出
	for i in 6:
		_px(img, 19 + i, 10 - i / 2, Color("8A6B45"))
	_barnacles(img, r, 6, 12, 2)
	_outline(img)
	_save(img, "rope_coil")


func _rope_hang() -> void:
	var img := _img(8, 38)
	var r := _rng("rope_hang")
	for y in 34:
		_px(img, 3, y + 1, Color("8A6B45") if y % 3 else Color("5C4428"))
		_px(img, 4, y + 1, Color("5C4428"))
	# 断股
	for i in 5:
		_px(img, 3 + r.randi_range(-2, 2), 35 + r.randi_range(0, 2), Color("8A6B45"))
	_outline(img)
	_save(img, "rope_hang")


# ---------------- 舱内海草（去饱和青绿） ----------------

func _seaweed() -> void:
	var img := _img(18, 26)
	var r := _rng("seaweed_hold")
	var blades := [
		[Vector2(3, 25), Vector2(1, 16), Vector2(4, 6), Vector2(2, 0)],
		[Vector2(8, 25), Vector2(8, 14), Vector2(6, 5), Vector2(7, 0)],
		[Vector2(13, 25), Vector2(15, 15), Vector2(12, 6), Vector2(14, 1)],
	]
	for b in blades:
		var pts: Array = b
		var blade_i: int = blades.find(b)
		for i in range(1, pts.size()):
			var a0: Vector2 = pts[i - 1]
			var a1: Vector2 = pts[i]
			var steps: int = int(a0.distance_to(a1) * 2.0) + 1
			for s in steps:
				var t: float = float(s) / float(steps)
				var p: Vector2 = a0.lerp(a1, t)
				var wob: int = int(round(sin(t * PI * 2.0 + float(blade_i)) * 0.7))
				var col: Color = TEAL_D.darkened(0.25 + 0.12 * (1.0 - t)).lerp(Color("2E6E63"), 0.4)
				_px(img, int(p.x) + wob, int(p.y), col)
				_px(img, int(p.x) + wob + 1, int(p.y), col)
				if i == pts.size() - 1 and t > 0.7:
					_px(img, int(p.x) + wob, int(p.y) - 1, TEAL)
					_px(img, int(p.x) + wob + 1, int(p.y) - 1, TEAL)
	_outline(img, Color("12241F"))
	_save(img, "seaweed_hold")


# ---------------- 沉积堆 ----------------

func _sediment(w: int, h: int, name: String) -> void:
	var img := _img(w + 2, h + 2)
	var r := _rng(name)
	for y in h:
		var t := float(y) / float(h - 1)
		var half := int(round(float(w) / 2.0 * (0.35 + 0.65 * t)))
		for x in range(w / 2 - half, w / 2 + half):
			var base := SILT.lerp(SILT_D, t)
			_px(img, x + 1, y + 1, _jit(base, r, 0.03))
		if y == 0:
			for x in range(w / 2 - half, w / 2 + half):
				_px(img, x + 1, y + 1, SILT_L)
	# 碎石
	for i in 4:
		var px := 3 + r.randi_range(0, w - 6)
		var py := h - 1 - r.randi_range(0, 2)
		_px(img, px, py, SILT_L)
		_px(img, px + 1, py, SILT)
		_px(img, px, py + 1, SILT_D)
	_save(img, name)


# ---------------- 舷窗 ----------------

func _porthole() -> void:
	var img := _img(18, 18)
	var c := Vector2(9, 9)
	for y in 18:
		for x in 18:
			var d := Vector2(x, y).distance_to(c)
			if d <= 7.5 and d > 5.0:
				_px(img, x, y, Color("8A6538") if (x + y) % 5 else Color("6B4A2A"))
			elif d <= 5.0:
				var t := float(y) / 18.0
				_px(img, x, y, WATER.lerp(WATER_D, t))
	# 高光斜条
	for i in 4:
		_px(img, 6 + i, 6 + i, Color("BFE8F0"))
	# 螺栓
	for b in [Vector2(9, 2), Vector2(9, 16), Vector2(2, 9), Vector2(16, 9)]:
		_px(img, int(b.x), int(b.y), GOLD_D)
		_px(img, int(b.x), int(b.y) + (1 if b.y < 9 else -1), METAL_L)
	_outline(img)
	_save(img, "porthole")


# ---------------- 油灯 ----------------

func _lantern() -> void:
	var img := _img(12, 16)
	# 吊钩
	_px(img, 5, 1, METAL)
	_px(img, 6, 0, METAL)
	_px(img, 7, 1, METAL)
	# 顶罩
	_rect(img, 3, 2, 6, 2, METAL)
	# 笼体与暖光
	for y in range(4, 13):
		for x in range(2, 10):
			var d := Vector2(x, y).distance_to(Vector2(5.5, 8.5))
			if d < 2.2:
				_px(img, x, y, Color("FFF6D0"))
			elif d < 4.0:
				_px(img, x, y, GOLD if (x + y) % 4 else GOLD_L)
	# 竖笼条
	for y in range(4, 13):
		_px(img, 2, y, METAL)
		_px(img, 9, y, METAL)
		if y % 2:
			_px(img, 5, y, Color("3A3F46", 0.9))
			_px(img, 6, y, Color("3A3F46", 0.9))
	_rect(img, 3, 13, 6, 2, METAL)
	_outline(img)
	_save(img, "lantern")


# ---------------- 航海桌 ----------------

func _desk() -> void:
	var img := _img(44, 32)
	var r := _rng("desk")
	# 桌面
	_grain(img, r, WOOD_LL, 2, 7, 40, 2, 0.02)
	_grain(img, r, WOOD, 2, 9, 40, 3, 0.03)
	# 桌身
	_grain(img, r, WOOD_D, 4, 12, 36, 10, 0.04)
	# 抽屉
	for dx in [7, 23]:
		_rect(img, dx, 14, 14, 6, WOOD)
		for x in 14:
			_px(img, dx + x, 14, WOOD_DD)
			_px(img, dx + x, 19, WOOD_DD)
		for y in 6:
			_px(img, dx, 14 + y, WOOD_DD)
			_px(img, dx + 13, 14 + y, WOOD_DD)
		_px(img, dx + 6, 17, GOLD_D)
		_px(img, dx + 7, 17, GOLD)
	# 桌腿
	_rect(img, 5, 22, 3, 7, WOOD_DD)
	_rect(img, 36, 22, 3, 7, WOOD_DD)
	# 桌上：蜡烛 + 墨渍
	_rect(img, 36, 4, 2, 3, Color("E8E4D0"))
	_rect(img, 35, 7, 4, 1, METAL)
	_px(img, 36, 3, GOLD)
	_rect(img, 12, 8, 2, 1, Color("1E2A3A"))
	_barnacles(img, r, 6, 24, 3)
	_outline(img)
	_save(img, "desk")


# ---------------- 船尾神龛 ----------------

func _shrine() -> void:
	var img := _img(30, 36)
	var r := _rng("shrine")
	# 龛内阴影
	_rect(img, 8, 11, 15, 15, NIGHT)
	# 石柱与楣
	_grain(img, r, SILT, 4, 10, 3, 16, 0.03)
	_grain(img, r, SILT, 23, 10, 3, 16, 0.03)
	_grain(img, r, SILT_L, 3, 8, 24, 2, 0.02)
	# 三角楣
	for row in 3:
		_rect(img, 5 + row * 3, 5 + row, 20 - row * 6, 1, SILT.lerp(SILT_D, row / 3.0))
	# 小神像：暗色剪影 + 金饰 + 青绿眼（放大保证可读）
	_rect(img, 12, 13, 7, 12, Color("1A2430"))
	_rect(img, 13, 12, 5, 2, Color("24303E"))
	_rect(img, 12, 18, 7, 1, GOLD_D)
	_rect(img, 13, 18, 5, 1, GOLD)
	_px(img, 14, 15, TEAL)
	_px(img, 16, 15, TEAL)
	# 供盘
	_rect(img, 12, 25, 7, 1, GOLD_D)
	# 基座
	_grain(img, r, SILT, 2, 26, 26, 7, 0.03)
	for x in 26:
		_px(img, x + 2, 26, SILT_L)
		_px(img, x + 2, 32, SILT_D)
	# 供烛（火苗由关卡层动画绘制）
	_rect(img, 8, 23, 2, 3, Color("E8E4D0"))
	_rect(img, 20, 23, 2, 3, Color("E8E4D0"))
	_barnacles(img, r, 4, 30, 4)
	_barnacles(img, r, 24, 24, 3)
	_outline(img)
	_save(img, "shrine")


# ---------------- 应急绞盘 ----------------

func _winch() -> void:
	var img := _img(26, 28)
	var r := _rng("winch")
	# 底座
	_grain(img, r, WOOD_DD, 2, 22, 22, 4, 0.03)
	for x in 22:
		_px(img, x + 2, 22, WOOD_D)
	# A 型架
	_rect(img, 5, 9, 2, 13, WOOD_D)
	_rect(img, 19, 9, 2, 13, WOOD_D)
	_rect(img, 5, 8, 16, 2, WOOD)
	# 绞鼓
	_grain(img, r, WOOD, 7, 11, 12, 6, 0.03)
	_rect(img, 7, 11, 2, 6, METAL)
	_rect(img, 17, 11, 2, 6, METAL)
	_px(img, 7, 11, METAL_L)
	_px(img, 17, 11, METAL_L)
	# 摇柄
	_rect(img, 21, 12, 3, 2, WOOD_DD)
	_rect(img, 23, 13, 2, 4, METAL)
	# 链头
	for y in range(17, 22, 2):
		_rect(img, 12, y, 2, 1, METAL)
	_outline(img)
	_save(img, "winch")


# ---------------- 宝箱（升级件：关 / 开两态） ----------------

func _chest(open: bool, name: String) -> void:
	var img := _img(30, 28)
	var r := _rng(name)
	if open:
		# 掀开的盖（后仰）
		_grain(img, r, WOOD_DD, 2, 1, 26, 5, 0.03)
		for x in 26:
			_px(img, x + 2, 5, DARK)
		# 盖内暗面 + 箱内金堆
		_rect(img, 4, 6, 22, 7, NIGHT)
		for i in 16:
			_px(img, 8 + r.randi_range(0, 14), 10 + r.randi_range(0, 2),
				GOLD if r.randf() > 0.4 else GOLD_L)
		_px(img, 10, 8, Color.WHITE)
		_px(img, 19, 9, Color.WHITE)
	else:
		# 弧形盖
		_grain(img, r, WOOD_L, 8, 7, 14, 2, 0.02)
		_grain(img, r, WOOD, 5, 9, 20, 2, 0.02)
		_grain(img, r, WOOD_D, 3, 11, 24, 2, 0.02)
	# 箱体
	_grain(img, r, WOOD, 3, 13, 24, 10, 0.03)
	for x in 24:
		_px(img, x + 3, 13, WOOD_L)
		_px(img, x + 3, 22, WOOD_DD)
	# 金饰条
	for x in 24:
		_px(img, x + 3, 12, GOLD_D)
	for gx in [6, 13, 21]:
		_px(img, gx, 12, GOLD_L)
	# 金属包边与锁牌
	_rect(img, 6, 12, 1, 11, METAL)
	_rect(img, 23, 12, 1, 11, METAL)
	if not open:
		_rect(img, 12, 12, 6, 6, GOLD_D)
		_rect(img, 13, 13, 4, 4, GOLD)
		_px(img, 14, 15, DARK)
		_px(img, 15, 16, DARK)
	else:
		_rect(img, 12, 13, 6, 4, GOLD_D)
	# 箱脚
	_rect(img, 5, 23, 3, 2, WOOD_DD)
	_rect(img, 22, 23, 3, 2, WOOD_DD)
	_outline(img)
	_save(img, name)


# ---------------- 倾斜搁架（可疑角落） ----------------

func _shelf() -> void:
	var img := _img(32, 14)
	var r := _rng("shelf")
	_grain(img, r, WOOD, 1, 4, 30, 4, 0.03)
	for x in 30:
		_px(img, x + 1, 4, WOOD_L)
		_px(img, x + 1, 7, WOOD_DD)
	# 托架
	for bx in [3, 25]:
		_rect(img, bx, 8, 2, 3, WOOD_DD)
		_rect(img, bx, 10, 4, 1, WOOD_DD)
	# 瓶子
	_rect(img, 8, 1, 3, 3, Color("2E4A3A"))
	_px(img, 9, 0, Color("2E4A3A"))
	_px(img, 9, 1, Color("4E7A62"))
	# 金杯
	_rect(img, 16, 1, 3, 3, GOLD_D)
	_rect(img, 17, 0, 1, 1, GOLD)
	# 烛头
	_rect(img, 24, 2, 2, 2, Color("E8E4D0"))
	_outline(img)
	_save(img, "shelf")


# ---------------- 粒子点 ----------------

func _mote() -> void:
	var img := _img(6, 6)
	var c := Vector2(2.5, 2.5)
	for y in 6:
		for x in 6:
			var d := Vector2(x, y).distance_to(c)
			if d <= 1.2:
				_px(img, x, y, Color("CFEDEA"))
			elif d <= 2.2:
				_px(img, x, y, Color("CFEDEA", 0.45))
	img.save_png(OUT + "/mote.png")


# ---------------- HUD 小图标（12×12，1:1） ----------------

func _pattern(rows: Array, map: Dictionary, name: String) -> void:
	var img := _img(12, 12)
	for y in rows.size():
		var s: String = rows[y]
		for x in s.length():
			var ch := s[x]
			if map.has(ch):
				_px(img, x, y, map[ch])
	_outline(img, Color(0.06, 0.05, 0.05))
	_save(img, name, OUT_HUD)


func _hud_heart() -> void:
	_pattern([
		".RR..RR.",
		"RrRRRRrR",
		"RRRRRRRR",
		".RRRRRR.",
		"..RRRR..",
		"...RR...",
	], {"R": RED, "r": RED_L}, "hud_heart")


func _hud_bolt() -> void:
	_pattern([
		"....GG",
		"...GGg",
		"..GG..",
		".GGGGg",
		"...GG.",
		"..GG..",
		".GG...",
		"GG....",
	], {"G": GOLD, "g": GOLD_L}, "hud_bolt")


func _hud_bag() -> void:
	_pattern([
		"...BB...",
		"..B..B..",
		".BBBBBB.",
		"BddddddB",
		"BddddddB",
		"BddGgddB",
		"BBBBBBBB",
		".BBBBBB.",
	], {"B": WOOD_D, "d": WOOD, "G": GOLD, "g": GOLD_L}, "hud_bag")


func _hud_coin() -> void:
	var img := _img(12, 12)
	for y in 12:
		for x in 12:
			var d := Vector2(x, y).distance_to(Vector2(5.5, 5.5))
			if d <= 5.0 and d > 3.8:
				_px(img, x, y, GOLD_D)
			elif d <= 3.8:
				_px(img, x, y, GOLD)
	_px(img, 4, 3, GOLD_L)
	_px(img, 3, 4, GOLD_L)
	_px(img, 7, 6, GOLD_D)
	_px(img, 6, 7, GOLD_D)
	_outline(img, Color(0.06, 0.05, 0.05))
	_save(img, "hud_coin", OUT_HUD)


func _hud_timer() -> void:
	_pattern([
		".CCCCCC.",
		"..CttC..",
		"...CC...",
		"..C..C..",
		".C.tt.C.",
		".Cttt.C.",
		".CCCCCC.",
	], {"C": GOLD_D, "t": TEAL}, "hud_timer")


func _hud_warn() -> void:
	_pattern([
		"....W....",
		"....W....",
		"...WWW...",
		"...WwW...",
		"..WWWWW..",
		"..WWWWW..",
		".WWWWWWW.",
		".WWwWwWW.",
		"WWWWWWWWW",
	], {"W": RED_L, "w": DARK}, "hud_warn")


# ---------------- 色板样张（自制，供目视校准） ----------------

func _palette() -> void:
	var groups := [
		["深海黑蓝", Color("0E1B2E"), Color("071018"), Color("16273D")],
		["海水青蓝", Color("1E5666"), Color("123641"), Color("2E7A8A")],
		["远景灰蓝", Color("3E5568"), Color("2A3B4A"), Color("5A7186")],
		["木质棕褐", Color("6B4A2A"), Color("4A3320"), Color("8A6538")],
		["宝物暖金", Color("F2C53D"), Color("C99420"), Color("FFE08A")],
		["危险暗红", Color("C43B30"), Color("8A2420"), Color("E05A4E")],
		["荧光青绿", Color("66F0D9"), Color("3FBFAE"), Color("9FF7EA")],
	]
	var img := _img(7 * 76 + 8, 3 * 56 + 8)
	_rect(img, 0, 0, img.get_width(), img.get_height(), Color("0D1219"))
	for g in groups.size():
		for row in 3:
			_rect(img, 8 + g * 76, 8 + row * 56, 60, 48, groups[g][row + 1])
	img.save_png(ProjectSettings.globalize_path(OUT_PAL))


# ==================== 纠偏阶段：全船与环境件 ====================

## 甲板板面（平铺件）：纵向甲板板 + 捻缝 + 钉。
func _deck_plank() -> void:
	var img := _img(96, 20)
	var r := _rng("deck_plank")
	const ROW_H := 5
	for row in 4:
		var y0 := row * ROW_H
		var shade := WOOD.lerp(WOOD_D, float(row) / 5.0)
		_grain(img, r, shade, 0, y0, 96, ROW_H, 0.04)
		for x in 96:
			_px(img, x, y0, shade.darkened(0.4))
			_px(img, x, y0 + 1, shade.lightened(0.12))
		var joint := (row * 11 + 5) % 17
		while joint < 96:
			for yy in ROW_H:
				_px(img, joint, y0 + yy, shade.darkened(0.3))
			_px(img, joint + 1, y0 + 2, DARK)
			joint += 17
	for x in 96:
		_px(img, x, 0, WOOD_L)
		_px(img, x, 19, WOOD_DD)
	_save(img, "deck_plank")


## 船首柱：前倾龙骨柱 + 汇入的外板。
func _hull_bow() -> void:
	var img := _img(52, 70)
	var r := _rng("hull_bow")
	for i in 5:
		var y := 6 + i * 13
		var col := WOOD.lerp(WOOD_D, float(i) / 5.0)
		for t in 30:
			var px0 := int(lerpf(2.0, 26.0, t / 29.0))
			var py := int(y + (t / 29.0) * 10.0)
			_px(img, px0, py, _jit(col, r))
			_px(img, px0, py + 1, col.darkened(0.25))
			_px(img, px0 + 1, py, col.lightened(0.1))
	for y in 66:
		var lean := int(y * 0.12)
		_rect(img, 26 + lean, y, 5, 1, WOOD_D)
		_px(img, 26 + lean, y, WOOD_L)
	_rect(img, 24, 0, 9, 4, WOOD_LL)
	_barnacles(img, r, 30, 58, 5)
	for i in 4:
		_px(img, 8 + r.randi_range(0, 20), 10 + i * 14, NIGHT)
	_outline(img)
	_save(img, "hull_bow")


## 船尾：横木板 + 双扇琥珀舷窗。
func _hull_stern() -> void:
	var img := _img(60, 76)
	var r := _rng("hull_stern")
	for row in 9:
		var y := 8 + row * 7
		var inset := maxi(0, (4 - row) * 2) if row < 5 else 0
		var w := 56 - inset * 2
		var shade := WOOD.lerp(WOOD_D, float(row) / 10.0)
		_grain(img, r, shade, 2 + inset, y, w, 6, 0.03)
		for x in w:
			_px(img, 2 + inset + x, y, shade.darkened(0.35))
	_rect(img, 0, 2, 60, 5, WOOD_L)
	for x in 60:
		_px(img, x, 6, WOOD_DD)
	for wx in [12, 36]:
		_rect(img, wx, 16, 12, 14, METAL)
		_rect(img, wx + 2, 18, 8, 10, GOLD)
		_rect(img, wx + 3, 19, 4, 4, GOLD_L)
		_px(img, wx, 16, METAL_L)
		_px(img, wx + 11, 29, DARK)
	_barnacles(img, r, 8, 66, 5)
	_barnacles(img, r, 48, 60, 4)
	_outline(img)
	_save(img, "hull_stern")


## 断桅：立柱 + 绳箍 + 顶端断口。
func _mast() -> void:
	var img := _img(24, 128)
	var r := _rng("mast")
	_grain(img, r, WOOD_D, 6, 4, 12, 120, 0.05)
	for y in 120:
		_px(img, 6, y + 4, WOOD_L)
		_px(img, 17, y + 4, WOOD_DD)
	for wy in [30, 88]:
		for x in 16:
			_px(img, x + 4, wy, Color("5C4428") if x % 3 else Color("8A6B45"))
			_px(img, x + 4, wy + 1, Color("8A6B45") if x % 3 else Color("5C4428"))
	var jag: Array = [0, 4, 1, 5, 2, 6, 1, 3]
	for x in 18:
		var end_y := 2 + int(jag[x % jag.size()])
		for y in range(end_y, 8):
			_px(img, x + 3, y, Color(0, 0, 0, 0))
		if x % 2 == 0:
			_px(img, x + 3, end_y, WOOD_L)
	_grain(img, r, WOOD_DD, 4, 124, 16, 4, 0.03)
	_barnacles(img, r, 18, 110, 4)
	_outline(img)
	_save(img, "mast")


## 横桁（桅杆帆桁）。
func _spar() -> void:
	var img := _img(128, 12)
	var r := _rng("spar")
	_grain(img, r, WOOD_L, 2, 2, 124, 8, 0.05)
	for x in 124:
		_px(img, x + 2, 2, WOOD_LL)
		_px(img, x + 2, 9, WOOD_D)
	for x in 8:
		_px(img, 58 + x, 1, Color("5C4428"))
		_px(img, 58 + x, 10, Color("8A6B45"))
	_rect(img, 0, 3, 3, 6, WOOD_D)
	_rect(img, 125, 3, 3, 6, WOOD_D)
	_outline(img)
	_save(img, "spar")


## 甲板栏杆：立柱 + 垂绳。
func _railing() -> void:
	var img := _img(96, 28)
	var r := _rng("railing")
	_grain(img, r, WOOD_L, 2, 2, 92, 4, 0.03)
	for x in 92:
		_px(img, x + 2, 5, WOOD_DD)
	for post_x in [6, 46, 86]:
		_rect(img, post_x, 4, 5, 22, WOOD_D)
		_px(img, post_x, 4, WOOD_L)
		_px(img, post_x + 4, 25, DARK)
	for seg in [[9, 45], [49, 85]]:
		for t in 36:
			var x: int = int(seg[0]) + t
			var sag := int(round(sin(PI * float(t) / 35.0) * 5.0))
			_px(img, x, 8 + sag, Color("8A6B45") if t % 2 else Color("5C4428"))
	_outline(img)
	_save(img, "railing")


## 舱口围板（甲板破口边缘的框架）。
func _hatch_coaming() -> void:
	var img := _img(72, 18)
	var r := _rng("hatch_coaming")
	_grain(img, r, WOOD_D, 2, 8, 68, 8, 0.04)
	for x in 68:
		_px(img, x + 2, 8, WOOD)
		_px(img, x + 2, 15, WOOD_DD)
	for post_x in [2, 64]:
		_rect(img, post_x, 2, 6, 14, WOOD)
		_px(img, post_x, 2, WOOD_L)
		_px(img, post_x + 1, 9, DARK)
		_px(img, post_x + 4, 9, DARK)
	_barnacles(img, r, 20, 12, 3)
	_outline(img)
	_save(img, "hatch_coaming")


## 舱门框（低门/顶门通道的木框）。
func _door_frame() -> void:
	var img := _img(52, 46)
	var r := _rng("door_frame")
	for post_x in [2, 42]:
		_rect(img, post_x, 4, 8, 40, WOOD_D)
		_rect(img, post_x + 1, 4, 2, 40, WOOD)
		_px(img, post_x + 2, 12, DARK)
		_px(img, post_x + 6, 12, DARK)
		_px(img, post_x + 2, 32, DARK)
		_px(img, post_x + 6, 32, DARK)
	_grain(img, r, WOOD, 2, 2, 48, 6, 0.03)
	for x in 48:
		_px(img, x + 2, 2, WOOD_L)
	for x in 40:
		_px(img, x + 6, 44, WOOD_DD if x % 3 else WOOD_D)
	_outline(img)
	_save(img, "door_frame")


## 轮机舱锅炉：铆钉钢筒 + 炉门微光。
func _boiler() -> void:
	var img := _img(48, 44)
	var r := _rng("boiler")
	_grain(img, r, METAL, 4, 8, 40, 30, 0.03)
	for y in 30:
		_px(img, 7, y + 8, METAL_L)
		_px(img, 8, y + 8, METAL_L.darkened(0.1))
		_px(img, 42, y + 8, METAL.darkened(0.3))
	for row in 4:
		var inset := 4 + row * 3
		_rect(img, inset, 5 + row, 48 - inset * 2, 1, METAL.lerp(METAL_L, 0.3 - row * 0.06))
	for y in range(12, 36, 6):
		for x in [10, 20, 30, 38]:
			_px(img, x, y, METAL_L)
			_px(img, x, y + 1, DARK)
	_rect(img, 16, 22, 16, 13, Color("1E2226"))
	_rect(img, 17, 23, 14, 11, NIGHT)
	_rect(img, 19, 26, 10, 6, Color("B3541E"))
	_rect(img, 21, 28, 6, 3, Color("F2A24D"))
	_px(img, 18, 22, GOLD_D)
	_px(img, 33, 22, GOLD_D)
	_rect(img, 36, 0, 5, 6, METAL)
	_px(img, 36, 0, METAL_L)
	_rect(img, 2, 38, 44, 4, METAL.darkened(0.35))
	_barnacles(img, r, 6, 34, 3)
	_outline(img)
	_save(img, "boiler")


## 立管（带法兰与锈迹）。
func _pipe() -> void:
	var img := _img(14, 72)
	var r := _rng("pipe")
	_grain(img, r, METAL, 4, 2, 6, 68, 0.02)
	for y in 68:
		_px(img, 5, y + 2, METAL_L)
		_px(img, 9, y + 2, METAL.darkened(0.35))
	for fy in [4, 34, 64]:
		_rect(img, 2, fy, 10, 4, METAL_L)
		_rect(img, 2, fy + 3, 10, 1, METAL.darkened(0.3))
		_px(img, 3, fy + 1, DARK)
		_px(img, 10, fy + 1, DARK)
	for i in 6:
		var ry := 8 + r.randi_range(0, 54)
		_px(img, 8, ry, Color("6B4A2A"))
		_px(img, 8, ry + 1, Color("6B4A2A").darkened(0.2))
	_outline(img)
	_save(img, "pipe")


## 金属格栅（龙骨活门）。
func _hatch_grate() -> void:
	var img := _img(60, 22)
	_rect(img, 1, 1, 58, 20, METAL)
	_rect(img, 3, 3, 54, 16, NIGHT)
	for x in range(6, 54, 7):
		_rect(img, x, 3, 3, 16, METAL)
		_px(img, x, 3, METAL_L)
	for t in 52:
		_px(img, 4 + t, 18 - int(t * 0.28), Color("4A515A"))
	_rect(img, 8, 0, 6, 3, METAL_L)
	_rect(img, 46, 0, 6, 3, METAL_L)
	_outline(img)
	_save(img, "hatch_grate")


## 坍塌堆积（木板 + 碎石交错）。
func _debris_pile() -> void:
	var img := _img(136, 44)
	var r := _rng("debris")
	for y in range(14, 42):
		var half := int(64 * (float(y - 12) / 30.0))
		for x in range(68 - half, 68 + half):
			_px(img, x, y, _jit(SILT.lerp(SILT_D, float(y) / 44.0), r, 0.05))
	for plank in [[20, 36, -0.5], [46, 40, 0.3], [78, 38, -0.2], [104, 34, 0.55]]:
		var bx: int = plank[0]
		var by: int = plank[1]
		var slope: float = plank[2]
		for t in 26:
			var px0 := bx + t
			var py := by - int(absf(t * slope))
			_px(img, px0, py, WOOD if t % 7 else WOOD_D)
			_px(img, px0, py + 1, WOOD_D)
	for t in 14:
		_px(img, 58 + t, 26 - int(sin(PI * t / 13.0) * 6), METAL)
	_barnacles(img, r, 30, 38, 5)
	_outline(img)
	_save(img, "debris_pile")


## 礁岩（带层理与藤壶的巨石）。
func _rock(w: int, h: int, name: String) -> void:
	var img := _img(w + 2, h + 2)
	var r := _rng(name)
	for y in h:
		var t := float(y) / float(h)
		var half := int(round(float(w) / 2.0 * pow(0.15 + 0.85 * t, 0.7)))
		for x in range(w / 2 - half, w / 2 + half):
			var shade := SILT.lerp(SILT_D, t * 0.8)
			shade = shade.lerp(SILT_L, maxf(0.0, 0.35 - absf(float(x) / float(w) - 0.3) - t * 0.3))
			_px(img, x + 1, y + 1, _jit(shade, r, 0.05))
	for crack in 3:
		var cx := 6 + r.randi_range(0, w - 14)
		var cy := 4 + r.randi_range(0, h / 3)
		for t in r.randi_range(10, h - 6):
			_px(img, cx + r.randi_range(-1, 2), cy + t, SILT_D.darkened(0.3))
	for x in w:
		if img.get_pixel(x + 1, 2).a > 0.5:
			_px(img, x + 1, 1, SILT_L)
			_px(img, x + 1, h, Color("1A2734"))
	_barnacles(img, r, w / 2 - 8, h / 3, 5)
	_barnacles(img, r, w / 2 + 6, h - 8, 3)
	_outline(img, Color("141E28"))
	_save(img, name)


## 海床条（沙与淤积，平铺件）。
func _sand_tile() -> void:
	var img := _img(96, 22)
	var r := _rng("sand_tile")
	var sand := Color("8A7C5E")
	for y in 22:
		var t := float(y) / 22.0
		var base := sand.lerp(Color("4A4234"), t)
		for x in 96:
			_px(img, x, y, _jit(base, r, 0.04))
	for x in 96:
		_px(img, x, 0, Color("A3936E"))
		_px(img, x, 1, sand.lightened(0.08))
	for i in 7:
		var sx := r.randi_range(2, 92)
		var sy := r.randi_range(3, 16)
		_px(img, sx, sy, Color("C9C2AC"))
		_px(img, sx + 1, sy, sand.darkened(0.2))
	for i in 4:
		var peb := r.randi_range(4, 90)
		_rect(img, peb, r.randi_range(6, 14), 2, 1, SILT)
	_save(img, "sand_tile")


## 撤离浮标：灯 + 浮体 + 锚链。
func _buoy() -> void:
	var img := _img(20, 30)
	_rect(img, 7, 2, 6, 5, GOLD_D)
	_rect(img, 8, 3, 4, 3, GOLD_L)
	_px(img, 9, 1, GOLD)
	_rect(img, 4, 8, 12, 10, RED)
	_rect(img, 4, 11, 12, 2, RED_L)
	_rect(img, 4, 15, 12, 2, Color("8A2420"))
	_px(img, 4, 8, Color("E88A80"))
	for y in range(19, 28, 2):
		_rect(img, 9, y, 2, 1, METAL)
	_outline(img)
	_save(img, "buoy")


## 金币堆。
func _gold_pile() -> void:
	var img := _img(44, 20)
	var r := _rng("gold_pile")
	for y in range(8, 18):
		var half := int(20 * (float(y - 6) / 12.0))
		for x in range(22 - half, 22 + half):
			_px(img, x, y, _jit(GOLD_D, r, 0.06))
	for i in 14:
		var cx := 8 + r.randi_range(0, 28)
		var cy := 9 + r.randi_range(0, 8)
		_px(img, cx, cy, GOLD)
		_px(img, cx + 1, cy, GOLD_D.darkened(0.15))
		if i % 4 == 0:
			_px(img, cx, cy - 1, GOLD_L)
	_px(img, 12, 8, Color.WHITE)
	_px(img, 30, 10, Color.WHITE)
	_outline(img, GOLD_D.darkened(0.5))
	_save(img, "gold_pile")


## 鱼骨（龙骨夹层的死亡暗示）。
func _fishbone() -> void:
	var img := _img(32, 16)
	var bone := Color("E8E4D0")
	var bone_d := Color("B8B4A0")
	for x in range(4, 28):
		_px(img, x, 8, bone)
		if x % 3 == 0:
			_px(img, x, 7, bone_d)
			_px(img, x, 9, bone_d)
	for i in 7:
		var bx := 8 + i * 3
		for t in 6:
			_px(img, bx, 8 - t, bone if t % 2 else bone_d)
			_px(img, bx + 1, 8 - t + 1, bone_d)
	_rect(img, 26, 6, 5, 5, bone)
	_px(img, 28, 8, DARK)
	_px(img, 30, 8, DARK)
	_outline(img, Color("6E6A58"))
	_save(img, "fishbone")


## 垂挂渔网。
func _net() -> void:
	var img := _img(44, 34)
	var rope := Color("8A6B45")
	var rope_d := Color("5C4428")
	for t in 44:
		_px(img, t, int(t * 0.8), rope_d if t % 3 else rope)
		_px(img, 43 - t, int(t * 0.8), rope if t % 3 else rope_d)
		if t < 22:
			_px(img, 2 + t * 2 - 22, 18 + int(t * 0.7), rope_d)
	for x in 44:
		if x % 2 == 0:
			_px(img, x, 0, rope)
	for y in range(22, 32):
		for x in range(24, 40):
			_px(img, x, y, Color(0, 0, 0, 0))
	_rect(img, 6, 30, 3, 3, METAL)
	_rect(img, 18, 31, 3, 3, METAL)
	_outline(img, Color("3E3324"))
	_save(img, "net")


## UI 九宫格木纹面板（HUD/弹窗底板）。
func _wood_panel() -> void:
	var img := _img(36, 36)
	var r := _rng("wood_panel")
	var base := Color("241A10")
	for y in 36:
		var shade := base.lerp(Color("2E2115"), float(y % 12) / 12.0)
		for x in 36:
			_px(img, x, y, _jit(shade, r, 0.03))
	for y in range(5, 36, 12):
		for x in 36:
			_px(img, x, y, Color("1A120A"))
	for i in 36:
		_px(img, i, 0, Color("3A2E1E"))
		_px(img, i, 35, Color("1C150C"))
		_px(img, 0, i, Color("3A2E1E"))
		_px(img, 35, i, Color("1C150C"))
	for c in [[3, 3], [31, 3], [3, 31], [31, 31]]:
		_px(img, c[0], c[1], GOLD_D)
		_px(img, c[0] + 1, c[1], Color("8A6538"))
	_save(img, "wood_panel")


## 远景礁影（视差层用，平铺件）。
func _far_rock() -> void:
	var img := _img(220, 90)
	var r := _rng("far_rock")
	var col := Color("14222F")
	var col_l := Color("1B2E3E")
	for hump in [[10, 54, 60], [80, 40, 78], [160, 58, 52]]:
		var hx: int = hump[0]
		var hy: int = hump[1]
		var hw: int = hump[2]
		for t in hw:
			var hh := int(hy * sin(PI * float(t) / float(hw - 1)))
			for y in hh:
				_px(img, hx + t, 88 - y, col if y % 7 else col_l)
	for i in 6:
		_px(img, r.randi_range(4, 214), r.randi_range(10, 50), Color("24404F"))
	_save(img, "far_rock")


# ==================== 正式关卡模块（岛屿/浅海/洞穴/深层） ====================

## 椰子树。
func _palm() -> void:
	var img := _img(30, 66)
	var r := _rng("palm")
	for i in 34:
		var t := float(i) / 33.0
		var x := 13.0 + sin(t * 1.9) * 4.0
		var y := 62.0 - t * 56.0
		var col := WOOD_D.lerp(WOOD, t * 0.4)
		_rect(img, int(x - 2), int(y), 4, 2, _jit(col, r, 0.03))
		if i % 6 == 3:
			_px(img, int(x), int(y), WOOD_DD)
	for a in [-2.6, -1.9, -1.2, -0.5, 0.2, 0.9, 1.6, 2.3]:
		var dir := Vector2(cos(a), -absf(sin(a)) * 0.5 - 0.4).normalized()
		for t in 13:
			var p := Vector2(14.0, 8.0) + dir * t * 1.15
			_px(img, int(p.x), int(p.y), Color("2E6E3A") if t % 4 else Color("3E8A4A"))
			if t > 8:
				_px(img, int(p.x), int(p.y + 1), Color("245630"))
	_px(img, 12, 12, WOOD_DD)
	_px(img, 16, 13, WOOD_DD)
	_outline(img)
	_save(img, "palm")


## 岛上草丛。
func _grass_tuft() -> void:
	var img := _img(18, 12)
	var r := _rng("grass_tuft")
	for i in 6:
		var bx := 2 + i * 3
		var h := 5 + r.randi_range(0, 4)
		var col := Color("4E8A3E") if i % 2 else Color("3E7232")
		for t in h:
			var sway := int(round(sin(t * 0.8 + i) * 1.2))
			_px(img, bx + sway, 10 - t, col if t < h - 2 else Color("6EA84E"))
	_save(img, "grass_tuft")


## 草地边条（平铺件：草皮压在沙上）。
func _grass_edge() -> void:
	var img := _img(96, 14)
	var r := _rng("grass_edge")
	for x in 96:
		var depth := 6 + int(3.0 * absf(sin(x * 0.35)))
		for y in depth:
			var col: Color = Color("3E7232").lerp(Color("2E5A26"), float(y) / 8.0)
			_px(img, x, y, _jit(col, r, 0.04))
		if x % 3 == 0:
			_px(img, x, depth, Color("5EA046"))
			_px(img, x, depth + 1, Color("8A7C5E"))
	_save(img, "grass_edge")


## 商人摊位：条纹雨棚 + 柜台 + 货品。
func _tent_stall() -> void:
	var img := _img(66, 54)
	var r := _rng("tent_stall")
	for post_x in [4, 58]:
		_rect(img, post_x, 16, 4, 34, WOOD_D)
		_px(img, post_x, 16, WOOD_L)
	for row in 3:
		var y := 12 + row * 4
		var inset := (2 - row) * 2
		for x in 62 - inset * 2:
			var stripe: Color = RED if ((x + row * 8) / 8) % 2 == 0 else Color("E8DCC4")
			_px(img, 2 + inset + x, y, stripe if row < 2 else stripe.darkened(0.15))
	for x in 66:
		if x % 2 == 0:
			_px(img, x, 24, Color("E8DCC4"))
	_grain(img, r, WOOD, 4, 42, 58, 6, 0.03)
	for x in 58:
		_px(img, x + 4, 42, WOOD_L)
		_px(img, x + 4, 47, WOOD_DD)
	_rect(img, 10, 34, 3, 8, Color("2E4A3A"))
	_px(img, 11, 33, Color("2E4A3A"))
	_rect(img, 40, 36, 8, 6, WOOD_D)
	_px(img, 43, 38, GOLD)
	_px(img, 44, 38, GOLD_L)
	_rect(img, 24, 37, 5, 5, Color("5C4428"))
	_outline(img)
	_save(img, "tent_stall")


## 装备工作台：厚桌 + 铁砧 + 工具架。
func _workbench() -> void:
	var img := _img(52, 40)
	var r := _rng("workbench")
	_grain(img, r, WOOD_DD, 14, 2, 24, 14, 0.03)
	_grain(img, r, WOOD_LL, 2, 16, 48, 5, 0.02)
	_grain(img, r, WOOD, 2, 21, 48, 5, 0.03)
	_rect(img, 4, 26, 5, 12, WOOD_D)
	_rect(img, 43, 26, 5, 12, WOOD_D)
	_rect(img, 26, 10, 14, 5, METAL)
	_rect(img, 30, 15, 5, 3, METAL.darkened(0.2))
	_px(img, 26, 10, METAL_L)
	_rect(img, 18, 5, 2, 7, WOOD_DD)
	_rect(img, 16, 4, 5, 2, METAL_L)
	_rect(img, 22, 5, 1, 6, METAL)
	_outline(img)
	_save(img, "workbench")


## 木牌路标（箭头板 + 钉）。
func _signpost() -> void:
	var img := _img(22, 38)
	var r := _rng("signpost")
	_grain(img, r, WOOD_D, 9, 8, 4, 28, 0.03)
	_grain(img, r, WOOD, 2, 4, 17, 9, 0.03)
	_px(img, 2, 4, WOOD_L)
	_px(img, 19, 8, WOOD_DD)
	_px(img, 2, 12, WOOD_DD)
	_rect(img, 5, 7, 8, 1, WOOD_DD)
	_px(img, 13, 6, WOOD_DD)
	_px(img, 13, 8, WOOD_DD)
	_px(img, 4, 5, METAL_L)
	_rect(img, 7, 34, 8, 3, SILT)
	_outline(img)
	_save(img, "signpost")


## 营火（石圈 + 木柴 + 余烬；火苗由场景动画叠加）。
func _campfire() -> void:
	var img := _img(24, 20)
	var r := _rng("campfire")
	for i in 7:
		var a := TAU * i / 7.0
		_px(img, 12 + int(cos(a) * 9), 15 + int(sin(a) * 3.5), SILT)
		_px(img, 12 + int(cos(a) * 9) + 1, 15 + int(sin(a) * 3.5), SILT_D)
	for t in 9:
		_px(img, 5 + t, 14 - t / 3, WOOD_D if t % 3 else WOOD)
		_px(img, 18 - t, 14 - t / 3, WOOD if t % 3 else WOOD_D)
	_rect(img, 10, 12, 4, 2, Color("B3541E"))
	_px(img, 11, 11, Color("F2A24D"))
	_px(img, 13, 11, Color("F2A24D"))
	_outline(img)
	_save(img, "campfire")


## 洞穴岩壁（平铺件：湿暗岩层）。
func _cave_wall() -> void:
	var img := _img(96, 48)
	var r := _rng("cave_wall")
	var base := Color("2A3340")
	for y in 48:
		for x in 96:
			var strata := 0.9 + 0.1 * sin(y * 0.4 + sin(x * 0.05) * 2.0)
			var col: Color = base.lerp(Color("1C242E"), float(y) / 48.0) * strata
			_px(img, x, y, _jit(col, r, 0.05))
	for i in 5:
		var sx := 8 + r.randi_range(0, 80)
		for y in r.randi_range(14, 40):
			_px(img, sx + r.randi_range(-1, 1), y, Color("3A4E60"))
	for i in 3:
		var cx := 10 + r.randi_range(0, 76)
		for y in r.randi_range(16, 44):
			_px(img, cx + r.randi_range(-1, 2), y, Color("12181F"))
	_save(img, "cave_wall")


## 发光藻丛。
func _glow_algae() -> void:
	var img := _img(16, 22)
	var r := _rng("glow_algae")
	for i in 5:
		var bx := 3 + r.randi_range(0, 9)
		var by := 20 - r.randi_range(0, 6)
		var h := 6 + r.randi_range(0, 8)
		for t in h:
			var col := TEAL_D.lerp(TEAL, float(t) / h)
			_px(img, bx + int(round(sin(t * 0.6 + i * 2.0) * 1.5)), by - t, col)
			if t == h - 1:
				_px(img, bx + int(round(sin(t * 0.6 + i * 2.0) * 1.5)), by - t - 1, Color("9FF7EA"))
	_outline(img, Color("1A3A34"))
	_save(img, "glow_algae")


func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for y in ry * 2 + 1:
		for x in rx * 2 + 1:
			var d := Vector2(float(x - rx), float(y - ry) * (float(rx) / float(ry)))
			if d.length() <= float(rx):
				_px(img, cx - rx + x, cy - ry + y, col)


## 珊瑚（0=枝状粉 / 1=脑纹橙）。
func _coral(variant: int) -> void:
	var img := _img(26, 26 if variant == 0 else 30)
	var r := _rng("coral_%d" % variant)
	if variant == 0:
		var pink := Color("D86A8A")
		var pink_d := Color("A84E6A")
		for branch in [[13, 24, -1.9], [11, 24, -1.4], [15, 24, -0.8], [13, 20, -1.6]]:
			var bx: int = branch[0]
			var by: int = branch[1]
			var ang: float = branch[2]
			for t in 12:
				var p := Vector2(bx, by) + Vector2(cos(ang), sin(ang)) * t * 0.9
				_px(img, int(p.x), int(p.y), pink if t % 3 else pink_d)
				if t > 6:
					_px(img, int(p.x) + 1, int(p.y), pink_d)
		_rect(img, 9, 22, 9, 3, pink_d)
	else:
		var org := Color("D8924E")
		var org_d := Color("A86A32")
		_fill_ellipse(img, 13, 18, 9, 8, org_d)
		_fill_ellipse(img, 13, 17, 8, 7, org)
		for i in 4:
			var yy := 12 + i * 3
			for x in range(7, 20):
				if (x + i) % 3 == 0:
					_px(img, x, yy, org_d)
	_outline(img)
	_save(img, "coral_b" if variant else "coral_a")


## 异化岩石（紫脉晶石）。
func _corrupt_rock() -> void:
	var img := _img(54, 46)
	var r := _rng("corrupt_rock")
	var base := Color("3A2E44")
	for y in 44:
		var t := float(y) / 44.0
		var half := int(24 * pow(0.2 + 0.8 * t, 0.7))
		for x in range(27 - half, 27 + half):
			var shade := base.lerp(Color("241A2E"), t * 0.7)
			shade = shade.lerp(Color("524063"), maxf(0.0, 0.3 - absf(float(x) / 54.0 - 0.32) - t * 0.25))
			_px(img, x + 1, y + 1, _jit(shade, r, 0.05))
	for i in 4:
		var cx := 10 + r.randi_range(0, 32)
		var cy := 8 + r.randi_range(0, 10)
		for t in r.randi_range(12, 28):
			_px(img, cx + r.randi_range(-1, 2), cy + t,
				Color("B45AD6") if t % 3 else Color("8A3AA8"))
	_barnacles(img, r, 20, 36, 3)
	_outline(img, Color("1E1428"))
	_save(img, "corrupt_rock")


## 诅咒祭坛（石板 + 符文 + 烛座）。
func _altar() -> void:
	var img := _img(40, 34)
	var r := _rng("altar")
	_grain(img, r, Color("3A3344"), 6, 14, 28, 16, 0.04)
	_grain(img, r, Color("4A4156"), 2, 28, 36, 5, 0.04)
	for x in 36:
		_px(img, x + 2, 28, Color("5C5268"))
	_grain(img, r, Color("554A64"), 4, 10, 32, 4, 0.03)
	for i in 5:
		_px(img, 13 + i * 3, 16 + (i % 2) * 4, Color("8A2430"))
		_px(img, 14 + i * 3, 17 + (i % 2) * 4, Color("C43B4A"))
	_rect(img, 8, 7, 2, 3, Color("E8E4D0"))
	_rect(img, 30, 7, 2, 3, Color("E8E4D0"))
	_px(img, 19, 9, GOLD_D)
	_px(img, 20, 9, GOLD)
	_outline(img, Color("241E2C"))
	_save(img, "altar")


## 黑色海草（深层）。
func _seaweed_black() -> void:
	var img := _img(16, 28)
	var r := _rng("seaweed_black")
	for i in 3:
		var bx := 4 + i * 4
		var h := 16 + r.randi_range(0, 8)
		for t in h:
			var sway := int(round(sin(t * 0.5 + i * 2.0) * 1.6))
			var col := Color("3A2A4A").lerp(Color("241A30"), float(t) / h)
			_px(img, bx + sway, 27 - t, col)
			if t > h - 4:
				_px(img, bx + sway, 27 - t, Color("5A3A6A"))
	_outline(img, Color("180F22"))
	_save(img, "seaweed_black")


## 浅海小残骸（船肋残段半埋）。
func _wreck_debris() -> void:
	var img := _img(44, 30)
	var r := _rng("wreck_debris")
	for y in range(18, 28):
		var half := int(20 * (float(y - 16) / 12.0))
		for x in range(22 - half, 22 + half):
			_px(img, x, y, _jit(SILT.lerp(SILT_D, float(y) / 30.0), r, 0.05))
	for i in 3:
		var bx := 10 + i * 11
		for t in 14:
			_px(img, bx + int(t * 0.2), 24 - t, WOOD_D if t % 4 else WOOD)
			_px(img, bx + int(t * 0.2) + 1, 24 - t, WOOD_DD)
	for t in 12:
		_px(img, 4 + t, 20 - int(t * 0.4), WOOD)
	_barnacles(img, r, 14, 24, 4)
	_outline(img)
	_save(img, "wreck_debris")


## 栈桥桩柱。
func _pier_post() -> void:
	var img := _img(12, 44)
	var r := _rng("pier_post")
	_grain(img, r, WOOD_D, 4, 2, 4, 40, 0.04)
	for y in 40:
		_px(img, 4, y + 2, WOOD_L)
	for t in 8:
		_px(img, 4 + t, 10, Color("8A6B45") if t % 2 else Color("5C4428"))
	_barnacles(img, r, 4, 38, 3)
	_outline(img)
	_save(img, "pier_post")


## 柴堆。
func _wood_pile() -> void:
	var img := _img(32, 22)
	var r := _rng("wood_pile")
	for row in 2:
		var n := 4 - row
		for i in n:
			var cx := 4 + i * 7 + row * 3
			var cy := 15 - row * 7
			for x in 6:
				_px(img, cx + x, cy, WOOD_D if x % 2 else WOOD)
			_px(img, cx, cy - 1, WOOD_L)
			_px(img, cx + 5, cy, WOOD_DD)
			_px(img, cx, cy, WOOD_DD)
	_outline(img)
	_save(img, "wood_pile")


# ==================== 角色帧动画（潜水员 / 鲨鱼） ====================

const SUIT := Color("24384C")
const SUIT_D := Color("182A3A")
const SKIN := Color("C89468")
const MASK_G := Color("63C7CE")
const TANK_S := Color("9AA6B2")
const FIN_Y := Color("C9B44A")
const SHARK_C := Color("5A6470")
const SHARK_D2 := Color("454E58")
const SHARK_L := Color("8C96A2")
const BELLY := Color("C6CDD4")


## 潜水员游动帧（水平，头朝右；脚蹼相位 上/中/下/中）。
func _diver_swim(frame: int) -> void:
	var img := _img(28, 18)
	var kick: int = [-1, 0, 1, 0][frame]
	# 躯干
	for x in range(6, 20):
		for y in range(6, 12):
			var col: Color = SUIT
			if y == 11 or x == 6:
				col = SUIT_D
			_px(img, x, y, col)
	_px(img, 7, 6, SUIT_D)
	_px(img, 18, 6, SUIT_D)
	# 头 + 面镜
	for x in range(19, 24):
		for y in range(5, 11):
			if Vector2(x - 21.0, y - 8.0).length() <= 3.1:
				_px(img, x, y, SKIN)
	_rect(img, 21, 5, 4, 3, MASK_G)
	_rect(img, 21, 5, 4, 1, Color("0F2A30"))
	_px(img, 24, 7, Color("0F2A30"))
	# 背上气瓶
	_rect(img, 9, 2, 7, 4, TANK_S)
	_rect(img, 9, 2, 7, 1, Color("C9D2DA"))
	_px(img, 15, 3, Color("6A7280"))
	# 手臂沿身体前伸
	_rect(img, 16, 10, 4, 2, SUIT_D)
	_px(img, 20, 11, SKIN)
	# 双脚蹼（反相摆动）
	var f1y := 7 + kick * 2
	var f2y := 10 - kick * 2
	for t in 6:
		var drop: int = int(float(t) / 3.0 * float(kick))
		_px(img, 5 - t, f1y + drop, FIN_Y)
		_px(img, 5 - t, f1y + drop + 1, Color("9A8834"))
		_px(img, 5 - t, f2y - drop, FIN_Y)
		_px(img, 5 - t, f2y - drop + 1, Color("9A8834"))
	# 呼气气泡（隔帧）
	if frame % 2 == 1:
		_px(img, 26, 3, Color("BFE8F0"))
		_px(img, 25, 1, Color("BFE8F0"))
	_outline(img)
	_save(img, "diver_swim_%d" % frame)


## 潜水员行走帧（竖直，朝右；跨步 左/并/右/并）。
func _diver_walk(frame: int) -> void:
	var img := _img(16, 22)
	var stride: int = [1, 0, -1, 0][frame]
	# 头（额上面镜带）
	for x in range(4, 12):
		for y in range(2, 9):
			if Vector2(x - 8.0, y - 5.0).length() <= 3.2:
				_px(img, x, y, SKIN)
	_rect(img, 6, 2, 5, 1, MASK_G)
	# 躯干
	for y in range(8, 16):
		for x in range(6, 11):
			_px(img, x, y, SUIT if y < 14 else SUIT_D)
	# 腰带与扣
	_rect(img, 6, 12, 5, 1, Color("3A2E1E"))
	_px(img, 8, 12, GOLD_D)
	# 背上气瓶（右肩后侧露出）
	_rect(img, 11, 8, 2, 6, TANK_S)
	_px(img, 11, 8, Color("C9D2DA"))
	# 手臂随步伐轻摆
	_rect(img, 10 + stride, 10, 2, 4, SUIT_D)
	_px(img, 10 + stride, 14, SKIN)
	# 双腿交替
	var lx := 7 + stride
	var rx := 8 - stride
	for y in range(15, 19):
		_px(img, lx, y, SUIT_D)
		_px(img, rx, y, SUIT_D)
	_rect(img, lx - 1, 18, 3, 2, Color("14181E"))
	_rect(img, rx - 1, 18, 3, 2, Color("14181E"))
	_outline(img)
	_save(img, "diver_walk_%d" % frame)


## 鲨鱼游动帧（头朝右；尾摆相位 上/中/下/中）。
func _shark_swim(frame: int) -> void:
	var img := _img(46, 20)
	var sway: int = [-1, 0, 1, 0][frame]
	# 纺锤身体
	for x in range(6, 36):
		var t := float(x - 6) / 29.0
		var half := 2.8 + 4.6 * sin(PI * (0.12 + 0.88 * t))
		for y in range(int(round(10.0 - half)), int(round(10.0 + half)) + 1):
			var col: Color = SHARK_C
			if y >= 10:
				col = BELLY.lerp(SHARK_C, clampf(float(y - 10) / (half + 1.0), 0.0, 1.0) * 0.55)
			if x <= 10:
				col = col.darkened(0.12)
			_px(img, x, y, col)
	# 背鳍
	_rect(img, 16, 3, 2, 1, SHARK_D2)
	_rect(img, 14, 4, 6, 1, SHARK_D2)
	_rect(img, 13, 5, 8, 1, SHARK_D2)
	# 胸鳍
	for t in 5:
		_px(img, 20 - t, 14 + t / 2, SHARK_D2)
	# 鳃缝
	for g in 3:
		_px(img, 24 - g * 2, 11, SHARK_D2)
		_px(img, 24 - g * 2, 12, SHARK_D2)
	# 嘴线与眼
	for t in 4:
		_px(img, 30 + t, 13, SHARK_D2)
	_px(img, 31, 8, Color("0A0C0E"))
	_px(img, 32, 8, Color("0A0C0E"))
	_px(img, 31, 7, Color.WHITE)
	# 尾部（随相位上下摆 + 上下叶）
	for t in 10:
		var ty := 10.0 + (float(t) / 10.0) * float(sway) * 4.0
		_px(img, 6 - t, int(round(ty)), SHARK_D2)
		_px(img, 6 - t, int(round(ty)) + 1, SHARK_D2)
	for t in 5:
		_px(img, 1 - t / 2, int(8 + sway * 3) - t / 2, SHARK_D2)
		_px(img, 1 - t / 2, int(12 + sway * 3) + t / 2, SHARK_D2)
	_outline(img)
	_save(img, "shark_swim_%d" % frame)

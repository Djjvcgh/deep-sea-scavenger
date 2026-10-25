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

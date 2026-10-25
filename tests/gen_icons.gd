extends SceneTree
## 物品图标生成器：64×64 像素风占位图标（原创程序绘制，无第三方素材）。
## godot --headless -s res://tests/gen_icons.gd
## 输出 res://assets/icons/items/<物品id>.png，可重复运行（幂等覆盖）。

const OUT_DIR := "res://assets/icons/items"
const S := 64

# 统一色板（与游戏 UI 配色一致）
const GOLD := Color(0.95, 0.78, 0.25)
const GOLD_DARK := Color(0.6, 0.45, 0.12)
const SILVER := Color(0.8, 0.84, 0.9)
const SILVER_DARK := Color(0.5, 0.54, 0.62)
const BRONZE := Color(0.72, 0.55, 0.3)
const BRONZE_DARK := Color(0.45, 0.32, 0.14)
const OUTLINE := Color(0.08, 0.07, 0.06)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_old_coin()
	_pearl()
	_bronze_coins()
	_silver_platter()
	_gold_cup()
	_cursed_idol()
	_captain_compass()
	_gold_sextant()
	_ritual_relic()
	_cursed_relic()
	_serpent_pearl()
	_figurehead_blacktide()
	_wood()
	_iron()
	_canvas()
	_leather()
	print("图标生成完成：%s（16 个）" % OUT_DIR)
	quit(0)


# ---------------- 图标绘制 ----------------

func _old_coin() -> void:
	var img := _new()
	_fill_ellipse(img, 32, 33, 20, 20, OUTLINE)
	_fill_ellipse(img, 32, 32, 18, 18, GOLD_DARK)
	_fill_ellipse(img, 32, 32, 14, 14, GOLD)
	# 硬币面的王冠剪影
	_fill_poly(img, [Vector2(24, 36), Vector2(40, 36), Vector2(38, 28), Vector2(33, 32),
		Vector2(32, 26), Vector2(31, 32), Vector2(26, 28)], GOLD_DARK)
	# 左上高光
	_ring_arc(img, 32, 32, 15, 1.0, -2.4, -1.2, Color(1.0, 0.92, 0.6))
	_save(img, "old_coin")


func _pearl() -> void:
	var img := _new()
	# 底衬：张开的小贝壳
	_fill_poly(img, [Vector2(10, 50), Vector2(32, 40), Vector2(54, 50), Vector2(32, 56)], Color(0.85, 0.6, 0.68))
	_fill_ellipse(img, 32, 34, 17, 18, Color(0.7, 0.66, 0.7))
	_fill_ellipse(img, 32, 34, 15, 16, Color(0.92, 0.86, 0.9))
	_fill_ellipse(img, 32, 40, 11, 8, Color(0.82, 0.72, 0.82))
	_fill_ellipse(img, 26, 27, 4, 5, Color(1, 1, 1))
	_save(img, "pearl")


func _bronze_coins() -> void:
	var img := _new()
	for i in 3:
		var y := 42.0 - i * 9.0
		var c: Color = GOLD_DARK.lerp(BRONZE, i / 2.0)
		# 币身侧沿 + 顶面
		_fill_rect(img, 12, int(y) - 4, 40, 6, OUTLINE)
		_fill_ellipse(img, 32, y, 20, 7, c.darkened(0.25))
		_fill_ellipse(img, 32, y - 3, 20, 7, c)
		_fill_ellipse(img, 32, y - 3, 14, 4, c.lightened(0.12))
	_save(img, "bronze_coins")


func _silver_platter() -> void:
	var img := _new()
	_fill_ellipse(img, 32, 40, 25, 11, OUTLINE)
	_fill_ellipse(img, 32, 39, 23, 10, SILVER_DARK)
	_fill_ellipse(img, 32, 37, 23, 10, SILVER)
	_fill_ellipse(img, 32, 36, 17, 6, Color(0.9, 0.93, 0.96))
	# 盘心刻纹
	_ring_arc(img, 32, 36, 9, 1.0, 0.2, PI - 0.2, SILVER_DARK)
	_fill_ellipse(img, 32, 18, 8, 6, SILVER_DARK)
	_fill_ellipse(img, 32, 17, 8, 6, SILVER)
	_save(img, "silver_platter")


func _gold_cup() -> void:
	var img := _new()
	# 杯口与杯身
	_fill_ellipse(img, 32, 20, 15, 6, GOLD_DARK)
	_fill_poly(img, [Vector2(17, 20), Vector2(47, 20), Vector2(40, 38), Vector2(24, 38)], GOLD)
	_fill_poly(img, [Vector2(17, 20), Vector2(24, 38), Vector2(28, 38), Vector2(23, 20)], Color(1.0, 0.88, 0.5))
	_fill_ellipse(img, 32, 20, 11, 4, Color(0.5, 0.36, 0.1))
	# 杯柄
	_ring_arc(img, 17, 26, 5, 1.0, 0.5, 2.6, GOLD_DARK)
	_ring_arc(img, 47, 26, 5, 1.0, 0.5, 2.6, GOLD_DARK)
	# 杯颈与底座
	_fill_rect(img, 29, 38, 6, 10, GOLD_DARK)
	_fill_rect(img, 29, 38, 3, 10, GOLD)
	_fill_ellipse(img, 32, 50, 13, 5, GOLD)
	_fill_ellipse(img, 32, 48, 13, 4, GOLD_DARK)
	_save(img, "gold_cup")


func _cursed_idol() -> void:
	var img := _new()
	_fill_poly(img, [Vector2(18, 54), Vector2(46, 54), Vector2(41, 28), Vector2(32, 16), Vector2(23, 28)], OUTLINE)
	_fill_poly(img, [Vector2(20, 52), Vector2(44, 52), Vector2(39, 28), Vector2(32, 19), Vector2(25, 28)], Color(0.5, 0.28, 0.62))
	_fill_poly(img, [Vector2(20, 52), Vector2(28, 52), Vector2(26, 28), Vector2(32, 19), Vector2(25, 28)], Color(0.66, 0.42, 0.78))
	# 双眼与紫光纹
	_fill_ellipse(img, 26, 34, 3.5, 4.5, Color(0.98, 0.85, 0.3))
	_fill_ellipse(img, 38, 34, 3.5, 4.5, Color(0.98, 0.85, 0.3))
	_fill_ellipse(img, 26, 34, 1.5, 2.2, OUTLINE)
	_fill_ellipse(img, 38, 34, 1.5, 2.2, OUTLINE)
	_fill_rect(img, 30, 42, 4, 8, Color(0.78, 0.5, 0.92))
	_save(img, "cursed_idol")


func _captain_compass() -> void:
	var img := _new()
	_fill_ellipse(img, 32, 32, 21, 21, OUTLINE)
	_fill_ellipse(img, 32, 32, 19, 19, GOLD_DARK)
	_fill_ellipse(img, 32, 32, 16, 16, Color(0.12, 0.16, 0.22))
	# 指针：北红南白
	_fill_poly(img, [Vector2(32, 16), Vector2(36, 32), Vector2(28, 32)], Color(0.9, 0.3, 0.25))
	_fill_poly(img, [Vector2(32, 48), Vector2(36, 32), Vector2(28, 32)], Color(0.9, 0.92, 0.95))
	_fill_ellipse(img, 32, 32, 3, 3, GOLD)
	# 刻度
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		_line(img, Vector2(32, 32) + Vector2(cos(a), sin(a)) * 13.0,
			Vector2(32, 32) + Vector2(cos(a), sin(a)) * 16.0, 1, GOLD_DARK)
	_save(img, "captain_compass")


func _gold_sextant() -> void:
	var img := _new()
	# 60° 弧框
	_ring_arc(img, 28, 40, 22, 2.5, -PI * 0.55, -PI * 0.05, OUTLINE)
	_ring_arc(img, 28, 40, 21, 2.0, -PI * 0.55, -PI * 0.05, GOLD)
	# 照准架与支臂
	_line(img, Vector2(28, 40), Vector2(48, 22), 3, GOLD_DARK)
	_line(img, Vector2(28, 40), Vector2(48, 22), 1.6, GOLD)
	_line(img, Vector2(20, 52), Vector2(40, 30), 1.5, SILVER)
	_fill_rect(img, 44, 16, 8, 6, SILVER_DARK)
	_fill_rect(img, 44, 16, 8, 2, SILVER)
	_fill_ellipse(img, 28, 40, 3.5, 3.5, OUTLINE)
	_fill_ellipse(img, 28, 40, 2.5, 2.5, GOLD)
	_save(img, "gold_sextant")


func _ritual_relic() -> void:
	var img := _new()
	_fill_rect(img, 18, 12, 28, 40, OUTLINE)
	_fill_rect(img, 20, 14, 24, 36, Color(0.5, 0.54, 0.48))
	_fill_rect(img, 20, 14, 24, 36, Color(0.56, 0.6, 0.52))
	# 发光符文：竖线 + 眼
	_fill_rect(img, 30, 22, 4, 20, Color(0.35, 0.9, 0.85))
	_fill_ellipse(img, 32, 30, 7, 5, Color(0.35, 0.9, 0.85, 0.35))
	_fill_ellipse(img, 32, 30, 2.5, 2.5, Color(0.8, 1.0, 0.98))
	# 底座与裂纹
	_fill_rect(img, 16, 50, 32, 5, Color(0.4, 0.42, 0.38))
	_line(img, Vector2(24, 46), Vector2(28, 38), 1, Color(0.36, 0.4, 0.36))
	_save(img, "ritual_relic")


func _cursed_relic() -> void:
	var img := _new()
	# 挂环
	_ring_arc(img, 32, 12, 5, 1.5, PI, TAU, SILVER_DARK)
	_fill_ellipse(img, 32, 34, 19, 19, OUTLINE)
	_fill_ellipse(img, 32, 34, 17, 17, Color(0.16, 0.1, 0.2))
	# 紫晶核心 + 辉光
	_fill_ellipse(img, 32, 34, 10, 10, Color(0.42, 0.16, 0.52))
	_fill_ellipse(img, 32, 34, 7, 7, Color(0.72, 0.32, 0.9))
	_fill_ellipse(img, 30, 32, 2.5, 2.5, Color(0.95, 0.8, 1.0))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		_line(img, Vector2(32, 34) + Vector2(cos(a), sin(a)) * 12.0,
			Vector2(32, 34) + Vector2(cos(a), sin(a)) * 16.0, 1, Color(0.6, 0.3, 0.75))
	_save(img, "cursed_relic")


func _serpent_pearl() -> void:
	var img := _new()
	_fill_ellipse(img, 32, 32, 20, 20, OUTLINE)
	_fill_ellipse(img, 32, 32, 18, 18, Color(0.1, 0.4, 0.38))
	_fill_ellipse(img, 32, 32, 15, 15, Color(0.22, 0.68, 0.62))
	# 蛇瞳：竖缝
	_fill_ellipse(img, 32, 32, 4, 11, Color(0.05, 0.1, 0.1))
	_fill_ellipse(img, 32, 32, 1.5, 6, Color(0.95, 0.9, 0.4))
	_fill_ellipse(img, 26, 25, 4, 3, Color(0.7, 0.95, 0.9, 0.8))
	_save(img, "serpent_pearl")


func _wood() -> void:
	var img := _new()
	_fill_rect(img, 10, 24, 44, 18, OUTLINE)
	_fill_rect(img, 12, 26, 40, 14, Color(0.5, 0.35, 0.18))
	_fill_rect(img, 12, 26, 40, 5, Color(0.62, 0.45, 0.24))
	# 树皮纹
	for lx in [20, 30, 40]:
		_line(img, Vector2(lx, 28), Vector2(lx - 2, 38), 1, Color(0.38, 0.26, 0.12))
	# 年轮端面
	_fill_ellipse(img, 12, 33, 5, 9, Color(0.72, 0.56, 0.34))
	_fill_ellipse(img, 12, 33, 2.5, 5, Color(0.55, 0.4, 0.22))
	_save(img, "wood")


func _iron() -> void:
	var img := _new()
	_fill_poly(img, [Vector2(12, 42), Vector2(52, 42), Vector2(45, 24), Vector2(19, 24)], OUTLINE)
	_fill_poly(img, [Vector2(15, 40), Vector2(49, 40), Vector2(43, 27), Vector2(21, 27)], Color(0.55, 0.58, 0.64))
	_fill_poly(img, [Vector2(19, 24), Vector2(45, 24), Vector2(43, 27), Vector2(21, 27)], Color(0.72, 0.75, 0.8))
	_fill_poly(img, [Vector2(15, 40), Vector2(24, 40), Vector2(22, 27), Vector2(21, 27)], Color(0.68, 0.71, 0.76))
	_save(img, "iron")


func _canvas() -> void:
	var img := _new()
	# 帆布卷：布面 + 右端卷轴
	_fill_rect(img, 10, 24, 38, 18, OUTLINE)
	_fill_rect(img, 12, 26, 36, 14, Color(0.9, 0.86, 0.76))
	_fill_rect(img, 12, 26, 36, 4, Color(0.97, 0.94, 0.86))
	_line(img, Vector2(14, 34), Vector2(44, 34), 1, Color(0.72, 0.66, 0.55))
	_fill_ellipse(img, 48, 33, 8, 9, Color(0.78, 0.72, 0.6))
	_fill_ellipse(img, 48, 33, 4, 5, Color(0.6, 0.54, 0.44))
	# 捆绳
	_fill_rect(img, 22, 24, 3, 18, Color(0.5, 0.36, 0.18))
	_save(img, "canvas")


func _leather() -> void:
	var img := _new()
	# 兽皮外形
	_fill_poly(img, [Vector2(14, 26), Vector2(30, 16), Vector2(50, 24), Vector2(46, 44), Vector2(22, 48)], OUTLINE)
	_fill_poly(img, [Vector2(16, 27), Vector2(30, 19), Vector2(48, 26), Vector2(44, 42), Vector2(23, 45)], Color(0.55, 0.38, 0.22))
	_fill_poly(img, [Vector2(16, 27), Vector2(30, 19), Vector2(34, 24), Vector2(24, 34)], Color(0.66, 0.47, 0.28))
	# 缝线
	for i in 5:
		var t := i / 4.0
		_line(img, Vector2(17, 27).lerp(Vector2(48, 26), t) + Vector2(0, 1),
			Vector2(17, 27).lerp(Vector2(48, 26), t) + Vector2(0, 4), 1, Color(0.35, 0.22, 0.1))
	_save(img, "leather")


func _figurehead_blacktide() -> void:
	var img := _new()
	# 展翼造型：双翼 + 船首躯体 + 铆钉缘饰
	_fill_poly(img, [Vector2(6, 40), Vector2(26, 24), Vector2(28, 34), Vector2(12, 46)], Color(0.55, 0.74, 0.72))
	_fill_poly(img, [Vector2(58, 40), Vector2(38, 24), Vector2(36, 34), Vector2(52, 46)], Color(0.55, 0.74, 0.72))
	_fill_poly(img, [Vector2(8, 42), Vector2(24, 29), Vector2(25, 34), Vector2(13, 44)], Color(0.72, 0.92, 0.88))
	_fill_poly(img, [Vector2(56, 42), Vector2(40, 29), Vector2(39, 34), Vector2(51, 44)], Color(0.72, 0.92, 0.88))
	# 船首躯体（深色船木）与金色缘饰
	_fill_poly(img, [Vector2(22, 52), Vector2(42, 52), Vector2(46, 30), Vector2(32, 10), Vector2(18, 30)], OUTLINE)
	_fill_poly(img, [Vector2(24, 50), Vector2(40, 50), Vector2(43, 30), Vector2(32, 13), Vector2(21, 30)], Color(0.36, 0.26, 0.16))
	_fill_poly(img, [Vector2(24, 50), Vector2(32, 50), Vector2(32, 13), Vector2(21, 30)], Color(0.48, 0.35, 0.2))
	_ring_arc(img, 32, 12, 5, 1.5, PI, TAU, GOLD_DARK)
	# 胸口海蓝宝石
	_fill_ellipse(img, 32, 34, 6, 8, Color(0.16, 0.5, 0.48))
	_fill_ellipse(img, 32, 34, 4, 6, Color(0.45, 0.88, 0.8))
	_fill_ellipse(img, 30, 31, 1.5, 2, Color(0.9, 1.0, 0.98))
	# 底座缘饰与铆钉
	_fill_rect(img, 20, 50, 24, 5, GOLD_DARK)
	_fill_rect(img, 20, 50, 24, 2, GOLD)
	for x in [24, 32, 40]:
		_fill_ellipse(img, x, 52.5, 1.5, 1.5, GOLD)
	_save(img, "figurehead_blacktide")


# ---------------- 绘制基元 ----------------

func _new() -> Image:
	return Image.create(S, S, false, Image.FORMAT_RGBA8)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < S and y >= 0 and y < S:
		img.set_pixel(x, y, c)


func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(maxi(0, int(floor(cy - ry))), mini(S, int(ceil(cy + ry)) + 1)):
		for x in range(maxi(0, int(floor(cx - rx))), mini(S, int(ceil(cx + rx)) + 1)):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				_px(img, x, y, c)


## 椭圆弧环（角度制弧度，-PI 朝左，顺时针到 TAU），用于杯柄/罗盘高光/弧框
func _ring_arc(img: Image, cx: float, cy: float, r: float, w: float, a0: float, a1: float, c: Color) -> void:
	var steps := int(maxf(12.0, absf(a1 - a0) * r))
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / float(steps))
		var p := Vector2(cx, cy) + Vector2(cos(a), sin(a)) * r
		_fill_ellipse(img, p.x, p.y, w, w, c)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(0, y), mini(S, y + h)):
		for xx in range(maxi(0, x), mini(S, x + w)):
			_px(img, xx, yy, c)


func _fill_poly(img: Image, pts: Array, c: Color) -> void:
	var miny := int(floor(pts[0].y))
	var maxy := int(ceil(pts[0].y))
	for p in pts:
		miny = mini(miny, int(floor(p.y)))
		maxy = maxi(maxy, int(ceil(p.y)))
	for y in range(maxi(0, miny), mini(S, maxy + 1)):
		var xs: Array = []
		var yc := y + 0.5
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			for x in range(maxi(0, int(ceil(xs[k] - 0.5))), mini(S, int(ceil(xs[k + 1] - 0.5)))):
				_px(img, x, y, c)
			k += 2


func _line(img: Image, from: Vector2, to: Vector2, w: float, c: Color) -> void:
	var len := from.distance_to(to)
	var steps := int(maxf(1.0, len * 2.0))
	for i in steps + 1:
		var p := from.lerp(to, float(i) / float(steps))
		_fill_ellipse(img, p.x, p.y, w, w, c)


func _save(img: Image, item_id: String) -> void:
	img.save_png(OUT_DIR + "/" + item_id + ".png")

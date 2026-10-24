extends Control
## 船只示意图：随材料投入逐步显形（船体=木材，桅杆=铁件，船帆=帆布）。

func _ready() -> void:
	custom_minimum_size = Vector2(0, 180)
	GameState.boat_changed.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var water_y := h * 0.72

	draw_line(Vector2(10, water_y), Vector2(w - 10, water_y), Color(0.3, 0.5, 0.55, 0.8), 2.0)

	var wood_r: float = clampf(float(GameState.boat_invested["wood"]) / 2.0, 0.0, 1.0)
	var iron_r: float = clampf(float(GameState.boat_invested["iron"]) / 1.0, 0.0, 1.0)
	var canvas_r: float = clampf(float(GameState.boat_invested["canvas"]) / 1.0, 0.0, 1.0)

	# 船体
	var hull := PackedVector2Array([
		Vector2(cx - 100, water_y), Vector2(cx + 100, water_y),
		Vector2(cx + 68, water_y + 34), Vector2(cx - 68, water_y + 34)])
	draw_colored_polygon(hull, Color(0.5, 0.34, 0.16, 0.25 + 0.75 * wood_r))
	if wood_r > 0.0:
		draw_line(Vector2(cx - 100, water_y), Vector2(cx + 100, water_y),
			Color(0.72, 0.55, 0.3, 0.4 + 0.6 * wood_r), 3.0)

	# 桅杆
	if iron_r > 0.0:
		draw_line(Vector2(cx, water_y), Vector2(cx, h * 0.16),
			Color(0.62, 0.63, 0.68, 0.3 + 0.7 * iron_r), 5.0)

	# 船帆
	if canvas_r > 0.0:
		var sail := PackedVector2Array([
			Vector2(cx + 4, h * 0.2), Vector2(cx + 4, water_y - 6), Vector2(cx + 78, water_y - 6)])
		draw_colored_polygon(sail, Color(0.92, 0.9, 0.82, 0.25 + 0.75 * canvas_r))

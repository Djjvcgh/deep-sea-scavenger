class_name UICommon
## UI 构建公用工具：统一配色与控件样式。

const GOLD := Color(0.95, 0.78, 0.25)
const DANGER := Color(0.95, 0.3, 0.25)
const ORANGE := Color(0.98, 0.6, 0.15)
const CYAN := Color(0.3, 0.75, 0.8)
const TEXT := Color(0.94, 0.93, 0.88)
const DIM := Color(0.68, 0.71, 0.75)
const GOOD := Color(0.45, 0.85, 0.5)


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	return b


static func vspace(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## 全屏半透明遮罩，挡住鼠标。
static func dim_overlay() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0.55)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


## 常用弹窗容器：居中容器（内含面板，用 get_meta("panel") 取面板）。
static func popup_panel(width: float) -> CenterContainer:
	var overlay_root := CenterContainer.new()
	overlay_root.name = "Center"
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	overlay_root.add_child(panel)
	overlay_root.set_meta("panel", panel)
	return overlay_root

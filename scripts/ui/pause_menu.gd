extends CanvasLayer
## 暂停菜单。水下模式多一个「放弃本次下潜」（丢弃临时宝物返回荒岛）。
## 有战利品时离开前二次确认。

var _underwater_mode := false


func setup(underwater_mode: bool) -> void:
	_underwater_mode = underwater_mode
	_build()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _build() -> void:
	var overlay := UICommon.dim_overlay()
	add_child(overlay)

	var popup := UICommon.popup_panel(360.0)
	add_child(popup)
	var panel: PanelContainer = popup.get_meta("panel")
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(UICommon.label("暂停", 30, UICommon.GOLD))

	var resume := UICommon.button("继续游戏", 20)
	resume.pressed.connect(close)
	box.add_child(resume)

	if _underwater_mode:
		var abandon := UICommon.button("放弃本次下潜（丢失战利品）", 18)
		abandon.pressed.connect(_confirm_leave.bind(_abandon_dive))
		box.add_child(abandon)

	var quit := UICommon.button("返回主菜单", 20)
	quit.pressed.connect(_confirm_leave.bind(_quit_to_menu))
	box.add_child(quit)


func _confirm_leave(action: Callable) -> void:
	var loot := GameState.dive_total_value()
	if loot <= 0:
		action.call()
		return
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "将丢失本次战利品（估值 %d），确定离开？" % loot
	dlg.ok_button_text = "放弃战利品"
	dlg.cancel_button_text = "继续下潜"
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	dlg.confirmed.connect(func() -> void:
		dlg.queue_free()
		action.call())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _abandon_dive() -> void:
	GameState.end_dive(false)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/island.tscn")


func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	Sfx.play("click")


func close() -> void:
	visible = false
	get_tree().paused = false

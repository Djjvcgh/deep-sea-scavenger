extends Node
## 存档管理（autoload: SaveManager）。JSON 存档，位于 user:// 目录。

const SAVE_PATH := "user://deepsea_scavenger_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("存档写入失败：%s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


## 返回存档字典；无存档或存档损坏时返回空字典。
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("存档读取失败，按无存档处理。")
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存档已损坏，按无存档处理。")
		return {}
	return parsed

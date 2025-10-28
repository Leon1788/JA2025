# res://Managers/PersistenceManager.gd
## Zentrale Save/Load-Verwaltung
## KORRIGIERT: make_abs_absolute() -> make_dir_absolute()

extends IManager

var save_directory: String = "user://saves/"
var current_save_data: Dictionary = {}

func _ready() -> void:
	super._ready()
	
	self.name = "PersistenceManager"
	
	# Erstelle Save-Verzeichnis falls nicht vorhanden
	if not DirAccess.dir_exists_absolute(save_directory):
		DirAccess.make_dir_absolute(save_directory)  # KORRIGIERT!
		_debug_log("Created save directory: %s" % save_directory)
	
	_debug_log("PersistenceManager initialized")

# ============================================================================
# SAVE SYSTEM
# ============================================================================

func save_game(save_file: String) -> bool:
	_debug_log("Saving game to: %s" % save_file)
	
	var save_data = _gather_save_data()
	var json_string = JSON.stringify(save_data)
	
	var file_path = save_directory + save_file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		_report_error("Could not open file for writing: %s" % file_path)
		return false
	
	file.store_string(json_string)
	current_save_data = save_data
	
	_debug_log("Game saved successfully to: %s" % file_path)
	return true

func load_game(save_file: String) -> bool:
	_debug_log("Loading game from: %s" % save_file)
	
	var file_path = save_directory + save_file
	
	if not FileAccess.file_exists(file_path):
		_report_error("Save file not found: %s" % file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		_report_error("Could not open file for reading: %s" % file_path)
		return false
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	
	if json.parse(json_string) != OK:
		_report_error("Could not parse JSON from: %s" % file_path)
		return false
	
	var save_data = json.data
	_apply_save_data(save_data)
	current_save_data = save_data
	
	_debug_log("Game loaded successfully from: %s" % file_path)
	return true

func _gather_save_data() -> Dictionary:
	var data = {
		"version": GameConstants.SAVE_FORMAT_VERSION,
		"save_time": TimeManager.get_full_time_string(),
		
		"time": {
			"day": TimeManager.current_day,
			"hour": TimeManager.current_hour,
			"minute": TimeManager.current_minute
		},
		
		"game_state": GameController.current_game_state,
		
		"strategic": {}
	}
	
	return data

func _apply_save_data(save_data: Dictionary) -> void:
	if save_data.get("version", -1) != GameConstants.SAVE_FORMAT_VERSION:
		_report_warning("Save file has different version!")
	
	if "time" in save_data:
		var time_data = save_data["time"]
		TimeManager.set_time(
			time_data.get("day", 1),
			time_data.get("hour", 8),
			time_data.get("minute", 0)
		)
	
	_debug_log("Save data applied")

# ============================================================================
# SAVE SLOT MANAGEMENT
# ============================================================================

func get_save_slots() -> Array:
	var slots = []
	var dir = DirAccess.open(save_directory)
	
	if dir == null:
		_report_warning("Could not open save directory: %s" % save_directory)
		return slots
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			slots.append(file_name)
		file_name = dir.get_next()
	
	return slots

func delete_save_slot(save_file: String) -> bool:
	var file_path = save_directory + save_file
	
	if not FileAccess.file_exists(file_path):
		_report_warning("Save file not found: %s" % file_path)
		return false
	
	var error = DirAccess.remove_absolute(file_path)
	
	if error == OK:
		_debug_log("Save slot deleted: %s" % save_file)
		return true
	else:
		_report_error("Could not delete save slot: %s" % save_file)
		return false

func get_save_info(save_file: String) -> Dictionary:
	var file_path = save_directory + save_file
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	
	if json.parse(json_string) != OK:
		return {}
	
	var save_data = json.data
	
	return {
		"file": save_file,
		"save_time": save_data.get("save_time", "Unknown"),
		"game_state": save_data.get("game_state", -1)
	}

func print_all_saves() -> void:
	if not GameConstants.DEBUG_ENABLED:
		return
	
	var slots = get_save_slots()
	
	print("[PersistenceManager] Available Saves:")
	for slot in slots:
		var info = get_save_info(slot)
		print("  - " + info.get("file", "?") + " (Time: " + info.get("save_time", "?") + ")")

func on_manager_activate() -> void:
	super.on_manager_activate()

func on_manager_deactivate() -> void:
	super.on_manager_deactivate()

func on_game_reset() -> void:
	super.on_game_reset()
	current_save_data.clear()
	_debug_log("PersistenceManager reset")

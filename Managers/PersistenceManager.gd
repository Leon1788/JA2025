# res://Managers/PersistenceManager.gd
## Zentrale Save/Load-Verwaltung
## 
## REFAKTORIERT: Alle _debug_log() → DebugLogger.log()

extends IManager

var save_directory: String = "user://saves/"
var current_save_data: Dictionary = {}

func _ready() -> void:
	super._ready()
	
	self.name = "PersistenceManager"
	
	# Erstelle Save-Verzeichnis falls nicht vorhanden
	if not DirAccess.dir_exists_absolute(save_directory):
		DirAccess.make_dir_absolute(save_directory)
		DebugLogger.log(self.name, "Created save directory: %s" % save_directory)
	
	DebugLogger.log(self.name, "PersistenceManager initialized")

# ============================================================================
# SAVE SYSTEM
# ============================================================================

func save_game(save_file: String) -> bool:
	DebugLogger.log(self.name, "Saving game to: %s" % save_file)
	
	var save_data = _gather_save_data()
	var json_string = JSON.stringify(save_data)
	
	var file_path = save_directory + save_file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		_report_error("Could not open file for writing: %s" % file_path)
		return false
	
	file.store_string(json_string)
	current_save_data = save_data
	
	DebugLogger.log(self.name, "Game saved successfully to: %s" % file_path)
	return true

func load_game(save_file: String) -> bool:
	DebugLogger.log(self.name, "Loading game from: %s" % save_file)
	
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
	
	DebugLogger.log(self.name, "Game loaded successfully from: %s" % file_path)
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
	
	# TODO: Apply strategic data
	DebugLogger.log(self.name, "Save data applied")

# ============================================================================
# SAVE FILE MANAGEMENT
# ============================================================================

## Gib alle verfügbaren Save-Slots zurück
func get_save_slots() -> Array:
	return get_save_files()

func get_save_files() -> Array:
	var files: Array = []
	var dir = DirAccess.open(save_directory)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				files.append(file_name)
			file_name = dir.get_next()
	
	DebugLogger.log(self.name, "Found %d save files" % files.size())
	return files

func delete_save_file(save_file: String) -> bool:
	var file_path = save_directory + save_file
	var result = DirAccess.remove_absolute(file_path)
	
	if result == OK:
		DebugLogger.log(self.name, "Save file deleted: %s" % save_file)
		return true
	else:
		_report_error("Failed to delete save file: %s" % save_file)
		return false

func save_file_exists(save_file: String) -> bool:
	var file_path = save_directory + save_file
	return FileAccess.file_exists(file_path)

# ============================================================================
# DATA EXPORT (für Debug/Mods)
# ============================================================================

func export_save_to_json(save_file: String, export_path: String) -> bool:
	if not save_file_exists(save_file):
		_report_error("Save file does not exist: %s" % save_file)
		return false
	
	var file_path = save_directory + save_file
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	
	var export_file = FileAccess.open(export_path, FileAccess.WRITE)
	if export_file == null:
		_report_error("Could not open export file: %s" % export_path)
		return false
	
	export_file.store_string(content)
	DebugLogger.log(self.name, "Save exported to: %s" % export_path)
	return true

# ============================================================================
# MANAGER INTERFACE (von IManager)
# ============================================================================

func on_manager_activate() -> void:
	super.on_manager_activate()

func on_manager_deactivate() -> void:
	super.on_manager_deactivate()

func on_game_reset() -> void:
	super.on_game_reset()
	current_save_data.clear()
	DebugLogger.log(self.name, "PersistenceManager reset")

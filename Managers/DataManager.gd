# res://Managers/DataManager.gd
## Zentrale Daten-Verwaltung und Asset-Loader
## 
## REFAKTORIERT (30.10.2025):
## - Nutzt jetzt ResourceLoader.load() statt load()
## - Prüft mit FileAccess.file_exists()
## - Wirft _report_error() statt _report_warning(), wenn
##   Ressourcen-Laden fehlschlägt.

extends IManager

# ============================================================================
# PROPERTIES - CACHES
# ============================================================================

var weapon_cache: Dictionary = {}
var merc_cache: Dictionary = {}
var attachment_cache: Dictionary = {}
var map_cache: Dictionary = {}

# ============================================================================
# EIGENSCHAFTEN - PFADE
# ============================================================================

const WEAPONS_PATH: String = "res://Data/Weapons/"
const MERCS_PATH: String = "res://Data/Mercs/"
const ATTACHMENTS_PATH: String = "res://Data/Attachments/"
const MAPS_PATH: String = "res://Data/Maps/"
const CONFIG_PATH: String = "res://Data/Config/"

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	self.name = "DataManager"
	_preload_essential_data()
	
	_debug_log("DataManager initialized with %d weapons, %d mercs, %d attachments" % [weapon_cache.size(), merc_cache.size(), attachment_cache.size()])

func _preload_essential_data() -> void:
	_debug_log("Pre-loading essential data...")
	_load_all_from_directory(WEAPONS_PATH, _load_weapon)
	_load_all_from_directory(MERCS_PATH, _load_merc)
	_load_all_from_directory(ATTACHMENTS_PATH, _load_attachment)

## NEU: Generische Ladefunktion
func _load_all_from_directory(path: String, load_func: Callable) -> void:
	var dir = DirAccess.open(path)
	
	if dir == null:
		# Erstelle Verzeichnis, falls es fehlt
		DirAccess.make_dir_recursive_absolute(path)
		dir = DirAccess.open(path)
		if dir == null:
			_report_error("Konnte Verzeichnis nicht öffnen oder erstellen: %s" % path)
			return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource_id = file_name.trim_suffix(".tres")
			load_func.call(resource_id)
		
		file_name = dir.get_next()

# ============================================================================
# WAFFEN LOADING
# ============================================================================

func _load_weapon(weapon_id: String) -> void:
	if weapon_cache.has(weapon_id):
		return
	
	var resource_path = WEAPONS_PATH + weapon_id + ".tres"
	
	# REFAKTORIERT: Nutzt ResourceLoader für bessere Fehler
	if not FileAccess.file_exists(resource_path):
		_report_error("Ressource nicht gefunden: %s" % resource_path)
		return

	var resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if resource == null:
		_report_error("Konnte Waffe nicht laden: %s. Ist die .tres Datei beschädigt oder der Pfad im Inneren falsch?" % resource_path)
		return
	
	weapon_cache[weapon_id] = resource
	_debug_log("Loaded weapon: %s" % weapon_id)

func get_weapon(weapon_id: String) -> Resource:
	if not weapon_cache.has(weapon_id):
		_load_weapon(weapon_id)
	
	return weapon_cache.get(weapon_id, null)

func get_all_weapon_ids() -> Array:
	return weapon_cache.keys()

func get_weapon_count() -> int:
	return weapon_cache.size()

# ============================================================================
# MERCS LOADING
# ============================================================================

func _load_merc(merc_id: String) -> void:
	if merc_cache.has(merc_id):
		return
	
	var resource_path = MERCS_PATH + merc_id + ".tres"
	if not FileAccess.file_exists(resource_path):
		_report_error("Ressource nicht gefunden: %s" % resource_path)
		return
		
	var resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if resource == null:
		_report_error("Konnte Merc nicht laden: %s" % resource_path)
		return
	
	merc_cache[merc_id] = resource
	_debug_log("Loaded merc: %s" % merc_id)

func get_merc(merc_id: String) -> Resource:
	if not merc_cache.has(merc_id):
		_load_merc(merc_id)
	
	return merc_cache.get(merc_id, null)

func get_all_merc_ids() -> Array:
	return merc_cache.keys()

func get_merc_count() -> int:
	return merc_cache.size()

# ============================================================================
# ATTACHMENTS LOADING
# ============================================================================

func _load_attachment(attachment_id: String) -> void:
	if attachment_cache.has(attachment_id):
		return
	
	var resource_path = ATTACHMENTS_PATH + attachment_id + ".tres"
	if not FileAccess.file_exists(resource_path):
		_report_error("Ressource nicht gefunden: %s" % resource_path)
		return

	var resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if resource == null:
		_report_error("Konnte Attachment nicht laden: %s" % resource_path)
		return
	
	attachment_cache[attachment_id] = resource
	_debug_log("Loaded attachment: %s" % attachment_id)

func get_attachment(attachment_id: String) -> Resource:
	if not attachment_cache.has(attachment_id):
		_load_attachment(attachment_id)
	
	return attachment_cache.get(attachment_id, null)

func get_all_attachment_ids() -> Array:
	return attachment_cache.keys()

func get_attachment_count() -> int:
	return attachment_cache.size()

# ============================================================================
# MAPS LOADING
# ============================================================================

func _load_map(map_id: String) -> void:
	if map_cache.has(map_id):
		return
	
	var resource_path = MAPS_PATH + map_id + ".tres"
	var resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if resource == null:
		_report_warning("Konnte Map nicht laden: %s" % map_id)
		return
	
	map_cache[map_id] = resource
	_debug_log("Loaded map: %s" % map_id)

func get_map(map_id: String) -> Resource:
	if not map_cache.has(map_id):
		_load_map(map_id)
	
	return map_cache.get(map_id, null)

# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

func clear_all_caches() -> void:
	weapon_cache.clear()
	merc_cache.clear()
	attachment_cache.clear()
	map_cache.clear()
	_debug_log("All caches cleared")

# ============================================================================
# MANAGER INTERFACE (von IManager)
# ============================================================================

func on_manager_activate() -> void:
	super.on_manager_activate()

func on_manager_deactivate() -> void:
	super.on_manager_deactivate()

func on_game_reset() -> void:
	super.on_game_reset()
	# Nicht clearen - Assets können wiederverwendet werden
	_debug_log("DataManager reset")

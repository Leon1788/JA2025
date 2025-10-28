# res://Managers/DataManager.gd
## Zentrale Daten-Verwaltung und Asset-Loader
## 
## Verantwortlichkeiten:
## - Lade Ressourcen (Waffen, Mercs, Attachments, etc.)
## - Cache Ressourcen (keine mehrfachen Ladevorgänge)
## - Stelle zentrale Daten-Zugriff zur Verfügung
##
## WICHTIG: Dieses ist ein AutoLoad (Singleton)

extends IManager

# ============================================================================
# PROPERTIES - CACHES
# ============================================================================

## Cache für geladene Waffen
var weapon_cache: Dictionary = {}  # key = weapon_id, value = WeaponResource

## Cache für geladene Mercs
var merc_cache: Dictionary = {}  # key = merc_id, value = MercProfile

## Cache für geladene Attachments
var attachment_cache: Dictionary = {}  # key = attachment_id, value = AttachmentResource

## Cache für geladene Maps
var map_cache: Dictionary = {}  # key = map_id, value = TacticalMapData

# ============================================================================
# EIGENSCHAFTEN - PFADE
# ============================================================================

## Base Pfade für Assets
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
	
	# Pre-lade häufig verwendete Daten
	_preload_essential_data()
	
	_debug_log("DataManager initialized with %d weapons, %d mercs, %d attachments" % [weapon_cache.size(), merc_cache.size(), attachment_cache.size()])

## Pre-lade essenzielle Daten (wird beim Start aufgerufen)
func _preload_essential_data() -> void:
	_debug_log("Pre-loading essential data...")
	
	# Lade alle Waffen
	_load_all_weapons()
	
	# Lade alle Mercs
	_load_all_mercs()
	
	# Lade alle Attachments
	_load_all_attachments()

# ============================================================================
# WAFFEN LOADING
# ============================================================================

## Lade alle Waffen aus dem Weapons Ordner
func _load_all_weapons() -> void:
	var dir = DirAccess.open(WEAPONS_PATH)
	
	if dir == null:
		_report_warning("Could not open weapons directory: %s" % WEAPONS_PATH)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var weapon_id = file_name.trim_suffix(".tres")
			_load_weapon(weapon_id)
		
		file_name = dir.get_next()

## Lade eine spezifische Waffe
func _load_weapon(weapon_id: String) -> void:
	if weapon_cache.has(weapon_id):
		return  # Bereits gecacht
	
	var resource_path = WEAPONS_PATH + weapon_id + ".tres"
	var resource = load(resource_path)
	
	if resource == null:
		_report_warning("Could not load weapon: %s" % weapon_id)
		return
	
	weapon_cache[weapon_id] = resource
	_debug_log("Loaded weapon: %s" % weapon_id)

## Gib eine Waffe zurück
func get_weapon(weapon_id: String) -> Resource:
	if not weapon_cache.has(weapon_id):
		_load_weapon(weapon_id)
	
	return weapon_cache.get(weapon_id, null)

## Gib alle Waffen-IDs zurück
func get_all_weapon_ids() -> Array:
	return weapon_cache.keys()

## Gib anzahl gecachter Waffen zurück
func get_weapon_count() -> int:
	return weapon_cache.size()

# ============================================================================
# MERCS LOADING
# ============================================================================

## Lade alle Mercs aus dem Mercs Ordner
func _load_all_mercs() -> void:
	var dir = DirAccess.open(MERCS_PATH)
	
	if dir == null:
		_report_warning("Could not open mercs directory: %s" % MERCS_PATH)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var merc_id = file_name.trim_suffix(".tres")
			_load_merc(merc_id)
		
		file_name = dir.get_next()

## Lade einen spezifischen Merc
func _load_merc(merc_id: String) -> void:
	if merc_cache.has(merc_id):
		return  # Bereits gecacht
	
	var resource_path = MERCS_PATH + merc_id + ".tres"
	var resource = load(resource_path)
	
	if resource == null:
		_report_warning("Could not load merc: %s" % merc_id)
		return
	
	merc_cache[merc_id] = resource
	_debug_log("Loaded merc: %s" % merc_id)

## Gib einen Merc zurück
func get_merc(merc_id: String) -> Resource:
	if not merc_cache.has(merc_id):
		_load_merc(merc_id)
	
	return merc_cache.get(merc_id, null)

## Gib alle Merc-IDs zurück
func get_all_merc_ids() -> Array:
	return merc_cache.keys()

## Gib Anzahl gecachter Mercs zurück
func get_merc_count() -> int:
	return merc_cache.size()

# ============================================================================
# ATTACHMENTS LOADING
# ============================================================================

## Lade alle Attachments
func _load_all_attachments() -> void:
	var dir = DirAccess.open(ATTACHMENTS_PATH)
	
	if dir == null:
		_report_warning("Could not open attachments directory: %s" % ATTACHMENTS_PATH)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var attachment_id = file_name.trim_suffix(".tres")
			_load_attachment(attachment_id)
		
		file_name = dir.get_next()

## Lade ein spezifisches Attachment
func _load_attachment(attachment_id: String) -> void:
	if attachment_cache.has(attachment_id):
		return  # Bereits gecacht
	
	var resource_path = ATTACHMENTS_PATH + attachment_id + ".tres"
	var resource = load(resource_path)
	
	if resource == null:
		_report_warning("Could not load attachment: %s" % attachment_id)
		return
	
	attachment_cache[attachment_id] = resource
	_debug_log("Loaded attachment: %s" % attachment_id)

## Gib ein Attachment zurück
func get_attachment(attachment_id: String) -> Resource:
	if not attachment_cache.has(attachment_id):
		_load_attachment(attachment_id)
	
	return attachment_cache.get(attachment_id, null)

## Gib alle Attachment-IDs zurück
func get_all_attachment_ids() -> Array:
	return attachment_cache.keys()

## Gib Anzahl gecachter Attachments zurück
func get_attachment_count() -> int:
	return attachment_cache.size()

# ============================================================================
# MAPS LOADING
# ============================================================================

## Lade eine spezifische Map
func _load_map(map_id: String) -> void:
	if map_cache.has(map_id):
		return  # Bereits gecacht
	
	var resource_path = MAPS_PATH + map_id + ".tres"
	var resource = load(resource_path)
	
	if resource == null:
		_report_warning("Could not load map: %s" % map_id)
		return
	
	map_cache[map_id] = resource
	_debug_log("Loaded map: %s" % map_id)

## Gib eine Map zurück
func get_map(map_id: String) -> Resource:
	if not map_cache.has(map_id):
		_load_map(map_id)
	
	return map_cache.get(map_id, null)

# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

## Cleere den Waffen-Cache (z.B. wenn neue Waffen geladen werden)
func clear_weapon_cache() -> void:
	weapon_cache.clear()
	_debug_log("Weapon cache cleared")

## Cleere den Merc-Cache
func clear_merc_cache() -> void:
	merc_cache.clear()
	_debug_log("Merc cache cleared")

## Cleere den Attachment-Cache
func clear_attachment_cache() -> void:
	attachment_cache.clear()
	_debug_log("Attachment cache cleared")

## Cleere alle Caches
func clear_all_caches() -> void:
	weapon_cache.clear()
	merc_cache.clear()
	attachment_cache.clear()
	map_cache.clear()
	_debug_log("All caches cleared")

# ============================================================================
# DEBUG
# ============================================================================

## Gib Cache-Info aus
func print_cache_info() -> void:
	if not GameConstants.DEBUG_ENABLED:
		return
	
	print("[DataManager] Cache Info:")
	print("  Weapons: %d" % weapon_cache.size())
	print("  Mercs: %d" % merc_cache.size())
	print("  Attachments: %d" % attachment_cache.size())
	print("  Maps: %d" % map_cache.size())

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

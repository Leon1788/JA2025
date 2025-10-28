# res://Managers/GameController.gd
## Zentrale Zustandsmaschine für das gesamte Spiel
## 
## WICHTIG: TODO-Kommentare für fehlende Komponenten!

extends IManager

var current_game_state: int = GameConstants.GAME_STATE.MAIN_MENU
var current_scene: Node = null
var is_game_paused: bool = false
var current_event_bus: EventBus = null

signal game_state_changed(new_state: int)
signal scene_loaded(scene_name: String)
signal scene_unloaded(scene_name: String)

func _ready() -> void:
	super._ready()
	self.name = "GameController"
	current_game_state = GameConstants.GAME_STATE.MAIN_MENU
	_debug_log("GameController initialized. Starting state: %s" % GameConstants.GAME_STATE.keys()[current_game_state])

func _process(delta: float) -> void:
	_handle_global_input()

# ============================================================================
# SZENEN-MANAGEMENT
# ============================================================================

func load_scene(scene_path: String, new_game_state: int) -> void:
	_debug_log("Loading scene: %s" % scene_path)
	
	if current_scene != null:
		_unload_current_scene()
	
	current_game_state = new_game_state
	game_state_changed.emit(new_game_state)
	
	var scene = load(scene_path)
	if scene == null:
		_report_error("Could not load scene: %s" % scene_path)
		return
	
	current_scene = scene.instantiate()
	get_tree().root.add_child(current_scene)
	
	current_event_bus = current_scene.get_node_or_null("EventBus")
	
	scene_loaded.emit(scene_path)
	_debug_log("Scene loaded: %s" % scene_path)

func _unload_current_scene() -> void:
	if current_scene == null:
		return
	
	var scene_name = current_scene.name
	current_scene.queue_free()
	current_scene = null
	current_event_bus = null
	
	scene_unloaded.emit(scene_name)
	_debug_log("Scene unloaded: %s" % scene_name)

# ============================================================================
# GAME STATE MANAGEMENT
# ============================================================================

func go_to_main_menu() -> void:
	_debug_log("Switching to Main Menu")
	load_scene("res://UI/Common/MainMenu.tscn", GameConstants.GAME_STATE.MAIN_MENU)

func start_new_game() -> void:
	_debug_log("Starting new game")
	
	# Reset TimeManager
	if TimeManager and TimeManager is IManager:
		TimeManager.on_game_reset()
	
	# TODO: StrategicManager als AutoLoad hinzufügen und hier aufrufen:
	# if StrategicManager and StrategicManager is IManager:
	#     StrategicManager.on_game_reset()
	
	# TODO: Strategic Scene laden:
	# load_scene("res://Modules/Strategic/StrategicScene.tscn", GameConstants.GAME_STATE.STRATEGIC_MAP)
	
	_debug_log("New game started")

func load_game(save_file: String) -> void:
	_debug_log("Loading game: %s" % save_file)
	
	if PersistenceManager.load_game(save_file):
		_debug_log("Game loaded successfully")
		# TODO: StrategicManager Daten laden
	else:
		_report_error("Failed to load game: %s" % save_file)

func save_game(save_file: String) -> void:
	_debug_log("Saving game: %s" % save_file)
	
	if PersistenceManager.save_game(save_file):
		_debug_log("Game saved successfully")
	else:
		_report_error("Failed to save game: %s" % save_file)

# ============================================================================
# COMBAT MANAGEMENT
# ============================================================================

func start_tactical_combat(combat_data: Dictionary) -> void:
	_debug_log("Starting tactical combat with map: %s" % combat_data.get("map_id", "unknown"))
	
	# TODO: TacticalManager als AutoLoad hinzufügen und Daten übergeben
	# if TacticalManager:
	#     TacticalManager.setup_combat(combat_data)
	
	load_scene("res://Modules/Tactical/TacticalScene.tscn", GameConstants.GAME_STATE.TACTICAL_COMBAT)

func end_tactical_combat(victory: bool) -> void:
	_debug_log("Ending tactical combat. Victory: %s" % victory)
	
	# TODO: StrategicManager mit Victory-Status updaten
	# if StrategicManager:
	#     StrategicManager.on_combat_ended(victory)
	
	# TODO: Zurück zur Strategic Map
	# load_scene("res://Modules/Strategic/StrategicScene.tscn", GameConstants.GAME_STATE.STRATEGIC_MAP)

# ============================================================================
# PAUSE SYSTEM
# ============================================================================

func pause_game() -> void:
	if is_game_paused:
		return
	
	is_game_paused = true
	get_tree().paused = true
	
	if current_event_bus:
		current_event_bus.game_paused.emit(true)
	
	_debug_log("Game paused")

func unpause_game() -> void:
	if not is_game_paused:
		return
	
	is_game_paused = false
	get_tree().paused = false
	
	if current_event_bus:
		current_event_bus.game_paused.emit(false)
	
	_debug_log("Game unpaused")

func toggle_pause() -> void:
	if is_game_paused:
		unpause_game()
	else:
		pause_game()

# ============================================================================
# GLOBAL INPUT HANDLING
# ============================================================================

func _handle_global_input() -> void:
	if Input.is_action_just_pressed("ui_f9"):
		save_game("quicksave.json")
	
	if Input.is_action_just_pressed("ui_f10"):
		load_game("quicksave.json")
	
	if Input.is_action_just_pressed("ui_cancel"):
		if current_game_state == GameConstants.GAME_STATE.MAIN_MENU:
			get_tree().quit()
		else:
			go_to_main_menu()

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

func get_current_game_state() -> int:
	return current_game_state

func is_in_tactical_combat() -> bool:
	return current_game_state == GameConstants.GAME_STATE.TACTICAL_COMBAT

func is_on_strategic_map() -> bool:
	return current_game_state == GameConstants.GAME_STATE.STRATEGIC_MAP

func get_game_state_name() -> String:
	return GameConstants.GAME_STATE.keys()[current_game_state]

func get_current_scene() -> Node:
	return current_scene

func get_current_event_bus() -> EventBus:
	return current_event_bus

# ============================================================================
# MANAGER INTERFACE (von IManager)
# ============================================================================

func on_manager_activate() -> void:
	super.on_manager_activate()
	_debug_log("GameController activated")

func on_manager_deactivate() -> void:
	super.on_manager_deactivate()
	_debug_log("GameController deactivated")

func on_game_reset() -> void:
	super.on_game_reset()
	current_game_state = GameConstants.GAME_STATE.MAIN_MENU
	_unload_current_scene()
	_debug_log("GameController reset")

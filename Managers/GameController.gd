# res://Managers/GameController.gd
## Zentrale Zustandsmaschine für das gesamte Spiel
## 
## WICHTIG: TODO-Kommentare für fehlende Komponenten!
## REFAKTORIERT: Alle _debug_log() → DebugLogger.log()

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
	DebugLogger.log(self.name, "GameController initialized. Starting state: %s" % GameConstants.GAME_STATE.keys()[current_game_state])

func _process(delta: float) -> void:
	_handle_global_input()

# ============================================================================
# SZENEN-MANAGEMENT
# ============================================================================

func load_scene(scene_path: String, new_game_state: int) -> void:
	DebugLogger.log(self.name, "Loading scene: %s" % scene_path)
	
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
	DebugLogger.log(self.name, "Scene loaded: %s" % scene_path)

func _unload_current_scene() -> void:
	if current_scene == null:
		return
	
	var scene_name = current_scene.name
	current_scene.queue_free()
	current_scene = null
	current_event_bus = null
	
	scene_unloaded.emit(scene_name)
	DebugLogger.log(self.name, "Scene unloaded: %s" % scene_name)

# ============================================================================
# GAME STATE MANAGEMENT
# ============================================================================

func go_to_main_menu() -> void:
	DebugLogger.log(self.name, "Switching to Main Menu")
	load_scene("res://UI/Common/MainMenu.tscn", GameConstants.GAME_STATE.MAIN_MENU)

func start_new_game() -> void:
	DebugLogger.log(self.name, "Starting new game")
	
	# Reset TimeManager
	if TimeManager and TimeManager is IManager:
		TimeManager.on_game_reset()
	
	# TODO: StrategicManager als AutoLoad hinzufügen und hier aufrufen:
	# if StrategicManager and StrategicManager is IManager:
	#     StrategicManager.on_game_reset()
	
	# TODO: Strategic Scene laden:
	# load_scene("res://Modules/Strategic/StrategicScene.tscn", GameConstants.GAME_STATE.STRATEGIC_MAP)
	
	DebugLogger.log(self.name, "New game started")

func load_game(save_file: String) -> void:
	DebugLogger.log(self.name, "Loading game: %s" % save_file)
	
	if PersistenceManager.load_game(save_file):
		DebugLogger.log(self.name, "Game loaded successfully")
		# TODO: StrategicManager Daten laden
	else:
		_report_error("Failed to load game: %s" % save_file)

func save_game(save_file: String) -> void:
	DebugLogger.log(self.name, "Saving game: %s" % save_file)
	
	if PersistenceManager.save_game(save_file):
		DebugLogger.log(self.name, "Game saved successfully")
	else:
		_report_error("Failed to save game: %s" % save_file)

# ============================================================================
# COMBAT MANAGEMENT
# ============================================================================

func start_tactical_combat(combat_data: Dictionary) -> void:
	DebugLogger.log(self.name, "Starting tactical combat with map: %s" % combat_data.get("map_id", "unknown"))
	
	# TODO: TacticalManager als AutoLoad hinzufügen und Daten übergeben
	# if TacticalManager:
	#     TacticalManager.setup_combat(combat_data)
	
	load_scene("res://Modules/Tactical/TacticalScene.tscn", GameConstants.GAME_STATE.TACTICAL_COMBAT)

func end_tactical_combat(victory: bool) -> void:
	DebugLogger.log(self.name, "Ending tactical combat. Victory: %s" % victory)
	
	# TODO: Resultate speichern
	# TODO: Strategic Scene laden
	
	go_to_main_menu()

# ============================================================================
# PAUSE SYSTEM
# ============================================================================

func pause_game() -> void:
	if is_game_paused:
		return
	
	is_game_paused = true
	get_tree().paused = true
	DebugLogger.log(self.name, "Game paused")
	
	if current_event_bus:
		current_event_bus.game_paused.emit(true)

func unpause_game() -> void:
	if not is_game_paused:
		return
	
	is_game_paused = false
	get_tree().paused = false
	DebugLogger.log(self.name, "Game unpaused")
	
	if current_event_bus:
		current_event_bus.game_paused.emit(false)

## Toggle Pause State (NEU HINZUGEFÜGT - War fehlend!)
func toggle_pause() -> void:
	if is_game_paused:
		unpause_game()
	else:
		pause_game()

# ============================================================================
# STATE QUERY FUNCTIONS (NEU HINZUGEFÜGT - Tests brauchten das!)
# ============================================================================

## Gib aktuellen Game State zurück
func get_current_game_state() -> int:
	return current_game_state

## Gib Game State Namen zurück (für Debug)
func get_game_state_name() -> String:
	var state_names = GameConstants.GAME_STATE
	if current_game_state in state_names.values():
		for key in state_names.keys():
			if state_names[key] == current_game_state:
				return key
	return "UNKNOWN"

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _handle_global_input() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if is_game_paused:
			unpause_game()
		else:
			pause_game()
	
	if Input.is_action_just_pressed("ui_select"):
		DebugLogger.log(self.name, "ENTER pressed")

# ============================================================================
# GAME EXIT
# ============================================================================

func quit_game() -> void:
	DebugLogger.log(self.name, "Quitting game")
	get_tree().quit()

# ============================================================================
# MANAGER INTERFACE (von IManager)
# ============================================================================

func on_manager_activate() -> void:
	super.on_manager_activate()
	DebugLogger.log(self.name, "GameController activated")

func on_manager_deactivate() -> void:
	super.on_manager_deactivate()
	DebugLogger.log(self.name, "GameController deactivated")

func on_game_reset() -> void:
	super.on_game_reset()
	current_game_state = GameConstants.GAME_STATE.MAIN_MENU
	is_game_paused = false
	DebugLogger.log(self.name, "GameController reset to initial state")

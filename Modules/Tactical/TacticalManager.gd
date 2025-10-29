# res://Modules/Tactical/TacticalManager.gd (REFACTORED)
## Zentrale Orchestrierung des Taktischen Kampfes
##
## VEREINFACHT: Nur noch Orchestration
## Turn Management → TurnSystem
## Action Processing → ActionSystem
## Initiative Calc → InitiativeSystem

class_name TacticalManager extends Node

# ============================================================================
# PROPERTIES - SUBSYSTEMS
# ============================================================================

var turn_system: TurnSystem = null
var action_system: ActionSystem = null
var grid: GridSystem = null

var all_units: Array = []
var player_units: Array = []
var enemy_units: Array = []

var is_combat_active: bool = false
var event_bus: EventBus = null

# ============================================================================
# SIGNALS (delegiert zu Subsystems)
# ============================================================================

signal combat_started()
signal combat_ended(victory: bool)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	self.name = "TacticalManager"
	DebugLogger.log("TacticalManager", "Initialized")

func _process(delta: float) -> void:
	if not is_combat_active:
		return
	
	# Check wenn Kampf vorbei sein sollte
	if _check_combat_end():
		is_combat_active = false

# ============================================================================
# COMBAT INITIALIZATION
# ============================================================================

## Starte Kampf
func start_combat(
	player_mercs: Array,
	enemy_mercs: Array,
	event_bus_ref: EventBus = null
) -> void:
	
	if is_combat_active:
		DebugLogger.warn("TacticalManager", "Combat already active!")
		return
	
	player_units = player_mercs
	enemy_units = enemy_mercs
	all_units = player_mercs + enemy_mercs
	event_bus = event_bus_ref
	
	# Initialisiere Grid
	grid = GridSystem.new(
		GameConstants.TACTICAL_MAP_WIDTH,
		GameConstants.TACTICAL_MAP_HEIGHT
	)
	
	# Platziere Units
	_place_units_on_grid()
	
	# Erstelle Subsystems
	_create_subsystems()
	
	# Setup Subsystems
	turn_system.setup(player_units, enemy_units)
	action_system.setup(turn_system, event_bus, enemy_units, player_units)
	
	# Verbinde Signals
	_connect_signals()
	
	is_combat_active = true
	combat_started.emit()
	
	DebugLogger.log("TacticalManager", "Combat started! %d player, %d enemy" % [player_units.size(), enemy_units.size()])
	
	# Starte erstes Turn
	turn_system.start_first_turn()

# ============================================================================
# SUBSYSTEM CREATION
# ============================================================================

## Erstelle alle Subsystems
func _create_subsystems() -> void:
	# TurnSystem
	turn_system = TurnSystem.new()
	add_child(turn_system)
	
	# ActionSystem
	action_system = ActionSystem.new()
	add_child(action_system)
	
	DebugLogger.log("TacticalManager", "Subsystems created")

## Verbinde Signals
func _connect_signals() -> void:
	# Turn System Signals
	turn_system.turn_started.connect(_on_turn_started)
	turn_system.turn_ended.connect(_on_turn_ended)
	turn_system.round_started.connect(_on_round_started)
	turn_system.round_ended.connect(_on_round_ended)
	
	# Action System Signals
	action_system.action_completed.connect(_on_action_completed)
	action_system.interrupt_occurred.connect(_on_interrupt_occurred)

# ============================================================================
# UNIT PLACEMENT
# ============================================================================

## Platziere Units auf Grid
func _place_units_on_grid() -> void:
	# Player Units: Linke Seite
	var player_positions = [
		Vector3(2, 0, 5),
		Vector3(2, 0, 10),
		Vector3(2, 0, 15),
		Vector3(2, 0, 20)
	]
	
	for i in range(mini(player_units.size(), player_positions.size())):
		var unit = player_units[i]
		var pos = player_positions[i]
		var grid_x = int(pos.x / GameConstants.TILE_SIZE)
		var grid_z = int(pos.z / GameConstants.TILE_SIZE)
		grid.place_unit(unit, grid_x, grid_z)
		unit.activate()
	
	# Enemy Units: Rechte Seite (25 Tiles weg)
	var enemy_positions = [
		Vector3(25, 0, 5),
		Vector3(25, 0, 10),
		Vector3(25, 0, 15),
		Vector3(25, 0, 20)
	]
	
	for i in range(mini(enemy_units.size(), enemy_positions.size())):
		var unit = enemy_units[i]
		var pos = enemy_positions[i]
		var grid_x = int(pos.x / GameConstants.TILE_SIZE)
		var grid_z = int(pos.z / GameConstants.TILE_SIZE)
		grid.place_unit(unit, grid_x, grid_z)
		unit.activate()

# ============================================================================
# PUBLIC ACTION INTERFACE (von UI/Player)
# ============================================================================

## Spieler ordnet Bewegung an
func player_move_unit(target_pos: Vector3) -> bool:
	if action_system == null or not is_combat_active:
		return false
	
	return await action_system.order_move(target_pos)

## Spieler ordnet Schuss an
func player_shoot_unit(target: MercEntity) -> bool:
	if action_system == null or not is_combat_active:
		return false
	
	return await action_system.order_shoot(target)

## Spieler ordnet Reload an
func player_reload() -> bool:
	if action_system == null or not is_combat_active:
		return false
	
	return await action_system.order_reload()

## Spieler ordnet Haltungswechsel an
func player_change_stance(new_stance: int) -> bool:
	if action_system == null or not is_combat_active:
		return false
	
	return await action_system.order_stance_change(new_stance)

## Spieler beendet Turn
func player_end_turn() -> void:
	if action_system == null or not is_combat_active:
		return
	
	action_system.end_turn()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_turn_started(actor: MercEntity) -> void:
	DebugLogger.log("TacticalManager", "Turn started: %s" % actor.merc_name)
	if event_bus:
		event_bus.turn_started.emit(GameConstants.TURN_STATE.PLAYER_TURN, actor)

func _on_turn_ended() -> void:
	DebugLogger.log("TacticalManager", "Turn ended")
	if event_bus:
		event_bus.turn_ended.emit()

func _on_round_started(round_number: int) -> void:
	DebugLogger.log("TacticalManager", "Round %d started" % round_number)

func _on_round_ended() -> void:
	DebugLogger.log("TacticalManager", "Round ended")

func _on_action_completed(actor: MercEntity, action: String, success: bool) -> void:
	DebugLogger.log("TacticalManager", "Action completed: %s (%s)" % [action, "success" if success else "failed"])

func _on_interrupt_occurred(interrupter: MercEntity, target: MercEntity) -> void:
	DebugLogger.log("TacticalManager", "INTERRUPT! %s interrupts %s" % [interrupter.merc_name, target.merc_name])

# ============================================================================
# COMBAT END CHECKING
# ============================================================================

## Prüfe ob Kampf zu Ende
func _check_combat_end() -> bool:
	var player_alive = false
	var enemy_alive = false
	
	for unit in player_units:
		if unit.is_alive():
			player_alive = true
			break
	
	for unit in enemy_units:
		if unit.is_alive():
			enemy_alive = true
			break
	
	if not player_alive:
		_end_combat(false)  # Enemy win
		return true
	
	if not enemy_alive:
		_end_combat(true)  # Player win
		return true
	
	return false

## Beende Kampf
func _end_combat(victory: bool) -> void:
	is_combat_active = false
	combat_ended.emit(victory)
	DebugLogger.log("TacticalManager", "Combat ended! Victory: %s" % ("YES" if victory else "NO"))

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

func get_current_actor() -> MercEntity:
	if turn_system == null:
		return null
	return turn_system.get_current_actor()

func is_player_turn() -> bool:
	if turn_system == null:
		return false
	return turn_system.is_player_turn()

func get_all_units() -> Array:
	return all_units

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "TacticalManager:\n"
	info += "  Combat Active: %s\n" % is_combat_active
	info += "  Player Units: %d\n" % player_units.size()
	info += "  Enemy Units: %d\n" % enemy_units.size()
	
	if turn_system:
		info += "\n" + turn_system.get_debug_info()
	
	if action_system:
		info += "\n" + action_system.get_debug_info()
	
	return info

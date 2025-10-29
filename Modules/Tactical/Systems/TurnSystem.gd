# res://Modules/Tactical/Systems/TurnSystem.gd
## Turn Management System
##
## Verantwortlichkeiten:
## - Turn Order Management
## - Turn Sequencing
## - Actor Rotation
## - AP Reset

class_name TurnSystem extends Node

# ============================================================================
# PROPERTIES - TURN STATE
# ============================================================================

var turn_order: Array = []  # Sortiert nach Initiative
var current_turn: int = 0
var current_actor_index: int = 0
var current_actor: MercEntity = null

var all_units: Array = []

# ============================================================================
# SIGNALS
# ============================================================================

signal turn_started(actor: MercEntity)
signal turn_ended()
signal round_started(round_number: int)
signal round_ended()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	self.name = "TurnSystem"
	DebugLogger.log("TurnSystem", "Initialized")

## Setup mit Units
func setup(player_units: Array, enemy_units: Array) -> void:
	all_units = player_units + enemy_units
	
	# Berechne Turn Order via InitiativeSystem
	turn_order = InitiativeSystem.calculate_turn_order(player_units, enemy_units)
	
	current_turn = 0
	current_actor_index = 0
	current_actor = null
	
	DebugLogger.log("TurnSystem", "Setup with %d units" % all_units.size())
	_debug_print_turn_order()

# ============================================================================
# TURN FLOW
# ============================================================================

## Starte erste Runde
func start_first_turn() -> void:
	current_turn = 1
	round_started.emit(current_turn)
	DebugLogger.log("TurnSystem", "Round %d started" % current_turn)
	_start_actor_turn()

## Starte nächsten Actor's Turn
func _start_actor_turn() -> void:
	if current_actor_index >= turn_order.size():
		# Runde vorbei - neue Runde starten
		_end_round()
		return
	
	current_actor = turn_order[current_actor_index]
	
	# Überspringe tote Units
	if not current_actor.is_alive():
		current_actor_index += 1
		_start_actor_turn()
		return
	
	# Reset Actor's AP für neuen Turn
	_reset_actor_ap(current_actor)
	
	turn_started.emit(current_actor)
	DebugLogger.log("TurnSystem", "Turn started: %s" % current_actor.merc_name)

## Beende aktuellen Turn
func end_current_turn() -> void:
	if current_actor == null:
		return
	
	turn_ended.emit()
	DebugLogger.log("TurnSystem", "Turn ended: %s" % current_actor.merc_name)
	
	current_actor_index += 1
	_start_actor_turn()

## Beende Runde (alle Actors waren dran)
func _end_round() -> void:
	round_ended.emit()
	DebugLogger.log("TurnSystem", "Round %d ended" % current_turn)
	
	# Neue Runde
	current_turn += 1
	current_actor_index = 0
	round_started.emit(current_turn)
	DebugLogger.log("TurnSystem", "Round %d started" % current_turn)
	
	_start_actor_turn()

# ============================================================================
# AP MANAGEMENT
# ============================================================================

## Reset AP aller Units (für neue Runde)
func reset_all_ap() -> void:
	for unit in all_units:
		_reset_actor_ap(unit)

## Reset AP für einen Unit
func _reset_actor_ap(unit: MercEntity) -> void:
	var soldier_state = unit.get_component("SoldierState") as SoldierState
	if soldier_state:
		soldier_state.reset_ap_to_max()
	
	# Reset Combat State
	var combat = unit.get_component("CombatComponent") as CombatComponent
	if combat:
		combat.reset_turn_state()

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Gib aktuellen Actor zurück
func get_current_actor() -> MercEntity:
	return current_actor

## Gib aktuellen Turn zurück
func get_current_turn() -> int:
	return current_turn

## Gib Position in Turn Order zurück
func get_actor_position(actor: MercEntity) -> int:
	return turn_order.find(actor)

## Prüfe ob Spieler am Zug ist
func is_player_turn() -> bool:
	if current_actor == null:
		return false
	return current_actor.faction == "player"

## Gib nächsten Actor zurück (für UI Preview)
func get_next_actor() -> MercEntity:
	if current_actor_index + 1 >= turn_order.size():
		return null
	return turn_order[current_actor_index + 1]

## Gib alle lebenden Units zurück
func get_alive_units() -> Array:
	var alive = []
	for unit in all_units:
		if unit.is_alive():
			alive.append(unit)
	return alive

# ============================================================================
# DEBUG
# ============================================================================

func _debug_print_turn_order() -> void:
	if not GameConstants.DEBUG_ENABLED:
		return
	
	DebugLogger.log("TurnSystem", "Turn Order:")
	for i in range(turn_order.size()):
		var unit = turn_order[i]
		var init = InitiativeSystem.calculate_unit_initiative(unit)
		DebugLogger.log("TurnSystem", "  %d. %s (Initiative: %d)" % [i + 1, unit.merc_name, init])

func get_debug_info() -> String:
	var info = "TurnSystem:\n"
	info += "  Current Turn: %d\n" % current_turn
	info += "  Current Actor: %s\n" % (current_actor.merc_name if current_actor else "None")
	info += "  Actor Position: %d/%d\n" % [current_actor_index, turn_order.size()]
	info += "  Alive Units: %d/%d" % [get_alive_units().size(), all_units.size()]
	return info

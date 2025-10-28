# res://Modules/Tactical/TacticalManager.gd
## Zentrale Orchestrierung des Taktischen Kampfes
##
## Verantwortlichkeiten:
## - Turn Management
## - Unit Initiative
## - Turn Order
## - Interrupt Handling
## - Combat State

class_name TacticalManager extends Node

# ============================================================================
# PROPERTIES - COMBAT STATE
# ============================================================================

var grid: GridSystem = null
var all_units: Array = []  # Alle Units in Kampf

var player_units: Array = []
var enemy_units: Array = []

var combat_state: int = GameConstants.TURN_STATE.WAITING
var current_turn: int = 0
var current_actor: MercEntity = null

var turn_order: Array = []  # Sortiert nach Initiative
var current_actor_index: int = 0

# ============================================================================
# PROPERTIES - COMBAT CONFIG
# ============================================================================

var is_combat_active: bool = false
var is_player_turn: bool = false

# ============================================================================
# SIGNALS
# ============================================================================

signal combat_started()
signal combat_ended(victory: bool)
signal turn_started(actor: MercEntity)
signal turn_ended()
signal unit_acted(unit: MercEntity, action: String)
signal interrupt_triggered(interrupter: MercEntity, target: MercEntity)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_debug_log("TacticalManager initialized")

func _process(delta: float) -> void:
	if not is_combat_active:
		return
	
	# TODO: Handle async actions (animations, etc.)

# ============================================================================
# COMBAT INITIALIZATION
# ============================================================================

## Starte Kampf mit gegebenen Units
func start_combat(player_mercs: Array, enemy_mercs: Array) -> void:
	if is_combat_active:
		_report_warning("Combat already active!")
		return
	
	player_units = player_mercs
	enemy_units = enemy_mercs
	all_units = player_mercs + enemy_mercs
	
	# Initialisiere Grid
	grid = GridSystem.new(
		GameConstants.TACTICAL_MAP_WIDTH,
		GameConstants.TACTICAL_MAP_HEIGHT
	)
	
	# Platziere Units
	_place_units_on_grid()
	
	# Berechne Initiative
	_calculate_initiative()
	
	# Reset State
	current_turn = 0
	current_actor_index = 0
	is_combat_active = true
	combat_state = GameConstants.TURN_STATE.WAITING
	
	combat_started.emit()
	_debug_log("Combat started! %d player units, %d enemy units" % [player_units.size(), enemy_units.size()])
	
	# Starte erstes Turn
	_start_next_turn()

## Platziere Units auf Grid
func _place_units_on_grid() -> void:
	# Player Units: Linke Seite
	var player_positions = [
		Vector3(2, 0, 5),
		Vector3(2, 0, 10),
		Vector3(2, 0, 15),
		Vector3(2, 0, 20)
	]
	
	for i in range(min(player_units.size(), player_positions.size())):
		var unit = player_units[i]
		var pos = player_positions[i]
		var grid_x = int(pos.x / GameConstants.TILE_SIZE)
		var grid_z = int(pos.z / GameConstants.TILE_SIZE)
		grid.place_unit(unit, grid_x, grid_z)
		unit.activate()
	
	# Enemy Units: NAHO (25 Tiles weg - sichtbar!)
	var enemy_positions = [
		Vector3(25, 0, 5),
		Vector3(25, 0, 10),
		Vector3(25, 0, 15),
		Vector3(25, 0, 20)
	]
	
	for i in range(min(enemy_units.size(), enemy_positions.size())):
		var unit = enemy_units[i]
		var pos = enemy_positions[i]
		var grid_x = int(pos.x / GameConstants.TILE_SIZE)
		var grid_z = int(pos.z / GameConstants.TILE_SIZE)
		grid.place_unit(unit, grid_x, grid_z)
		unit.activate()

## Berechne Initiative und erstelle Turn Order
func _calculate_initiative() -> void:
	turn_order.clear()
	
	# Alle Units bekommen Initiative-Wert basierend auf Agility
	var units_with_initiative = []
	for unit in all_units:
		var initiative = unit.agility + randi() % 20  # Agility + random bonus
		units_with_initiative.append({
			"unit": unit,
			"initiative": initiative
		})
	
	# Sortiere nach Initiative (höher = früher)
	units_with_initiative.sort_custom(func(a, b): return a.initiative > b.initiative)
	
	# Extrahiere Units
	for item in units_with_initiative:
		turn_order.append(item.unit)
	
	_debug_log("Initiative calculated. Turn order:")
	for i in range(turn_order.size()):
		_debug_log("  %d. %s" % [i + 1, turn_order[i].merc_name])

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

## Starte nächstes Turn
func _start_next_turn() -> void:
	# Reset all APs
	for unit in all_units:
		var soldier_state = unit.get_component("SoldierState") as SoldierState
		if soldier_state:
			soldier_state.reset_ap_to_max()
		
		# Reset combat state
		var combat = unit.get_component("CombatComponent") as CombatComponent
		if combat:
			combat.reset_turn_state()
	
	current_turn += 1
	current_actor_index = 0
	
	_start_actor_turn()

## Starte Zug des nächsten Actors
func _start_actor_turn() -> void:
	if current_actor_index >= turn_order.size():
		# Runde vorbei
		_start_next_turn()
		return
	
	current_actor = turn_order[current_actor_index]
	
	if not current_actor.is_alive():
		# Actor tot, überspringe
		current_actor_index += 1
		_start_actor_turn()
		return
	
	is_player_turn = current_actor.faction == "player"
	combat_state = GameConstants.TURN_STATE.PLAYER_TURN if is_player_turn else GameConstants.TURN_STATE.ENEMY_TURN
	
	turn_started.emit(current_actor)
	_debug_log("Turn started: %s (%s)" % [current_actor.merc_name, current_actor.faction])
	
	# KEIN AUTO-PLAY für Enemies! Nur für Manual Testing
	# if current_actor.faction == "enemy":
	#	await _execute_enemy_turn()

## Beende aktuellen Turn
func end_actor_turn() -> void:
	if current_actor == null:
		return
	
	turn_ended.emit()
	_debug_log("Turn ended: %s" % current_actor.merc_name)
	
	current_actor_index += 1
	_start_actor_turn()

# ============================================================================
# ENEMY AI
# ============================================================================

## Führe Enemy-Turn automatisch aus (DISABLED für Testing)
func _execute_enemy_turn() -> void:
	var ai = current_actor.get_component("AIComponent") as AIComponent
	if ai == null:
		end_actor_turn()
		return
	
	# Enemy macht 1-2 Sekunden seine Moves
	await get_tree().create_timer(0.5).timeout
	
	# AI trifft Entscheidung
	# TODO: Tatsächliche AI-Logic
	
	# Placeholder: Schießen wenn möglich
	var visible_enemies = ai.current_target
	if visible_enemies == null and player_units.size() > 0:
		visible_enemies = player_units[0]
	
	if visible_enemies:
		ai.acquire_target(visible_enemies)
		await current_actor.shoot(visible_enemies)
	
	await get_tree().create_timer(0.3).timeout
	end_actor_turn()

# ============================================================================
# ACTION HANDLING
# ============================================================================

## Spieler ordnet Unit an, zu Position zu gehen
func player_order_move(unit: MercEntity, target_pos: Vector3) -> bool:
	if unit != current_actor:
		_debug_log("Not this unit's turn!")
		return false
	
	if not is_player_turn:
		_debug_log("Not player turn!")
		return false
	
	var success = await unit.move_to(target_pos)
	
	if success:
		# NUTZE InterruptSystem!
		var interrupters = InterruptSystem.get_potential_interrupters(
			enemy_units,
			unit,
			"visual"
		)
		
		# Sortiere nach Priorität
		var sorted = InterruptSystem.sort_by_priority(interrupters, unit.global_position)
		
		# Erste schießt
		if sorted.size() > 0:
			InterruptSystem.execute_interrupt_shot(sorted[0], unit, self)
	
	return success

## Spieler ordnet Unit an, zu schießen
func player_order_shoot(unit: MercEntity, target: MercEntity) -> bool:
	if unit != current_actor:
		_debug_log("Not this unit's turn!")
		return false
	
	if not is_player_turn:
		_debug_log("Not player turn!")
		return false
	
	var success = await unit.shoot(target)
	
	if success:
		# NUTZE InterruptSystem!
		var interrupters = InterruptSystem.get_potential_interrupters(
			enemy_units,
			unit,
			"visual"
		)
		
		if interrupters.size() > 0:
			var sorted = InterruptSystem.sort_by_priority(interrupters, unit.global_position)
			InterruptSystem.execute_interrupt_shot(sorted[0], unit, self)
	
	return success

# ============================================================================
# INTERRUPT SYSTEM
# ============================================================================

## Prüfe ob andere Units unterbrechen sollten
func _check_interrupt(actor: MercEntity, trigger_event_target: MercEntity) -> void:
	# Alle Enemy Units können unterbrechen
	for enemy in enemy_units:
		if enemy == actor or not enemy.is_alive():
			continue
		
		# Prüfe ob Enemy sieht/hört die Aktion
		var vision = enemy.get_component("VisionComponent") as VisionComponent
		if vision == null:
			continue
		
		var can_interrupt = vision.can_see(actor)
		
		if can_interrupt:
			# Prüfe ob genug AP
			var soldier_state = enemy.get_component("SoldierState") as SoldierState
			if soldier_state and soldier_state.current_ap >= GameConstants.AP_SHOOT_SINGLE:
				interrupt_triggered.emit(enemy, actor)
				_debug_log("INTERRUPT triggered! %s interrupts %s" % [enemy.merc_name, actor.merc_name])
				
				# Enemy schießt auf Actor (Interrupt Shot)
				await enemy.shoot(actor)

# ============================================================================
# COMBAT END
# ============================================================================

## Beende Kampf
func end_combat(victory: bool) -> void:
	is_combat_active = false
	combat_state = GameConstants.TURN_STATE.WAITING
	
	combat_ended.emit(victory)
	_debug_log("Combat ended. Victory: %s" % ("YES" if victory else "NO"))

## Prüfe ob Kampf zu Ende sein sollte
func check_combat_end() -> bool:
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
		end_combat(false)  # Enemy win
		return true
	
	if not enemy_alive:
		end_combat(true)  # Player win
		return true
	
	return false

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Gib aktuellen Actor zurück
func get_current_actor() -> MercEntity:
	return current_actor

## Gib alle Units zurück
func get_all_units() -> Array:
	return all_units

## Prüfe ob Spieler am Zug ist
func is_player_acting() -> bool:
	return is_player_turn and is_combat_active

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "TacticalManager:\n"
	info += "  Combat Active: %s\n" % is_combat_active
	info += "  Current Turn: %d\n" % current_turn
	info += "  Current Actor: %s\n" % (current_actor.merc_name if current_actor else "None")
	info += "  Player Units: %d\n" % player_units.size()
	info += "  Enemy Units: %d" % enemy_units.size()
	return info

func _debug_log(message: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[TacticalManager] " + message)

func _report_warning(message: String) -> void:
	push_warning("[TacticalManager] " + message)

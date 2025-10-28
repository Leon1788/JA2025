# res://Modules/Tactical/Components/MovementComponent.gd
## Bewegungs-Komponente - Verwaltet Unit-Bewegung
##
## Verantwortlichkeiten:
## - Pathfinding via APUtility
## - AP-Kosten berechnen
## - Bewegungs-Animation
## - Signals emittieren

class_name MovementComponent extends IComponent

# ============================================================================
# PROPERTIES - MOVEMENT STATE
# ============================================================================

var is_moving: bool = false
var current_path: Array = []
var current_position_index: int = 0
var current_tween: Tween = null  # NEU: Tween-Referenz speichern

# ============================================================================
# PROPERTIES - MOVEMENT CONFIG
# ============================================================================

## Bewegungs-Geschwindigkeit (Sekunden pro Tile)
var movement_speed: float = 0.3

## Maximale Bewegungs-Range
var max_movement_tiles: int = 20

# ============================================================================
# SIGNALS
# ============================================================================

signal movement_started(path: Array)
signal movement_progress(current_index: int, total: int)
signal movement_completed(final_position: Vector3)
signal movement_failed(reason: String)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	_debug_log("MovementComponent initialized")

func _process(delta: float) -> void:
	if not is_enabled:
		return
	
	# Animation wird via Tween gehandhabt, nicht hier

# ============================================================================
# MAIN MOVEMENT INTERFACE
# ============================================================================

## Bewege Unit zu Ziel-Position
## Gibt true zurück wenn Bewegung gestartet, false wenn fehlgeschlagen
func move_to(target_world_pos: Vector3) -> bool:
	# Verhindere doppelte Bewegungen
	if is_moving:
		_debug_log("Already moving!")
		return false
	
	# Hol SoldierState für AP-Check
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		_report_error("SoldierState component not found!")
		return false
	
	# Berechne Pfad via APUtility
	var start_pos = entity.global_position
	var path = APUtility.find_path(
		start_pos,
		target_world_pos,
		Vector2i(GameConstants.TACTICAL_MAP_WIDTH, GameConstants.TACTICAL_MAP_HEIGHT),
		soldier_state.current_stance
	)
	
	# Pfad leer = keine Route gefunden
	if path.is_empty():
		movement_failed.emit("No path found")
		_debug_log("Pathfinding failed: No path to target")
		return false
	
	# Berechne AP-Kosten
	var ap_cost = APUtility.calculate_path_cost(path, soldier_state.current_stance)
	
	_debug_log("Path found: %d tiles, AP cost: %d" % [path.size(), ap_cost])
	
	# Prüfe ob genug AP
	if not soldier_state.can_afford_ap(ap_cost):
		movement_failed.emit("Not enough AP (need %d, have %d)" % [ap_cost, soldier_state.current_ap])
		_debug_log("Not enough AP: need %d, have %d" % [ap_cost, soldier_state.current_ap])
		return false
	
	# Gebe AP aus
	if not soldier_state.spend_ap(ap_cost):
		movement_failed.emit("Failed to spend AP")
		return false
	
	# Starte Bewegungs-Animation
	current_path = path
	is_moving = true
	current_position_index = 0
	
	movement_started.emit(path)
	
	# Führe Bewegung aus (asynchron)
	await _animate_movement()
	
	return true

# ============================================================================
# MOVEMENT ANIMATION
# ============================================================================

## Animiere die Bewegung entlang des Pfads
func _animate_movement() -> void:
	for i in range(current_path.size()):
		if not is_moving:  # Wurde unterbrochen?
			break
		
		var target_pos = current_path[i]
		current_position_index = i
		
		# Kill previous tween (für Sicherheit)
		if current_tween:
			current_tween.kill()
		
		# Tweene Position
		current_tween = create_tween()
		current_tween.tween_property(
			entity,
			"global_position",
			target_pos,
			movement_speed
		)
		
		await current_tween.finished
		
		if is_moving:  # Prüfe nochmal ob nicht unterbrochen
			movement_progress.emit(i, current_path.size())
	
	# Bewegung fertig oder unterbrochen
	is_moving = false
	var final_pos = entity.global_position
	movement_completed.emit(final_pos)
	
	_debug_log("Movement completed to %v" % final_pos)

## Stoppe Bewegung (wird von außen aufgerufen, z.B. bei Interrupt)
func stop_movement() -> void:
	if not is_moving:
		return
	
	is_moving = false
	
	# WICHTIG: Kill das aktuelle Tween! (War das Fehler vorher)
	if current_tween:
		current_tween.kill()
		current_tween = null
	
	_debug_log("Movement stopped at position %v" % entity.global_position)

## Setze Position direkt (für Teleportation, etc.)
func set_position(new_pos: Vector3) -> void:
	entity.global_position = new_pos
	_debug_log("Position set directly to %v" % new_pos)

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Berechne AP-Kosten für einen Ziel-Punkt (ohne zu bewegen)
func calculate_movement_cost(target_pos: Vector3) -> int:
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return -1
	
	var path = APUtility.find_path(
		entity.global_position,
		target_pos,
		Vector2i(GameConstants.TACTICAL_MAP_WIDTH, GameConstants.TACTICAL_MAP_HEIGHT),
		soldier_state.current_stance
	)
	
	if path.is_empty():
		return -1
	
	return APUtility.calculate_path_cost(path, soldier_state.current_stance)

## Gib voraussichtlichen Pfad zurück (für UI Preview)
func get_preview_path(target_pos: Vector3) -> Array:
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return []
	
	return APUtility.find_path(
		entity.global_position,
		target_pos,
		Vector2i(GameConstants.TACTICAL_MAP_WIDTH, GameConstants.TACTICAL_MAP_HEIGHT),
		soldier_state.current_stance
	)

## Prüfe ob Ziel erreichbar ist mit aktuellem AP
func is_target_reachable(target_pos: Vector3) -> bool:
	var cost = calculate_movement_cost(target_pos)
	if cost < 0:
		return false
	
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	return soldier_state.can_afford_ap(cost)

## Gib Bewegungs-Range zurück (max Entfernung mit aktuellem AP)
func get_movement_range() -> float:
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return 0.0
	
	# Vereinfachung: max_tiles * base_ap_cost
	var tiles_per_ap = GameConstants.AP_MOVE_STANDING
	var reachable_tiles = soldier_state.current_ap / tiles_per_ap
	
	return float(reachable_tiles) * GameConstants.TILE_SIZE

# ============================================================================
# COMPONENT INTERFACE
# ============================================================================

func on_enable() -> void:
	super.on_enable()
	_debug_log("MovementComponent enabled")

func on_disable() -> void:
	stop_movement()  # Kill Tween wenn deaktiviert
	super.on_disable()
	_debug_log("MovementComponent disabled")

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "MovementComponent:\n"
	info += "  Is Moving: %s\n" % is_moving
	info += "  Current Path: %d waypoints\n" % current_path.size()
	info += "  Position: %v" % entity.global_position
	return info

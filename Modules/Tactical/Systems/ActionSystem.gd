# res://Modules/Tactical/Systems/ActionSystem.gd
## Action Processing System
##
## Verantwortlichkeiten:
## - Spieler-Befehle verarbeiten
## - Action Validierung
## - Interrupt Handling nach Aktionen
## - Action Feedback

class_name ActionSystem extends Node

# ============================================================================
# PROPERTIES - REFERENCES
# ============================================================================

var turn_system: TurnSystem = null
var interrupt_system: InterruptSystem = null
var event_bus: EventBus = null

var all_enemies: Array = []
var all_allies: Array = []

# ============================================================================
# SIGNALS
# ============================================================================

signal action_started(actor: MercEntity, action: String)
signal action_completed(actor: MercEntity, action: String, success: bool)
signal interrupt_occurred(interrupter: MercEntity, target: MercEntity)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	self.name = "ActionSystem"
	DebugLogger.log("ActionSystem", "Initialized")

## Setup mit References
func setup(
	turn_sys: TurnSystem,
	event_bus_ref: EventBus,
	enemies: Array,
	allies: Array
) -> void:
	turn_system = turn_sys
	event_bus = event_bus_ref
	all_enemies = enemies
	all_allies = allies
	
	DebugLogger.log("ActionSystem", "Setup complete")

# ============================================================================
# ACTION PROCESSING - MOVEMENT
# ============================================================================

## Spieler befiehlt Unit, zu bewegen
func order_move(target_pos: Vector3) -> bool:
	var actor = turn_system.get_current_actor()
	
	# Validierung
	if not _validate_action(actor, "move"):
		return false
	
	action_started.emit(actor, "move")
	DebugLogger.log("ActionSystem", "Movement ordered for %s" % actor.merc_name)
	
	# Führe Bewegung aus
	var success = await actor.move_to(target_pos)
	
	if success:
		# Prüfe Interrupt
		await _check_for_interrupt(actor, "movement")
	
	action_completed.emit(actor, "move", success)
	return success

# ============================================================================
# ACTION PROCESSING - COMBAT
# ============================================================================

## Spieler befiehlt Unit, zu schießen
func order_shoot(target: MercEntity) -> bool:
	var actor = turn_system.get_current_actor()
	
	# Validierung
	if not _validate_action(actor, "shoot"):
		return false
	
	if not _validate_target(actor, target):
		return false
	
	action_started.emit(actor, "shoot")
	DebugLogger.log("ActionSystem", "%s shoots %s" % [actor.merc_name, target.merc_name])
	
	# Führe Schuss aus
	var success = await actor.shoot(target)
	
	if success:
		# Prüfe Interrupt
		await _check_for_interrupt(actor, "shooting")
	
	action_completed.emit(actor, "shoot", success)
	return success

## Spieler befiehlt Unit, nachzuladen
func order_reload() -> bool:
	var actor = turn_system.get_current_actor()
	
	if not _validate_action(actor, "reload"):
		return false
	
	action_started.emit(actor, "reload")
	DebugLogger.log("ActionSystem", "%s reloads" % actor.merc_name)
	
	var combat = actor.get_component("CombatComponent") as CombatComponent
	if combat == null:
		return false
	
	var success = await combat.reload()
	action_completed.emit(actor, "reload", success)
	return success

## Spieler befiehlt Unit, Haltung zu wechseln
func order_stance_change(new_stance: int) -> bool:
	var actor = turn_system.get_current_actor()
	
	if not _validate_action(actor, "stance"):
		return false
	
	action_started.emit(actor, "stance")
	
	var soldier_state = actor.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return false
	
	var success = soldier_state.change_stance(new_stance)
	action_completed.emit(actor, "stance", success)
	return success

# ============================================================================
# ACTION VALIDATION
# ============================================================================

## Prüfe ob Aktion möglich ist
func _validate_action(actor: MercEntity, action: String) -> bool:
	# Prüfe ob richtiger Actor
	if actor != turn_system.get_current_actor():
		DebugLogger.warn("ActionSystem", "Not this unit's turn!")
		return false
	
	# Prüfe ob Spieler am Zug
	if not turn_system.is_player_turn():
		DebugLogger.warn("ActionSystem", "Not player turn!")
		return false
	
	# Prüfe ob Unit noch lebendig
	if not actor.is_alive():
		DebugLogger.warn("ActionSystem", "Unit is dead!")
		return false
	
	# Aktion-spezifische Checks
	match action:
		"move":
			pass  # Bewegung braucht keine Vorbedingung
		
		"shoot":
			var combat = actor.get_component("CombatComponent") as CombatComponent
			if combat == null or combat.current_ammo <= 0:
				DebugLogger.warn("ActionSystem", "No ammo or no weapon!")
				return false
		
		"reload":
			var combat = actor.get_component("CombatComponent") as CombatComponent
			if combat == null:
				DebugLogger.warn("ActionSystem", "No weapon!")
				return false
	
	return true

## Prüfe ob Ziel gültig ist
func _validate_target(actor: MercEntity, target: MercEntity) -> bool:
	# Prüfe ob Ziel lebendig
	if not target.is_alive():
		DebugLogger.warn("ActionSystem", "Target is dead!")
		return false
	
	# Prüfe ob Ziel feindlich
	if target.faction == actor.faction:
		DebugLogger.warn("ActionSystem", "Cannot shoot allies!")
		return false
	
	# Prüfe ob Ziel sichtbar
	var vision = actor.get_component("VisionComponent") as VisionComponent
	if vision and not vision.can_see(target):
		DebugLogger.warn("ActionSystem", "Target not in sight!")
		return false
	
	return true

# ============================================================================
# INTERRUPT HANDLING
# ============================================================================

## Prüfe ob Interrupt auftritt
func _check_for_interrupt(actor: MercEntity, trigger_type: String) -> void:
	# Finde potentielle Interrupter
	var interrupters = InterruptSystem.get_potential_interrupters(
		all_enemies,
		actor,
		"visual"
	)
	
	if interrupters.size() == 0:
		return
	
	# Sortiere nach Priorität
	var sorted = InterruptSystem.sort_by_priority(interrupters, actor.global_position)
	
	# Erste (beste) Enemy schießt
	var interrupter = sorted[0]
	
	DebugLogger.log("ActionSystem", "INTERRUPT! %s interrupts %s" % [interrupter.merc_name, actor.merc_name])
	interrupt_occurred.emit(interrupter, actor)
	
	# Führe Interrupt-Schuss aus
	InterruptSystem.execute_interrupt_shot(interrupter, actor, null)
	
	# Emit EventBus Signal
	if event_bus:
		event_bus.interrupt_triggered.emit(interrupter, actor)

# ============================================================================
# END TURN
# ============================================================================

## Beende aktuellen Turn
func end_turn() -> void:
	if turn_system == null:
		return
	
	turn_system.end_current_turn()

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Prüfe ob Aktion möglich wäre
func can_perform_action(actor: MercEntity, action: String) -> bool:
	return _validate_action(actor, action)

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "ActionSystem:\n"
	info += "  Enemies: %d\n" % all_enemies.size()
	info += "  Allies: %d" % all_allies.size()
	return info

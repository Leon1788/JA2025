# res://Modules/Tactical/Components/AIComponent.gd
## AI-Komponente - Enemy AI und Verhalten
##
## Verantwortlichkeiten:
## - Zielerfassung
## - Verhalten (Idle, Pursuing, Attacking)
## - Tactical Decisions
## - Patrol / Reactive Behavior

class_name AIComponent extends IComponent

# ============================================================================
# PROPERTIES - AI STATE
# ============================================================================

var behavior_state: String = "idle"  # idle, pursuing, attacking, fleeing
var current_target: MercEntity = null
var last_known_position: Vector3 = Vector3.ZERO

var is_alerted: bool = false
var alert_level: float = 0.0  # 0.0 - 1.0

# ============================================================================
# PROPERTIES - BEHAVIOR CONFIG
# ============================================================================

var decision_interval: float = 1.0  # Decisions pro Sekunde
var time_since_last_decision: float = 0.0

var pursuit_timeout: float = 10.0  # Gib Target auf nach X Sekunden
var time_pursuing: float = 0.0

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(new_state: String)
signal target_acquired(target: MercEntity)
signal target_lost()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	_debug_log("AIComponent initialized for %s" % entity.name)

func _process(delta: float) -> void:
	if not is_enabled:
		return
	
	# Nur für Enemies (nicht für Player-Controllable Units)
	if entity.faction != "enemy":
		return
	
	# Update Alert Level
	alert_level = maxf(alert_level - delta * 0.1, 0.0)  # Decay
	
	# Decision-Making
	time_since_last_decision += delta
	if time_since_last_decision >= decision_interval:
		time_since_last_decision = 0.0
		_make_decision()

# ============================================================================
# MAIN AI LOOP
# ============================================================================

## Zentrale AI-Entscheidung
func _make_decision() -> void:
	match behavior_state:
		"idle":
			_handle_idle()
		"alerted":
			_handle_alerted()
		"pursuing":
			_handle_pursuing()
		"attacking":
			_handle_attacking()
		"fleeing":
			_handle_fleeing()

# ============================================================================
# IDLE STATE
# ============================================================================

func _handle_idle() -> void:
	# Suche nach sichtbaren Feinden
	var vision = entity.get_component("VisionComponent") as VisionComponent
	if vision == null:
		return
	
	# TODO: Prüfe alle aktiven Units
	# Für Phase 3: Placeholder
	
	# Optional: Patroullieren
	if randf() < 0.1:  # 10% Chance pro Decision
		_start_patrol()

# ============================================================================
# ALERTED STATE
# ============================================================================

func _handle_alerted() -> void:
	# Erhöhe Alert Level
	alert_level = minf(alert_level + 0.2, 1.0)
	
	# Wenn voll alarmiert, wechsle zu Pursuing/Attacking
	if alert_level >= 0.8:
		_change_behavior("attacking")

# ============================================================================
# PURSUING STATE
# ============================================================================

func _handle_pursuing() -> void:
	if current_target == null:
		_change_behavior("idle")
		return
	
	# Prüfe ob Target noch sichtbar
	var vision = entity.get_component("VisionComponent") as VisionComponent
	if vision and vision.can_see(current_target):
		# Target noch sichtbar: Angreifen
		_change_behavior("attacking")
		return
	
	# Verfolge letzte bekannte Position
	time_pursuing += decision_interval
	if time_pursuing > pursuit_timeout:
		# Gib auf
		_change_behavior("idle")
		return
	
	# Bewege zu letzter Position
	var movement = entity.get_component("MovementComponent") as MovementComponent
	if movement:
		await movement.move_to(last_known_position)

# ============================================================================
# ATTACKING STATE
# ============================================================================

func _handle_attacking() -> void:
	if current_target == null or not current_target.is_alive():
		_change_behavior("pursuing")
		return
	
	# Prüfe ob Target noch sichtbar
	var vision = entity.get_component("VisionComponent") as VisionComponent
	if not vision or not vision.can_see(current_target):
		last_known_position = current_target.global_position
		_change_behavior("pursuing")
		return
	
	# Schießen wenn möglich
	var combat = entity.get_component("CombatComponent") as CombatComponent
	if combat and combat.can_shoot_target(current_target):
		await combat.shoot(current_target)
	
	# Optional: Bewege näher heran
	var distance = entity.global_position.distance_to(current_target.global_position)
	if distance > 5.0 and randf() < 0.3:  # 30% Chance pro Decision
		var movement = entity.get_component("MovementComponent") as MovementComponent
		if movement:
			# Bewege näher heran
			var approach_direction = (current_target.global_position - entity.global_position).normalized()
			var new_target = entity.global_position + approach_direction * 3.0
			await movement.move_to(new_target)

# ============================================================================
# FLEEING STATE
# ============================================================================

func _handle_fleeing() -> void:
	# Wenn Health erholt: Normal Battle Resume
	var soldier_state = entity.get_component("SoldierState") as SoldierState
	if soldier_state and soldier_state.get_health_percent() > 0.5:
		_change_behavior("attacking")
		return
	
	# Versuche zu fliehen
	var movement = entity.get_component("MovementComponent") as MovementComponent
	if movement and current_target:
		var flee_direction = (entity.global_position - current_target.global_position).normalized()
		var flee_target = entity.global_position + flee_direction * 5.0
		await movement.move_to(flee_target)

# ============================================================================
# BEHAVIOR TRANSITIONS
# ============================================================================

## Wechsle Verhalten
func _change_behavior(new_state: String) -> void:
	if new_state == behavior_state:
		return
	
	behavior_state = new_state
	state_changed.emit(new_state)
	_debug_log("AI behavior changed to: %s" % new_state)

## Erfasse Ziel
func acquire_target(target: MercEntity) -> void:
	current_target = target
	last_known_position = target.global_position
	time_pursuing = 0.0
	_change_behavior("attacking")
	target_acquired.emit(target)

## Verliere Ziel
func lose_target() -> void:
	current_target = null
	target_lost.emit()
	_change_behavior("pursuing")

## Werde alarmiert (z.B. durch Geräusch)
func on_alert(alert_source: Vector3, alert_level_amount: float = 0.5) -> void:
	alert_level = minf(alert_level + alert_level_amount, 1.0)
	is_alerted = true
	_debug_log("AI alerted! Alert level: %.1f" % alert_level)

# ============================================================================
# TACTICAL DECISIONS
# ============================================================================

## Sollte fliehen?
func should_flee() -> bool:
	var soldier_state = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return false
	
	# Fliehe wenn <30% Health
	if soldier_state.get_health_percent() < 0.3:
		return true
	
	# Fliehe wenn stark unterlegen (mehrere Feinde)
	# TODO: Count enemy count nearby
	
	return false

## Sollte in Deckung gehen?
func should_take_cover() -> bool:
	# TODO: Implement cover decision
	return randf() < 0.3  # Placeholder: 30% Chance

## Nächstes Taktik-Ziel
func get_next_tactical_objective() -> String:
	# Einfache Utility-Entscheidung
	if not current_target:
		return "patrol"
	
	var distance = entity.global_position.distance_to(current_target.global_position)
	if distance > 10.0:
		return "pursue"
	elif distance > 3.0:
		return "attack_distance"
	else:
		return "attack_close"

# ============================================================================
# PATROL SYSTEM
# ============================================================================

func _start_patrol() -> void:
	# Zufällige Position in der Nähe
	var random_offset = Vector3(
		randf_range(-5.0, 5.0),
		0.0,
		randf_range(-5.0, 5.0)
	)
	var patrol_target = entity.global_position + random_offset
	
	var movement = entity.get_component("MovementComponent") as MovementComponent
	if movement:
		await movement.move_to(patrol_target)

# ============================================================================
# COMPONENT INTERFACE
# ============================================================================

func on_enable() -> void:
	super.on_enable()
	_debug_log("AIComponent enabled")

func on_disable() -> void:
	super.on_disable()
	_debug_log("AIComponent disabled")

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "AIComponent:\n"
	info += "  Behavior: %s\n" % behavior_state
	info += "  Current Target: %s\n" % (current_target.merc_name if current_target else "None")
	info += "  Alert Level: %.1f\n" % alert_level
	info += "  Time Pursuing: %.1f/%ds" % [time_pursuing, pursuit_timeout]
	return info

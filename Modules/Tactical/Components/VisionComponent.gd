# res://Modules/Tactical/Components/VisionComponent.gd
## Vision-Komponente - Verwaltet Sicht und Zielerfassung
##
## Verantwortlichkeiten:
## - Sight Range Berechnung
## - Line of Sight Checks
## - Spotted Units Tracking
## - Enemy Detection

class_name VisionComponent extends IComponent

# ============================================================================
# PROPERTIES - VISION STATE
# ============================================================================

var sight_range: float = 15.0
var spotted_units: Array = []  # Sichtbar für diese Unit

var current_light_level: float = 1.0  # 0.0 (dunkel) bis 1.0 (hell)
var has_night_vision: bool = false

# ============================================================================
# PROPERTIES - DETECTION
# ============================================================================

## Wie oft Vision pro Second aktualisiert werden (nicht jeden Frame)
var vision_update_interval: float = 0.5
var time_since_last_update: float = 0.0

# ============================================================================
# SIGNALS
# ============================================================================

signal unit_spotted(unit: MercEntity)
signal unit_lost_sight(unit: MercEntity)
signal spotted_units_changed()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	_debug_log("VisionComponent initialized")

func _process(delta: float) -> void:
	if not is_enabled:
		return
	
	# Update Vision in Intervallen (Performance)
	time_since_last_update += delta
	if time_since_last_update >= vision_update_interval:
		time_since_last_update = 0.0
		_update_vision()

# ============================================================================
# INITIALIZATION
# ============================================================================

## Aktualisiere Sichtweite basierend auf Attributen
func update_sight_range(wisdom: int, agility: int) -> void:
	sight_range = VisionUtility.calculate_sight_range(
		agility,
		wisdom,
		current_light_level,
		has_night_vision
	)
	_debug_log("Sight range updated: %.1f tiles" % sight_range)

## Setze Lichtverhältnisse
func set_light_level(light_level: float) -> void:
	current_light_level = clamp(light_level, 0.0, 1.0)
	# Recalculate sight range
	var soldier_state = entity.get_component("SoldierState")
	if soldier_state:
		update_sight_range(entity.wisdom, entity.agility)

## Aktiviere Night Vision
func set_night_vision(enabled: bool) -> void:
	has_night_vision = enabled
	_debug_log("Night vision: %s" % ("ON" if enabled else "OFF"))

# ============================================================================
# VISION SYSTEM
# ============================================================================

## Update sichtbare Units (wird von _process aufgerufen)
func _update_vision() -> void:
	var old_spotted = spotted_units.duplicate()
	spotted_units.clear()
	
	# HACK: Aktuell keine Szenen-Referenz, daher können wir nicht alle Units checken
	# TODO: TacticalManager übergeben oder Global Scene Registry
	# Für Phase 3: Placeholder
	
	# Prüfe ob sichtbare Units nicht mehr sichtbar sind
	for unit in old_spotted:
		if unit not in spotted_units:
			unit_lost_sight.emit(unit)
	
	# Prüfe ob neue Units sichtbar sind
	for unit in spotted_units:
		if unit not in old_spotted:
			unit_spotted.emit(unit)
	
	spotted_units_changed.emit()

## Prüfe ob eine Unit sichtbar ist (manuelle Abfrage)
func can_see(target: MercEntity) -> bool:
	if target == null or entity == null:
		return false
	
	# SCHRITT 1: Distance Check
	var distance = entity.global_position.distance_to(target.global_position)
	if not VisionUtility.is_within_sight_range(
		entity.global_position,
		target.global_position,
		sight_range
	):
		return false
	
	# SCHRITT 2: Line of Sight (vereinfacht - kein Raycast in Phase 3)
	# TODO: Raycast-Integration mit TacticalWorld
	# Für Phase 3: Nur Distance-Check
	
	# SCHRITT 3: Faction Check (sehe nur Feinde/Neutrale, nicht Freunde)
	if target.faction == entity.faction and target.faction != "civilian":
		return false
	
	return true

## Gib alle sichtbaren Feinde zurück
func get_visible_enemies(all_units: Array) -> Array:
	var visible_enemies = []
	
	for unit in all_units:
		if unit == entity:
			continue  # Nicht selbst
		
		if unit.faction == entity.faction:
			continue  # Nicht Verbündete
		
		if can_see(unit):
			visible_enemies.append(unit)
	
	return visible_enemies

## Gib alle sichtbaren verbündeten zurück
func get_visible_allies(all_units: Array) -> Array:
	var visible_allies = []
	
	for unit in all_units:
		if unit == entity:
			continue
		
		if unit.faction != entity.faction:
			continue
		
		if can_see(unit):
			visible_allies.append(unit)
	
	return visible_allies

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Berechne Entfernung zu Unit (in Tiles)
func get_distance_to_target(target: MercEntity) -> float:
	return VisionUtility.calculate_distance_in_tiles(
		entity.global_position,
		target.global_position
	)

## Gib Sichtweite in Tiles zurück
func get_sight_range_tiles() -> int:
	return VisionUtility.sight_range_to_tiles(sight_range)

## Prüfe ob Unit in kritischer Distanz (nah genug für Interrupt)
func is_target_in_interrupt_range(target: MercEntity) -> bool:
	var distance = get_distance_to_target(target)
	return distance <= GameConstants.INTERRUPT_SOUND_BASE_RADIUS

## Prüfe ob Unit an Position sichtbar ist (für UI Preview)
func is_position_visible(world_pos: Vector3) -> bool:
	return VisionUtility.is_within_sight_range(
		entity.global_position,
		world_pos,
		sight_range
	)

# ============================================================================
# SOUND & HEARING
# ============================================================================

## Prüfe ob Geräusch gehört wird
func can_hear_sound(sound_position: Vector3, sound_volume: float) -> bool:
	var distance = entity.global_position.distance_to(sound_position)
	
	return VisionUtility.can_hear_noise(
		distance,
		sound_volume,
		entity.agility
	)

## Berechne Geräuschlautstärke mit Silencer
func calculate_suppressed_volume(base_volume: float, has_silencer: bool) -> float:
	return VisionUtility.is_noise_suppressed(has_silencer, "single")

# ============================================================================
# COMPONENT INTERFACE
# ============================================================================

func on_enable() -> void:
	super.on_enable()
	_debug_log("VisionComponent enabled")

func on_disable() -> void:
	super.on_disable()
	spotted_units.clear()
	_debug_log("VisionComponent disabled")

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "VisionComponent:\n"
	info += "  Sight Range: %.1f tiles\n" % sight_range
	info += "  Light Level: %.1f\n" % current_light_level
	info += "  Night Vision: %s\n" % ("ON" if has_night_vision else "OFF")
	info += "  Spotted Units: %d" % spotted_units.size()
	return info

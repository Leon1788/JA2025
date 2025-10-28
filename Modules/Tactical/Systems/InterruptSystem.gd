# res://Modules/Tactical/Systems/InterruptSystem.gd
## Interrupt System - Gegner unterbrechen Spielerzüge
##
## PURE CLASS - Keine Godot Node Dependencies!
## 100% testbar
##
## Verantwortlichkeiten:
## - Prüfe Interrupt-Bedingungen
## - Entscheide ob Interrupt ausgelöst wird
## - Berechne Interrupt-Prioritäten

class_name InterruptSystem

# ============================================================================
# INTERRUPT CHECKS
# ============================================================================

## Prüfe ob ein Interrupt ausgelöst werden sollte
static func should_trigger_interrupt(
	trigger_type: String,
	triggering_actor: Dictionary,
	observer_actor: Dictionary,
	distance: float,
	light_level: float = 1.0
) -> bool:
	
	match trigger_type:
		"visual":
			return _check_visual_interrupt(triggering_actor, observer_actor, distance, light_level)
		"sound":
			return _check_sound_interrupt(triggering_actor, observer_actor, distance)
		"hp_critical":
			return _check_hp_critical_interrupt()
		_:
			return false

## Prüfe visuellen Interrupt
static func _check_visual_interrupt(
	triggering_actor: Dictionary,
	observer_actor: Dictionary,
	distance: float,
	light_level: float
) -> bool:
	
	if triggering_actor.get("faction") == observer_actor.get("faction"):
		return false
	
	if not observer_actor.get("can_see", true):
		return false
	
	if distance > GameConstants.BASE_SIGHT_RANGE * (1.0 if light_level > 0.3 else 0.5):
		return false
	
	return true

## Prüfe Sound-basierten Interrupt
static func _check_sound_interrupt(
	triggering_actor: Dictionary,
	observer_actor: Dictionary,
	distance: float
) -> bool:
	
	if triggering_actor.get("faction") == observer_actor.get("faction"):
		return false
	
	var sound_volume = triggering_actor.get("sound_volume", 1.0)
	var hearing_range = GameConstants.INTERRUPT_SOUND_BASE_RADIUS * sound_volume
	
	return distance <= hearing_range

## Prüfe kritischen HP Interrupt
static func _check_hp_critical_interrupt() -> bool:
	return true

# ============================================================================
# INTERRUPT TYPES
# ============================================================================

## Interrupt durch Bewegung
static func create_movement_interrupt(
	moving_actor: IEntity,
	observer: IEntity,
	distance: float
) -> Dictionary:
	
	return {
		"type": "movement",
		"triggering_actor": moving_actor,
		"observer": observer,
		"distance": distance,
		"can_interrupt": true
	}

## Interrupt durch Schuss
static func create_shot_interrupt(
	shooting_actor: IEntity,
	observer: IEntity,
	distance: float,
	is_silenced: bool = false
) -> Dictionary:
	
	var sound_volume = 1.0 if not is_silenced else GameConstants.SILENCER_SOUND_REDUCTION
	
	return {
		"type": "shot",
		"triggering_actor": shooting_actor,
		"observer": observer,
		"distance": distance,
		"sound_volume": sound_volume,
		"is_silenced": is_silenced,
		"can_interrupt": true
	}

## Interrupt durch Geräusch
static func create_noise_interrupt(
	noise_source: Vector3,
	observer: IEntity,
	noise_volume: float = 0.5,
	noise_type: String = "general"
) -> Dictionary:
	
	return {
		"type": "noise",
		"noise_source": noise_source,
		"observer": observer,
		"noise_volume": noise_volume,
		"noise_type": noise_type,
		"can_interrupt": true
	}

# ============================================================================
# INTERRUPT RESOLUTION
# ============================================================================

## Berechne wer darf diesen Interrupt ausführen
static func get_valid_interrupters(
	trigger_data: Dictionary,
	all_enemies: Array,
	current_faction: String = "player"
) -> Array:
	
	var valid_interrupters: Array = []
	
	for enemy in all_enemies:
		if enemy.get("faction") == current_faction:
			continue
		
		if _can_interrupt(enemy, trigger_data):
			valid_interrupters.append(enemy)
	
	return valid_interrupters

## Prüfe ob ein spezifischer Actor unterbrechen kann
static func _can_interrupt(actor: Dictionary, trigger_data: Dictionary) -> bool:
	if not actor.get("is_active", true):
		return false
	
	if actor.get("current_ap", 0) < GameConstants.AP_SHOOT_SINGLE:
		return false
	
	if trigger_data.get("type") == "movement":
		return actor.get("can_see", true)
	elif trigger_data.get("type") == "shot":
		return actor.get("can_see", true) or actor.get("can_hear", true)
	
	return true

## Berechne Interrupt-Priorität
static func calculate_interrupt_priority(
	actor: Dictionary,
	trigger_distance: float
) -> float:
	
	var priority = 0.0
	
	var alertness = actor.get("alertness", 0.5)
	priority += alertness * 100.0
	
	var distance_factor = 1.0 - clamp(trigger_distance / GameConstants.BASE_SIGHT_RANGE, 0.0, 1.0)
	priority += distance_factor * 50.0
	
	var skill = actor.get("marksmanship", 50) / 100.0
	priority += skill * 25.0
	
	return priority

## Sortiere Interrupter nach Priorität
static func sort_interrupters_by_priority(
	interrupters: Array,
	trigger_data: Dictionary
) -> Array:
	
	var sorted = interrupters.duplicate()
	
	sorted.sort_custom(func(a, b):
		var priority_a = calculate_interrupt_priority(a, trigger_data.get("distance", 0.0))
		var priority_b = calculate_interrupt_priority(b, trigger_data.get("distance", 0.0))
		return priority_a > priority_b
	)
	
	return sorted

# ============================================================================
# OVERWATCH SYSTEM
# ============================================================================

## Erstelle Overwatch-Status
static func create_overwatch_state(
	actor: IEntity,
	allowed_arcs: Array = []
) -> Dictionary:
	
	return {
		"is_overwatch": true,
		"actor": actor,
		"allowed_arcs": allowed_arcs,
		"ap_reserved": GameConstants.AP_SHOOT_SINGLE,
		"created_at": Time.get_ticks_msec()
	}

## Prüfe ob Overwatch aktiv ist
static func is_overwatch_active(
	actor: IEntity,
	trigger_data: Dictionary
) -> bool:
	
	if actor.get_soldier_state().current_ap < GameConstants.AP_SHOOT_SINGLE:
		return false
	
	return true

## Führe Overwatch-Schuss aus
static func execute_overwatch_shot(
	actor: IEntity,
	target: IEntity,
	trigger_data: Dictionary
) -> Dictionary:
	
	return {
		"shooter": actor,
		"target": target,
		"shot_type": "overwatch",
		"ap_cost": GameConstants.AP_SHOOT_SINGLE,
		"success": true
	}

# ============================================================================
# INTERRUPT ANIMATION & TIMING
# ============================================================================

## Berechne Interrupt-Dauer
static func get_interrupt_duration(interrupt_type: String) -> float:
	match interrupt_type:
		"movement":
			return 0.3
		"shot":
			return 1.2
		"noise":
			return 0.5
		_:
			return 0.5

## Berechne Reaktions-Delay (wie lange bis Interrupt ausgelöst wird)
static func get_reaction_delay(actor_alertness: float) -> float:
	# Höhere Alertness = schnellere Reaktion
	var base_delay = 0.5
	var alertness_factor = 1.0 - (actor_alertness * 0.5)
	return base_delay * alertness_factor

# ============================================================================
# DEBUG & UTILITIES
# ============================================================================

## Gib Interrupt-Debug-Info aus
static func get_interrupt_debug_info(
	trigger_type: String,
	distance: float,
	can_interrupt: bool
) -> String:
	var info = "Interrupt Check:\n"
	info += "  Type: %s\n" % trigger_type
	info += "  Distance: %.1f\n" % distance
	info += "  Triggered: %s" % ("YES" if can_interrupt else "NO")
	return info

## Konvertiere Interrupt-Type zu Namen
static func get_interrupt_name(interrupt_type: String) -> String:
	match interrupt_type:
		"visual":
			return "Visual Interrupt"
		"sound":
			return "Sound Interrupt"
		"hp_critical":
			return "Critical HP"
		_:
			return "Unknown"

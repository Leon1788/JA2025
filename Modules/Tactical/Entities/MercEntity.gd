# res://Modules/Tactical/Entities/MercEntity.gd
## Zentrale Entity-Klasse für jeden Merc
##
## Erbt von IEntity und orchestriert alle Components
## Stellt High-Level Interface bereit (move, shoot, take_damage)
##
## Nicht direkt in der Scene - wird vom TacticalManager instanziiert

class_name MercEntity extends IEntity

# ============================================================================
# PROPERTIES - MERC PROFILE DATA
# ============================================================================

## Eindeutige ID (z.B. "merc_ivan", "enemy_01")
var merc_id: String = ""

## Display Name
var merc_name: String = ""

## Faction (player, enemy, civilian)
var faction: String = "player"

# ============================================================================
# PROPERTIES - ATTRIBUTES
# ============================================================================

## Attribute (0-100)
var agility: int = 50
var marksmanship: int = 50
var wisdom: int = 50
var strength: int = 50

## Armor
var armor_value: int = 0
var armor_type: String = "medium"

# ============================================================================
# PROPERTIES - VISUALS & PHYSICS
# ============================================================================

var model_path: String = ""  # Path to 3D model (.gltf)
var current_weapon: Dictionary = {}

# ============================================================================
# SIGNALS
# ============================================================================

signal merc_moved(from_pos: Vector3, to_pos: Vector3)
signal merc_shot(target: MercEntity, hit: bool, damage: int)
signal merc_took_damage(damage: int, remaining_hp: int)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	
	# Stelle sicher dass Components vorhanden sind
	if components.is_empty():
		_report_warning("MercEntity has no components!")
		return
	
	# Aktiviere Entity
	activate()
	
	_debug_log("MercEntity ready: %s (%s)" % [merc_name, merc_id])

# ============================================================================
# INITIALIZATION
# ============================================================================

## Initialisiere Merc mit Profil-Daten
func setup_from_profile(profile: Dictionary) -> void:
	merc_id = profile.get("id", "unknown")
	merc_name = profile.get("name", "Unknown")
	faction = profile.get("faction", "player")
	
	# Attribute
	agility = profile.get("agility", 50)
	marksmanship = profile.get("marksmanship", 50)
	wisdom = profile.get("wisdom", 50)
	strength = profile.get("strength", 50)
	
	# Armor
	armor_value = profile.get("armor_value", 0)
	armor_type = profile.get("armor_type", "medium")
	
	# Model
	model_path = profile.get("model_path", "")
	
	# Initialisiere Components mit Daten
	_initialize_components_with_profile(profile)
	
	_debug_log("MercEntity setup complete: %s" % merc_name)

## Initialisiere Components
func _initialize_components_with_profile(profile: Dictionary) -> void:
	# SoldierState
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state:
		var max_hp = strength * 0.5 + 50  # Base: 50 + Bonus
		soldier_state.max_hp = int(max_hp)
		soldier_state.current_hp = int(max_hp)
		soldier_state.faction = faction
		soldier_state.calculate_max_ap(agility)
		soldier_state.armor_value = armor_value
		soldier_state.armor_type = armor_type
	
	# MovementComponent
	var movement = get_component("MovementComponent") as MovementComponent
	if movement:
		movement.movement_speed = 0.2 + (agility / 100.0) * 0.1  # Schneller mit Agility
	
	# CombatComponent
	var combat = get_component("CombatComponent") as CombatComponent
	if combat:
		combat.marksmanship = marksmanship
		combat.equipped_weapon = profile.get("starting_weapon", {})
	
	# VisionComponent
	var vision = get_component("VisionComponent") as VisionComponent
	if vision:
		vision.update_sight_range(wisdom, agility)
	
	# AIComponent (nur für Enemies)
	var ai = get_component("AIComponent") as AIComponent
	if ai and faction == "enemy":
		ai.enable()
	else:
		ai = get_component("AIComponent")
		if ai:
			ai.disable()

# ============================================================================
# HIGH-LEVEL INTERFACE - MOVEMENT
# ============================================================================

## Bewege Unit zu Position
func move_to(target_pos: Vector3) -> bool:
	var movement = get_component("MovementComponent") as MovementComponent
	if movement == null:
		_report_error("MovementComponent not found!")
		return false
	
	var success = await movement.move_to(target_pos)
	
	if success:
		merc_moved.emit(entity_id, target_pos)
	
	return success

## Gib Bewegungs-Preview zurück
func get_movement_preview(target_pos: Vector3) -> Array:
	var movement = get_component("MovementComponent") as MovementComponent
	if movement == null:
		return []
	
	return movement.get_preview_path(target_pos)

## Prüfe ob Position erreichbar ist
func can_reach(target_pos: Vector3) -> bool:
	var movement = get_component("MovementComponent") as MovementComponent
	if movement == null:
		return false
	
	return movement.is_target_reachable(target_pos)

## Berechne Bewegungs-Kosten
func get_movement_cost(target_pos: Vector3) -> int:
	var movement = get_component("MovementComponent") as MovementComponent
	if movement == null:
		return -1
	
	return movement.calculate_movement_cost(target_pos)

# ============================================================================
# HIGH-LEVEL INTERFACE - COMBAT
# ============================================================================

## Schieße auf ein Ziel
func shoot(target: MercEntity, weapon_name: String = "") -> bool:
	var combat = get_component("CombatComponent") as CombatComponent
	if combat == null:
		_report_error("CombatComponent not found!")
		return false
	
	var success = await combat.shoot(target, weapon_name)
	
	if success:
		# TODO: Get actual damage from CombatComponent
		merc_shot.emit(target, true, 0)
	
	return success

## Lade Waffe nach
func reload(weapon_name: String = "") -> bool:
	var combat = get_component("CombatComponent") as CombatComponent
	if combat == null:
		return false
	
	return await combat.reload(weapon_name)

# ============================================================================
# HIGH-LEVEL INTERFACE - HEALTH
# ============================================================================

## Nimm Schaden
func take_damage(damage_amount: int, hitzone: int = 1) -> void:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return
	
	soldier_state.apply_damage(damage_amount, hitzone)
	merc_took_damage.emit(damage_amount, soldier_state.current_hp)

## Heile Unit
func heal(heal_amount: int) -> void:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return
	
	soldier_state.apply_healing(heal_amount)

## Prüfe ob lebendig
func is_alive() -> bool:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return false
	
	return soldier_state.is_alive()

# ============================================================================
# HIGH-LEVEL INTERFACE - STATE
# ============================================================================

## Wechsle Haltung
func change_stance(new_stance: int) -> bool:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return false
	
	return soldier_state.change_stance(new_stance)

## Gib aktuellen Stance zurück
func get_stance() -> int:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return GameConstants.STANCE.STANDING
	
	return soldier_state.current_stance

## Gib Health-Prozentsatz zurück
func get_health_percent() -> float:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return 0.0
	
	return soldier_state.get_health_percent()

## Gib AP-Prozentsatz zurück
func get_ap_percent() -> float:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return 0.0
	
	return soldier_state.get_ap_percent()

## Gib aktuelle HP zurück
func get_current_hp() -> int:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return 0
	
	return soldier_state.current_hp

## Gib aktuelle AP zurück
func get_current_ap() -> int:
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return 0
	
	return soldier_state.current_ap

# ============================================================================
# VISION & TARGETING
# ============================================================================

## Prüfe ob diese Unit eine andere Unit sieht
func can_see(other: MercEntity) -> bool:
	var vision = get_component("VisionComponent") as VisionComponent
	if vision == null:
		return false
	
	return vision.can_see(other)

## Gib alle sichtbaren Feinde zurück
func get_visible_enemies() -> Array:
	var vision = get_component("VisionComponent") as VisionComponent
	if vision == null:
		return []
	
	var visible = []
	for unit in vision.spotted_units:
		if unit.faction != self.faction:
			visible.append(unit)
	
	return visible

# ============================================================================
# DEBUG & SERIALIZATION
# ============================================================================

## Gib vollständige Debug-Info aus
func get_debug_info() -> String:
	var info = "\n=== MercEntity Debug Info ===\n"
	info += "Name: %s (ID: %s)\n" % [merc_name, merc_id]
	info += "Position: %v\n" % global_position
	info += "Faction: %s\n" % faction
	info += "\n--- Attributes ---\n"
	info += "Agility: %d | Marksmanship: %d | Wisdom: %d | Strength: %d\n" % [agility, marksmanship, wisdom, strength]
	info += "\n--- Components ---\n"
	
	for component_name in components.keys():
		var component = components[component_name]
		info += "  ✓ %s\n" % component_name
	
	# Component-spezifische Infos
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state:
		info += "\n--- Soldier State ---\n"
		info += soldier_state.get_debug_info()
	
	var movement = get_component("MovementComponent") as MovementComponent
	if movement:
		info += "\n--- Movement ---\n"
		info += movement.get_debug_info()
	
	info += "\n===========================\n"
	return info

## Serialisiere für Save-System
func to_dict() -> Dictionary:
	var soldier_state = get_component("SoldierState") as SoldierState
	
	return {
		"merc_id": merc_id,
		"merc_name": merc_name,
		"faction": faction,
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"agility": agility,
		"marksmanship": marksmanship,
		"wisdom": wisdom,
		"strength": strength,
		"armor_value": armor_value,
		"armor_type": armor_type,
		"soldier_state": soldier_state.to_dict() if soldier_state else {}
	}

## Deserialisiere von Save-System
func from_dict(data: Dictionary) -> void:
	merc_id = data.get("merc_id", "")
	merc_name = data.get("merc_name", "")
	faction = data.get("faction", "player")
	
	# Position
	var pos_data = data.get("position", {})
	global_position = Vector3(
		pos_data.get("x", 0),
		pos_data.get("y", 0),
		pos_data.get("z", 0)
	)
	
	# Attribute
	agility = data.get("agility", 50)
	marksmanship = data.get("marksmanship", 50)
	wisdom = data.get("wisdom", 50)
	strength = data.get("strength", 50)
	armor_value = data.get("armor_value", 0)
	armor_type = data.get("armor_type", "medium")
	
	# Components
	var soldier_state = get_component("SoldierState") as SoldierState
	if soldier_state and "soldier_state" in data:
		soldier_state.from_dict(data["soldier_state"])

# res://Modules/Tactical/Systems/InitiativeSystem.gd
## Initiative Berechnung für Turn-Order
##
## PURE CLASS - Keine Godot Node Dependencies!
## 100% testbar, keine Side-Effects

class_name InitiativeSystem

# ============================================================================
# INITIATIVE CALCULATION
# ============================================================================

## Berechne Initiative für einen Unit
## Höher = agiert zuerst
static func calculate_unit_initiative(
	unit: MercEntity,
	random_variance: int = 20
) -> int:
	
	if unit == null:
		return 0
	
	# Base: Agility des Units
	var base_initiative = unit.agility
	
	# Bonus: Random zwischen 0 und variance
	var random_bonus = randi() % random_variance
	
	# Zusatz: Status Effects
	var status_bonus = _get_status_effect_bonus(unit)
	
	var final_initiative = base_initiative + random_bonus + status_bonus
	
	return final_initiative

## Bonus für Status Effects
static func _get_status_effect_bonus(unit: MercEntity) -> int:
	var bonus = 0
	var soldier_state = unit.get_component("SoldierState") as SoldierState
	
	if soldier_state == null:
		return 0
	
	# Wenn kritisch verwundet: -10 Initiative
	if soldier_state.is_critical():
		bonus -= 10
	
	# Wenn frisch: +5 Initiative
	if soldier_state.fatigue < 20:
		bonus += 5
	
	return bonus

## Sortiere Units nach Initiative
static func sort_by_initiative(units: Array) -> Array:
	var sorted = units.duplicate()
	
	sorted.sort_custom(func(a, b):
		var init_a = calculate_unit_initiative(a)
		var init_b = calculate_unit_initiative(b)
		return init_a > init_b
	)
	
	return sorted

## Berechne komplette Turn-Order
static func calculate_turn_order(
	player_units: Array,
	enemy_units: Array
) -> Array:
	
	var all_units = player_units + enemy_units
	return sort_by_initiative(all_units)

# ============================================================================
# DEBUG
# ============================================================================

static func get_initiative_debug_info(unit: MercEntity) -> String:
	var init = calculate_unit_initiative(unit)
	return "Initiative: %d (Agility: %d)" % [init, unit.agility]

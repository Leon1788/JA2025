# res://Modules/Tactical/Systems/InterruptSystem.gd (REFACTORED für MVP)

class_name InterruptSystem

# ============================================================================
# SIMPLIFIED MVP - Nur das was wir brauchen!
# ============================================================================

## Sollte Interrupt ausgelöst werden? (Simplified)
static func should_trigger_interrupt(
	enemy: MercEntity,
	player_actor: MercEntity,
	trigger_type: String = "visual"
) -> bool:
	
	# Check 1: Lebt noch?
	if not enemy.is_alive():
		return false
	
	# Check 2: Hat genug AP?
	var soldier_state = enemy.get_component("SoldierState") as SoldierState
	if soldier_state.current_ap < GameConstants.AP_SHOOT_SINGLE:
		return false
	
	# Check 3: Kann sehen/hören?
	match trigger_type:
		"visual":
			var vision = enemy.get_component("VisionComponent") as VisionComponent
			if vision == null:
				return false
			return vision.can_see(player_actor)
		
		"sound":
			var distance = enemy.global_position.distance_to(player_actor.global_position)
			# Geräusch-Interrupt wenn nah genug
			return distance < GameConstants.INTERRUPT_SOUND_BASE_RADIUS
		
		"hp_critical":
			# Wenn Spieler plötzlich verwundet wird
			return player_actor.get_health_percent() < 0.3
	
	return false

## Berechne Interrupt-Priorität (welcher Enemy schießt zuerst?)
static func calculate_interrupt_priority(
	enemy: MercEntity,
	trigger_distance: float
) -> float:
	var soldier_state = enemy.get_component("SoldierState") as SoldierState
	
	var priority = 0.0
	
	# Höhere Skills = höhere Priorität
	priority += (enemy.marksmanship / 100.0) * 100.0
	
	# Nähere Enemies haben Vorrang
	var distance_bonus = max(0.0, 20.0 - trigger_distance)
	priority += distance_bonus
	
	# Weniger verwundet = höhere Priorität
	var hp_bonus = soldier_state.get_health_percent() * 50.0
	priority += hp_bonus
	
	return priority

## Führe Interrupt-Schuss aus
static func execute_interrupt_shot(
	interrupter: MercEntity,
	target: MercEntity,
	tactical_manager: Node  # ← Brauchen wir für AP-Handling
) -> void:
	# Schuss mit vollem Schaden
	# AP wird NICHT gezogen (Interrupt = Free Action)
	
	DebugLogger.log("InterruptSystem", "INTERRUPT: %s shoots %s!" % [interrupter.merc_name, target.merc_name])
	
	# Stats für Hit-Chance
	var distance = interrupter.global_position.distance_to(target.global_position)
	var hit_chance = CombatUtility.calculate_hit_chance(
		interrupter.marksmanship,
		distance,
		0,  # Kein Cover annahme
		interrupter.get_stance(),
		target.get_stance()
	)
	
	# Würfeln
	if randf() < hit_chance:
		# Treffer!
		var damage = DamageUtility.calculate_final_damage(
			20, 40,  # Beispiel Waffen-Damage
			100,     # Weapon Condition
			target.armor_value,
			target.armor_type,
			randi() % 6,  # Random Hitzone
			false
		)
		target.take_damage(damage)
		DebugLogger.log("InterruptSystem", "INTERRUPT HIT: %d damage!" % damage)
	else:
		# Verfehlt!
		DebugLogger.log("InterruptSystem", "INTERRUPT MISSED!")

# ============================================================================
# HELPER: Finde potentielle Interrupter
# ============================================================================

## Gib alle Enemies die unterbrechen könnten
static func get_potential_interrupters(
	all_enemies: Array,
	player_actor: MercEntity,
	trigger_type: String = "visual"
) -> Array:
	
	var candidates = []
	
	for enemy in all_enemies:
		if should_trigger_interrupt(enemy, player_actor, trigger_type):
			candidates.append(enemy)
	
	return candidates

## Sortiere nach Priorität (erste schießt zuerst)
static func sort_by_priority(
	interrupters: Array,
	player_position: Vector3
) -> Array:
	
	var sorted = interrupters.duplicate()
	
	sorted.sort_custom(func(a, b):
		var priority_a = calculate_interrupt_priority(
			a,
			a.global_position.distance_to(player_position)
		)
		var priority_b = calculate_interrupt_priority(
			b,
			b.global_position.distance_to(player_position)
		)
		return priority_a > priority_b
	)
	
	return sorted

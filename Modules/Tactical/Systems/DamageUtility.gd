# res://Modules/Tactical/Systems/DamageUtility.gd
## Damage Calculation System
##
## PURE CLASS - Keine Godot Node Dependencies!
## 100% testbar
##
## Verantwortlichkeiten:
## - Berechne Schaden basierend auf Waffe
## - Berechne Rüstungs-Reduktion
## - Berechne Körpertreffer-Multiplikatoren

class_name DamageUtility

# ============================================================================
# DAMAGE CALCULATION
# ============================================================================

## Berechne Basis-Schaden einer Waffe
## damage_min/max aus Waffen-Definition
static func calculate_base_damage(
	damage_min: int,
	damage_max: int,
	weapon_condition: int = 100
) -> int:
	
	# Random zwischen min und max
	var base_damage = randi_range(damage_min, damage_max)
	
	# Waffen-Zustand multipliziert
	var condition_percent = float(weapon_condition) / 100.0
	base_damage = int(base_damage * condition_percent)
	
	return base_damage

## Berechne Schaden mit Attachment-Modifikatoren
static func calculate_modified_damage(
	base_damage: int,
	has_hollow_point: bool = false,
	has_ap_rounds: bool = false
) -> int:
	
	var modified_damage = base_damage
	
	# Hollow Point: Weniger Durchschlagskraft, aber mehr Schaden
	if has_hollow_point:
		modified_damage = int(modified_damage * 1.2)  # +20% Schaden
	
	# AP Rounds: Mehr Durchschlagskraft, aber weniger Schaden
	if has_ap_rounds:
		modified_damage = int(modified_damage * 1.1)  # +10% Schaden (aber penetriert mehr)
	
	return modified_damage

## Berechne Schaden nach Armor-Reduktion
static func calculate_armor_reduction(
	damage: int,
	armor_value: int,
	armor_type: String = "medium",
	ammo_type: String = "standard"
) -> int:
	
	# Rüstungs-Reduktions-Prozentsatz
	var reduction_factor = _get_armor_reduction_factor(armor_type)
	
	# Munitions-Penetration
	var penetration = _get_ammo_penetration(ammo_type)
	
	# Finale Reduktion = Armor * Reduktion * Penetration^-1
	var final_reduction = int(armor_value * reduction_factor / penetration)
	
	# Schaden nach Rüstung
	var damage_after_armor = damage - final_reduction
	
	return maxi(damage_after_armor, 0)

## Gib Rüstungs-Reduktions-Faktor zurück
static func _get_armor_reduction_factor(armor_type: String) -> float:
	match armor_type:
		"light":
			return GameConstants.ARMOR_DAMAGE_REDUCTION_LIGHT
		"medium":
			return GameConstants.ARMOR_DAMAGE_REDUCTION_MEDIUM
		"heavy":
			return GameConstants.ARMOR_DAMAGE_REDUCTION_HEAVY
		_:
			return 1.0  # Keine Rüstung

## Gib Munitions-Penetration zurück
static func _get_ammo_penetration(ammo_type: String) -> float:
	match ammo_type:
		"standard":
			return GameConstants.AMMO_PENETRATION_STANDARD
		"ap":  # Armor Piercing
			return GameConstants.AMMO_PENETRATION_AP
		"hollow_point":
			return GameConstants.AMMO_PENETRATION_HOLLOW_POINT
		_:
			return 1.0

# ============================================================================
# HIT ZONE & CRITICAL DAMAGE
# ============================================================================

## Berechne Körpertreffer-Zone Multiplikator
## hitzone = 0 (Head), 1 (Torso), 2-3 (Arms), 4-5 (Legs)
static func calculate_hitzone_multiplier(hitzone: int) -> float:
	match hitzone:
		0:  # HEAD
			return GameConstants.HITZONE_HEAD_MULTIPLIER
		1:  # TORSO
			return GameConstants.HITZONE_TORSO_MULTIPLIER
		2, 3:  # ARMS
			return GameConstants.HITZONE_LIMBS_MULTIPLIER
		4, 5:  # LEGS
			return GameConstants.HITZONE_LEGS_MULTIPLIER
		_:
			return 1.0

## Gib Körpertreffer-Zone Namen zurück
static func get_hitzone_name(hitzone: int) -> String:
	match hitzone:
		0:
			return "HEAD"
		1:
			return "TORSO"
		2:
			return "LEFT_ARM"
		3:
			return "RIGHT_ARM"
		4:
			return "LEFT_LEG"
		5:
			return "RIGHT_LEG"
		_:
			return "UNKNOWN"

## Berechne ob ein Kopfschuss letal ist
static func is_headshot_lethal(damage: int, target_hp: int) -> bool:
	return damage >= target_hp

# ============================================================================
# FINAL DAMAGE CALCULATION
# ============================================================================

## Berechne finalen Schaden mit ALLEN Modifikatoren
static func calculate_final_damage(
	weapon_min_damage: int,
	weapon_max_damage: int,
	weapon_condition: int = 100,
	armor_value: int = 0,
	armor_type: String = "medium",
	hitzone: int = 1,
	is_critical: bool = false,
	ammo_type: String = "standard",
	distance: float = 0.0,
	has_muzzle_brake: bool = false
) -> int:
	
	# SCHRITT 1: Base-Schaden (mit Waffen-Zustand)
	var base_damage = calculate_base_damage(weapon_min_damage, weapon_max_damage, weapon_condition)
	
	# SCHRITT 2: Rüstungs-Reduktion
	var damage_after_armor = calculate_armor_reduction(base_damage, armor_value, armor_type, ammo_type)
	
	# SCHRITT 3: Körpertreffer-Multiplikator
	var hitzone_multiplier = calculate_hitzone_multiplier(hitzone)
	var damage_with_hitzone = int(damage_after_armor * hitzone_multiplier)
	
	# SCHRITT 4: Critical Hit
	var final_damage = damage_with_hitzone
	if is_critical:
		final_damage = int(damage_with_hitzone * 2.0)  # 2x Schaden
	
	# SCHRITT 5: Entfernungs-Faktor (Schrotflinte nah = mehr Schaden, weit = weniger)
	# Ignore für Ballistische Waffen (Linear Drop)
	
	return GameConstants.clamp_damage(final_damage)

# ============================================================================
# BLEEDING & CRITICAL WOUNDS
# ============================================================================

## Prüfe ob ein Schuss zu Blutung führt
static func should_cause_bleeding(
	damage: int,
	hitzone: int,
	armor_protection: float
) -> bool:
	# Blutung bei signifikantem Schaden an weichen Zielen
	var bleeding_threshold = int(10.0 * armor_protection)  # Mit Rüstung schwerer
	return damage > bleeding_threshold

## Berechne Blutungs-Intensität (0.0 - 1.0)
static func calculate_bleeding_intensity(
	damage: int,
	hitzone: int
) -> float:
	var intensity = float(damage) / 50.0  # Normalisierung
	
	# Head-Schüsse bluten intensiver
	if hitzone == 0:
		intensity *= 1.5
	
	return clamp(intensity, 0.0, 1.0)

# ============================================================================
# KNOCKBACK & SPECIAL EFFECTS
# ============================================================================

## Berechne Knockback-Kraft
static func calculate_knockback_force(
	damage: int,
	target_weight: float = 1.0
) -> float:
	var knockback = float(damage) / 100.0
	knockback /= target_weight
	return knockback

## Prüfe ob Target zu Boden geht
static func should_knockdown(
	knockback_force: float,
	target_hp_percent: float
) -> bool:
	# Nur bei hohem Knockback UND nierigem HP
	if knockback_force > 1.0 and target_hp_percent < 0.3:
		return true
	return false

# ============================================================================
# EXPLOSIVE & AREA DAMAGE
# ============================================================================

## Berechne Schaden in einem Radius (für Granaten, etc.)
static func calculate_explosion_damage(
	explosion_center: Vector3,
	target_position: Vector3,
	max_damage: int,
	explosion_radius: float = 5.0
) -> int:
	
	var distance = explosion_center.distance_to(target_position)
	
	# Wenn zu weit weg: kein Schaden
	if distance > explosion_radius:
		return 0
	
	# Linear falloff: nah = max damage, weit = 0 damage
	var damage_percent = 1.0 - (distance / explosion_radius)
	var damage = int(max_damage * damage_percent)
	
	return maxi(damage, 0)

# ============================================================================
# DEBUG & UTILITIES
# ============================================================================

## Gib Schaden-Berechnung Debug-Info aus
static func get_damage_debug_info(
	base_damage: int,
	armor_reduction: int,
	hitzone_multiplier: float,
	final_damage: int
) -> String:
	var info = "Damage Calc:\n"
	info += "  Base: %d\n" % base_damage
	info += "  Armor: -%d\n" % armor_reduction
	info += "  Zone: x%.2f\n" % hitzone_multiplier
	info += "  Final: %d" % final_damage
	return info

## Gib durchschnittlichen Schaden aus (min + max / 2)
static func get_average_damage(damage_min: int, damage_max: int) -> int:
	return (damage_min + damage_max) / 2

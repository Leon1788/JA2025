# res://Modules/Tactical/Systems/CombatUtility.gd
## Combat System - Hit Chance, Cover, Stance
##
## PURE CLASS - Keine Godot Node Dependencies!
## 100% testbar
##
## Verantwortlichkeiten:
## - Berechne Trefferwahrscheinlichkeit
## - Berechne Deckungsmodifikatoren
## - Berechne Haltungsmodifikatoren

class_name CombatUtility

# ============================================================================
# HIT CHANCE CALCULATION
# ============================================================================

## Berechne Trefferwahrscheinlichkeit
## 
## Formel:
## HitChance = BASE + ShooterSkill - DistancePenalty - CoverPenalty + ScopeBonus - RecoilPenalty
##
## Ergebnis ist immer zwischen 0.0 und 1.0
static func calculate_hit_chance(
	shooter_marksmanship: int,
	distance: float,
	target_cover: int,
	shooter_stance: int,
	target_stance: int,
	attachments: Dictionary = {},
	recoil_penalty: float = 0.0,
	fatigue_modifier: float = 1.0
) -> float:
	
	# SCHRITT 1: Base-Chance
	var base_chance = GameConstants.BASE_HIT_CHANCE
	
	# SCHRITT 2: Schützen-Skill Bonus
	# Pro Punkt Marksmanship (0-100) gibt +0.003 Accuracy
	var skill_bonus = (shooter_marksmanship / 100.0) * 0.3
	
	# SCHRITT 3: Entfernungs-Penalty
	# Pro Kachel Entfernung -0.02
	var distance_penalty = (distance * GameConstants.DISTANCE_PENALTY_PER_TILE)
	
	# SCHRITT 4: Deckungs-Penalty (Ziel)
	var cover_penalty = _get_cover_penalty(target_cover)
	
	# SCHRITT 5: Haltungs-Boni (Schütze)
	var shooter_stance_bonus = _get_shooter_stance_bonus(shooter_stance)
	var target_stance_bonus = _get_target_stance_bonus(target_stance)
	
	# SCHRITT 6: Attachment-Boni (z.B. Scope)
	var scope_bonus = _get_scope_bonus(attachments)
	
	# SCHRITT 7: Recoil-Penalty (vom letzten Schuss)
	
	# SCHRITT 8: Zusammenrechnen
	var final_chance = base_chance + skill_bonus - distance_penalty - cover_penalty + shooter_stance_bonus + target_stance_bonus + scope_bonus - recoil_penalty
	final_chance *= fatigue_modifier
	
	# Clamp zu 0.0 - 1.0
	return GameConstants.clamp_hit_chance(final_chance)

## Berechne Cover-Penalty für Ziel
static func _get_cover_penalty(cover_type: int) -> float:
	match cover_type:
		GameConstants.COVER_TYPE.NONE:
			return 0.0
		GameConstants.COVER_TYPE.HALF:
			return GameConstants.COVER_PENALTY_HALF
		GameConstants.COVER_TYPE.FULL:
			return GameConstants.COVER_PENALTY_FULL
		_:
			return 0.0

## Berechne Haltungs-Bonus für Schützen
static func _get_shooter_stance_bonus(stance: int) -> float:
	match stance:
		GameConstants.STANCE.STANDING:
			return GameConstants.STANCE_PENALTY_STANDING
		GameConstants.STANCE.CROUCHING:
			return GameConstants.STANCE_BONUS_CROUCHING
		GameConstants.STANCE.PRONE:
			return GameConstants.STANCE_BONUS_PRONE
		_:
			return 0.0

## Berechne Haltungs-Bonus für Ziel (negative = Strafe für Ziel)
static func _get_target_stance_bonus(stance: int) -> float:
	match stance:
		GameConstants.STANCE.STANDING:
			return 0.0
		GameConstants.STANCE.CROUCHING:
			return -0.05  # Schwerer zu treffen
		GameConstants.STANCE.PRONE:
			return -0.10  # Noch schwerer zu treffen
		_:
			return 0.0

## Berechne Scope-Bonus (falls angebracht)
static func _get_scope_bonus(attachments: Dictionary) -> float:
	if attachments.get("has_scope", false):
		return GameConstants.ATTACHMENT_SCOPE_BONUS
	return 0.0

# ============================================================================
# COVER & DEFENSE
# ============================================================================

## Berechne Deckungswert für eine Position
## cover_value = 0.0 (keine Deckung) bis 1.0 (vollständige Deckung)
static func calculate_cover_value(los_blocked: bool, partial_cover: bool) -> float:
	if los_blocked:
		return 1.0  # Vollständige Deckung
	elif partial_cover:
		return 0.5  # Halbe Deckung
	else:
		return 0.0  # Keine Deckung

## Berechne Deckungs-Typ basierend auf Wert
static func get_cover_type_from_value(cover_value: float) -> int:
	if cover_value >= 0.9:
		return GameConstants.COVER_TYPE.FULL
	elif cover_value >= 0.3:
		return GameConstants.COVER_TYPE.HALF
	else:
		return GameConstants.COVER_TYPE.NONE

## Berechne Sicherheitswert einer Position
## Höher = Sicherer (für KI-Entscheidungen)
static func calculate_position_safety(
	distance_to_enemy: float,
	cover_value: float,
	line_of_sight: bool
) -> float:
	var safety = 0.0
	
	# Cover ist wichtigster Faktor
	safety += cover_value * 0.5
	
	# Distanz zum Enemy
	if distance_to_enemy > 15.0:
		safety += 0.3
	elif distance_to_enemy > 10.0:
		safety += 0.2
	elif distance_to_enemy > 5.0:
		safety += 0.1
	
	# Sichtbarkeit
	if not line_of_sight:
		safety += 0.2
	
	return clamp(safety, 0.0, 1.0)

# ============================================================================
# RECOIL & ACCURACY DEGRADATION
# ============================================================================

## Berechne Recoil-Penalty nach Schüssen
## shots_fired = Anzahl Schüsse in dieser Runde
static func calculate_recoil_penalty(shots_fired: int, shot_type: String) -> float:
	var base_recoil = 0.0
	
	match shot_type:
		"single":
			base_recoil = GameConstants.RECOIL_PENALTY_BASE
		"burst":
			base_recoil = GameConstants.RECOIL_PENALTY_BURST
		"auto":
			base_recoil = GameConstants.RECOIL_PENALTY_AUTO
	
	# Kumulativer Recoil pro Schuss
	var cumulative_recoil = base_recoil * shots_fired
	return clamp(cumulative_recoil, 0.0, 0.5)  # Max 50% Penalty

## Berechne Recoil-Reduktion durch Attachment
static func calculate_recoil_reduction(has_muzzle_brake: bool, has_grip: bool) -> float:
	var reduction = 0.0
	
	if has_muzzle_brake:
		reduction += GameConstants.ATTACHMENT_MUZZLE_BRAKE_RECOIL_REDUCTION
	
	if has_grip:
		reduction += GameConstants.ATTACHMENT_GRIP_RECOIL_REDUCTION
	
	return clamp(reduction, 0.0, 1.0)

## Berechne finalen Recoil mit Reduktionen
static func calculate_final_recoil(
	base_recoil: float,
	recoil_reduction: float
) -> float:
	var final_recoil = base_recoil * (1.0 - recoil_reduction)
	return clamp(final_recoil, 0.0, 1.0)

# ============================================================================
# FATIGUE & MORALE EFFECTS
# ============================================================================

## Berechne Ermüdungs-Modifikator
## fatigue = 0 (keine Ermüdung) bis 100 (völlig erschöpft)
static func calculate_fatigue_accuracy_modifier(fatigue: int) -> float:
	if fatigue <= 20:
		return 1.0  # Keine Penalty
	elif fatigue <= 40:
		return 0.95  # -5%
	elif fatigue <= 60:
		return 0.90  # -10%
	elif fatigue <= 80:
		return 0.85  # -15%
	else:
		return 0.75  # -25%

## Berechne Morale-Modifikator
## morale = 0 (panisch) bis 100 (tapfer)
static func calculate_morale_accuracy_modifier(morale: int) -> float:
	if morale >= 80:
		return 1.1  # +10% bei hoher Moral
	elif morale >= 60:
		return 1.0  # Normal
	elif morale >= 40:
		return 0.95  # -5%
	elif morale >= 20:
		return 0.85  # -15%
	else:
		return 0.70  # -30% bei Panik

# ============================================================================
# SUPPRESSION & STATUS EFFECTS
# ============================================================================

## Berechne ob Unit unterdrückt wird
## Ein Schuss in der Nähe reduziert Accuracy
static func is_unit_suppressed(
	distance_to_last_shot: float,
	last_shot_was_close: bool
) -> bool:
	if last_shot_was_close and distance_to_last_shot < 5.0:
		return true
	return false

## Berechne Suppression-Modifikator
static func calculate_suppression_modifier(is_suppressed: bool) -> float:
	return 0.70 if is_suppressed else 1.0  # -30% wenn unterdrückt

# ============================================================================
# CRITICAL HIT & SPECIAL
# ============================================================================

## Prüfe ob Critical Hit passiert
## Critical Hit = 2x Damage, aber schwer zu treffen
static func should_be_critical_hit(shot_roll: float, critical_threshold: float = 0.05) -> bool:
	return shot_roll < critical_threshold

## Berechne Critical Hit Multiplikator
static func get_critical_multiplier() -> float:
	return 2.0  # 2x Damage

# ============================================================================
# DEBUG & UTILITIES
# ============================================================================

## Gib Hit-Chance Debug-Info aus
static func get_hit_chance_debug_info(
	shooter_skill: int,
	distance: float,
	cover: int,
	shooter_stance: int
) -> String:
	var hit_chance = calculate_hit_chance(shooter_skill, distance, cover, shooter_stance, GameConstants.STANCE.STANDING)
	var hit_percent = int(hit_chance * 100)
	return "Hit Chance: %d%%" % hit_percent

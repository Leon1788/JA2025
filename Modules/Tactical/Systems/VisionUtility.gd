# res://Modules/Tactical/Systems/VisionUtility.gd
## Vision System - Line of Sight (LOS) & Field of View (FOV)
##
## PURE CLASS - Keine Godot Node Dependencies!
## 100% testbar (braucht nur raycast Callback)
##
## Verantwortlichkeiten:
## - Berechne Line of Sight zwischen zwei Punkten
## - Berechne maximale Sichtweite
## - Berechne Sichtbarkeit von Objekten

class_name VisionUtility

# ============================================================================
# VISION RANGE CALCULATION
# ============================================================================

## Berechne maximale Sichtweite für einen Merc
## sightrange = Base + Attribute Boni ± Licht Modifikator
static func calculate_sight_range(
	agility: int,
	wisdom: int,
	light_level: float = 1.0,  # 0.0 (dunkel) bis 1.0 (hell)
	has_night_vision: bool = false
) -> float:
	
	# SCHRITT 1: Base-Sichtweite
	var base_sight = GameConstants.BASE_SIGHT_RANGE as float
	
	# SCHRITT 2: Attribute-Boni
	var agility_bonus = agility * GameConstants.AGILITY_SIGHT_RANGE_PER_POINT
	var wisdom_bonus = wisdom * GameConstants.WISDOM_SIGHT_RANGE_PER_POINT
	
	# SCHRITT 3: Lichtverhältnisse
	var light_modifier = light_level
	if light_level < 0.3 and not has_night_vision:
		light_modifier = GameConstants.DARKNESS_MODIFIER
	elif has_night_vision:
		light_modifier = GameConstants.NIGHT_VISION_SIGHT_BONUS
	
	# Zusammenrechnen
	var final_sight_range = (base_sight + agility_bonus + wisdom_bonus) * light_modifier
	
	return final_sight_range

## Berechne Sichtweite Modifikator basierend auf Haltung
static func get_stance_vision_modifier(stance: int) -> float:
	match stance:
		GameConstants.STANCE.STANDING:
			return 1.0
		GameConstants.STANCE.CROUCHING:
			return 0.95  # -5% Sichtweite
		GameConstants.STANCE.PRONE:
			return 0.85  # -15% Sichtweite
		_:
			return 1.0

## Berechne Fatigue-Effekt auf Vision
static func get_fatigue_vision_modifier(fatigue: int) -> float:
	if fatigue <= 20:
		return 1.0
	elif fatigue <= 40:
		return 0.95
	elif fatigue <= 60:
		return 0.90
	elif fatigue <= 80:
		return 0.85
	else:
		return 0.70

# ============================================================================
# LINE OF SIGHT (LOS)
# ============================================================================

## Berechne ob von Position A Position B sieht (Line of Sight)
## 
## Diese Funktion braucht einen "raycast_callback" um tatsächlich Raycasting zu machen
## raycast_callback = Callable( (from: Vector3, to: Vector3) -> bool )
## 
## Returns: true = kann sehen, false = blockiert
static func can_see(
	from_position: Vector3,
	from_height: float,
	to_position: Vector3,
	to_height: float,
	obstacle_check_callback: Callable
) -> bool:
	
	# Berechne Augenhöhe des Schützen
	var eye_position = from_position + Vector3.UP * from_height
	
	# Berechne Zielposition (Kopf/Brust des Ziels)
	var target_position = to_position + Vector3.UP * to_height
	
	# Führe Raycast durch (externe Funktion, da wir keine Godot Abhängigkeit haben)
	if obstacle_check_callback.is_valid():
		return obstacle_check_callback.call(eye_position, target_position)
	
	# Fallback wenn keine Callback
	return true

## Prüfe ob Ziel in maximaler Sichtweite ist
static func is_within_sight_range(
	from_position: Vector3,
	to_position: Vector3,
	max_sight_range: float
) -> bool:
	
	var distance = from_position.distance_to(to_position)
	return distance <= max_sight_range

## Berechne Entfernung zwischen zwei Positionen (in Kacheln)
static func calculate_distance_in_tiles(
	from_position: Vector3,
	to_position: Vector3
) -> float:
	
	return from_position.distance_to(to_position) / GameConstants.TILE_SIZE

# ============================================================================
# VISIBILITY & SPOTTING
# ============================================================================

## Berechne ob Ziel sichtbar ist (Kombination aus LOS + Range + Deckung)
static func should_spot_target(
	from_position: Vector3,
	from_height: float,
	to_position: Vector3,
	to_height: float,
	max_sight_range: float,
	target_cover: int,
	target_stance: int,
	obstacle_check_callback: Callable
) -> bool:
	
	# PRÜFUNG 1: Entfernung
	if not is_within_sight_range(from_position, to_position, max_sight_range):
		return false
	
	# PRÜFUNG 2: Line of Sight
	if not can_see(from_position, from_height, to_position, to_height, obstacle_check_callback):
		return false
	
	# PRÜFUNG 3: Cover/Haltung Modifikatoren
	var cover_concealment = _get_cover_concealment(target_cover)
	var stance_concealment = _get_stance_concealment(target_stance)
	
	# Wenn gut gedeckt: kann schwerer gesehen werden
	var final_visibility = 1.0 - cover_concealment - stance_concealment
	
	# Random Chance ob wirklich erkannt (mit eingebauter Varianz)
	var spot_chance = clamp(final_visibility, 0.1, 1.0)
	return randf() < spot_chance

## Berechne Verbergung durch Cover (0.0 = sichtbar, 1.0 = unsichtbar)
static func _get_cover_concealment(cover_type: int) -> float:
	match cover_type:
		GameConstants.COVER_TYPE.NONE:
			return 0.0
		GameConstants.COVER_TYPE.HALF:
			return 0.3
		GameConstants.COVER_TYPE.FULL:
			return 0.7
		_:
			return 0.0

## Berechne Verbergung durch Haltung
static func _get_stance_concealment(stance: int) -> float:
	match stance:
		GameConstants.STANCE.STANDING:
			return 0.0
		GameConstants.STANCE.CROUCHING:
			return 0.2  # 20% weniger sichtbar
		GameConstants.STANCE.PRONE:
			return 0.4  # 40% weniger sichtbar
		_:
			return 0.0

# ============================================================================
# FIELD OF VIEW (FOV) / AUFKLÄRUNG
# ============================================================================

## Berechne Sektor-Array von Einheit (Vereinfachte FOV für Performance)
## Gibt Array von Kachel-Positionen zurück die sichtbar sind
static func get_visible_tiles(
	from_position: Vector3,
	sight_range: float,
	grid_size: Vector2i
) -> Array:
	
	var visible_tiles: Array = []
	var sight_range_squared = sight_range * sight_range
	
	# Grid-Position
	var center_grid = _world_to_grid(from_position, grid_size)
	
	# Rayon durchsuchen
	for x in range(max(0, center_grid.x - int(sight_range)), min(grid_size.x, center_grid.x + int(sight_range) + 1)):
		for z in range(max(0, center_grid.y - int(sight_range)), min(grid_size.y, center_grid.y + int(sight_range) + 1)):
			var tile = Vector2i(x, z)
			var tile_world = _grid_to_world(tile)
			
			if from_position.distance_squared_to(tile_world) <= sight_range_squared:
				visible_tiles.append(tile_world)
	
	return visible_tiles

## Hilfsfunktion: Konvertiere World zu Grid
static func _world_to_grid(world_pos: Vector3, grid_size: Vector2i) -> Vector2i:
	var grid_x = int(world_pos.x / GameConstants.TILE_SIZE)
	var grid_z = int(world_pos.z / GameConstants.TILE_SIZE)
	return Vector2i(
		clampi(grid_x, 0, grid_size.x - 1),
		clampi(grid_z, 0, grid_size.y - 1)
	)

## Hilfsfunktion: Konvertiere Grid zu World
static func _grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		grid_pos.x * GameConstants.TILE_SIZE,
		0.0,
		grid_pos.y * GameConstants.TILE_SIZE
	)

# ============================================================================
# NOISE & SOUND DETECTION
# ============================================================================

## Berechne ob ein Geräusch gehört wird
## noise_volume = 0.0 (leise) bis 1.0 (laut)
## distance = Entfernung zum Geräusch
static func can_hear_noise(
	distance: float,
	noise_volume: float,
	observer_agility: int
) -> bool:
	
	# Base hearing range (bei 1.0 Lautstärke)
	var base_hearing_range = GameConstants.INTERRUPT_SOUND_BASE_RADIUS as float
	
	# Erhöhe Range mit hoher Lautstärke
	var effective_range = base_hearing_range * noise_volume
	
	# Agility beeinflusst Hörvermögen
	var agility_bonus = observer_agility * 0.1
	effective_range += agility_bonus
	
	return distance <= effective_range

## Berechne ob Geräusch unterdrückt wird (z.B. mit Silencer)
static func is_noise_suppressed(
	has_silencer: bool,
	shot_type: String = "single"
) -> float:
	
	var suppression_factor = 1.0
	
	if has_silencer:
		suppression_factor = GameConstants.SILENCER_SOUND_REDUCTION
	
	# Auto-Feuer ist lauter
	if shot_type == "auto":
		suppression_factor *= 1.5
	elif shot_type == "burst":
		suppression_factor *= 1.2
	
	return clamp(suppression_factor, 0.0, 1.0)

# ============================================================================
# DEBUG & UTILITIES
# ============================================================================

## Gib Vision-Info aus
static func get_vision_debug_info(
	sight_range: float,
	distance_to_target: float,
	can_see: bool
) -> String:
	var info = "Vision:\n"
	info += "  Range: %.1f\n" % sight_range
	info += "  Distance: %.1f\n" % distance_to_target
	info += "  LOS: %s" % ("YES" if can_see else "NO")
	return info

## Konvertiere Sichtweite zu Kacheln
static func sight_range_to_tiles(sight_range: float) -> int:
	return int(sight_range / GameConstants.TILE_SIZE)

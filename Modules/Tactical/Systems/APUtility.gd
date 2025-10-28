# res://Modules/Tactical/Systems/APUtility.gd
## Action Point System & Pathfinding
## 
## PURE CLASS - Keine Godot Node Dependencies!
## 100% testbar, keine Side-Effects
##
## Verantwortlichkeiten:
## - Berechne AP-Kosten für Aktionen
## - Berechne optimale Pfade (A*)
## - Berücksichtige Terrain, Haltung, Status

class_name APUtility

# ============================================================================
# AP COST CALCULATIONS
# ============================================================================

## Berechne maximale AP für einen Merc
## max_ap = 50 + (AGI * 0.5) - Wund_Penalty
static func calculate_max_ap(agility: int, health_percent: float, is_wounded: bool = false) -> int:
	var base_ap = GameConstants.BASE_AP_PER_TURN
	var agility_bonus = agility * 0.5
	var wound_penalty = 10 if is_wounded else 0
	
	var max_ap = int(base_ap + agility_bonus - wound_penalty)
	return maxi(max_ap, 10)  # Minimum 10 AP

## Berechne AP-Kosten für Bewegung
## Distance = Anzahl Kacheln, Stance = Haltung
static func calculate_movement_cost(distance: int, stance: int) -> int:
	var base_cost_per_tile = GameConstants.AP_MOVE_STANDING
	var stance_multiplier = 1.0
	
	match stance:
		GameConstants.STANCE.STANDING:
			stance_multiplier = 1.0
		GameConstants.STANCE.CROUCHING:
			stance_multiplier = 1.25
		GameConstants.STANCE.PRONE:
			stance_multiplier = 1.5
		_:
			stance_multiplier = 1.0
	
	var total_cost = int(distance * base_cost_per_tile * stance_multiplier)
	return total_cost

## Berechne AP-Kosten für einen einzelnen Schritt (für Pfadfindung)
static func calculate_step_cost(current_stance: int, terrain_type: int = 0) -> int:
	var base_cost = GameConstants.AP_MOVE_STANDING
	var stance_multiplier = 1.0
	
	match current_stance:
		GameConstants.STANCE.STANDING:
			stance_multiplier = 1.0
		GameConstants.STANCE.CROUCHING:
			stance_multiplier = 1.25
		GameConstants.STANCE.PRONE:
			stance_multiplier = 1.5
	
	# Terrain-Modifikatoren (optional)
	var terrain_multiplier = 1.0
	# z.B. Schlamm = 1.5x, Wasser = 2.0x
	
	var cost = int(base_cost * stance_multiplier * terrain_multiplier)
	return cost

## Berechne AP-Kosten für Schießen
static func calculate_shot_cost(shot_type: String) -> int:
	match shot_type:
		"single":
			return GameConstants.AP_SHOOT_SINGLE
		"burst":
			return GameConstants.AP_SHOOT_BURST
		"auto":
			return GameConstants.AP_SHOOT_FULL_AUTO
		_:
			return GameConstants.AP_SHOOT_SINGLE

## Berechne AP-Kosten für Reload
static func calculate_reload_cost() -> int:
	return GameConstants.AP_RELOAD

## Berechne AP-Kosten für Haltungswechsel
static func calculate_stance_change_cost() -> int:
	return GameConstants.AP_STANCE_CHANGE

## Berechne AP-Kosten für Ausrüstung
static func calculate_equip_cost() -> int:
	return GameConstants.AP_EQUIP_ITEM

## Berechne AP-Kosten für Medizinische Aktion
static func calculate_medical_cost() -> int:
	return GameConstants.AP_USE_MEDICAL_ITEM

## Berechne Modifikator für Attachment
static func calculate_attachment_ap_modifier(attachment_data: Dictionary) -> float:
	var modifier = attachment_data.get("ap_cost_modifier", 1.0)
	return modifier

## Berechne finalen AP-Kosten mit allen Modifikatoren
static func calculate_final_shot_cost(
	base_shot_type: String,
	attachment_modifier: float = 1.0,
	fatigue_modifier: float = 1.0
) -> int:
	var base_cost = calculate_shot_cost(base_shot_type)
	var final_cost = int(base_cost * attachment_modifier * fatigue_modifier)
	return final_cost

# ============================================================================
# PATHFINDING (A* Algorithm)
# ============================================================================

## A* Pathfinding zwischen zwei Positionen
## Gibt Array[Vector3] zurück mit dem optimalen Pfad
## Returns empty Array wenn kein Pfad gefunden
static func find_path(
	start_pos: Vector3,
	target_pos: Vector3,
	grid_size: Vector2i,
	stance: int,
	can_pass_func: Callable = Callable()
) -> Array:
	
	# Konvertiere zu Grid-Koordinaten
	var start = _world_to_grid(start_pos, grid_size)
	var target = _world_to_grid(target_pos, grid_size)
	
	# Prüfe Grenzen
	if not _is_valid_grid_pos(start, grid_size) or not _is_valid_grid_pos(target, grid_size):
		return []
	
	# A* Algorithmus
	var open_set: Array = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: _heuristic(start, target)}
	
	while open_set.size() > 0:
		# Finde Node mit niedrigstem f_score
		var current_idx = 0
		var current = open_set[0]
		
		for i in range(1, open_set.size()):
			if f_score.get(open_set[i], INF) < f_score.get(current, INF):
				current_idx = i
				current = open_set[i]
		
		# Ziel erreicht
		if current == target:
			return _reconstruct_path(came_from, current)
		
		open_set.remove_at(current_idx)
		
		# Prüfe alle Nachbarn
		var neighbors = _get_neighbors(current, grid_size)
		for neighbor in neighbors:
			# Prüfe ob begehbar
			if can_pass_func.is_valid():
				if not can_pass_func.call(neighbor):
					continue
			
			var tentative_g_score = g_score.get(current, INF) + calculate_step_cost(stance)
			
			if tentative_g_score < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = g_score[neighbor] + _heuristic(neighbor, target)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	# Kein Pfad gefunden
	return []

## Hilfsfunktion: Heuristic für A*
static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return a.distance_to(b) as float

## Hilfsfunktion: Konvertiere World zu Grid
static func _world_to_grid(world_pos: Vector3, grid_size: Vector2i) -> Vector2i:
	var grid_x = int(world_pos.x / GameConstants.TILE_SIZE)
	var grid_z = int(world_pos.z / GameConstants.TILE_SIZE)
	return Vector2i(grid_x, grid_z)

## Hilfsfunktion: Konvertiere Grid zu World
static func _grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		grid_pos.x * GameConstants.TILE_SIZE,
		0.0,
		grid_pos.y * GameConstants.TILE_SIZE
	)

## Hilfsfunktion: Prüfe ob Grid-Position gültig ist
static func _is_valid_grid_pos(pos: Vector2i, grid_size: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

## Hilfsfunktion: Gib Nachbarn eines Grid-Node zurück
static func _get_neighbors(pos: Vector2i, grid_size: Vector2i) -> Array:
	var neighbors: Array = []
	
	# 8-directional movement
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			
			var neighbor = Vector2i(pos.x + dx, pos.y + dy)
			if _is_valid_grid_pos(neighbor, grid_size):
				neighbors.append(neighbor)
	
	return neighbors

## Hilfsfunktion: Rekonstruiere Pfad vom A*
static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path = [_grid_to_world(current)]
	
	while current in came_from:
		current = came_from[current]
		path.insert(0, _grid_to_world(current))
	
	return path

# ============================================================================
# PATH COST CALCULATION
# ============================================================================

## Berechne Gesamt-AP-Kosten für einen Pfad
static func calculate_path_cost(
	path: Array,
	stance: int
) -> int:
	if path.size() <= 1:
		return 0
	
	var total_cost = 0
	var step_cost = calculate_step_cost(stance)
	
	for i in range(1, path.size()):
		total_cost += step_cost
	
	return total_cost

## Prüfe ob genug AP für Pfad vorhanden ist
static func can_afford_path(current_ap: int, path: Array, stance: int) -> bool:
	var cost = calculate_path_cost(path, stance)
	return current_ap >= cost

## Prüfe ob genug AP für Aktion vorhanden ist
static func can_afford_action(current_ap: int, action_cost: int) -> bool:
	return current_ap >= action_cost

# ============================================================================
# DEBUG & UTILITIES
# ============================================================================

## Gib AP-Info aus (für Debug)
static func get_ap_debug_info(max_ap: int, current_ap: int, last_action_cost: int) -> String:
	return "AP: %d/%d (Last action: %d)" % [current_ap, max_ap, last_action_cost]

## Berechne Prozentsatz der verfügbaren AP
static func get_ap_percent(current_ap: int, max_ap: int) -> float:
	if max_ap == 0:
		return 0.0
	return float(current_ap) / float(max_ap)

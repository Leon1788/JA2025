# res://Modules/Tactical/Systems/GridSystem.gd
## Tile-basiertes Grid System für Taktik-Map
##
## Verantwortlichkeiten:
## - Grid Datenstruktur
## - Tile Properties (walkable, cover, height)
## - Unit Placement
## - Grid Queries

class_name GridSystem

# ============================================================================
# PROPERTIES - GRID
# ============================================================================

var grid_width: int = GameConstants.TACTICAL_MAP_WIDTH
var grid_height: int = GameConstants.TACTICAL_MAP_HEIGHT
var tile_size: float = GameConstants.TILE_SIZE

## Master Grid: grid[x][z] = GridTile
var grid: Array = []

# ============================================================================
# TILE DATA STRUCTURE
# ============================================================================

class GridTile:
	var x: int = 0
	var z: int = 0
	var walkable: bool = true
	var cover_type: int = GameConstants.COVER_TYPE.NONE  # 0=none, 1=half, 2=full
	var height: float = 0.0
	var occupant: MercEntity = null  # Welche Unit steht hier?
	var is_blocked: bool = false  # Von außen blockiert (z.B. Wand)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(width: int = GameConstants.TACTICAL_MAP_WIDTH, height: int = GameConstants.TACTICAL_MAP_HEIGHT) -> void:
	grid_width = width
	grid_height = height
	_initialize_grid()

## Initialisiere leeres Grid
func _initialize_grid() -> void:
	grid.clear()
	
	for x in range(grid_width):
		var row: Array = []
		for z in range(grid_height):
			var tile = GridTile.new()
			tile.x = x
			tile.z = z
			tile.walkable = true
			tile.cover_type = GameConstants.COVER_TYPE.NONE
			tile.height = 0.0
			tile.occupant = null
			tile.is_blocked = false
			row.append(tile)
		grid.append(row)

# ============================================================================
# TILE ACCESS
# ============================================================================

## Gib Tile bei Grid-Koordinaten zurück
func get_tile(x: int, z: int) -> GridTile:
	if not _is_valid_tile(x, z):
		return null
	return grid[x][z]

## Gib Tile bei World-Position zurück
func get_tile_from_world_pos(world_pos: Vector3) -> GridTile:
	var x = int(world_pos.x / tile_size)
	var z = int(world_pos.z / tile_size)
	return get_tile(x, z)

## Prüfe ob Grid-Koordinaten gültig sind
func _is_valid_tile(x: int, z: int) -> bool:
	return x >= 0 and x < grid_width and z >= 0 and z < grid_height

# ============================================================================
# TILE PROPERTIES
# ============================================================================

## Setze Tile als begehbar/blockiert
func set_tile_walkable(x: int, z: int, walkable: bool) -> void:
	var tile = get_tile(x, z)
	if tile:
		tile.walkable = walkable

## Setze Cover-Typ für Tile
func set_tile_cover(x: int, z: int, cover_type: int) -> void:
	var tile = get_tile(x, z)
	if tile:
		tile.cover_type = cover_type

## Setze Höhe für Tile (für Unterschied zwischen Stockwerken)
func set_tile_height(x: int, z: int, height: float) -> void:
	var tile = get_tile(x, z)
	if tile:
		tile.height = height

## Blockiere Tile (z.B. Wand, Objekt)
func set_tile_blocked(x: int, z: int, blocked: bool) -> void:
	var tile = get_tile(x, z)
	if tile:
		tile.is_blocked = blocked
		tile.walkable = not blocked

# ============================================================================
# UNIT PLACEMENT
# ============================================================================

## Platziere Unit auf Tile
func place_unit(unit: MercEntity, x: int, z: int) -> bool:
	var tile = get_tile(x, z)
	if tile == null or not tile.walkable or tile.occupant != null:
		return false
	
	tile.occupant = unit
	unit.global_position = _grid_to_world(x, z)
	return true

## Entferne Unit von Tile
func remove_unit(x: int, z: int) -> void:
	var tile = get_tile(x, z)
	if tile:
		tile.occupant = null

## Prüfe ob Tile besetzt ist
func is_tile_occupied(x: int, z: int) -> bool:
	var tile = get_tile(x, z)
	if tile == null:
		return false
	return tile.occupant != null

## Gib Unit auf Tile zurück
func get_unit_at(x: int, z: int) -> MercEntity:
	var tile = get_tile(x, z)
	if tile:
		return tile.occupant
	return null

# ============================================================================
# PATHFINDING HELPERS
# ============================================================================

## Prüfe ob Tile begehbar ist (für Pathfinding)
func is_tile_walkable(x: int, z: int) -> bool:
	var tile = get_tile(x, z)
	if tile == null:
		return false
	return tile.walkable and tile.occupant == null  # Auch nicht besetzt

## Gib alle begehbaren Nachbar-Tiles zurück
func get_walkable_neighbors(x: int, z: int) -> Array:
	var neighbors: Array = []
	
	# 8-directional neighbors
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			
			var nx = x + dx
			var nz = z + dz
			
			if is_tile_walkable(nx, nz):
				neighbors.append([nx, nz])
	
	return neighbors

# ============================================================================
# COORDINATE CONVERSION
# ============================================================================

## Konvertiere Grid zu World-Position
func _grid_to_world(x: int, z: int) -> Vector3:
	return Vector3(
		x * tile_size + tile_size * 0.5,
		0.0,
		z * tile_size + tile_size * 0.5
	)

## Konvertiere World zu Grid-Koordinaten
func _world_to_grid(world_pos: Vector3) -> Vector2i:
	var x = int(world_pos.x / tile_size)
	var z = int(world_pos.z / tile_size)
	return Vector2i(x, z)

# ============================================================================
# COVER QUERIES
# ============================================================================

## Gib Cover-Wert für Tile zurück
func get_cover_value(x: int, z: int) -> float:
	var tile = get_tile(x, z)
	if tile == null:
		return 0.0
	
	match tile.cover_type:
		GameConstants.COVER_TYPE.NONE:
			return 0.0
		GameConstants.COVER_TYPE.HALF:
			return 0.5
		GameConstants.COVER_TYPE.FULL:
			return 1.0
		_:
			return 0.0

# ============================================================================
# VISIBILITY QUERIES
# ============================================================================

## Gib alle Tiles in Sichtweite zurück
func get_tiles_in_range(center_x: int, center_z: int, range_tiles: int) -> Array:
	var tiles_in_range: Array = []
	
	for x in range(maxi(0, center_x - range_tiles), mini(grid_width, center_x + range_tiles + 1)):
		for z in range(maxi(0, center_z - range_tiles), mini(grid_height, center_z + range_tiles + 1)):
			var dist = sqrt((x - center_x) * (x - center_x) + (z - center_z) * (z - center_z))
			if dist <= range_tiles:
				tiles_in_range.append([x, z])
	
	return tiles_in_range

# ============================================================================
# DEBUG & VISUALIZATION
# ============================================================================

## Gib Grid-Info aus
func get_debug_info() -> String:
	var info = "GridSystem:\n"
	info += "  Size: %dx%d tiles\n" % [grid_width, grid_height]
	info += "  Tile Size: %.1f units\n" % tile_size
	
	var walkable_count = 0
	var occupied_count = 0
	
	for row in grid:
		for tile in row:
			if tile.walkable:
				walkable_count += 1
			if tile.occupant != null:
				occupied_count += 1
	
	info += "  Walkable Tiles: %d\n" % walkable_count
	info += "  Occupied Tiles: %d" % occupied_count
	return info

## Drucke Grid (debug)
func print_grid() -> void:
	print("\n=== GRID DEBUG ===")
	print("Size: %dx%d" % [grid_width, grid_height])
	for z in range(grid_height):
		var row = ""
		for x in range(grid_width):
			var tile = get_tile(x, z)
			if tile.occupant:
				row += "U "
			elif not tile.walkable:
				row += "# "
			elif tile.cover_type > 0:
				row += "C "
			else:
				row += ". "
		print(row)
	print("=================\n")

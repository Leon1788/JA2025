# res://Modules/Tactical/GridVisualizer.gd
## Visualisierung des Taktik-Grids (Debug)
##
## Zeichnet Gitter auf der Scene zum Debuggen

class_name GridVisualizer extends Node3D

# ============================================================================
# PROPERTIES
# ============================================================================

var grid: GridSystem = null
var is_visible: bool = true

var grid_lines: MeshInstance3D = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_debug_log("GridVisualizer initialized")
	
	# Warte bis TacticalScene bereit ist
	await get_tree().process_frame
	_get_grid_reference()
	
	# Zeichne Grid einmalig
	_draw_grid_mesh()

func _process(delta: float) -> void:
	# DEBUG: Drücke G zum Toggle Grid Visibility
	if Input.is_key_pressed(KEY_G):
		is_visible = not is_visible
		if grid_lines:
			grid_lines.visible = is_visible
		_debug_log("Grid visibility: %s" % ("ON" if is_visible else "OFF"))
		await get_tree().create_timer(0.5).timeout  # Debounce

# ============================================================================
# SETUP
# ============================================================================

## Hole Grid-Referenz vom TacticalManager
func _get_grid_reference() -> void:
	var parent = get_parent() as Node
	if parent == null:
		_debug_log("Parent is null!")
		return
	
	# Suche TacticalScene (sollte Parent sein)
	var scene = parent as TacticalScene
	if scene == null:
		_debug_log("Parent is not TacticalScene!")
		return
	
	var manager = scene.get_tactical_manager()
	if manager == null:
		_debug_log("TacticalManager not found!")
		return
	
	grid = manager.grid
	if grid == null:
		_debug_log("Grid not found in TacticalManager!")
		return
	
	_debug_log("Grid reference obtained: %dx%d tiles" % [grid.grid_width, grid.grid_height])

# ============================================================================
# MESH GENERATION
# ============================================================================

## Generiere Grid-Mesh einmalig
func _draw_grid_mesh() -> void:
	if grid == null:
		_debug_log("Grid is null, cannot draw!")
		return
	
	# Erstelle SurfaceTool
	var surface_tool = SurfaceTool.new()
	
	# Zeichne Gitter-Linien als Mesh
	_generate_grid_lines(surface_tool)
	
	# Erstelle MeshInstance3D
	if grid_lines == null:
		grid_lines = MeshInstance3D.new()
		add_child(grid_lines)
	
	grid_lines.mesh = surface_tool.commit()
	
	# Material
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 0.4, 0.4, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_lines.set_surface_override_material(0, mat)
	
	_debug_log("Grid mesh drawn successfully")

## Generiere Grid-Linien
func _generate_grid_lines(surface_tool: SurfaceTool) -> void:
	surface_tool.begin(Mesh.PRIMITIVE_LINES)
	
	var tile_size = grid.tile_size
	var width = grid.grid_width
	var height = grid.grid_height
	
	# Vertikale Linien (X-Richtung)
	for x in range(width + 1):
		var x_pos = x * tile_size
		surface_tool.add_vertex(Vector3(x_pos, 0.05, 0))
		surface_tool.add_vertex(Vector3(x_pos, 0.05, height * tile_size))
	
	# Horizontale Linien (Z-Richtung)
	for z in range(height + 1):
		var z_pos = z * tile_size
		surface_tool.add_vertex(Vector3(0, 0.05, z_pos))
		surface_tool.add_vertex(Vector3(width * tile_size, 0.05, z_pos))

# ============================================================================
# DEBUG
# ============================================================================

func _debug_log(message: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[GridVisualizer] " + message)

# res://Modules/Tactical/TacticalScene.gd (REFACTORED)
## Root Scene für Taktischen Kampf
##
## Verantwortlichkeiten:
## - Scene Setup & Initialization
## - TacticalManager Koordination
## - Test Combat Setup
## - Debug Input Handling

class_name TacticalScene extends Node3D

# ============================================================================
# PROPERTIES - SCENE REFERENCES
# ============================================================================

var tactical_manager: TacticalManager = null
var event_bus: EventBus = null
var grid_visualizer: GridVisualizer = null

var player_mercs: Array = []
var enemy_mercs: Array = []

var combat_started: bool = false
var selected_unit: MercEntity = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	DebugLogger.log("TacticalScene", "Starting...")
	
	# Erstelle EventBus (lokal für diese Scene)
	_create_event_bus()
	
	# Registriere bei GlobalController
	GameController.current_event_bus = event_bus
	
	# Erstelle TacticalManager
	_create_tactical_manager()
	
	# Setup Test Combat
	_setup_test_combat()
	
	# Erstelle Grid Visualizer (für Debug)
	_create_grid_visualizer()
	
	# Setup Input Handling
	_setup_input()
	
	_print_instructions()
	
	DebugLogger.log("TacticalScene", "Ready!")

func _process(delta: float) -> void:
	_handle_debug_input()

# ============================================================================
# SCENE CREATION
# ============================================================================

## Erstelle lokalen EventBus
func _create_event_bus() -> void:
	event_bus = EventBus.new()
	event_bus.name = "EventBus"
	add_child(event_bus)
	
	DebugLogger.log("TacticalScene", "EventBus created (local)")

## Erstelle TacticalManager
func _create_tactical_manager() -> void:
	tactical_manager = TacticalManager.new()
	tactical_manager.name = "TacticalManager"
	add_child(tactical_manager)
	
	# Verbinde Signals
	tactical_manager.combat_started.connect(_on_combat_started)
	tactical_manager.combat_ended.connect(_on_combat_ended)
	
	DebugLogger.log("TacticalScene", "TacticalManager created")

## Erstelle Grid Visualizer (Debug-Gitter)
func _create_grid_visualizer() -> void:
	grid_visualizer = GridVisualizer.new()
	grid_visualizer.name = "GridVisualizer"
	add_child(grid_visualizer)
	
	DebugLogger.log("TacticalScene", "GridVisualizer created")

## Setup Input Actions
func _setup_input() -> void:
	# InputMap prüfen und erstellen falls nötig
	if not InputMap.has_action("left_click"):
		InputMap.add_action("left_click")
		InputMap.action_add_event("left_click", InputEventMouseButton.new())
	
	if not InputMap.has_action("right_click"):
		InputMap.add_action("right_click")
		InputMap.action_add_event("right_click", InputEventMouseButton.new())

# ============================================================================
# TEST COMBAT SETUP
# ============================================================================

## Initialisiere Test Combat
func _setup_test_combat() -> void:
	DebugLogger.log("TacticalScene", "Setting up test combat...")
	
	# Erstelle 2 Player Mercs
	for i in range(2):
		var merc = _create_test_merc("Player", i, "player")
		player_mercs.append(merc)
		add_child(merc)
	
	# Erstelle 2 Enemy Mercs
	for i in range(2):
		var merc = _create_test_merc("Enemy", i, "enemy")
		enemy_mercs.append(merc)
		add_child(merc)
	
	DebugLogger.log("TacticalScene", "Test mercs created: %d player, %d enemy" % [player_mercs.size(), enemy_mercs.size()])

## Erstelle einen Test-Merc
func _create_test_merc(faction_name: String, index: int, faction: String) -> MercEntity:
	# Lade Scene
	var merc_scene = load("res://Modules/Tactical/Entities/MercEntity.tscn")
	var merc = merc_scene.instantiate() as MercEntity
	
	# Basis-Daten
	merc.merc_id = "%s_%d" % [faction_name.to_lower(), index]
	merc.merc_name = "%s %d" % [faction_name, index + 1]
	merc.faction = faction
	
	# Randomize Stats (aber sinnvoll)
	merc.agility = 45 + randi() % 40  # 45-85
	merc.marksmanship = 45 + randi() % 40
	merc.wisdom = 45 + randi() % 40
	merc.strength = 45 + randi() % 40
	
	# Profil-Daten
	var profile = {
		"id": merc.merc_id,
		"name": merc.merc_name,
		"faction": faction,
		"agility": merc.agility,
		"marksmanship": merc.marksmanship,
		"wisdom": merc.wisdom,
		"strength": merc.strength,
		"armor_value": 5 if faction == "enemy" else 0,
		"armor_type": "medium",
		"model_path": "",
		"starting_weapon": {
			"id": "rifle_test",
			"name": "Assault Rifle",
			"damage_min": 18,
			"damage_max": 38,
			"magazine_size": 30,
			"ammo": 30,
			"condition": 100,
			"ammo_type": "standard",
			"attachments": {}
		}
	}
	
	merc.setup_from_profile(profile)
	
	return merc

# ============================================================================
# COMBAT CONTROL
# ============================================================================

## Starte Test-Kampf
func _start_test_combat() -> void:
	if combat_started:
		DebugLogger.warn("TacticalScene", "Combat already started!")
		return
	
	DebugLogger.log("TacticalScene", "Starting test combat!")
	tactical_manager.start_combat(player_mercs, enemy_mercs, event_bus)
	combat_started = true

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_combat_started() -> void:
	DebugLogger.log("TacticalScene", "Combat started event!")
	event_bus.combat_started.emit({})

func _on_combat_ended(victory: bool) -> void:
	DebugLogger.log("TacticalScene", "Combat ended! Victory: %s" % ("YES" if victory else "NO"))
	event_bus.combat_ended.emit(victory)
	combat_started = false

# ============================================================================
# DEBUG INPUT HANDLING
# ============================================================================

func _handle_debug_input() -> void:
	# E - Starte Kampf
	if Input.is_action_just_pressed("ui_select") and not combat_started:
		_start_test_combat()
	
	# SPACE - Beende Turn
	if Input.is_action_just_pressed("ui_accept") and combat_started:
		if tactical_manager.is_player_turn():
			DebugLogger.log("TacticalScene", "Ending player turn...")
			tactical_manager.player_end_turn()
	
	# 1-4 - Wähle Unit (Player mercs)
	if Input.is_action_just_pressed("ui_1") and combat_started:
		_select_unit(0)
	if Input.is_action_just_pressed("ui_2") and combat_started:
		_select_unit(1)
	if Input.is_action_just_pressed("ui_3") and combat_started:
		_select_unit(2)
	if Input.is_action_just_pressed("ui_4") and combat_started:
		_select_unit(3)
	
	# M - Print Debug Info
	if Input.is_action_just_pressed("ui_cancel"):
		print(tactical_manager.get_debug_info())
	
	# G - Toggle Grid (wurde schon in GridVisualizer gemacht, aber doppelt ok)
	if Input.is_key_pressed(KEY_G):
		if grid_visualizer:
			grid_visualizer.is_visible = not grid_visualizer.is_visible
	
	# Mouse Click - Bewege Unit
	if Input.is_action_just_pressed("left_click") and combat_started and tactical_manager.is_player_turn():
		_handle_left_click()
	
	# Right Click - Schießen
	if Input.is_action_just_pressed("right_click") and combat_started and tactical_manager.is_player_turn():
		_handle_right_click()

## Linker Click - Bewegung
func _handle_left_click() -> void:
	if selected_unit == null:
		DebugLogger.log("TacticalScene", "No unit selected. Press 1-4 to select unit.")
		return
	
	# Berechne World Position unter Maus
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	
	if camera == null:
		return
	
	var ray = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, 0)  # Boden Plane
	var intersection = plane.intersects_ray(camera.global_position, ray)
	
	if intersection == null:
		DebugLogger.log("TacticalScene", "Could not calculate world position")
		return
	
	var target_pos = intersection as Vector3
	
	DebugLogger.log("TacticalScene", "Moving %s to %v" % [selected_unit.merc_name, target_pos])
	
	var success = await tactical_manager.player_move_unit(target_pos)
	
	if success:
		DebugLogger.log("TacticalScene", "Movement successful!")
	else:
		DebugLogger.warn("TacticalScene", "Movement failed!")

## Rechter Click - Schießen
func _handle_right_click() -> void:
	if selected_unit == null:
		DebugLogger.log("TacticalScene", "No unit selected. Press 1-4 to select unit.")
		return
	
	# Finde nächsten feindlichen Unit zum Schießen
	var target = _find_nearest_enemy_from(selected_unit)
	
	if target == null:
		DebugLogger.warn("TacticalScene", "No visible target!")
		return
	
	DebugLogger.log("TacticalScene", "%s shoots at %s" % [selected_unit.merc_name, target.merc_name])
	
	var success = await tactical_manager.player_shoot_unit(target)
	
	if success:
		DebugLogger.log("TacticalScene", "Shot fired!")
	else:
		DebugLogger.warn("TacticalScene", "Shot failed!")

## Wähle Unit
func _select_unit(index: int) -> void:
	if index >= player_mercs.size():
		DebugLogger.warn("TacticalScene", "Unit %d does not exist!" % (index + 1))
		return
	
	selected_unit = player_mercs[index]
	DebugLogger.log("TacticalScene", "Selected: %s (HP: %d, AP: %d)" % [
		selected_unit.merc_name,
		selected_unit.get_current_hp(),
		selected_unit.get_current_ap()
	])

## Finde nächsten Enemy
func _find_nearest_enemy_from(unit: MercEntity) -> MercEntity:
	var nearest = null
	var nearest_distance = INF
	
	for enemy in enemy_mercs:
		if not enemy.is_alive():
			continue
		
		# Prüfe ob sichtbar
		var vision = unit.get_component("VisionComponent") as VisionComponent
		if vision and not vision.can_see(enemy):
			continue
		
		var distance = unit.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	
	return nearest

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

func get_tactical_manager() -> TacticalManager:
	return tactical_manager

func get_event_bus() -> EventBus:
	return event_bus

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Print Anleitung
func _print_instructions() -> void:
	print("\n" + "=".repeat(60))
	print("🎮 TACTICAL SCENE - DEBUG CONTROLS")
	print("=".repeat(60))
	print("\n📋 COMBAT:")
	print("  E           - Start combat")
	print("  SPACE       - End turn")
	print("\n👤 UNIT SELECTION:")
	print("  1-4         - Select player unit 1-4")
	print("\n⚔️  ACTIONS:")
	print("  LEFT CLICK  - Move selected unit to position")
	print("  RIGHT CLICK - Shoot nearest visible enemy")
	print("\n🔧 DEBUG:")
	print("  G           - Toggle grid visualization")
	print("  M           - Print debug info")
	print("  ESC         - Print this menu again")
	print("\n" + "=".repeat(60) + "\n")

# ============================================================================
# FINAL STATS / END GAME
# ============================================================================

## Drucke Kampf-Statistik
func print_combat_stats() -> void:
	print("\n" + "=".repeat(60))
	print("📊 COMBAT STATISTICS")
	print("=".repeat(60))
	
	print("\n🔵 PLAYER UNITS:")
	for unit in player_mercs:
		var status = "ALIVE" if unit.is_alive() else "DEAD"
		var soldier_state = unit.get_component("SoldierState") as SoldierState
		print("  %s: HP %d/%d | %s" % [
			unit.merc_name,
			unit.get_current_hp(),
			soldier_state.max_hp if soldier_state else 100,
			status
		])
	
	print("\n🔴 ENEMY UNITS:")
	for unit in enemy_mercs:
		var status = "ALIVE" if unit.is_alive() else "DEAD"
		var soldier_state = unit.get_component("SoldierState") as SoldierState
		print("  %s: HP %d/%d | %s" % [
			unit.merc_name,
			unit.get_current_hp(),
			soldier_state.max_hp if soldier_state else 100,
			status
		])
	
	if tactical_manager:
		print("\n" + tactical_manager.get_debug_info())
	
	print("\n" + "=".repeat(60) + "\n")

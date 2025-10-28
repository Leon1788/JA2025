# res://Modules/Tactical/TacticalScene.gd
## Root Script für Taktisches Kampf-Szenario
##
## Verantwortlichkeiten:
## - Scene Setup
## - TacticalManager Instantiation
## - EventBus Creation (Local)
## - UI Initialization

class_name TacticalScene extends Node3D

# ============================================================================
# PROPERTIES - SCENE REFERENCES
# ============================================================================

var tactical_manager: TacticalManager = null
var event_bus: EventBus = null

var player_mercs: Array = []
var enemy_mercs: Array = []

var test_combat_data: Dictionary = {}
var combat_started: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_debug_log("TacticalScene starting...")
	
	# Erstelle lokalen EventBus
	_create_event_bus()
	
	# Registriere bei GameController
	GameController.current_event_bus = event_bus
	
	# Erstelle TacticalManager
	_create_tactical_manager()
	
	# Setup Test-Combat (für Phase 4 Testing)
	_setup_test_combat()
	
	_debug_log("TacticalScene ready!")
	_debug_log("Drücke E zum Kampf starten!")

func _process(delta: float) -> void:
	# DEBUG: Drücke E zum Kampf Starten
	if Input.is_key_pressed(KEY_E) and not combat_started:
		_debug_log("Starting combat!")
		_start_test_combat()
		combat_started = true
	
	# DEBUG: Drücke SPACE zum Turn Ende
	if Input.is_key_pressed(KEY_SPACE) and tactical_manager and tactical_manager.is_player_acting():
		_debug_log("Ending player turn!")
		tactical_manager.end_actor_turn()

# ============================================================================
# EVENT BUS
# ============================================================================

## Erstelle lokalen EventBus für diese Scene
func _create_event_bus() -> void:
	event_bus = EventBus.new()
	event_bus.name = "EventBus"
	add_child(event_bus)
	
	# Verbinde Signals
	event_bus.turn_started.connect(_on_turn_started)
	event_bus.turn_ended.connect(_on_turn_ended)
	
	_debug_log("EventBus created (local)")

# ============================================================================
# TACTICAL MANAGER
# ============================================================================

## Erstelle und konfiguriere TacticalManager
func _create_tactical_manager() -> void:
	tactical_manager = TacticalManager.new()
	tactical_manager.name = "TacticalManager"
	add_child(tactical_manager)
	
	# Verbinde Signals
	tactical_manager.combat_started.connect(_on_combat_started)
	tactical_manager.combat_ended.connect(_on_combat_ended)
	tactical_manager.turn_started.connect(_on_turn_started)
	tactical_manager.turn_ended.connect(_on_turn_ended)
	tactical_manager.interrupt_triggered.connect(_on_interrupt)
	
	_debug_log("TacticalManager created")

# ============================================================================
# SCENE SETUP
# ============================================================================

## Initialisiere Test-Kampf (für Phase 4 Demo)
func _setup_test_combat() -> void:
	_debug_log("Setting up test combat...")
	
	# Erstelle Player Mercs
	player_mercs = []
	for i in range(2):
		var merc = _create_test_merc("Player", i, "player")
		player_mercs.append(merc)
		add_child(merc)
	
	# Erstelle Enemy Mercs
	enemy_mercs = []
	for i in range(2):
		var merc = _create_test_merc("Enemy", i, "enemy")
		enemy_mercs.append(merc)
		add_child(merc)
	
	_debug_log("Test mercs created. Ready to start!")

## Erstelle Test-Merc
func _create_test_merc(faction_name: String, index: int, faction: String) -> MercEntity:
	# Lade Scene
	var merc_scene = load("res://Modules/Tactical/Entities/MercEntity.tscn")
	var merc = merc_scene.instantiate() as MercEntity
	
	# Konfiguriere
	merc.merc_id = "%s_%d" % [faction_name.to_lower(), index]
	merc.merc_name = "%s %d" % [faction_name, index + 1]
	merc.faction = faction
	merc.agility = 50 + randi() % 30
	merc.marksmanship = 50 + randi() % 30
	merc.wisdom = 50 + randi() % 30
	merc.strength = 50 + randi() % 30
	
	# Initialisiere mit Profil
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
			"name": "Test Rifle",
			"damage_min": 15,
			"damage_max": 35,
			"magazine_size": 30,
			"ammo": 30,
			"condition": 100,
			"ammo_type": "standard",
			"attachments": {}
		}
	}
	
	merc.setup_from_profile(profile)
	
	_debug_log("Created test merc: %s (%s)" % [merc.merc_name, merc.faction])
	return merc

## Starte Test-Kampf
func _start_test_combat() -> void:
	_debug_log("Starting test combat!")
	tactical_manager.start_combat(player_mercs, enemy_mercs)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_combat_started() -> void:
	_debug_log("Combat started!")
	event_bus.combat_started.emit({})

func _on_combat_ended(victory: bool) -> void:
	_debug_log("Combat ended! Victory: %s" % ("YES" if victory else "NO"))
	event_bus.combat_ended.emit(victory)

func _on_turn_started(actor: MercEntity) -> void:
	_debug_log("Turn started: %s (Faction: %s)" % [actor.merc_name, actor.faction])
	event_bus.turn_started.emit(GameConstants.TURN_STATE.PLAYER_TURN, actor)

func _on_turn_ended() -> void:
	_debug_log("Turn ended")
	event_bus.turn_ended.emit()

func _on_interrupt(interrupter: MercEntity, target: MercEntity) -> void:
	_debug_log("Interrupt! %s interrupts %s" % [interrupter.merc_name, target.merc_name])
	event_bus.interrupt_triggered.emit(interrupter, target)

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

## Spieler befiehlt Unit, zu bewegen
func player_move_unit(unit: MercEntity, target_pos: Vector3) -> bool:
	if tactical_manager == null:
		return false
	
	return await tactical_manager.player_order_move(unit, target_pos)

## Spieler befiehlt Unit, zu schießen
func player_shoot_unit(unit: MercEntity, target: MercEntity) -> bool:
	if tactical_manager == null:
		return false
	
	return await tactical_manager.player_order_shoot(unit, target)

## Beende aktuellen Turn
func end_current_turn() -> void:
	if tactical_manager == null:
		return
	
	tactical_manager.end_actor_turn()

## Gib TacticalManager zurück
func get_tactical_manager() -> TacticalManager:
	return tactical_manager

## Gib EventBus zurück
func get_event_bus() -> EventBus:
	return event_bus

# ============================================================================
# DEBUG
# ============================================================================

func _debug_log(message: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[TacticalScene] " + message)

func print_scene_debug() -> void:
	print("\n=== TacticalScene Debug ===")
	print("Tactical Manager: %s" % tactical_manager.get_debug_info())
	print("Player Units: %d" % player_mercs.size())
	for unit in player_mercs:
		print("  - %s (HP: %d/%d, AP: %d/%d)" % [
			unit.merc_name,
			unit.get_current_hp(),
			unit.get_soldier_state().max_hp,
			unit.get_current_ap(),
			unit.get_soldier_state().max_ap
		])
	print("Enemy Units: %d" % enemy_mercs.size())
	for unit in enemy_mercs:
		print("  - %s (HP: %d/%d, AP: %d/%d)" % [
			unit.merc_name,
			unit.get_current_hp(),
			unit.get_soldier_state().max_hp,
			unit.get_current_ap(),
			unit.get_soldier_state().max_ap
		])
	print("========================\n")

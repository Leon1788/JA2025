# res://Tests/test_packet_3.gd
## INTEGRATIONSTEST für Packet 3: Inventory & Equipment
##
## KORRIGIERT (30.10.2025): Erbt jetzt von TestBase, um
## die 'pass_test', 'assert_true' etc. Funktionen zu erhalten.

extends "res://Tests/TestBase.gd"

# Importiere alle Klassen, die wir benötigen
const MercEntity = preload("res://Modules/Tactical/Entities/MercEntity.gd")
const SoldierState = preload("res://Modules/Tactical/Components/SoldierState.gd")
const CombatComponent = preload("res://Modules/Tactical/Components/CombatComponent.gd")
const InventoryComponent = preload("res://Modules/Tactical/Components/InventoryComponent.gd")

const WeaponResource = preload("res://Architecture/Resources/WeaponResource.gd")
const AttachmentResource = preload("res://Architecture/Resources/AttachmentResource.gd")
const ItemInstance = preload("res://Modules/Tactical/Inventory/ItemInstance.gd")
const NullComponent = preload("res://Architecture/NullComponent.gd")

# Mocks für Komponenten, die wir nicht testen, aber die MercEntity braucht
const MovementComponent = preload("res://Modules/Tactical/Components/MovementComponent.gd")
const VisionComponent = preload("res://Modules/Tactical/Components/VisionComponent.gd")
const AIComponent = preload("res://Modules/Tactical/Components/AIComponent.gd")

# Test-Variablen (geerbt von TestBase)
# var tests_passed: int = 0
# var tests_failed: int = 0

# Mock-Objekte
var merc: MercEntity
var state: SoldierState
var combat: CombatComponent
var inventory: InventoryComponent

var test_rifle_res: WeaponResource
var test_scope_res: AttachmentResource
var test_armor_res: WeaponResource # Wir simulieren Rüstung mit einer WeaponResource

# MOCK OBJEKTE (müssen erstellt werden, da MercEntity sie erwartet)
var mock_movement: MovementComponent
var mock_vision: VisionComponent
var mock_ai: AIComponent


func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("🧪 STARTING PACKET 3 INTEGRATION TEST (Inventory & Equipment)")
	print("=".repeat(80) + "\n")
	
	# 1. Mock-Daten im DataManager erstellen
	setup_mock_data_manager()
	
	# 2. Mock-Entity im Speicher aufbauen
	setup_mock_entity()
	
	# 3. Tests durchführen
	if tests_failed == 0: # Stoppe Tests, wenn Setup fehlschlägt
		test_add_item_to_inventory()
	if tests_failed == 0:
		test_equip_weapon()
	if tests_failed == 0:
		test_equip_armor()
	if tests_failed == 0:
		test_attach_mod()
	if tests_failed == 0:
		test_unequip_all()
	
	# 4. Aufräumen
	cleanup_mock_entity()
	
	# 5. Zusammenfassung (Funktion von TestBase)
	_print_summary("PACKET 3 INTEGRATION")

# ============================================================================
# TEST SETUP
# ============================================================================

## Erstellt Test-Ressourcen und lädt sie in den Cache des DataManagers
func setup_mock_data_manager() -> void:
	# 1. Test-Gewehr
	test_rifle_res = WeaponResource.new()
	test_rifle_res.id = "test_rifle"
	test_rifle_res.weapon_name = "Test Rifle"
	test_rifle_res.accuracy = 0.7
	test_rifle_res.ap_cost_single = 8
	test_rifle_res.attachment_slots = PackedStringArray(["scope", "muzzle"])
	DataManager.weapon_cache[test_rifle_res.id] = test_rifle_res

	# 2. Test-Zielfernrohr
	test_scope_res = AttachmentResource.new()
	test_scope_res.id = "test_scope"
	test_scope_res.stat_modifiers = {"accuracy_bonus": 0.1}
	test_scope_res.compatible_slots = PackedStringArray(["scope"])
	DataManager.attachment_cache[test_scope_res.id] = test_scope_res

	# 3. Test-Rüstung (simuliert mit WeaponResource)
	test_armor_res = WeaponResource.new()
	test_armor_res.id = "test_armor"
	test_armor_res.weapon_name = "Test Vest"
	DataManager.weapon_cache[test_armor_res.id] = test_armor_res
	
	pass_test("Setup: Mock-DataManager initialisiert")

## Erstellt eine MercEntity im Speicher mit allen Komponenten
func setup_mock_entity() -> void:
	merc = MercEntity.new()
	merc.name = "TestMerc"
	
	state = SoldierState.new()
	state.name = "SoldierState"
	
	combat = CombatComponent.new()
	combat.name = "CombatComponent"
	
	inventory = InventoryComponent.new()
	inventory.name = "InventoryComponent"
	
	# Echte Mocks für die restlichen Komponenten
	mock_movement = MovementComponent.new()
	mock_movement.name = "MovementComponent"
	mock_vision = VisionComponent.new()
	mock_vision.name = "VisionComponent"
	mock_ai = AIComponent.new()
	mock_ai.name = "AIComponent"

	# Komponenten zur Entity hinzufügen (Simuliert die Szene)
	merc.add_child(state)
	merc.add_child(combat)
	merc.add_child(inventory)
	merc.add_child(mock_movement)
	merc.add_child(mock_vision)
	merc.add_child(mock_ai)
	
	# _ready() manuell aufrufen (normalerweise macht das die Szene)
	# Wichtig, damit 'entity' und 'get_sibling_component' funktionieren
	merc._ready() # Ruft _gather_components auf
	
	# Komponenten einzeln aufrufen (wie Godot es tun würde)
	for child in merc.get_children():
		if child is IComponent:
			child._ready()
	
	# Sicherstellen, dass die Mocks nicht null sind (falls _ready() fehlschlägt)
	if inventory.get_sibling_component("CombatComponent") == null: # KORRIGIERT: 'is NullComponent' -> '== null'
		fail_test("Setup: Sibling-Verknüpfung (Inventory -> Combat) FEHLGESCHLAGEN", "MercEntity._gather_components() hat CombatComponent nicht gefunden.")
		return
	if combat.get_sibling_component("SoldierState") == null: # KORRIGIERT: 'is NullComponent' -> '== null'
		fail_test("Setup: Sibling-Verknüpfung (Combat -> State) FEHLGESCHLAGEN", "MercEntity._gather_components() hat SoldierState nicht gefunden.")
		return
		
	assert_true(inventory.get_sibling_component("CombatComponent") is CombatComponent, "Setup: Sibling-Verknüpfung (Inventory -> Combat) OK")
	assert_true(combat.get_sibling_component("SoldierState") is SoldierState, "Setup: Sibling-Verknüpfung (Combat -> State) OK")
	assert_true(inventory.entity == merc, "Setup: Entity-Verknüpfung (Inventory -> Merc) OK")
	
	# on_enable() aufrufen, um die Komponenten zu aktivieren (wichtig für _update_component_stats)
	inventory.on_enable()

## Räumt die Mock-Entity auf
func cleanup_mock_entity() -> void:
	DataManager.weapon_cache.clear()
	DataManager.attachment_cache.clear()
	if merc and is_instance_valid(merc):
		merc.queue_free()
	pass_test("Cleanup: Mock-Daten entfernt")

# ============================================================================
# TESTS
# ============================================================================

func test_add_item_to_inventory() -> void:
	print("\n[TEST 1] InventoryComponent.add_item_to_inventory()")
	var rifle_inst = ItemInstance.from_weapon_resource(test_rifle_res)
	
	var success = inventory.add_item_to_inventory(rifle_inst)
	
	assert_true(success, "Add Item: Funktion war erfolgreich")
	assert_equal(inventory.inventory_slots.size(), 1, "Add Item: 'inventory_slots' Größe ist 1")
	assert_equal(inventory.inventory_slots[0], rifle_inst, "Add Item: Korrektes Item im Slot")

func test_equip_weapon() -> void:
	print("\n[TEST 2] InventoryComponent.equip_item_from_inventory() (Waffe)")
	var rifle_inst = inventory.get_items_by_type("rifle")[0]
	assert_not_null(rifle_inst, "Equip Weapon: Setup - Waffe im Rucksack gefunden")
	
	var success = inventory.equip_item_from_inventory("primary_weapon", rifle_inst)
	
	assert_true(success, "Equip Weapon: Funktion war erfolgreich")
	assert_equal(inventory.inventory_slots.size(), 0, "Equip Weapon: 'inventory_slots' ist jetzt leer")
	assert_equal(inventory.equipment_slots["primary_weapon"], rifle_inst, "Equip Weapon: 'equipment_slots' hat die Waffe")
	assert_equal(combat.equipped_weapon_instance, rifle_inst, "Equip Weapon: CombatComponent wurde aktualisiert (SYNC OK)")

func test_equip_armor() -> void:
	print("\n[TEST 3] InventoryComponent.equip_item_from_inventory() (Rüstung)")
	# HINWEIS: Wir müssen die Rüstungs-Stats manuell in die 'base_weapon_data'
	# der ItemInstance injizieren, da 'test_armor_res' keine Rüstungs-Klasse ist.
	var armor_inst = ItemInstance.from_weapon_resource(test_armor_res)
	armor_inst.base_weapon_data["armor_value"] = 50
	armor_inst.base_weapon_data["armor_type"] = "heavy"
	# Stats neu berechnen, um die Rüstungswerte in 'effective_stats' zu bekommen
	WeaponModSystem.recalculate_stats(armor_inst) 
	
	inventory.add_item_to_inventory(armor_inst) # Erst in Rucksack
	
	var success = inventory.equip_item_from_inventory("armor", armor_inst)
	
	assert_true(success, "Equip Armor: Funktion war erfolgreich")
	assert_equal(inventory.equipment_slots["armor"], armor_inst, "Equip Armor: 'equipment_slots' hat die Rüstung")
	
	# Der wichtigste Test: Wurde der SoldierState aktualisiert?
	assert_equal(state.armor_value, 50, "Equip Armor: SoldierState.armor_value wurde aktualisiert (SYNC OK)")
	assert_equal(state.armor_type, "heavy", "Equip Armor: SoldierState.armor_type wurde aktualisiert (SYNC OK)")

func test_attach_mod() -> void:
	print("\n[TEST 4] InventoryComponent.attach_mod()")
	# Setup: Erstelle eine ItemInstance für das Scope und lege sie in den Rucksack
	var scope_inst = ItemInstance.new()
	scope_inst.instance_id = "scope_instance_1"
	scope_inst.base_item_id = "test_scope" # Wichtig, damit DataManager es findet
	inventory.add_item_to_inventory(scope_inst)
	
	assert_equal(inventory.inventory_slots.size(), 1, "Attach Mod: Setup - Scope ist im Rucksack")
	
	var base_accuracy = combat.equipped_weapon_instance.get_effective_stats()["accuracy"]
	
	# Test: Mod anbringen
	var success = inventory.attach_mod("primary_weapon", scope_inst, "scope")
	
	assert_true(success, "Attach Mod: Funktion war erfolgreich")
	assert_equal(inventory.inventory_slots.size(), 0, "Attach Mod: Scope-Item wurde aus Rucksack verbraucht")
	
	var modified_accuracy = combat.equipped_weapon_instance.get_effective_stats()["accuracy"]

# res://Tests/test_resources.gd
## Unit-Test-Suite für Packet 1 (WeaponModSystem) und Packet 2 (Data Resources).
##
## KORRIGIERT (30.10.2025): Erbt jetzt von TestBase und entfernt
## alle doppelten Hilfsfunktionen.

extends "res://Tests/TestBase.gd"

# Importiere die neuen Klassen, damit wir sie verwenden können
const WeaponResource = preload("res://Architecture/Resources/WeaponResource.gd")
const AttachmentResource = preload("res://Architecture/Resources/AttachmentResource.gd")
const MercProfile = preload("res://Architecture/Resources/MercProfile.gd")
const ItemInstance = preload("res://Modules/Tactical/Inventory/ItemInstance.gd")
const WeaponModSystem = preload("res://Modules/Inventory/WeaponModSystem.gd")

# 'tests_passed' und 'tests_failed' werden von TestBase geerbt

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("🧪 STARTING PACKET 1 & 2 TEST SUITE (Resources & ModSystem)")
	print("=".repeat(80) + "\n")
	
	test_weapon_resource()
	test_attachment_resource()
	test_merc_profile()
	test_item_instance_creation()
	test_mod_system_integration()
	test_mod_system_compatibility()
	test_item_instance_serialization()
	
	_print_summary("PACKET 1 & 2") # Aufruf der geerbten Funktion

# ============================================================================
# TEST HELPERS
# ============================================================================

# ALLE HILFSFUNKTIONEN (pass_test, assert_true, etc.)
# WURDEN ENTFERNT. SIE WERDEN JETZT VON TestBase.gd GEERBT.

# ============================================================================
# TESTS
# ============================================================================

## Testet, ob die WeaponResource-Klasse Daten speichert und to_dict() funktioniert
func test_weapon_resource() -> void:
	print("\n[TEST 1] WeaponResource.gd")
	var res = WeaponResource.new()
	res.id = "test_rifle"
	res.weapon_name = "Test Rifle"
	res.damage_min = 20
	res.damage_max = 30
	res.ap_cost_single = 7
	res.attachment_slots = PackedStringArray(["scope", "muzzle"])
	
	var data = res.to_dict()
	assert_equal(data["id"], "test_rifle", "Resource: to_dict() 'id' korrekt")
	assert_equal(data["damage_min"], 20, "Resource: to_dict() 'damage_min' korrekt")
	assert_equal(data["attachment_slots"].size(), 2, "Resource: to_dict() 'attachment_slots' korrekt")

## Testet die AttachmentResource-Klasse
func test_attachment_resource() -> void:
	print("\n[TEST 2] AttachmentResource.gd")
	var res = AttachmentResource.new()
	res.id = "test_scope"
	res.stat_modifiers = {"accuracy_bonus": 0.15, "ap_cost_modifier": 1.1}
	res.compatible_slots = PackedStringArray(["scope"])
	
	var data = res.to_dict()
	assert_equal(data["id"], "test_scope", "Attachment: to_dict() 'id' korrekt")
	assert_almost_equal(data["stat_modifiers"]["accuracy_bonus"], 0.15, "Attachment: to_dict() 'stat_modifiers' korrekt")

## Testet die MercProfile-Klasse und berechnete Werte
func test_merc_profile() -> void:
	print("\n[TEST 3] MercProfile.gd")
	var res = MercProfile.new()
	res.agility = 80
	res.strength = 60
	
	var expected_ap = APUtility.calculate_max_ap(80, 1.0, false)
	assert_equal(res.calculate_max_ap(), expected_ap, "MercProfile: calculate_max_ap() korrekt")
	
	var expected_hp = int(50.0 + 60.0 * 0.5)
	assert_equal(res.calculate_max_hp(), expected_hp, "MercProfile: calculate_max_hp() korrekt")

## Testet, ob ItemInstance korrekt aus einer Ressource erstellt wird
func test_item_instance_creation() -> void:
	print("\n[TEST 4] ItemInstance.gd (Creation)")
	
	var weapon_res = WeaponResource.new()
	weapon_res.id = "test_rifle"
	weapon_res.damage_min = 20
	weapon_res.magazine_size = 30
	weapon_res.accuracy = 0.7
	
	var inst = ItemInstance.from_weapon_resource(weapon_res)
	
	assert_not_null(inst, "Instance: Erstellung erfolgreich")
	assert_equal(inst.base_item_id, "test_rifle", "Instance: 'base_item_id' ist korrekt")
	assert_equal(inst.current_ammo, 30, "Instance: Munition ist voll")
	
	var stats = inst.get_effective_stats()
	assert_true(stats.has("damage_min"), "Instance: 'effective_stats' wurden berechnet")
	assert_equal(stats["damage_min"], 20, "Instance: 'effective_stats' (unmodifiziert) sind korrekt")
	assert_almost_equal(stats["accuracy"], 0.7, "Instance: 'effective_stats' (accuracy) ist korrekt")

## Testet die Kernfunktion: Mod anbringen und Stats neu berechnen
func test_mod_system_integration() -> void:
	print("\n[TEST 5] WeaponModSystem.gd (Integration)")
	
	# 1. Waffe erstellen
	var weapon_res = WeaponResource.new()
	weapon_res.id = "test_rifle"
	weapon_res.accuracy = 0.7
	weapon_res.ap_cost_single = 8
	weapon_res.attachment_slots = PackedStringArray(["scope", "muzzle"])
	var inst = ItemInstance.from_weapon_resource(weapon_res)

	# 2. Attachment erstellen
	var scope = AttachmentResource.new()
	scope.id = "test_scope"
	scope.stat_modifiers = {"accuracy_bonus": 0.1, "ap_cost_modifier": 1.25}
	scope.compatible_slots = PackedStringArray(["scope"])
	
	var base_accuracy = inst.get_effective_stats()["accuracy"]
	var base_ap = inst.get_effective_stats()["ap_cost_single"]
	
	# 3. Mod anbringen
	var success = inst.add_attachment(scope, "scope")
	assert_true(success, "ModSystem: Anbringen war erfolgreich")
	
	var modified_stats = inst.get_effective_stats()
	
	# 4. Stats prüfen
	assert_almost_equal(modified_stats["accuracy"], base_accuracy + 0.1, "ModSystem: Accuracy wurde korrekt erhöht")
	assert_equal(modified_stats["ap_cost_single"], int(base_ap * 1.25), "ModSystem: AP-Kosten wurden korrekt erhöht")

	# 5. Mod entfernen
	var removed_mod = inst.remove_attachment("scope")
	assert_equal(removed_mod, scope, "ModSystem: Korrektes Attachment entfernt")
	
	var final_stats = inst.get_effective_stats()
	assert_almost_equal(final_stats["accuracy"], base_accuracy, "ModSystem: Accuracy wurde korrekt zurückgesetzt")

## Testet die Kompatibilitätsregeln
func test_mod_system_compatibility() -> void:
	print("\n[TEST 6] WeaponModSystem.gd (Compatibility)")

	var weapon_res = WeaponResource.new()
	weapon_res.id = "test_rifle"
	weapon_res.attachment_slots = PackedStringArray(["scope"])
	var inst = ItemInstance.from_weapon_resource(weapon_res)

	# 1. Falscher Slot
	var silencer = AttachmentResource.new()
	silencer.id = "test_silencer"
	silencer.stat_modifiers = {"sound_reduction": 0.5}
	silencer.compatible_slots = PackedStringArray(["muzzle"]) # Passt nur in "muzzle"
	
	var success = inst.add_attachment(silencer, "scope")
	assert_false(success, "Kompatibilität: Falscher Slot-Typ wurde blockiert")
	
	# 2. Waffe hat Slot nicht
	success = inst.add_attachment(silencer, "muzzle")
	assert_false(success, "Kompatibilität: Waffe hat diesen Slot nicht")

	# 3. Waffe nicht in Whitelist
	var ak_scope = AttachmentResource.new()
	ak_scope.id = "ak_scope"
	ak_scope.stat_modifiers = {"accuracy_bonus": 0.1}
	ak_scope.compatible_slots = PackedStringArray(["scope"])
	ak_scope.compatible_weapons = PackedStringArray(["ak47", "ak74"]) # Passt nur auf AKs
	
	success = inst.add_attachment(ak_scope, "scope")
	assert_false(success, "Kompatibilität: Waffe nicht in Whitelist wurde blockiert")

## Testet, ob 'to_dict' die Mod-IDs korrekt speichert
func test_item_instance_serialization() -> void:
	print("\n[TEST 7] ItemInstance.gd (Serialization)")
	
	var weapon_res = WeaponResource.new()
	weapon_res.id = "test_rifle"
	weapon_res.attachment_slots = PackedStringArray(["scope"])
	var inst = ItemInstance.from_weapon_resource(weapon_res)
	
	var scope = AttachmentResource.new()
	scope.id = "test_scope"
	scope.compatible_slots = PackedStringArray(["scope"])
	inst.add_attachment(scope, "scope")
	
	var data = inst.to_dict()
	
	assert_true(data.has("current_attachments_ids"), "Serialisierung: 'current_attachments_ids' vorhanden")
	assert_true(data["current_attachments_ids"].has("scope"), "Serialisierung: 'scope'-Slot wurde gespeichert")
	assert_equal(data["current_attachments_ids"]["scope"], "test_scope", "Serialisierung: Korrekte Attachment-ID gespeichert")
	
	pass_test("Serialisierung: 'from_dict' Test übersprungen (braucht DataManager)")

# ============================================================================
# SUMMARY
# ============================================================================

# Die Funktion _print_summary() wird von TestBase.gd geerbt

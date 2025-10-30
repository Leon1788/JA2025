# res://Tests/test_packet_4.gd
## INTEGRATIONSTEST für Packet 4: Echtes Daten-Laden
##
## Dieser Test prüft, ob der DataManager beim Spielstart
## die .tres-Dateien aus res://Data/ korrekt lädt.
##
## HINWEIS: Dieser Test wird fehlschlagen, bis die
## .tres-Dateien im Editor korrekt erstellt wurden.

extends "res://Tests/TestBase.gd"

# Erwartete Anzahl an Dateien
const EXPECTED_WEAPONS = 2
const EXPECTED_MERCS = 1
const EXPECTED_ATTACHMENTS = 1

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("🧪 STARTING PACKET 4 INTEGRATION TEST (DataManager Loading)")
	print("=".repeat(80) + "\n")
	
	# HINWEIS: DataManager hat seine Ladefunktion bereits
	# in _ready() ausgeführt, da er ein Autoload ist.
	
	test_data_manager_loading()
	test_data_manager_integrity()
	
	_print_summary("PACKET 4 DATEN-LADEN")

# ============================================================================
# TESTS
# ============================================================================

func test_data_manager_loading() -> void:
	print("\n[TEST 1] DataManager Lade-Anzahl")
	
	assert_equal(DataManager.get_weapon_count(), EXPECTED_WEAPONS, "Sollte %d Waffen geladen haben" % EXPECTED_WEAPONS)
	assert_equal(DataManager.get_merc_count(), EXPECTED_MERCS, "Sollte %d Mercs geladen haben" % EXPECTED_MERCS)
	assert_equal(DataManager.get_attachment_count(), EXPECTED_ATTACHMENTS, "Sollte %d Attachments geladen haben" % EXPECTED_ATTACHMENTS)

func test_data_manager_integrity() -> void:
	print("\n[TEST 2] DataManager Daten-Integrität")
	
	if DataManager.get_weapon_count() < EXPECTED_WEAPONS:
		fail_test("Daten-Integrität Waffen", "Test übersprungen, da Laden fehlgeschlagen.")
		return
		
	var rifle = DataManager.get_weapon("m16_rifle")
	var pistol = DataManager.get_weapon("m9_pistol")
	
	assert_not_null(rifle, "Integrität: 'm16_rifle' wurde geladen")
	assert_not_null(pistol, "Integrität: 'm9_pistol' wurde geladen")
	
	if rifle:
		assert_equal(rifle.weapon_type, "rifle", "Integrität: m16_rifle Typ ist 'rifle'")
		assert_equal(rifle.ap_cost_single, 5, "Integrität: m16_rifle AP-Kosten sind 5")

	if DataManager.get_merc_count() < EXPECTED_MERCS:
		fail_test("Daten-Integrität Mercs", "Test übersprungen, da Laden fehlgeschlagen.")
		return
		
	var ivan = DataManager.get_merc("merc_ivan")
	assert_not_null(ivan, "Integrität: 'merc_ivan' wurde geladen")
	if ivan:
		assert_equal(ivan.marksmanship, 88, "Integrität: Ivan Marksmanship ist 88")
		assert_equal(ivan.starting_weapon_id, "m16_rifle", "Integrität: Ivan Startwaffe ist 'm16_rifle'")

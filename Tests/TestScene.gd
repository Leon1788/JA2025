# res://Tests/TestScene.gd
## Umfassende Test-Suite für alle Systems
## FINAL KORRIGIERT - Alle Fehler weg

extends Node

var tests_passed: int = 0
var tests_failed: int = 0

func _ready() -> void:
	print("\n" + repeat_string("=", 80))
	print("🧪 STARTING COMPREHENSIVE TEST SUITE")
	print(repeat_string("=", 80) + "\n")
	
	test_game_constants()
	test_ap_utility()
	test_combat_utility()
	test_damage_utility()
	test_vision_utility()
	test_interrupt_system()
	test_game_controller()
	test_time_manager()
	test_data_manager()
	test_input_manager()
	test_sound_manager()
	test_persistence_manager()
	
	_print_summary()

# ============================================================================
# TEST HELPERS
# ============================================================================

func repeat_string(s: String, count: int) -> String:
	var result = ""
	for i in range(count):
		result += s
	return result

func pass_test(name: String) -> void:
	tests_passed += 1
	print("  ✅ " + name)

func fail_test(name: String, reason: String) -> void:
	tests_failed += 1
	print("  ❌ " + name)
	print("     Reason: " + reason)

func assert_true(condition: bool, name: String) -> void:
	if condition:
		pass_test(name)
	else:
		fail_test(name, "Expected true, got false")

func assert_false(condition: bool, name: String) -> void:
	if not condition:
		pass_test(name)
	else:
		fail_test(name, "Expected false, got true")

func assert_equal(actual: Variant, expected: Variant, name: String) -> void:
	if actual == expected:
		pass_test(name)
	else:
		fail_test(name, "Expected " + str(expected) + ", got " + str(actual))

func assert_almost_equal(actual: float, expected: float, tolerance: float, name: String) -> void:
	if abs(actual - expected) <= tolerance:
		pass_test(name)
	else:
		fail_test(name, "Expected ~" + str(expected) + ", got " + str(actual))

func assert_greater(actual: float, minimum: float, name: String) -> void:
	if actual > minimum:
		pass_test(name)
	else:
		fail_test(name, "Expected > " + str(minimum) + ", got " + str(actual))

func assert_less(actual: float, maximum: float, name: String) -> void:
	if actual < maximum:
		pass_test(name)
	else:
		fail_test(name, "Expected < " + str(maximum) + ", got " + str(actual))

# ============================================================================
# TEST 1: GameConstants
# ============================================================================

func test_game_constants() -> void:
	print("\n[TEST 1] GameConstants.gd")
	print(repeat_string("-", 40))
	
	assert_true(GameConstants.BASE_AP_PER_TURN > 0, "BASE_AP_PER_TURN ist positiv")
	assert_equal(GameConstants.BASE_AP_PER_TURN, 50, "BASE_AP_PER_TURN = 50")
	
	assert_true(GameConstants.BASE_HIT_CHANCE > 0.0, "BASE_HIT_CHANCE > 0")
	assert_true(GameConstants.BASE_HIT_CHANCE < 1.0, "BASE_HIT_CHANCE < 1")
	
	assert_equal(GameConstants.TACTICAL_MAP_WIDTH, 160, "Map Width = 160")
	assert_equal(GameConstants.TACTICAL_MAP_HEIGHT, 160, "Map Height = 160")
	
	assert_equal(GameConstants.STRATEGIC_MAP_WIDTH, 16, "Strategic Map Width = 16")
	assert_equal(GameConstants.STRATEGIC_MAP_HEIGHT, 16, "Strategic Map Height = 16")
	
	assert_equal(GameConstants.STANCE.STANDING, 0, "STANCE.STANDING = 0")
	assert_equal(GameConstants.STANCE.CROUCHING, 1, "STANCE.CROUCHING = 1")
	assert_equal(GameConstants.STANCE.PRONE, 2, "STANCE.PRONE = 2")

# ============================================================================
# TEST 2: APUtility
# ============================================================================

func test_ap_utility() -> void:
	print("\n[TEST 2] APUtility.gd")
	print(repeat_string("-", 40))
	
	var max_ap_low = APUtility.calculate_max_ap(20, 1.0, false)
	var max_ap_high = APUtility.calculate_max_ap(80, 1.0, false)
	assert_greater(max_ap_high as float, max_ap_low as float, "Höhere Agility = mehr AP")
	
	var cost_standing = APUtility.calculate_movement_cost(5, GameConstants.STANCE.STANDING)
	var cost_crouching = APUtility.calculate_movement_cost(5, GameConstants.STANCE.CROUCHING)
	var cost_prone = APUtility.calculate_movement_cost(5, GameConstants.STANCE.PRONE)
	
	assert_equal(cost_standing, 20, "5 Tiles Standing = 20 AP")
	assert_greater(cost_crouching as float, cost_standing as float, "Crouching kostet mehr")
	assert_greater(cost_prone as float, cost_crouching as float, "Prone kostet mehr")
	
	var shot_single = APUtility.calculate_shot_cost("single")
	var shot_burst = APUtility.calculate_shot_cost("burst")
	var shot_auto = APUtility.calculate_shot_cost("auto")
	
	assert_equal(shot_single, 8, "Single Shot = 8 AP")
	assert_greater(shot_burst as float, shot_single as float, "Burst > Single")
	assert_greater(shot_auto as float, shot_burst as float, "Auto > Burst")
	
	var reload = APUtility.calculate_reload_cost()
	assert_greater(reload as float, 0, "Reload hat positive Kosten")
	
	assert_true(APUtility.can_afford_action(50, 8), "Mit 50 AP kann 8 AP leisten")
	assert_false(APUtility.can_afford_action(5, 8), "Mit 5 AP kann 8 AP nicht leisten")

# ============================================================================
# TEST 3: CombatUtility
# ============================================================================

func test_combat_utility() -> void:
	print("\n[TEST 3] CombatUtility.gd")
	print(repeat_string("-", 40))
	
	var hit_50 = CombatUtility.calculate_hit_chance(50, 0.0, 0, 0, 0)
	var hit_100 = CombatUtility.calculate_hit_chance(100, 0.0, 0, 0, 0)
	assert_greater(hit_100, hit_50, "Höhere Skill = bessere Hit Chance")
	
	var hit_close = CombatUtility.calculate_hit_chance(50, 1.0, 0, 0, 0)
	var hit_far = CombatUtility.calculate_hit_chance(50, 20.0, 0, 0, 0)
	assert_greater(hit_close, hit_far, "Nah > Weit")
	
	var hit_no_cover = CombatUtility.calculate_hit_chance(50, 5.0, GameConstants.COVER_TYPE.NONE, 0, 0)
	var hit_half_cover = CombatUtility.calculate_hit_chance(50, 5.0, GameConstants.COVER_TYPE.HALF, 0, 0)
	var hit_full_cover = CombatUtility.calculate_hit_chance(50, 5.0, GameConstants.COVER_TYPE.FULL, 0, 0)
	
	assert_greater(hit_no_cover, hit_half_cover, "Keine Deckung > Halb")
	assert_greater(hit_half_cover, hit_full_cover, "Halb > Voll")
	
	var hit_standing = CombatUtility.calculate_hit_chance(50, 5.0, 0, GameConstants.STANCE.STANDING, GameConstants.STANCE.STANDING)
	var hit_prone = CombatUtility.calculate_hit_chance(50, 5.0, 0, GameConstants.STANCE.PRONE, GameConstants.STANCE.STANDING)
	assert_greater(hit_prone, hit_standing, "Prone gibt Bonus")
	
	var hit_no_scope = CombatUtility.calculate_hit_chance(50, 10.0, 0, 0, 0, {})
	var hit_scope = CombatUtility.calculate_hit_chance(50, 10.0, 0, 0, 0, {"has_scope": true})
	assert_greater(hit_scope, hit_no_scope, "Mit Scope > Ohne")
	
	var hit_normal = CombatUtility.calculate_hit_chance(50, 5.0, 0, 0, 0)
	assert_greater(hit_normal, 0.0, "Hit >= 0.0")
	assert_less(hit_normal, 1.0, "Hit <= 1.0")
	
	var recoil_0 = CombatUtility.calculate_recoil_penalty(0, "single")
	var recoil_3 = CombatUtility.calculate_recoil_penalty(3, "single")
	assert_equal(recoil_0, 0.0, "Kein Recoil bei 0")
	assert_greater(recoil_3, recoil_0, "Recoil nimmt zu")

# ============================================================================
# TEST 4: DamageUtility
# ============================================================================

func test_damage_utility() -> void:
	print("\n[TEST 4] DamageUtility.gd")
	print(repeat_string("-", 40))
	
	var dmg1 = DamageUtility.calculate_base_damage(25, 35, 100)
	assert_greater(dmg1 as float, 24, "Damage >= Min")
	assert_less(dmg1 as float, 36, "Damage <= Max")
	
	var dmg_good = DamageUtility.calculate_base_damage(25, 35, 100)
	var dmg_bad = DamageUtility.calculate_base_damage(25, 35, 50)
	assert_greater(dmg_good as float, dmg_bad as float, "Besserer Zustand = mehr Schaden")
	
	var dmg_no_armor = DamageUtility.calculate_armor_reduction(30, 0, "medium")
	var dmg_light_armor = DamageUtility.calculate_armor_reduction(30, 5, "light")
	var dmg_heavy_armor = DamageUtility.calculate_armor_reduction(30, 10, "heavy")
	
	assert_equal(dmg_no_armor, 30, "Kein Verlust ohne Rüstung")
	assert_greater(dmg_no_armor as float, dmg_light_armor as float, "Light reduziert")
	assert_greater(dmg_light_armor as float, dmg_heavy_armor as float, "Heavy reduziert mehr")
	
	var head_multi = DamageUtility.calculate_hitzone_multiplier(0)
	var torso_multi = DamageUtility.calculate_hitzone_multiplier(1)
	var leg_multi = DamageUtility.calculate_hitzone_multiplier(4)
	
	assert_greater(head_multi, torso_multi, "Kopf > Torso")
	assert_greater(torso_multi, leg_multi, "Torso > Bein")
	
	var final_dmg = DamageUtility.calculate_final_damage(25, 35, 100, 10, "medium", 1, false, "standard")
	assert_greater(final_dmg as float, 0, "Final Damage positiv")

# ============================================================================
# TEST 5: VisionUtility
# ============================================================================

func test_vision_utility() -> void:
	print("\n[TEST 5] VisionUtility.gd")
	print(repeat_string("-", 40))
	
	var sight_low = VisionUtility.calculate_sight_range(20, 20, 1.0)
	var sight_high = VisionUtility.calculate_sight_range(80, 80, 1.0)
	assert_greater(sight_high, sight_low, "Höhere Attribute = größere Sicht")
	
	var sight_bright = VisionUtility.calculate_sight_range(50, 50, 1.0)
	var sight_dark = VisionUtility.calculate_sight_range(50, 50, 0.2)
	assert_greater(sight_bright, sight_dark, "Hell > Dunkel")
	
	var sight_dark_no_nvg = VisionUtility.calculate_sight_range(50, 50, 0.2, false)
	var sight_dark_with_nvg = VisionUtility.calculate_sight_range(50, 50, 0.2, true)
	assert_greater(sight_dark_with_nvg, sight_dark_no_nvg, "Mit NVG > Ohne")
	
	var dist = VisionUtility.calculate_distance_in_tiles(Vector3(0, 0, 0), Vector3(10, 0, 0))
	assert_equal(dist, 10.0, "Distanz = 10")
	
	var in_range = VisionUtility.is_within_sight_range(Vector3(0, 0, 0), Vector3(10, 0, 0), 15.0)
	var out_of_range = VisionUtility.is_within_sight_range(Vector3(0, 0, 0), Vector3(20, 0, 0), 15.0)
	assert_true(in_range, "10 in 15")
	assert_false(out_of_range, "20 out of 15")

# ============================================================================
# TEST 6: InterruptSystem
# ============================================================================

func test_interrupt_system() -> void:
	print("\n[TEST 6] InterruptSystem.gd")
	print(repeat_string("-", 40))
	
	var can_interrupt_same = InterruptSystem.should_trigger_interrupt(
		"visual",
		{"faction": "player"},
		{"faction": "player", "can_see": true},
		5.0,
		1.0
	)
	assert_false(can_interrupt_same, "Gleiche Fraktion: nein")
	
	var can_interrupt_diff = InterruptSystem.should_trigger_interrupt(
		"visual",
		{"faction": "player"},
		{"faction": "enemy", "can_see": true},
		5.0,
		1.0
	)
	assert_true(can_interrupt_diff, "Andere Fraktion: ja")
	
	var cannot_interrupt_far = InterruptSystem.should_trigger_interrupt(
		"visual",
		{"faction": "player"},
		{"faction": "enemy", "can_see": true},
		30.0,
		1.0
	)
	assert_false(cannot_interrupt_far, "Zu weit: nein")
	
	var sound_interrupt = InterruptSystem.should_trigger_interrupt(
		"sound",
		{"faction": "player", "sound_volume": 1.0},
		{"faction": "enemy"},
		10.0,
		1.0
	)
	assert_true(sound_interrupt, "Sound Interrupt: ja")
	
	var priority_alert = InterruptSystem.calculate_interrupt_priority(
		{"alertness": 0.8, "marksmanship": 70},
		5.0
	)
	var priority_sleepy = InterruptSystem.calculate_interrupt_priority(
		{"alertness": 0.2, "marksmanship": 30},
		5.0
	)
	assert_greater(priority_alert, priority_sleepy, "Alert > Sleepy")

# ============================================================================
# TEST 7: GameController
# ============================================================================

func test_game_controller() -> void:
	print("\n[TEST 7] GameController.gd (AutoLoad)")
	print(repeat_string("-", 40))
	
	assert_true(GameController != null, "GameController existiert")
	assert_true(GameController is IManager, "GameController ist IManager")
	
	var state = GameController.get_current_game_state()
	assert_equal(state, GameConstants.GAME_STATE.MAIN_MENU, "State = MAIN_MENU")
	
	var state_name = GameController.get_game_state_name()
	assert_equal(state_name, "MAIN_MENU", "State Name korrekt")

# ============================================================================
# TEST 8: TimeManager
# ============================================================================

func test_time_manager() -> void:
	print("\n[TEST 8] TimeManager.gd (AutoLoad)")
	print(repeat_string("-", 40))
	
	assert_true(TimeManager != null, "TimeManager existiert")
	assert_true(TimeManager is IManager, "TimeManager ist IManager")
	
	var day = TimeManager.get_day()
	var hour = TimeManager.get_hour()
	var minute = TimeManager.get_minute()
	
	assert_equal(day, 1, "Tag = 1")
	assert_equal(hour, 8, "Stunde = 8")
	assert_equal(minute, 0, "Minute = 0")
	
	var time_str = TimeManager.get_time_string()
	assert_equal(time_str, "08:00", "Time String korrekt")
	
	var warp_speed = TimeManager.get_time_warp_speed()
	assert_equal(warp_speed, 1.0, "Time-Warp = 1.0x")

# ============================================================================
# TEST 9: DataManager
# ============================================================================

func test_data_manager() -> void:
	print("\n[TEST 9] DataManager.gd (AutoLoad)")
	print(repeat_string("-", 40))
	
	assert_true(DataManager != null, "DataManager existiert")
	assert_true(DataManager is IManager, "DataManager ist IManager")
	
	var weapon_count = DataManager.get_weapon_count()
	var merc_count = DataManager.get_merc_count()
	var attachment_count = DataManager.get_attachment_count()
	
	assert_true(weapon_count >= 0, "Weapon count >= 0")
	assert_true(merc_count >= 0, "Merc count >= 0")
	assert_true(attachment_count >= 0, "Attachment count >= 0")

# ============================================================================
# TEST 10: InputManager
# ============================================================================

func test_input_manager() -> void:
	print("\n[TEST 10] InputManager.gd (AutoLoad)")
	print(repeat_string("-", 40))
	
	assert_true(InputManager != null, "InputManager existiert")
	assert_true(InputManager is IManager, "InputManager ist IManager")
	
	var mouse_pos = InputManager.get_mouse_position()
	assert_true(mouse_pos is Vector2, "Mouse Position ist Vector2")

# ============================================================================
# TEST 11: SoundManager
# ============================================================================

func test_sound_manager() -> void:
	print("\n[TEST 11] SoundManager.gd (AutoLoad)")
	print(repeat_string("-", 40))
	
	assert_true(SoundManager != null, "SoundManager existiert")
	assert_true(SoundManager is IManager, "SoundManager ist IManager")
	
	var volumes = SoundManager.get_volumes()
	assert_true(volumes.has("master"), "Hat master volume")
	assert_true(volumes.has("effects"), "Hat effects volume")
	assert_true(volumes.has("music"), "Hat music volume")

# ============================================================================
# TEST 12: PersistenceManager
# ============================================================================

func test_persistence_manager() -> void:
	print("\n[TEST 12] PersistenceManager.gd (AutoLoad)")
	print(repeat_string("-", 40))
	
	assert_true(PersistenceManager != null, "PersistenceManager existiert")
	assert_true(PersistenceManager is IManager, "PersistenceManager ist IManager")
	
	var slots = PersistenceManager.get_save_slots()
	assert_true(slots is Array, "Save Slots ist Array")

# ============================================================================
# SUMMARY
# ============================================================================

func _print_summary() -> void:
	print("\n" + repeat_string("=", 80))
	print("📊 TEST SUMMARY")
	print(repeat_string("=", 80))
	print("✅ PASSED: " + str(tests_passed))
	print("❌ FAILED: " + str(tests_failed))
	
	var total = tests_passed + tests_failed
	var percentage = (float(tests_passed) / float(total)) * 100.0 if total > 0 else 0.0
	
	print("Success Rate: " + str(percentage) + "%")
	print(repeat_string("=", 80) + "\n")
	
	if tests_failed == 0:
		print("🎉 ALL TESTS PASSED! Ready for development!")
	else:
		print("⚠️  SOME TESTS FAILED! Check errors above.")
	
	print("\n")

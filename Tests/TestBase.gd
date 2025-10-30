# res://Tests/TestBase.gd
## BASIS-KLASSE für alle Test-Szenen.
##
## Stellt die allgemeinen Hilfsfunktionen (Asserts, Summary)
## für alle Test-Skripte im Projekt bereit.
##
## Alle Test-Skripte (TestScene.gd, test_resources.gd, test_packet_3.gd)
## sollten von dieser Klasse erben.

class_name TestBase extends Node

var tests_passed: int = 0
var tests_failed: int = 0

# ============================================================================
# TEST ASSERTIONS (Hilfsfunktionen)
# ============================================================================

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

func assert_almost_equal(actual: float, expected: float, name: String, tolerance: float = 0.001) -> void:
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

func assert_not_null(item: Variant, name: String) -> void:
	if item != null:
		pass_test(name)
	else:
		fail_test(name, "Expected not null, got null")

func assert_is_null(item: Variant, name: String) -> void:
	if item == null:
		pass_test(name)
	else:
		fail_test(name, "Expected null, got " + str(item))

# ============================================================================
# TEST SUMMARY
# ============================================================================

## Gibt die Zusammenfassung aus. Muss manuell am Ende
## der _ready() Funktion des Kind-Skripts aufgerufen werden.
func _print_summary(test_suite_name: String) -> void:
	print("\n" + "=".repeat(80))
	print("📊 %s TEST SUMMARY" % test_suite_name.to_upper())
	print("=".repeat(80))
	print("✅ PASSED: " + str(tests_passed))
	print("❌ FAILED: " + str(tests_failed))
	
	var total = tests_passed + tests_failed
	var percentage = (float(tests_passed) / float(total)) * 100.0 if total > 0 else 0.0
	
	print("Success Rate: %.1f%%" % percentage)
	print("=".repeat(80) + "\n")
	
	if tests_failed == 0:
		print("🎉 ALL %s TESTS PASSED!" % test_suite_name.to_upper())
	else:
		print("⚠️  SOME TESTS FAILED! Check errors above.")
	
	print("\n")

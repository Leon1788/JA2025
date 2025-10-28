# res://Architecture/DebugLogger.gd
## DebugLogger - Zentrale Debug-Logging Utility Klasse
## 
## Ersetzt 20+ copy-paste _debug_log() Funktionen in verschiedenen Dateien
## SINGLE POINT OF CHANGE für Debug-Verhalten
##
## NUTZUNG:
##   DebugLogger.log(self.name, "Unit bewegte sich zu Position XYZ")
##   DebugLogger.warn(self.name, "AP zu niedrig!")
##   DebugLogger.error(self.name, "KRITISCHER FEHLER!")
##   DebugLogger.critical(self.name, "GAME CRASH IMMINENT!")
##
## VORTEILE:
## - Kein copy-paste mehr (~200 Zeilen Duplikation weg!)
## - Zentrale Kontrolle über Debug-Format
## - Leicht zu erweitern (z.B. File Logging später)
## - Alle Manager/Components nutzen die gleiche Quelle
## - DRY Principle (Don't Repeat Yourself)

class_name DebugLogger

# ============================================================================
# STANDARD DEBUG LOGGING
# ============================================================================

## Standard Debug-Log
## Wird nur ausgegeben wenn GameConstants.DEBUG_ENABLED true ist
static func log(source: String, message: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[%s] %s" % [source, message])

## Warning-Log
## Wird auch bei DEBUG disabled angezeigt (mit push_warning)
static func warn(source: String, message: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		push_warning("[%s] ⚠️  %s" % [source, message])

## Error-Log
## Wird IMMER angezeigt (auch in Production!) mit push_error
static func error(source: String, message: String) -> void:
	push_error("[%s] ❌ %s" % [source, message])

## Critical Error-Log
## IMMER angezeigt + push_error für sofortige Aufmerksamkeit
static func critical(source: String, message: String) -> void:
	push_error("[%s] 🔴 CRITICAL: %s" % [source, message])

# ============================================================================
# KATEGORIE-BASIERTES LOGGING
# ============================================================================

## Log mit Category-Prefix (für bessere Filterung)
## DebugLogger.log_category("COMBAT", self.name, "Schuss abgefeuert")
static func log_category(category: String, source: String, message: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[%s:%s] %s" % [category, source, message])

## Log für Spatial/Movement Events
static func log_movement(source: String, from_pos: Vector3, to_pos: Vector3) -> void:
	if GameConstants.DEBUG_ENABLED:
		var distance = from_pos.distance_to(to_pos)
		print("[%s] MOVE: (%.1f,%.1f,%.1f) → (%.1f,%.1f,%.1f) [%.1f units]" % 
			[source, from_pos.x, from_pos.y, from_pos.z, to_pos.x, to_pos.y, to_pos.z, distance])

## Log für Combat Events
static func log_combat(source: String, action: String, details: String = "") -> void:
	if GameConstants.DEBUG_ENABLED:
		if details == "":
			print("[%s] COMBAT: %s" % [source, action])
		else:
			print("[%s] COMBAT: %s (%s)" % [source, action, details])

## Log für Vision/LOS Events
static func log_vision(source: String, spotter: String, target: String, can_see: bool) -> void:
	if GameConstants.DEBUG_ENABLED:
		var sight_status = "SEES" if can_see else "BLIND"
		print("[%s] VISION: %s %s %s" % [source, spotter, sight_status, target])

# ============================================================================
# STRUKTUR-BASIERTES LOGGING
# ============================================================================

## Strukturiertes Logging für Daten-Dictionaries
## Gibt schöne formatierte Ausgabe aus
static func log_data(source: String, label: String, data_dict: Dictionary) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[%s] %s:" % [source, label])
		for key in data_dict.keys():
			var value = data_dict[key]
			print("  • %s: %s" % [key, str(value)])

## Log für Listen/Arrays
static func log_array(source: String, label: String, array: Array) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[%s] %s [%d items]:" % [source, label, array.size()])
		for i in range(mini(5, array.size())):  # Max 5 Items zeigen
			print("  [%d] %s" % [i, str(array[i])])
		if array.size() > 5:
			print("  ... und %d mehr" % [array.size() - 5])

# ============================================================================
# STATE & EVENT LOGGING
# ============================================================================

## Log State Change
static func log_state_change(source: String, from_state: String, to_state: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[%s] STATE: %s → %s" % [source, from_state, to_state])

## Log Signal Event
static func log_signal(source: String, signal_name: String, param: String = "") -> void:
	if GameConstants.DEBUG_ENABLED:
		if param == "":
			print("[%s] SIGNAL: %s" % [source, signal_name])
		else:
			print("[%s] SIGNAL: %s (%s)" % [source, signal_name, param])

## Log Action zwischen Entities
static func log_action(actor: String, action: String, target: String = "") -> void:
	if GameConstants.DEBUG_ENABLED:
		if target == "":
			print("[ACTION] %s %s" % [actor, action])
		else:
			print("[ACTION] %s %s → %s" % [actor, action, target])

# ============================================================================
# PERFORMANCE LOGGING
# ============================================================================

## Timing-Debug (für Performance Analysis)
## Warnt wenn über 16ms (60 FPS Limit)
static func log_performance(source: String, operation: String, time_ms: float) -> void:
	if GameConstants.DEBUG_ENABLED:
		var status = "✅" if time_ms < 16.0 else "⚠️"  # 60 FPS = 16.66ms
		print("[%s] PERF %s: %.2fms %s" % [source, operation, time_ms, status])

## Log für Pathfinding Performance
static func log_pathfinding(source: String, path_length: int, time_ms: float) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[%s] PATHFIND: %d steps in %.2fms" % [source, path_length, time_ms])

# ============================================================================
# GAMEFLOW LOGGING
# ============================================================================

## Log Spiel-Zustandsänderungen
static func log_game_state(old_state: int, new_state: int) -> void:
	if GameConstants.DEBUG_ENABLED:
		var state_names = GameConstants.GAME_STATE
		print("[GAME] STATE: %s → %s" % [state_names.keys()[old_state], state_names.keys()[new_state]])

## Log Scene-Wechsel
static func log_scene(action: String, scene_name: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[SCENE] %s: %s" % [action, scene_name])

## Log Combat Turn
static func log_turn(turn_number: int, actor_name: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[TURN] #%d - %s's turn" % [turn_number, actor_name])

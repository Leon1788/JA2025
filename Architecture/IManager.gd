# res://Architecture/IManager.gd
## Base Class für alle Manager/Singletons
## Definiert die Schnittstelle, die JEDER Manager implementieren muss
## 
## Manager sind globale Dienste, die während des gesamten Spiels laufen
## Sie verwalten einen spezifischen Aspekt des Spiels (Zeit, Daten, Input, etc.)

class_name IManager extends Node

# ============================================================================
# SIGNALS
# ============================================================================

## Emittiert wenn der Manager einen Fehler hat
signal error_occurred(error_message: String)

## Emittiert wenn der Manager initialisiert wurde
signal manager_ready()

# ============================================================================
# LIFECYCLE METHODS
# ============================================================================

## Wird aufgerufen, wenn der Manager als AutoLoad initialisiert wird
## Override diese Methode in Sub-Klassen für Custom Setup
func _ready() -> void:
	set_process(true)
	set_physics_process(false)
	
	DebugLogger.log(self.name, "Manager initialized")

## Wird aufgerufen in jedem Frame
## Override für regelmäßige Updates (z.B. Zeit-Ticks)
func _process(delta: float) -> void:
	pass

# ============================================================================
# MANAGER INTERFACE (zu implementieren in Sub-Klassen)
# ============================================================================

## Wird aufgerufen, wenn der Manager "aktiviert" wird
## z.B. wenn eine neue Szene geladen wird
func on_manager_activate() -> void:
	set_process(true)
	DebugLogger.log(self.name, "Manager activated")

## Wird aufgerufen, wenn der Manager "deaktiviert" wird
## z.B. wenn das Spiel pausiert wird oder Szene wechselt
func on_manager_deactivate() -> void:
	set_process(false)
	DebugLogger.log(self.name, "Manager deactivated")

## Wird aufgerufen, wenn das Spiel neu startet
## Setzt den Manager in den Initial-Zustand zurück
func on_game_reset() -> void:
	DebugLogger.log(self.name, "Manager reset")

# ============================================================================
# ERROR HANDLING (REFAKTORIERT: Nutzt DebugLogger)
# ============================================================================

## Zentrale Error-Handling Methode
## Verwendung: _report_error("Could not load data")
func _report_error(message: String) -> void:
	var full_message = "[%s] %s" % [self.name, message]
	push_error(full_message)
	error_occurred.emit(message)
	DebugLogger.error(self.name, full_message)

## Zentrale Warning-Methode
func _report_warning(message: String) -> void:
	var full_message = "[%s] %s" % [self.name, message]
	push_warning(full_message)
	DebugLogger.warn(self.name, full_message)

## Zentrale Log-Methode (nutzt DebugLogger - REFAKTORIERT)
func _debug_log(message: String) -> void:
	DebugLogger.log(self.name, message)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Gib den Manager-Namen zurück (zur Debug)
func get_manager_name() -> String:
	return self.name

## Prüfe ob der Manager aktiv ist
func is_manager_active() -> bool:
	return is_processing()

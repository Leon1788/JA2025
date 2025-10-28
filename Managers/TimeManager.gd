# res://Managers/TimeManager.gd
## Globale Spielzeit-Verwaltung
## 
## Verantwortlichkeiten:
## - Verwalte die globale Spielzeit (Tag, Stunde, Minute)
## - Emittiere Zeit-basierte Signale
## - Koordiniere alle Zeit-abhängigen Events
## - Time-Warp für schnelle Simulation
##
## WICHTIG: Dieses ist ein AutoLoad (Singleton)

extends IManager

# ============================================================================
# PROPERTIES - SPIELZEIT
# ============================================================================

## Aktuelle Spielzeit
var current_day: int = 1
var current_hour: int = 8  # Starten um 8:00
var current_minute: int = 0

## Real-Time zu Game-Time Multiplikator
## 1.0 = Normal (1 real sec = 1 game minute)
## 2.0 = 2x Speed (1 real sec = 2 game minutes)
var time_warp_speed: float = 1.0

## Akkumulator für Minuten-Ticks
var time_accumulator: float = 0.0

## Millisekunden pro Spiel-Minute (berechnet aus time_warp_speed)
var milliseconds_per_minute: float = 60.0  # 60 real-world milliseconds pro game-minute

# ============================================================================
# PROPERTIES - PAUSIERUNG
# ============================================================================

## Ist der TimeManager aktiv? (kann auch manuell pausiert werden)
var is_time_running: bool = true

# ============================================================================
# SIGNALS (werden nicht hier emittiert, aber Global verfügbar)
# ============================================================================

signal time_minute_tick(day: int, hour: int, minute: int)
signal time_hour_tick(day: int, hour: int)
signal time_day_tick(day: int)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	
	self.name = "TimeManager"
	
	# Starte mit normaler Geschwindigkeit
	time_warp_speed = GameConstants.TIME_WARP_SPEED_NORMAL
	_update_milliseconds_per_minute()
	
	_debug_log("TimeManager initialized. Current time: %02d:%02d (Day %d)" % [current_hour, current_minute, current_day])

func _process(delta: float) -> void:
	if not is_time_running:
		return
	
	# Akkumuliere Zeit
	time_accumulator += delta * 1000.0 * time_warp_speed  # Konvertiere zu Millisekunden
	
	# Prüfe ob eine Minute vergangen ist
	if time_accumulator >= milliseconds_per_minute:
		time_accumulator -= milliseconds_per_minute
		_advance_minute()

# ============================================================================
# ZEIT ADVANCEMENT
# ============================================================================

## Vorwärts eine Minute
func _advance_minute() -> void:
	current_minute += 1
	
	# Überprüfe ob Stunde vorbei ist
	if current_minute >= GameConstants.MINUTES_PER_HOUR:
		current_minute = 0
		_advance_hour()
	
	# Emittiere Signal
	_emit_time_tick()

## Vorwärts eine Stunde
func _advance_hour() -> void:
	current_hour += 1
	
	# Überprüfe ob Tag vorbei ist
	if current_hour >= GameConstants.HOURS_PER_DAY:
		current_hour = 0
		_advance_day()
	
	# Emittiere Signal
	_emit_hour_tick()

## Vorwärts einen Tag
func _advance_day() -> void:
	current_day += 1
	
	# Emittiere Signal
	_emit_day_tick()

## Emittiere Zeit-Signals
func _emit_time_tick() -> void:
	time_minute_tick.emit(current_day, current_hour, current_minute)
	
	# Emittiere auch über EventBus wenn vorhanden
	if GameController.current_event_bus:
		GameController.current_event_bus.time_minute_tick.emit(current_day, current_hour, current_minute)

func _emit_hour_tick() -> void:
	time_hour_tick.emit(current_day, current_hour)
	
	if GameController.current_event_bus:
		GameController.current_event_bus.time_hour_tick.emit(current_day, current_hour)

func _emit_day_tick() -> void:
	time_day_tick.emit(current_day)
	
	if GameController.current_event_bus:
		GameController.current_event_bus.time_day_tick.emit(current_day)

# ============================================================================
# TIME CONTROL
# ============================================================================

## Setze die aktuelle Zeit
func set_time(day: int, hour: int, minute: int) -> void:
	current_day = day
	current_hour = hour
	current_minute = minute
	time_accumulator = 0.0
	
	_debug_log("Time set to: %02d:%02d (Day %d)" % [current_hour, current_minute, current_day])

## Setze die Time-Warp Geschwindigkeit
## 1.0 = Normal, 2.0 = 2x schneller, 0.5 = Halb so schnell
func set_time_warp_speed(speed: float) -> void:
	if speed <= 0.0:
		_report_warning("Time warp speed must be > 0. Got: %f" % speed)
		return
	
	time_warp_speed = speed
	_update_milliseconds_per_minute()
	
	_debug_log("Time warp speed set to: %.2fx" % time_warp_speed)

## Gib die aktuelle Time-Warp Geschwindigkeit zurück
func get_time_warp_speed() -> float:
	return time_warp_speed

## Berechne Millisekunden pro Minute basierend auf time_warp_speed
func _update_milliseconds_per_minute() -> void:
	milliseconds_per_minute = 60.0 / time_warp_speed

## Pausiere die Zeit
func pause_time() -> void:
	is_time_running = false
	_debug_log("Time paused")

## Starte die Zeit
func resume_time() -> void:
	is_time_running = true
	_debug_log("Time resumed")

## Schalte Zeit um
func toggle_time() -> void:
	if is_time_running:
		pause_time()
	else:
		resume_time()

# ============================================================================
# TIME QUERIES
# ============================================================================

## Gib die aktuelle Zeit als String zurück
func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

## Gib die aktuelle Zeit als vollständigen String zurück
func get_full_time_string() -> String:
	return "Day %d, %02d:%02d" % [current_day, current_hour, current_minute]

## Gib den aktuellen Tag zurück
func get_day() -> int:
	return current_day

## Gib die aktuelle Stunde zurück
func get_hour() -> int:
	return current_hour

## Gib die aktuelle Minute zurück
func get_minute() -> int:
	return current_minute

## Berechne Spielzeit-Differenz in Minuten zwischen zwei Zeiten
func calculate_time_difference(day1: int, hour1: int, minute1: int, day2: int, hour2: int, minute2: int) -> int:
	var total_minutes_1 = (day1 * GameConstants.HOURS_PER_DAY * GameConstants.MINUTES_PER_HOUR) + (hour1 * GameConstants.MINUTES_PER_HOUR) + minute1
	var total_minutes_2 = (day2 * GameConstants.HOURS_PER_DAY * GameConstants.MINUTES_PER_HOUR) + (hour2 * GameConstants.MINUTES_PER_HOUR) + minute2
	
	return abs(total_minutes_2 - total_minutes_1)

# ============================================================================
# MANAGER INTERFACE (von IManager)
# ============================================================================

func on_manager_activate() -> void:
	super.on_manager_activate()
	resume_time()

func on_manager_deactivate() -> void:
	super.on_manager_deactivate()
	pause_time()

func on_game_reset() -> void:
	super.on_game_reset()
	current_day = 1
	current_hour = 8
	current_minute = 0
	time_accumulator = 0.0
	time_warp_speed = GameConstants.TIME_WARP_SPEED_NORMAL
	_update_milliseconds_per_minute()
	is_time_running = true
	_debug_log("TimeManager reset")

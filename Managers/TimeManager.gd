# res://Managers/TimeManager.gd
## Globale Spielzeit-Verwaltung
## 
## REFAKTORED: Benutzt DebugLogger statt _debug_log()

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
var milliseconds_per_minute: float = 60.0

# ============================================================================
# PROPERTIES - PAUSIERUNG
# ============================================================================

## Ist der TimeManager aktiv? (kann auch manuell pausiert werden)
var is_time_running: bool = true

# ============================================================================
# SIGNALS
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
	
	DebugLogger.log("TimeManager", "Initialized at %s" % get_full_time_string())

func _process(delta: float) -> void:
	if not is_time_running:
		return
	
	time_accumulator += delta * 1000.0 * time_warp_speed
	
	while time_accumulator >= milliseconds_per_minute:
		time_accumulator -= milliseconds_per_minute
		_advance_minute()

# ============================================================================
# TIME ADVANCEMENT
# ============================================================================

func _advance_minute() -> void:
	current_minute += 1
	
	if current_minute >= GameConstants.MINUTES_PER_HOUR:
		current_minute = 0
		current_hour += 1
		
		if current_hour >= GameConstants.HOURS_PER_DAY:
			current_hour = 0
			current_day += 1
			_emit_day_tick()
		
		_emit_hour_tick()
	
	_emit_minute_tick()

func _emit_minute_tick() -> void:
	time_minute_tick.emit(current_day, current_hour, current_minute)
	
	if GameController.current_event_bus:
		GameController.current_event_bus.time_minute_tick.emit(current_day, current_hour, current_minute)

func _emit_hour_tick() -> void:
	time_hour_tick.emit(current_day, current_hour)
	
	if GameController.current_event_bus:
		GameController.current_event_bus.time_hour_tick.emit(current_day, current_hour)
	
	DebugLogger.log("TimeManager", "Hour changed: %s" % get_full_time_string())

func _emit_day_tick() -> void:
	time_day_tick.emit(current_day)
	
	if GameController.current_event_bus:
		GameController.current_event_bus.time_day_tick.emit(current_day)
	
	DebugLogger.log("TimeManager", "Day changed: %s" % get_full_time_string())

# ============================================================================
# TIME CONTROL
# ============================================================================

func set_time(day: int, hour: int, minute: int) -> void:
	if day < 1 or hour < 0 or hour >= GameConstants.HOURS_PER_DAY or minute < 0 or minute >= GameConstants.MINUTES_PER_HOUR:
		DebugLogger.warn("TimeManager", "Invalid time: %d/%02d:%02d" % [day, hour, minute])
		return
	
	current_day = day
	current_hour = hour
	current_minute = minute
	DebugLogger.log("TimeManager", "Time set to: %s" % get_full_time_string())

func set_time_warp_speed(speed: float) -> void:
	if speed <= 0.0:
		DebugLogger.warn("TimeManager", "Invalid time warp speed: %f" % speed)
		return
	
	time_warp_speed = speed
	_update_milliseconds_per_minute()
	
	DebugLogger.log("TimeManager", "Time warp speed: %.2fx" % time_warp_speed)

func _update_milliseconds_per_minute() -> void:
	milliseconds_per_minute = 60.0 / time_warp_speed

func get_time_warp_speed() -> float:
	return time_warp_speed

func pause_time() -> void:
	is_time_running = false
	DebugLogger.log("TimeManager", "Time paused")

func resume_time() -> void:
	is_time_running = true
	DebugLogger.log("TimeManager", "Time resumed")

func toggle_time() -> void:
	if is_time_running:
		pause_time()
	else:
		resume_time()

# ============================================================================
# TIME QUERIES
# ============================================================================

func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

func get_full_time_string() -> String:
	return "Day %d, %02d:%02d" % [current_day, current_hour, current_minute]

func get_day() -> int:
	return current_day

func get_hour() -> int:
	return current_hour

func get_minute() -> int:
	return current_minute

func calculate_time_difference(day1: int, hour1: int, minute1: int, day2: int, hour2: int, minute2: int) -> int:
	var total_minutes_1 = (day1 * GameConstants.HOURS_PER_DAY * GameConstants.MINUTES_PER_HOUR) + (hour1 * GameConstants.MINUTES_PER_HOUR) + minute1
	var total_minutes_2 = (day2 * GameConstants.HOURS_PER_DAY * GameConstants.MINUTES_PER_HOUR) + (hour2 * GameConstants.MINUTES_PER_HOUR) + minute2
	
	return abs(total_minutes_2 - total_minutes_1)

# ============================================================================
# MANAGER INTERFACE
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

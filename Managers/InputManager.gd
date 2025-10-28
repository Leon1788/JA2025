# res://Managers/InputManager.gd
## Zentrale Input-Verwaltung
## KORRIGIERT: get_global_mouse_position() -> get_viewport().get_mouse_position()

extends IManager

var input_debounce_timer: float = 0.0
var last_mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	
	self.name = "InputManager"
	
	_debug_log("InputManager initialized")

func _process(delta: float) -> void:
	if input_debounce_timer > 0.0:
		input_debounce_timer -= delta
	
	# Track Maus-Position (KORRIGIERT für Godot 4.4)
	last_mouse_position = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_input(event)
	elif event is InputEventKey:
		_handle_key_input(event)

# ============================================================================
# MOUSE INPUT
# ============================================================================

func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_on_left_click(event.position)
			MOUSE_BUTTON_RIGHT:
				_on_right_click(event.position)
			MOUSE_BUTTON_MIDDLE:
				_on_middle_click(event.position)

func _on_left_click(position: Vector2) -> void:
	if not _can_input_fire():
		return
	
	_input_debounce()
	
	if GameController.current_event_bus:
		var click_data = {
			"button": "left",
			"position": position
		}
		GameController.current_event_bus.tile_clicked.emit(position, click_data)
	
	_debug_log("Left click at: " + str(position))

func _on_right_click(position: Vector2) -> void:
	if not _can_input_fire():
		return
	
	_input_debounce()
	
	if GameController.current_event_bus:
		var click_data = {
			"button": "right",
			"position": position
		}
		GameController.current_event_bus.tile_clicked.emit(position, click_data)
	
	_debug_log("Right click at: " + str(position))

func _on_middle_click(position: Vector2) -> void:
	_debug_log("Middle click at: " + str(position))

# ============================================================================
# KEYBOARD INPUT
# ============================================================================

func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed:
		return
	
	match event.keycode:
		KEY_ESCAPE:
			_on_escape_pressed()
		KEY_SPACE:
			_on_space_pressed()
		KEY_P:
			_on_p_pressed()
		KEY_TAB:
			_on_tab_pressed()

func _on_escape_pressed() -> void:
	_debug_log("ESC pressed")

func _on_space_pressed() -> void:
	_debug_log("SPACE pressed - Toggle pause")
	GameController.toggle_pause()

func _on_p_pressed() -> void:
	if not GameConstants.DEBUG_ENABLED:
		return
	
	_debug_log("P pressed - Print debug info")
	
	if GameController.current_event_bus:
		GameController.current_event_bus.debug_print_all_signals()

func _on_tab_pressed() -> void:
	_debug_log("TAB pressed - Next unit")

# ============================================================================
# INPUT CONTROL
# ============================================================================

func _can_input_fire() -> bool:
	return input_debounce_timer <= 0.0

func _input_debounce() -> void:
	input_debounce_timer = GameConstants.INPUT_DEBOUNCE_TIME

func get_mouse_position() -> Vector2:
	return last_mouse_position

func is_mouse_over_ui() -> bool:
	return get_tree().root.gui_is_dragging() or get_tree().root.is_input_handled()

func disable_input() -> void:
	set_process_input(false)
	_debug_log("Input disabled")

func enable_input() -> void:
	set_process_input(true)
	_debug_log("Input enabled")

# ============================================================================
# MANAGER INTERFACE (von IManager)
# ============================================================================

func on_manager_activate() -> void:
	super.on_manager_activate()
	enable_input()

func on_manager_deactivate() -> void:
	super.on_manager_deactivate()
	disable_input()

func on_game_reset() -> void:
	super.on_game_reset()
	input_debounce_timer = 0.0
	_debug_log("InputManager reset")

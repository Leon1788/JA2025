# res://Architecture/IComponent.gd
## Base Class für alle Components
## 
## Components sind wiederverwendbare Funktionalitäts-Module
## Sie werden an Entities (wie MercNode) angehängt
## 
## Architektur:
##   Entity (MercEntity)
##   ├── Component 1 (SoldierState)
##   ├── Component 2 (MovementComponent)
##   ├── Component 3 (CombatComponent)
##   └── ...
##
## Jeder Component ist unabhängig und kann auch woanders verwendet werden

class_name IComponent extends Node

# ============================================================================
# PROPERTIES
# ============================================================================

## Die Entity, zu der dieser Component gehört
var entity: IEntity = null

## Ist dieser Component aktiv/enabled?
var is_enabled: bool = false

# ============================================================================
# SIGNALS
# ============================================================================

## Emittiert wenn Component enablet wird
signal component_enabled()

## Emittiert wenn Component disabledt wird
signal component_disabled()

## Emittiert wenn ein Fehler im Component auftritt
signal component_error(message: String)

# ============================================================================
# LIFECYCLE
# ============================================================================

## Wird aufgerufen wenn die Szene geladen wird
## Findet die Parent-Entity automatisch
func _ready() -> void:
	# Finde die Parent-Entity
	entity = get_parent() as IEntity
	
	if entity == null:
		_report_error("Component '%s' nicht an ein IEntity angebunden!" % self.name)
		return
	
	# Starte disabled
	is_enabled = false
	set_process(false)
	
	_debug_log("Component ready, parent entity: %s" % entity.name)

# Wird in jedem Frame aufgerufen (wenn enabled)
func _process(delta: float) -> void:
	pass

# ============================================================================
# COMPONENT INTERFACE (für Sub-Klassen)
# ============================================================================

## Wird aufgerufen wenn die Entity aktiviert wird (sichtbar/in Kampf)
## Override in Sub-Klassen
func on_enable() -> void:
	is_enabled = true
	set_process(true)
	component_enabled.emit()
	_debug_log("Component enabled")

## Wird aufgerufen wenn die Entity deaktiviert wird
## Override in Sub-Klassen
func on_disable() -> void:
	is_enabled = false
	set_process(false)
	component_disabled.emit()
	_debug_log("Component disabled")

# ============================================================================
# ERROR HANDLING
# ============================================================================

## Zentrale Error-Handling Methode
func _report_error(message: String) -> void:
	var full_message = "[%s.%s] %s" % [entity.name if entity else "Unknown", self.name, message]
	push_error(full_message)
	component_error.emit(message)

## Zentrale Warning-Methode
func _report_warning(message: String) -> void:
	push_warning("[%s.%s] %s" % [entity.name if entity else "Unknown", self.name, message])

## Zentrale Debug-Log Methode
func _debug_log(message: String) -> void:
	if GameConstants.DEBUG_ENABLED:
		print("[%s.%s] %s" % [entity.name if entity else "Unknown", self.name, message])

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Gib den vollständigen Path des Components zurück (für Debug)
func get_component_path() -> String:
	if entity:
		return "%s/%s" % [entity.name, self.name]
	return self.name

## Prüfe ob Component enabled ist
func is_component_enabled() -> bool:
	return is_enabled

## Gib einen anderen Component von der gleichen Entity zurück
## Verwendung: var combat = get_sibling_component("CombatComponent") as CombatComponent
func get_sibling_component(component_name: String) -> IComponent:
	if entity == null:
		_report_error("Keine Entity gefunden!")
		return null
	
	return entity.get_component(component_name)

## Gib einen Child-Node von dieser Entity zurück (z.B. für AnimationPlayer)
func get_entity_child(node_name: String) -> Node:
	if entity == null:
		_report_error("Keine Entity gefunden!")
		return null
	
	return entity.get_node_or_null(node_name)

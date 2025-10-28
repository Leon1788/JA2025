# res://Architecture/NullComponent.gd
## Null-Component - Null-Object Pattern Implementation
## 
## Verhindert Null-Pointer-Exceptions durch stille Fehlertoleranz
## Wenn ein Component nicht gefunden wird, returnen wir NullComponent
## statt null - dies verhindert Crashes!
##
## VERWENDUNG (in IEntity.get_component()):
##   func get_component(component_name: String) -> IComponent:
##       var component = components.get(component_name, null)
##       if component == null:
##           return NullComponent.new()  # ← Statt null!
##       return component
##
## WICHTIG: NullComponent hat ALLE Funktionen der IComponent
## Aber alle machen NICHTS (No-Op/Silent Fail)
## Das ist das Null-Object Pattern - verhindert Crashes!

class_name NullComponent extends IComponent

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	set_process(false)
	set_physics_process(false)
	DebugLogger.log(self.name, "NullComponent created - Component was not found!")

# ============================================================================
# INTERFACE IMPLEMENTATION - ALL NO-OPS (Null-Object Pattern)
# ============================================================================

## Override: on_enable - Macht nichts (Null-Object Pattern)
## Dies ist absichtlich leer, um Fehler zu vermeiden
func on_enable() -> void:
	is_enabled = true
	component_enabled.emit()
	DebugLogger.warn(self.name, "on_enable() called on NullComponent - did you forget a component?")

## Override: on_disable - Macht nichts (Null-Object Pattern)
## Dies ist absichtlich leer, um Fehler zu vermeiden
func on_disable() -> void:
	is_enabled = false
	component_disabled.emit()
	DebugLogger.warn(self.name, "on_disable() called on NullComponent - did you forget a component?")

## Alias: enable() - Verschiedene Code-Teile nutzen enable() statt on_enable()
## NullComponent muss BEIDE Varianten abfangen!
func enable() -> void:
	on_enable()

## Alias: disable() - Verschiedene Code-Teile nutzen disable() statt on_disable()
## NullComponent muss BEIDE Varianten abfangen!
func disable() -> void:
	on_disable()

## Catchall: Falls irgendetwas anderes aufgerufen wird
## _notification erlaubt uns beliebige Methoden abzufangen
func _notification(what: int) -> void:
	pass  # Silent Fail - NullComponent macht einfach nichts

# ============================================================================
# OPTIONAL: Debug-Informationen
# ============================================================================

## Gibt Info über den Missing Component zurück
func get_null_component_info() -> String:
	return "NullComponent [Missing/Fallback] - Check debug logs for component name"

## Wird aufgerufen wenn jemand versucht auf die NullComponent zuzugreifen
## und etwas mit ihr machen will
func _process(delta: float) -> void:
	pass  # Absichtlich leer - NullComponent tut nichts

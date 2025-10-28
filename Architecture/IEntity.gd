# res://Architecture/IEntity.gd
## Base Class für alle Entities (Einheiten im Spiel)
## 
## Eine Entity ist ein Container für Components
## Alle aktiven Spielobjekte sind Entities (Merc, Enemy, NPC, etc.)
##
## ARCHITEKTUR:
##   Entity (erbt von IEntity)
##   ├── SoldierState (IComponent)
##   ├── MovementComponent (IComponent)
##   ├── CombatComponent (IComponent)
##   ├── InventoryComponent (IComponent)
##   ├── VisionComponent (IComponent)
##   ├── AIComponent (IComponent) - nur für Enemies
##   ├── MeshInstance3D (Visual)
##   ├── CollisionShape3D (Physics)
##   └── AnimationPlayer (Animation)

class_name IEntity extends Node3D

# ============================================================================
# PROPERTIES
# ============================================================================

## Dictionary aller Components, key = component_name, value = IComponent
var components: Dictionary = {}

## Ist diese Entity aktiv? (kann Aktionen ausführen)
var is_active: bool = false

## Eindeutige Entity-ID (z.B. "merc_01", "enemy_03")
var entity_id: String = ""

# ============================================================================
# SIGNALS
# ============================================================================

## Emittiert wenn Entity aktiviert wird
signal entity_activated()

## Emittiert wenn Entity deaktiviert wird
signal entity_deactivated()

## Emittiert wenn Entity stirbt
signal entity_died()

## Emittiert wenn ein Component zu dieser Entity hinzugefügt wird
signal component_added(component_name: String)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Sammle alle Components (Childer die von IComponent erben)
	_gather_components()
	
	# Starte deaktiviert
	is_active = false
	_disable_all_components()
	
	DebugLogger.log(self.name, "Entity ready with %d components" % components.size())

func _process(delta: float) -> void:
	pass

# ============================================================================
# COMPONENT MANAGEMENT
# ============================================================================

## Sammle alle Components automatisch
func _gather_components() -> void:
	components.clear()
	
	for child in get_children():
		if child is IComponent:
			components[child.name] = child
			component_added.emit(child.name)
	
	DebugLogger.log(self.name, "Gathered %d components" % components.size())

## Gib einen Component by Name zurück
## WICHTIG: Returnt NullComponent statt null wenn nicht gefunden!
## Verwendung: var state = entity.get_component("SoldierState")
func get_component(component_name: String) -> IComponent:
	var component = components.get(component_name, null)
	
	if component == null:
		_report_warning("Component '%s' nicht gefunden auf Entity '%s'" % [component_name, self.name])
		return NullComponent.new()  # ← Null-Object Pattern
	
	return component

## Gib einen Component by Type zurück
## Verwendung: var combat = entity.get_component_by_type("CombatComponent")
func get_component_by_type(component_type: String) -> IComponent:
	for component in components.values():
		if component.get_class() == component_type or component.get_script().resource_name.contains(component_type):
			return component
	
	_report_warning("Component vom Typ '%s' nicht gefunden" % component_type)
	return NullComponent.new()  # ← Null-Object Pattern

## Prüfe ob ein Component existiert
func has_component(component_name: String) -> bool:
	return component_name in components

## Addiere einen Component zur Entity (falls noch nicht vorhanden)
## Verwendung: entity.add_component(new_component)
func add_component(component: IComponent) -> void:
	if has_component(component.name):
		_report_warning("Component '%s' existiert bereits!" % component.name)
		return
	
	components[component.name] = component
	component_added.emit(component.name)
	DebugLogger.log(self.name, "Component added: %s" % component.name)

# ============================================================================
# ENTITY LIFECYCLE
# ============================================================================

## Aktiviere diese Entity (wenn sie in Kampf kommt)
func activate() -> void:
	if is_active:
		_report_warning("Entity ist bereits aktiv!")
		return
	
	is_active = true
	_enable_all_components()
	entity_activated.emit()
	
	DebugLogger.log(self.name, "Entity activated")

## Deaktiviere diese Entity
func deactivate() -> void:
	if not is_active:
		_report_warning("Entity ist bereits inaktiv!")
		return
	
	is_active = false
	_disable_all_components()
	entity_deactivated.emit()
	
	DebugLogger.log(self.name, "Entity deactivated")

## Enablet alle Components
func _enable_all_components() -> void:
	for component in components.values():
		if component:
			component.on_enable()

## Disabledt alle Components
func _disable_all_components() -> void:
	for component in components.values():
		if component:
			component.on_disable()

# ============================================================================
# STATE QUERIES
# ============================================================================

## Prüfe ob Entity aktiv ist
func is_entity_active() -> bool:
	return is_active

## Gib alle Components zurück
func get_all_components() -> Array:
	return components.values()

## Gib Anzahl der Components zurück
func get_component_count() -> int:
	return components.size()

## Gib Entity-Informationen aus (für Debug)
func get_debug_info() -> String:
	var info = "Entity: %s (ID: %s)\n" % [self.name, entity_id]
	info += "Active: %s\n" % is_active
	info += "Components: %d\n" % components.size()
	
	for component_name in components.keys():
		info += "  - %s\n" % component_name
	
	return info

# ============================================================================
# DEATH & CLEANUP
# ============================================================================

## Töte diese Entity
func die() -> void:
	deactivate()
	entity_died.emit()
	DebugLogger.log(self.name, "Entity died")
	
	# Optional: Fade-out Animation hier, dann queue_free()
	queue_free()

# ============================================================================
# ERROR HANDLING (REFAKTORIERT: Nutzt DebugLogger)
# ============================================================================

func _report_error(message: String) -> void:
	var full_message = "[Entity %s] %s" % [self.name, message]
	push_error(full_message)
	DebugLogger.error(self.name, full_message)

func _report_warning(message: String) -> void:
	var full_message = "[Entity %s] %s" % [self.name, message]
	push_warning(full_message)
	DebugLogger.warn(self.name, full_message)

func _debug_log(message: String) -> void:
	DebugLogger.log(self.name, message)

# ============================================================================
# HELPER: COMPONENT SHORTCUTS (optional)
# ============================================================================

## Schnell-Zugriff auf SoldierState (falls vorhanden)
func get_soldier_state() -> IComponent:
	return get_component("SoldierState")

## Schnell-Zugriff auf Movement Component
func get_movement_component() -> IComponent:
	return get_component("MovementComponent")

## Schnell-Zugriff auf Combat Component
func get_combat_component() -> IComponent:
	return get_component("CombatComponent")

## Schnell-Zugriff auf Inventory Component
func get_inventory_component() -> IComponent:
	return get_component("InventoryComponent")

## Schnell-Zugriff auf Vision Component
func get_vision_component() -> IComponent:
	return get_component("VisionComponent")

## Schnell-Zugriff auf AI Component
func get_ai_component() -> IComponent:
	return get_component("AIComponent")

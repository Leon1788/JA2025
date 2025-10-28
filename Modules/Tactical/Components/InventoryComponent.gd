# res://Modules/Tactical/Components/InventoryComponent.gd
## Inventar-Komponente - Items und Equipment-Verwaltung
##
## Verantwortlichkeiten:
## - Item Storage
## - Equipment Slots
## - Weapon/Item Equipping
## - Attachment Management

class_name InventoryComponent extends IComponent

# ============================================================================
# PROPERTIES - INVENTORY
# ============================================================================

var inventory_slots: Array = []  # Verfügbare Items
var max_inventory_slots: int = 20

var equipment_slots: Dictionary = {
	"primary_weapon": null,
	"secondary_weapon": null,
	"armor": null,
	"utility": []  # Grenades, Medical Items, etc.
}

# ============================================================================
# SIGNALS
# ============================================================================

signal item_added(item: Dictionary)
signal item_removed(item: Dictionary)
signal item_equipped(slot: String, item: Dictionary)
signal item_unequipped(slot: String)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	_debug_log("InventoryComponent initialized")

# ============================================================================
# ITEM MANAGEMENT
# ============================================================================

## Füge Item hinzu
func add_item(item_data: Dictionary) -> bool:
	if inventory_slots.size() >= max_inventory_slots:
		_debug_log("Inventory full!")
		return false
	
	inventory_slots.append(item_data)
	item_added.emit(item_data)
	_debug_log("Item added: %s" % item_data.get("name", "Unknown"))
	return true

## Entferne Item
func remove_item(item_data: Dictionary) -> bool:
	if item_data not in inventory_slots:
		return false
	
	inventory_slots.erase(item_data)
	item_removed.emit(item_data)
	_debug_log("Item removed: %s" % item_data.get("name", "Unknown"))
	return true

## Gib alle Items eines Typs zurück
func get_items_by_type(item_type: String) -> Array:
	var items = []
	for item in inventory_slots:
		if item.get("type", "") == item_type:
			items.append(item)
	return items

# ============================================================================
# EQUIPMENT SLOTS
# ============================================================================

## Bestücke Equipment-Slot
func equip_item(slot: String, item_data: Dictionary) -> bool:
	if slot not in equipment_slots:
		_report_warning("Unknown equipment slot: %s" % slot)
		return false
	
	# Prüfe ob Item im Inventar
	if item_data not in inventory_slots:
		_report_warning("Item not in inventory!")
		return false
	
	# Entferne altes Item aus Slot (falls vorhanden)
	var old_item = equipment_slots[slot]
	
	equipment_slots[slot] = item_data
	item_equipped.emit(slot, item_data)
	_debug_log("Item equipped: %s to slot %s" % [item_data.get("name", "Unknown"), slot])
	
	# Wenn Waffe: gib zu CombatComponent
	if slot == "primary_weapon" or slot == "secondary_weapon":
		var combat = entity.get_component("CombatComponent") as CombatComponent
		if combat:
			combat.equip_weapon(item_data)
	
	return true

## Entferne Item aus Equipment-Slot
func unequip_item(slot: String) -> bool:
	if slot not in equipment_slots:
		return false
	
	equipment_slots[slot] = null
	item_unequipped.emit(slot)
	_debug_log("Item unequipped from slot: %s" % slot)
	return true

## Gib ausgerüstetes Item zurück
func get_equipped_item(slot: String) -> Dictionary:
	if slot in equipment_slots:
		var item = equipment_slots[slot]
		if item is Dictionary:
			return item
	return {}

# ============================================================================
# ATTACHMENT SYSTEM
# ============================================================================

## Befestige Attachment an Waffe
func attach_mod(weapon_slot: String, attachment_data: Dictionary) -> bool:
	var weapon = get_equipped_item(weapon_slot)
	if weapon.is_empty():
		_debug_log("No weapon equipped in slot: %s" % weapon_slot)
		return false
	
	# TODO: WeaponModSystem.attach_mod()
	# Hier vereinfachte Version
	
	if "attachments" not in weapon:
		weapon["attachments"] = {}
	
	var attachment_slot = attachment_data.get("slot", "")
	weapon["attachments"][attachment_slot] = attachment_data
	
	_debug_log("Attachment added: %s" % attachment_data.get("name", "Unknown"))
	return true

## Entferne Attachment
func remove_mod(weapon_slot: String, attachment_slot: String) -> bool:
	var weapon = get_equipped_item(weapon_slot)
	if weapon.is_empty():
		return false
	
	if "attachments" in weapon and attachment_slot in weapon["attachments"]:
		weapon["attachments"].erase(attachment_slot)
		_debug_log("Attachment removed from slot: %s" % attachment_slot)
		return true
	
	return false

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Prüfe ob Slot leer ist
func is_slot_empty(slot: String) -> bool:
	if slot not in equipment_slots:
		return true
	return equipment_slots[slot] == null

## Gib Inventar-Platz-Prozentsatz zurück
func get_inventory_percent() -> float:
	if max_inventory_slots == 0:
		return 1.0
	return float(inventory_slots.size()) / float(max_inventory_slots)

# ============================================================================
# COMPONENT INTERFACE
# ============================================================================

func on_enable() -> void:
	super.on_enable()
	_debug_log("InventoryComponent enabled")

func on_disable() -> void:
	super.on_disable()
	_debug_log("InventoryComponent disabled")

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "InventoryComponent:\n"
	info += "  Items: %d/%d\n" % [inventory_slots.size(), max_inventory_slots]
	info += "  Primary Weapon: %s\n" % (equipment_slots["primary_weapon"].get("name", "None") if equipment_slots["primary_weapon"] else "None")
	info += "  Secondary Weapon: %s" % (equipment_slots["secondary_weapon"].get("name", "None") if equipment_slots["secondary_weapon"] else "None")
	return info

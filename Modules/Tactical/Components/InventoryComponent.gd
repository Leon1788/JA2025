# res://Modules/Tactical/Components/InventoryComponent.gd
## Inventar-Komponente - Items und Equipment-Verwaltung
##
## REFAKTORIERT (30.10.2025):
## - Delegiert alle Logik an InventorySystem und EquipmentSystem.
## - KORRIGIERT: 'is NullComponent' Check zu '== null' geändert,
##   um 'as' Cast-Fehler abzufangen.

class_name InventoryComponent extends IComponent

# Importiere die neuen Klassen, die wir benötigen
const ItemInstance = preload("res://Modules/Tactical/Inventory/ItemInstance.gd")
const InventorySystem = preload("res://Modules/Tactical/Systems/InventorySystem.gd")
const EquipmentSystem = preload("res://Modules/Tactical/Systems/EquipmentSystem.gd")
const CombatComponent = preload("res://Modules/Tactical/Components/CombatComponent.gd")
const SoldierState = preload("res://Modules/Tactical/Components/SoldierState.gd")
const AttachmentResource = preload("res://Architecture/Resources/AttachmentResource.gd")

# ============================================================================
# PROPERTIES - INVENTORY
# ============================================================================

## "Rucksack" - Items, die der Söldner trägt, aber nicht angelegt hat
var inventory_slots: Array[ItemInstance] = []
@export var max_inventory_slots: int = 20

## "Angelegt" - Items, die der Söldner am Körper trägt
var equipment_slots: Dictionary = {
	"primary_weapon": null,    # ItemInstance
	"secondary_weapon": null,  # ItemInstance
	"armor": null,             # ItemInstance
	"utility": []              # Array[ItemInstance] (z.B. Granaten)
}

# ============================================================================
# SIGNALS
# ============================================================================

signal item_added_to_inventory(item: ItemInstance)
signal item_removed_from_inventory(item: ItemInstance)
signal item_equipped(slot: String, item: ItemInstance)
signal item_unequipped(slot: String, item: ItemInstance)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	_debug_log("InventoryComponent (Refactored) initialized")

# ============================================================================
# ITEM MANAGEMENT (Rucksack)
# ============================================================================

## Fügt ein Item zum Rucksack hinzu.
func add_item_to_inventory(item: ItemInstance) -> bool:
	var success = InventorySystem.add_item(inventory_slots, item, max_inventory_slots)
	
	if success:
		item_added_to_inventory.emit(item)
		_debug_log("Item added to inventory: %s" % item.base_item_id)
	else:
		_debug_log("Inventory full! Item '%s' konnte nicht hinzugefügt werden." % item.base_item_id)
		
	return success

## Entfernt ein Item aus dem Rucksack.
func remove_item_from_inventory(item: ItemInstance) -> bool:
	var success = InventorySystem.remove_item(inventory_slots, item)
	
	if success:
		item_removed_from_inventory.emit(item)
		_debug_log("Item removed from inventory: %s" % item.base_item_id)
		
	return success

## Gibt alle Items eines bestimmten Typs aus dem Rucksack zurück.
func get_items_by_type(item_type: String) -> Array[ItemInstance]:
	return InventorySystem.find_items_by_type(inventory_slots, item_type)

# ============================================================================
# EQUIPMENT SLOTS (Anlegen / Ablegen)
# ============================================================================

## Rüste ein Item AUS DEM RUCKSACK in einen Slot aus.
func equip_item_from_inventory(slot: String, item_to_equip: ItemInstance) -> bool:
	if item_to_equip not in inventory_slots:
		_report_warning("Item '%s' ist nicht im Inventar!" % item_to_equip.instance_id)
		return false
	
	var old_item: ItemInstance = EquipmentSystem.equip_item(
		equipment_slots,
		inventory_slots,
		item_to_equip,
		slot
	)
	
	if equipment_slots.get(slot) != item_to_equip:
		_report_warning("Ausrüsten von '%s' in Slot '%s' fehlgeschlagen (inkompatibel?)." % [item_to_equip.base_item_id, slot])
		InventorySystem.add_item(inventory_slots, item_to_equip, max_inventory_slots)
		return false

	item_equipped.emit(slot, item_to_equip)
	_debug_log("Item equipped: %s to slot %s" % [item_to_equip.base_item_id, slot])

	if old_item:
		var added_back = add_item_to_inventory(old_item)
		if not added_back:
			_report_error("Inventar voll! Altes Item '%s' wurde auf den Boden geworfen." % old_item.base_item_id)
			
	_update_component_stats()
	return true

## Lege ein Item AUS EINEM SLOT zurück in den Rucksack.
func unequip_item_to_inventory(slot: String) -> bool:
	var item_in_slot = get_equipped_item(slot)
	if item_in_slot == null:
		_debug_log("Slot '%s' ist bereits leer." % slot)
		return true

	var success = EquipmentSystem.unequip_item(
		equipment_slots,
		inventory_slots,
		slot,
		max_inventory_slots
	)
	
	if success:
		_debug_log("Item unequipped from slot: %s" % slot)
		item_unequipped.emit(slot, item_in_slot)
		_update_component_stats()
	else:
		_report_warning("Ablegen fehlgeschlagen (Inventar voll?)")

	return success

## Gib das angelegte Item in einem Slot zurück.
func get_equipped_item(slot: String) -> ItemInstance:
	if equipment_slots.has(slot):
		var item = equipment_slots[slot]
		if item is ItemInstance:
			return item
	return null

# ============================================================================
# ATTACHMENT SYSTEM (Modding)
# ============================================================================

## Befestige ein Attachment (aus dem Rucksack) an einer Waffe (im Slot).
func attach_mod(weapon_slot: String, attachment_item: ItemInstance, attachment_slot_name: String) -> bool:
	var weapon = get_equipped_item(weapon_slot) as ItemInstance
	if weapon == null:
		_debug_log("Keine Waffe in Slot: %s" % weapon_slot)
		return false
		
	if attachment_item not in inventory_slots:
		_report_warning("Attachment '%s' ist nicht im Inventar!" % attachment_item.base_item_id)
		return false
		
	var attachment_res = DataManager.get_attachment(attachment_item.base_item_id) as AttachmentResource
	if attachment_res == null:
		_report_error("Attachment-Ressource '%s' konnte nicht geladen werden! (Fehlt Packet 4?)" % attachment_item.base_item_id)
		return false
		
	var success = weapon.add_attachment(attachment_res, attachment_slot_name)
	
	if not success:
		_debug_log("Attachment '%s' konnte nicht an '%s' angebracht werden (inkompatibel?)" % [attachment_item.base_item_id, weapon.base_item_id])
		return false
		
	InventorySystem.remove_item(inventory_slots, attachment_item)
	_debug_log("Attachment added: %s" % attachment_item.base_item_id)
	_update_combat_component()
	return true

## Entferne ein Attachment von einer Waffe.
func remove_mod(weapon_slot: String, attachment_slot_name: String) -> bool:
	var weapon = get_equipped_item(weapon_slot) as ItemInstance
	if weapon == null:
		return false
	
	var removed_attachment_res: AttachmentResource = weapon.remove_attachment(attachment_slot_name)
	
	if removed_attachment_res:
		var new_item_instance = ItemInstance.new()
		new_item_instance.instance_id = "item_%s" % Time.get_ticks_usec()
		new_item_instance.base_item_id = removed_attachment_res.id
		new_item_instance.base_weapon_data = removed_attachment_res.to_dict() 
		
		if not add_item_to_inventory(new_item_instance):
			_report_error("Inventar voll! Entferntes Attachment '%s' auf Boden geworfen." % removed_attachment_res.id)
			
		_debug_log("Attachment removed from slot: %s" % attachment_slot_name)
		_update_combat_component()
		return true
	
	_debug_log("Attachment '%s' konnte nicht entfernt werden." % attachment_slot_name)
	return false

# ============================================================================
# KOMPONENTEN-SYNCHRONISIERUNG (NEU)
# ============================================================================

## Informiert andere Komponenten (Combat, State) über Ausrüstungsänderungen.
func _update_component_stats() -> void:
	_update_combat_component()
	_update_soldier_state()

## Aktualisiert den CombatComponent mit der aktuell ausgerüsteten Waffe.
func _update_combat_component() -> void:
	var combat = get_sibling_component("CombatComponent") as CombatComponent
	
	# KORREKTUR: 'is NullComponent' -> '== null'
	# Der 'as CombatComponent' Cast schlägt fehl, wenn eine NullComponent
	# zurückgegeben wird, was zu 'null' führt.
	if combat == null: 
		_report_error("CombatComponent nicht gefunden!")
		return

	var primary_weapon = get_equipped_item("primary_weapon")
	
	if primary_weapon:
		combat.equip_weapon_instance(primary_weapon)
	else:
		combat.unequip_weapon()
		
	# TODO: Sekundärwaffe auch übergeben (später)

## Aktualisiert den SoldierState mit den Rüstungswerten.
func _update_soldier_state() -> void:
	var state = get_sibling_component("SoldierState") as SoldierState
	
	# KORREKTUR: 'is NullComponent' -> '== null'
	if state == null:
		_report_error("SoldierState nicht gefunden!")
		return
		
	var armor_stats = EquipmentSystem.get_total_armor(equipment_slots)
	state.set_armor(armor_stats["armor_value"], armor_stats["armor_type"])

# ============================================================================
# QUERY FUNCTIONS (Refaktoriert)
# ============================================================================

func is_slot_empty(slot: String) -> bool:
	if not equipment_slots.has(slot):
		return true
	return equipment_slots[slot] == null

func get_inventory_percent() -> float:
	return InventorySystem.get_inventory_fill_percent(inventory_slots, max_inventory_slots)

# ============================================================================
# COMPONENT INTERFACE
# ============================================================================

func on_enable() -> void:
	super.on_enable()
	_debug_log("InventoryComponent enabled")
	_update_component_stats()

func on_disable() -> void:
	super.on_disable()
	_debug_log("InventoryComponent disabled")

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "InventoryComponent:\n"
	info += "  Items: %d/%d\n" % [inventory_slots.size(), max_inventory_slots]
	
	var primary = get_equipped_item("primary_weapon")
	info += "  Primary Weapon: %s\n" % (primary.base_item_id if primary else "None")
	
	var secondary = get_equipped_item("secondary_weapon")
	info += "  Secondary Weapon: %s\n" % (secondary.base_item_id if secondary else "None")
	
	var armor = get_equipped_item("armor")
	info += "  Armor: %s" % (armor.base_item_id if armor else "None")
	return info

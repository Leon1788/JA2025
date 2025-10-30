# res://Modules/Tactical/Systems/EquipmentSystem.gd
## PURE CLASS - Keine Godot Node Dependencies!
##
## Verantwortlichkeiten:
## - Stellt statische Funktionen zur Verwaltung von Ausrüstungs-Slots bereit.
## - Logik für das An- und Ablegen von Items (equip/unequip).
## - Berechnet kombinierte Werte der Ausrüstung (z.B. Rüstung).
##
## Diese Klasse wird vom 'InventoryComponent' aufgerufen.

class_name EquipmentSystem

# Importiere die Klassen, mit denen wir arbeiten
const ItemInstance = preload("res://Modules/Tactical/Inventory/ItemInstance.gd")
const InventorySystem = preload("res://Modules/Tactical/Systems/InventorySystem.gd")

# ============================================================================
# AUSRÜSTUNGS-LOGIK
# ============================================================================

## Legt ein Item aus dem Inventar in einen Ausrüstungs-Slot an.
## equipment: Das 'equipment_slots' Dictionary vom InventoryComponent
## inventory: Das 'inventory_slots' Array vom InventoryComponent
## item_to_equip: Die Item-Instanz aus dem Inventar, die angelegt werden soll
## target_slot: Der Name des Slots (z.B. "primary_weapon", "armor")
##
## Gibt das Item zurück, das vorher in dem Slot war (oder null).
static func equip_item(
	equipment: Dictionary,
	inventory: Array,
	item_to_equip: ItemInstance,
	target_slot: String
) -> ItemInstance:
	
	if not equipment.has(target_slot):
		DebugLogger.error("EquipmentSystem", "Slot '%s' existiert nicht im Ausrüstungs-Dictionary." % target_slot)
		return null # Fehler, Slot existiert nicht

	# 1. Prüfe Kompatibilität
	if not _is_compatible_with_slot(item_to_equip, target_slot):
		DebugLogger.warn("EquipmentSystem", "Item '%s' (Typ: %s) passt nicht in Slot '%s'." % [
			item_to_equip.base_item_id,
			item_to_equip.base_weapon_data.get("weapon_type", "N/A"),
			target_slot
		])
		return null # Fehler, Item passt nicht in Slot

	# 2. Item aus Inventar entfernen
	var removed = InventorySystem.remove_item(inventory, item_to_equip)
	if not removed:
		DebugLogger.error("EquipmentSystem", "Item '%s' konnte nicht aus Inventar entfernt werden (Bug?)." % item_to_equip.instance_id)
		return null # Fehler, Item war nicht im Inventar

	# 3. Altes Item aus Slot holen (kann null sein)
	var old_item = equipment.get(target_slot) as ItemInstance
	
	# 4. Neues Item in Slot legen
	equipment[target_slot] = item_to_equip
	
	DebugLogger.log("EquipmentSystem", "Item '%s' in Slot '%s' angelegt." % [item_to_equip.base_item_id, target_slot])

	# 5. Altes Item zurückgeben (muss vom InventoryComponent wieder ins Inventar gelegt werden)
	return old_item

## Legt ein Item aus einem Slot zurück ins Inventar.
## Gibt true zurück, wenn erfolgreich.
static func unequip_item(
	equipment: Dictionary,
	inventory: Array,
	slot_to_unequip: String,
	max_inventory_slots: int
) -> bool:

	if not equipment.has(slot_to_unequip):
		DebugLogger.error("EquipmentSystem", "Slot '%s' existiert nicht." % slot_to_unequip)
		return false

	# 1. Item aus Slot holen
	var item_to_unequip = equipment.get(slot_to_unequip) as ItemInstance
	if item_to_unequip == null:
		DebugLogger.warn("EquipmentSystem", "Slot '%s' ist bereits leer." % slot_to_unequip)
		return true # Nichts zu tun

	# 2. Versuchen, es ins Inventar zu legen
	var added_to_inventory = InventorySystem.add_item(inventory, item_to_unequip, max_inventory_slots)
	
	if not added_to_inventory:
		DebugLogger.warn("EquipmentSystem", "Inventar ist voll. Item '%s' konnte nicht abgelegt werden." % item_to_unequip.base_item_id)
		return false # Fehler, Inventar voll

	# 3. Slot leeren
	equipment[slot_to_unequip] = null
	DebugLogger.log("EquipmentSystem", "Item '%s' aus Slot '%s' abgelegt." % [item_to_unequip.base_item_id, slot_to_unequip])
	
	return true

# ============================================================================
# BERECHNUNGEN
# ============================================================================

## Berechnet den Gesamtrüstungswert basierend auf angelegter Rüstung
## HINWEIS: Dies erfordert eine 'ArmorResource'-Klasse (Packet 4)
## Bis dahin verwenden wir einen Platzhalter.
static func get_total_armor(equipment: Dictionary) -> Dictionary:
	var total_armor = {
		"armor_value": 0,
		"armor_type": "none"
	}
	
	var armor_item = equipment.get("armor") as ItemInstance
	if armor_item:
		# PLATZHALTER-LOGIK (bis ArmorResource existiert)
		# Wir nehmen an, Rüstungen haben Stats in 'effective_stats'
		# (Diese Logik ist spekulativ, bis wir ArmorResource definieren)
		var armor_stats = armor_item.get_effective_stats()
		
		if armor_stats.has("armor_value"):
			total_armor["armor_value"] = armor_stats.get("armor_value", 0)
		if armor_stats.has("armor_type"):
			total_armor["armor_type"] = armor_stats.get("armor_type", "medium")
			
	return total_armor

# ============================================================================
# HELPER (KOMPATIBILITÄT)
# ============================================================================

## Prüft, ob ein Item-Typ in einen bestimmten Slot passt
static func _is_compatible_with_slot(item: ItemInstance, slot: String) -> bool:
	if not (item and item is ItemInstance):
		return false
		
	# Hole den "Typ" des Items. Für Waffen ist es 'weapon_type'.
	var item_type = "unknown"
	if item.base_weapon_data.has("weapon_type"):
		item_type = item.base_weapon_data["weapon_type"]
	# TODO: Später 'item.base_item_data.get("item_type")' für Rüstung/etc. prüfen

	match slot:
		"primary_weapon":
			# Große Waffen
			return item_type in ["rifle", "smg", "shotgun", "sniper", "lmg"]
		"secondary_weapon":
			# Kleine Waffen
			return item_type in ["pistol", "revolver"]
		"armor":
			# TODO: Erfordert 'ArmorResource'
			# return item_type == "armor"
			DebugLogger.warn("EquipmentSystem", "_is_compatible_with_slot: Rüstungs-Check ist noch Platzhalter.")
			return true # Platzhalter: Erlaube alles (zum Testen)
		"utility":
			# TODO: Erfordert 'ItemResource' (Granaten, Medkits)
			# return item_type in ["grenade", "medical", "tool"]
			DebugLogger.warn("EquipmentSystem", "_is_compatible_with_slot: Utility-Check ist noch Platzhalter.")
			return true # Platzhalter
		_:
			return false # Unbekannter Slot
			
	return false

# res://Modules/Tactical/Systems/InventorySystem.gd
## PURE CLASS - Keine Godot Node Dependencies!
##
## Verantwortlichkeiten:
## - Stellt statische Funktionen zur Verwaltung von Inventar-Listen bereit.
## - Hinzufügen, Entfernen, Suchen von Items.
## - Berechnung von Gewicht, Platz etc.
##
## Diese Klasse wird vom 'InventoryComponent' aufgerufen.

class_name InventorySystem

# Importiere die Klasse, mit der wir arbeiten
const ItemInstance = preload("res://Modules/Tactical/Inventory/ItemInstance.gd")

# ============================================================================
# ITEM MANAGEMENT (GRUNDFUNKTIONEN)
# ============================================================================

## Fügt ein Item zu einer Inventarliste hinzu (z.B. Rucksack)
## inventory: Das Array (z.B. InventoryComponent.inventory_slots)
## item: Die ItemInstance, die hinzugefügt werden soll
## max_slots: Die maximale Größe des Inventars
static func add_item(inventory: Array, item: ItemInstance, max_slots: int) -> bool:
	if not (item and item is ItemInstance):
		DebugLogger.error("InventorySystem", "add_item: Ungültiges Item übergeben.")
		return false
		
	# 1. Prüfe, ob Platz vorhanden ist
	if inventory.size() >= max_slots:
		DebugLogger.warn("InventorySystem", "Inventar ist voll (%d/%d). Kann '%s' nicht hinzufügen." % [inventory.size(), max_slots, item.base_item_id])
		return false
		
	# 2. TODO: Stacking-Logik (z.B. für Munition, Granaten)
	# if item.is_stackable():
	#     var existing_stack = find_stackable_item(inventory, item.base_item_id)
	#     if existing_stack:
	#         existing_stack.quantity += item.quantity
	#         return true
			
	# 3. Item zur Liste hinzufügen
	inventory.append(item)
	DebugLogger.log("InventorySystem", "Item '%s' (Instanz: %s) zum Inventar hinzugefügt." % [item.base_item_id, item.instance_id])
	return true

## Entfernt eine spezifische Item-Instanz aus einem Inventar
static func remove_item(inventory: Array, item_instance: ItemInstance) -> bool:
	var index = inventory.find(item_instance)
	
	if index == -1:
		DebugLogger.warn("InventorySystem", "remove_item: Item '%s' nicht im Inventar gefunden." % item_instance.instance_id)
		return false
		
	inventory.remove_at(index)
	DebugLogger.log("InventorySystem", "Item '%s' aus Inventar entfernt." % item_instance.instance_id)
	return true

## Entfernt ein Item anhand seiner Instanz-ID
static func remove_item_by_instance_id(inventory: Array, instance_id: String) -> ItemInstance:
	var item = find_item_by_instance_id(inventory, instance_id)
	if item:
		if remove_item(inventory, item):
			return item
	return null

# ============================================================================
# ITEM-SUCHE (QUERY-FUNKTIONEN)
# ============================================================================

## Findet die ERSTE Item-Instanz, die einer Basis-ID entspricht (z.B. "m16_rifle")
static func find_item_by_base_id(inventory: Array, base_id: String) -> ItemInstance:
	for item in inventory:
		var inst = item as ItemInstance
		if inst and inst.base_item_id == base_id:
			return inst
	return null

## Findet eine spezifische Item-Instanz anhand ihrer einzigartigen ID
static func find_item_by_instance_id(inventory: Array, instance_id: String) -> ItemInstance:
	for item in inventory:
		var inst = item as ItemInstance
		if inst and inst.instance_id == instance_id:
			return inst
	return null

## Findet ALLE Items, die einer Basis-ID entsprechen (z.B. alle Medkits)
static func find_all_items_by_base_id(inventory: Array, base_id: String) -> Array[ItemInstance]:
	var results: Array[ItemInstance] = []
	for item in inventory:
		var inst = item as ItemInstance
		if inst and inst.base_item_id == base_id:
			results.append(inst)
	return results

## Prüft, ob das Inventar mindestens ein Item mit dieser Basis-ID hat
static func has_item(inventory: Array, base_id: String) -> bool:
	return find_item_by_base_id(inventory, base_id) != null

## Findet alle Items eines bestimmten Typs (z.B. "rifle", "ammo", "medical")
static func find_items_by_type(inventory: Array, item_type: String) -> Array[ItemInstance]:
	var results: Array[ItemInstance] = []
	for item in inventory:
		var inst = item as ItemInstance
		# Prüfe, ob es eine Waffe ist
		if inst and inst.base_weapon_data.has("weapon_type"):
			if inst.base_weapon_data["weapon_type"] == item_type:
				results.append(inst)
		# TODO: Armor-Typen und generische Item-Typen hinzufügen (sobald ItemResource existiert)
	return results

# ============================================================================
# INVENTAR-BERECHNUNGEN
# ============================================================================

## Berechnet das Gesamtgewicht eines Inventars
static func get_total_weight(inventory: Array) -> float:
	var total_weight: float = 0.0
	
	# HINWEIS: 'ItemInstance' hat noch kein "Gewicht"-Property.
	# Wir fügen dies hinzu, sobald 'ItemResource.gd' (für generische Items) existiert.
	
	# for item in inventory:
	#    var inst = item as ItemInstance
	#    if inst and inst.effective_stats.has("weight"):
	#        total_weight += inst.effective_stats["weight"]
		
	return total_weight

## Prüft, ob das Inventar voll ist
static func is_inventory_full(inventory: Array, max_slots: int) -> bool:
	return inventory.size() >= max_slots

## Gibt den Füllstand als Prozent (0.0 - 1.0) zurück
static func get_inventory_fill_percent(inventory: Array, max_slots: int) -> float:
	if max_slots == 0:
		return 1.0
	return float(inventory.size()) / float(max_slots)

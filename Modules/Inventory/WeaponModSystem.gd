# res://Modules/Inventory/WeaponModSystem.gd
## PURE CLASS - Keine Godot Node Dependencies!
##
## KORRIGIERT (30.10.2025): .get() / .has() durch direkten Zugriff ersetzt.
## KORRIGIERT (30.10.2025): Logik in 'remove_mod' korrigiert.
## .erase() gibt bool zurück, nicht den gelöschten Wert.

class_name WeaponModSystem

# Importiere die Klassen, die wir als Typen erwarten
const ItemInstance = preload("res://Modules/Tactical/Inventory/ItemInstance.gd")
const AttachmentResource = preload("res://Architecture/Resources/AttachmentResource.gd")

# ============================================================================
# STAT CALCULATION
# ============================================================================

## Das Herzstück: Berechnet die finalen Stats einer Waffe mit allen Mods
static func calculate_final_stats(base_stats: Dictionary, attachments: Dictionary) -> Dictionary:
	
	var final_stats = base_stats.duplicate()
	
	if attachments.is_empty():
		return final_stats

	var accuracy_bonus = 0.0
	var recoil_reduction = 0.0
	var ap_cost_modifier = 1.0
	var sound_reduction = 0.0
	var damage_modifier = 1.0
	var sight_range_bonus = 0.0
	var critical_chance_bonus = 0.0

	for slot_name in attachments:
		var attachment: Resource = attachments[slot_name]
		
		if not (attachment and attachment is AttachmentResource):
			DebugLogger.warn("WeaponModSystem", "Attachment in slot '%s' is invalid" % slot_name)
			continue
			
		var mods: Dictionary = attachment.stat_modifiers

		if mods.has("accuracy_bonus"):
			accuracy_bonus += mods["accuracy_bonus"]
		if mods.has("recoil_reduction"):
			recoil_reduction += mods["recoil_reduction"]
		if mods.has("ap_cost_modifier"):
			ap_cost_modifier *= mods["ap_cost_modifier"]
		if mods.has("sound_reduction"):
			sound_reduction += mods["sound_reduction"]
		if mods.has("damage_modifier"):
			damage_modifier *= mods["damage_modifier"]
		if mods.has("sight_range_bonus"):
			sight_range_bonus += mods["sight_range_bonus"]
		if mods.has("critical_chance_bonus"):
			critical_chance_bonus += mods["critical_chance_bonus"]

	# Wende die akkumulierten Modifikatoren auf die finalen Stats an
	
	final_stats["accuracy"] = (final_stats["accuracy"] if final_stats.has("accuracy") else 0.7) + accuracy_bonus
	
	var base_recoil = final_stats["recoil_base"] if final_stats.has("recoil_base") else 0.0
	final_stats["recoil_final"] = base_recoil * (1.0 - clamp(recoil_reduction, 0.0, 1.0))
	
	final_stats["ap_cost_single"] = int((final_stats["ap_cost_single"] if final_stats.has("ap_cost_single") else 8) * ap_cost_modifier)
	final_stats["ap_cost_burst"] = int((final_stats["ap_cost_burst"] if final_stats.has("ap_cost_burst") else 10) * ap_cost_modifier)
	final_stats["ap_cost_auto"] = int((final_stats["ap_cost_auto"] if final_stats.has("ap_cost_auto") else 15) * ap_cost_modifier)
	final_stats["ap_cost_reload"] = int((final_stats["ap_cost_reload"] if final_stats.has("ap_cost_reload") else 6) * ap_cost_modifier)

	var base_sound = final_stats["sound_radius_base"] if final_stats.has("sound_radius_base") else GameConstants.SOUND_VOLUME_GUNSHOT
	final_stats["sound_radius_final"] = base_sound * (1.0 - clamp(sound_reduction, 0.0, 1.0))

	final_stats["damage_min"] = int((final_stats["damage_min"] if final_stats.has("damage_min") else 10) * damage_modifier)
	final_stats["damage_max"] = int((final_stats["damage_max"] if final_stats.has("damage_max") else 20) * damage_modifier)

	final_stats["sight_range_bonus"] = sight_range_bonus
	final_stats["critical_chance_bonus"] = critical_chance_bonus
	
	final_stats["accuracy"] = clamp(final_stats["accuracy"], 0.01, 1.0)
	final_stats["ap_cost_single"] = maxi(final_stats["ap_cost_single"], 1)
	final_stats["sound_radius_final"] = maxi(final_stats["sound_radius_final"], 0.0)

	var weapon_id_str = final_stats["id"] if final_stats.has("id") else "weapon"
	DebugLogger.log_data("WeaponModSystem", "Final stats calculated for %s" % weapon_id_str, final_stats)
	
	return final_stats

# ============================================================================
# MODIFICATION & VALIDATION
# ============================================================================

static func attach_mod(
	weapon_instance: ItemInstance,
	attachment_resource: AttachmentResource,
	slot: String
) -> bool:
	
	if not (weapon_instance and weapon_instance is ItemInstance):
		DebugLogger.error("WeaponModSystem", "attach_mod: 'weapon_instance' ist keine valide ItemInstance.")
		return false
	
	if not (attachment_resource and attachment_resource is AttachmentResource):
		DebugLogger.error("WeaponModSystem", "attach_mod: 'attachment_resource' ist keine valide AttachmentResource.")
		return false
	
	if not _is_compatible(weapon_instance, attachment_resource, slot):
		DebugLogger.warn("WeaponModSystem", "Attachment '%s' passt nicht in Slot '%s' von Waffe '%s'" % [attachment_resource.id, slot, weapon_instance.base_item_id])
		return false
		
	if weapon_instance.current_attachments.has(slot):
		DebugLogger.warn("WeaponModSystem", "Slot '%s' ist bereits belegt." % slot)
		return false
		
	weapon_instance.current_attachments[slot] = attachment_resource
	DebugLogger.log("WeaponModSystem", "Attachment '%s' an '%s' in Slot '%s' angebracht." % [attachment_resource.id, weapon_instance.base_item_id, slot])
	
	recalculate_stats(weapon_instance)
	return true

## Entfernt einen Mod von einer Waffe
static func remove_mod(weapon_instance: ItemInstance, slot: String) -> AttachmentResource:
	if not (weapon_instance and weapon_instance is ItemInstance):
		DebugLogger.error("WeaponModSystem", "remove_mod: 'weapon_instance' ist keine valide ItemInstance.")
		return null
		
	if not weapon_instance.current_attachments.has(slot):
		DebugLogger.warn("WeaponModSystem", "Slot '%s' ist bereits leer." % slot)
		return null
		
	# KORREKTUR: .erase() gibt bool zurück, nicht den Wert.
	# 1. Hole den Wert
	var removed_attachment: AttachmentResource = weapon_instance.current_attachments[slot]
	# 2. Lösche den Key
	var success: bool = weapon_instance.current_attachments.erase(slot)
	
	if not success:
		# Sollte nie passieren, da wir .has() geprüft haben
		DebugLogger.error("WeaponModSystem", "Konnte Attachment aus Slot '%s' nicht löschen." % slot)
		return null
	
	DebugLogger.log("WeaponModSystem", "Attachment '%s' von Slot '%s' entfernt." % [removed_attachment.id, slot])
	
	recalculate_stats(weapon_instance)
	
	return removed_attachment

## Berechnet die Stats einer ItemInstance neu und speichert sie im Cache
static func recalculate_stats(weapon_instance: ItemInstance) -> void:
	if not (weapon_instance and weapon_instance is ItemInstance):
		DebugLogger.error("WeaponModSystem", "recalculate_stats: 'weapon_instance' ist keine valide ItemInstance.")
		return

	var base_stats = weapon_instance.base_weapon_data
	var attachments = weapon_instance.current_attachments
	
	var final_stats = calculate_final_stats(base_stats, attachments)
	
	weapon_instance.effective_stats = final_stats
	
	DebugLogger.log("WeaponModSystem", "Stats für '%s' neu berechnet." % weapon_instance.base_item_id)


# ============================================================================
# HELPER & VALIDATION
# ============================================================================

static func _is_compatible(
	weapon_instance: ItemInstance,
	attachment_resource: AttachmentResource,
	target_slot: String
) -> bool:
	
	var base_weapon_data: Dictionary = weapon_instance.base_weapon_data
	var weapon_id = base_weapon_data["id"] if base_weapon_data.has("id") else ""

	var compatible_slots = attachment_resource.compatible_slots
	if not target_slot in compatible_slots:
		DebugLogger.warn("WeaponModSystem", "Kompatibilitäts-Check: Slot '%s' nicht in Attachment-Definition '%s' gefunden." % [target_slot, compatible_slots])
		return false
		
	var weapon_slots = base_weapon_data.get("attachment_slots", PackedStringArray())
	if not target_slot in weapon_slots:
		DebugLogger.warn("WeaponModSystem", "Kompatibilitäts-Check: Waffe '%s' hat keinen Slot namens '%s'." % [weapon_id, target_slot])
		return false
		
	var compatible_weapons = attachment_resource.compatible_weapons
	if compatible_weapons.is_empty():
		return true
		
	if not weapon_id in compatible_weapons:
		DebugLogger.warn("WeaponModSystem", "Kompatibilitäts-Check: Waffe '%s' nicht in kompatibler Liste von Attachment '%s' gefunden." % [weapon_id, attachment_resource.id])
		return false

	return true

static func get_weapon_slots(weapon_resource: Resource) -> PackedStringArray:
	if not (weapon_resource and weapon_resource is WeaponResource):
		DebugLogger.error("WeaponModSystem", "get_weapon_slots: Ungültige WeaponResource.")
		return PackedStringArray()
		
	return weapon_resource.attachment_slots

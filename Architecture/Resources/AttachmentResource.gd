# res://Architecture/Resources/AttachmentResource.gd
## Custom Resource für WAFFEN-ATTACHMENTS (Templates)
##
## KORRIGIERT (30.10.2025): Array[String] zu PackedStringArray geändert.

class_name AttachmentResource extends Resource

# ============================================================================
# IDENTIFICATION
# ============================================================================
@export var id: String = "attachment_id"
@export var attachment_name: String = "Attachment"
@export_multiline var description: String = "Attachment-Beschreibung"

# ============================================================================
# STAT MODIFIERS
# ============================================================================
@export_group("Stat Modifiers")
## Dieses Dictionary enthält die eigentliche Magie.
@export var stat_modifiers: Dictionary = {}

# ============================================================================
# KOMPATIBILITÄT
# ============================================================================
@export_group("Compatibility")
## In welche Slots passt dieses Attachment?
@export var compatible_slots: PackedStringArray = []

## Auf welche Waffen-IDs passt dieses Attachment?
## Eine leere Liste bedeutet "Passt auf alle Waffen", die den Slot haben.
@export var compatible_weapons: PackedStringArray = []

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func to_dict() -> Dictionary:
	return {
		"id": id,
		"attachment_name": attachment_name,
		"description": description,
		"stat_modifiers": stat_modifiers.duplicate(),
		"compatible_slots": compatible_slots.duplicate(),
		"compatible_weapons": compatible_weapons.duplicate()
	}

func get_display_info() -> String:
	var info = "%s\n" % attachment_name
	for key in stat_modifiers:
		var value = stat_modifiers[key]
		var value_str = ""
		if value is float:
			if value > 0.0:
				value_str = "+%.0f%%" % (value * 100)
			else:
				value_str = "%.0f%%" % (value * 100)
		else:
			value_str = str(value)
		
		info += "  %s: %s\n" % [key.replace("_", " ").capitalize(), value_str]
	return info

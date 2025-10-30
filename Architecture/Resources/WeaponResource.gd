# res://Architecture/Resources/WeaponResource.gd
## Custom Resource für WAFFEN-DEFINITIONEN (Templates)
##
## Definiert die Basis-Stats einer Waffe, bevor sie im Spiel instanziiert wird.
## Diese Datei wird im Godot-Editor verwendet, um .tres-Dateien zu erstellen
## (z.B. res://Data/Weapons/m16_rifle.tres)
##
## KORRIGIERT (30.10.2025): Array[String] zu PackedStringArray geändert,
## um Zuweisungsfehler in Tests zu beheben.

class_name WeaponResource extends Resource

# ============================================================================
# IDENTIFICATION
# ============================================================================
@export var id: String = "weapon_id"
@export var weapon_name: String = "Waffe"
@export_multiline var description: String = "Waffenbeschreibung"
@export var weapon_type: String = "rifle" # rifle, pistol, smg, shotgun, sniper, lmg

# ============================================================================
# CORE STATS (Basis-Werte)
# ============================================================================
@export_group("Core Stats")
@export_range(1, 200) var damage_min: int = 10
@export_range(1, 200) var damage_max: int = 20
@export_range(0.01, 1.0) var accuracy: float = 0.7 # Basis-Trefferchance
@export_range(0.0, 10.0) var recoil_base: float = 1.0 # Basis-Rückstoß
@export_range(1, 100) var magazine_size: int = 30
@export var ammo_type: String = "standard" # standard, ap, hollow_point

# ============================================================================
# AP COSTS (Aktionspunkte)
# ============================================================================
@export_group("AP Costs")
@export_range(1, 25) var ap_cost_single: int = 8
@export_range(1, 25) var ap_cost_burst: int = 10
@export_range(1, 25) var ap_cost_auto: int = 15
@export_range(1, 25) var ap_cost_reload: int = 6

# ============================================================================
# RANGE & SOUND
# ============================================================================
@export_group("Range & Sound")
@export_range(1.0, 200.0) var effective_range: float = 40.0 # In Kacheln (Tiles)
@export_range(0.0, 100.0) var sound_radius_base: float = GameConstants.SOUND_VOLUME_GUNSHOT

# ============================================================================
# MODDING
# ============================================================================
@export_group("Modding")
## Definiert, welche Slots diese Waffe hat (z.B. "scope", "muzzle", "grip")
# KORREKTUR: Array[String] -> PackedStringArray
@export var attachment_slots: PackedStringArray = []

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Konvertiert die Resource-Daten in ein einfaches Dictionary
## Wird von WeaponModSystem und ItemInstance verwendet
func to_dict() -> Dictionary:
	return {
		"id": id,
		"weapon_name": weapon_name,
		"description": description,
		"weapon_type": weapon_type,
		
		"damage_min": damage_min,
		"damage_max": damage_max,
		"accuracy": accuracy,
		"recoil_base": recoil_base,
		"magazine_size": magazine_size,
		"ammo_type": ammo_type,
		
		"ap_cost_single": ap_cost_single,
		"ap_cost_burst": ap_cost_burst,
		"ap_cost_auto": ap_cost_auto,
		"ap_cost_reload": ap_cost_reload,
		
		"effective_range": effective_range,
		"sound_radius_base": sound_radius_base,
		
		# KORREKTUR: .duplicate() ist sicher
		"attachment_slots": attachment_slots.duplicate()
	}

## Validierungsfunktion (wird vom Editor aufgerufen)
func _validate_property(property: Dictionary) -> void:
	if property.name == "damage_min":
		if property.value > damage_max:
			property.value = damage_max
			push_warning("WeaponResource: 'damage_min' kann nicht größer als 'damage_max' sein.")
			
	if property.name == "damage_max":
		if property.value < damage_min:
			property.value = damage_min
			push_warning("WeaponResource: 'damage_max' kann nicht kleiner als 'damage_min' sein.")

## Gibt eine schnelle Info für UI/Debug zurück
func get_display_info() -> String:
	return "%s [Dmg: %d-%d, AP: %d, Mag: %d]" % [weapon_name, damage_min, damage_max, ap_cost_single, magazine_size]

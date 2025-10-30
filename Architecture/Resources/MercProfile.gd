# res://Architecture/Resources/MercProfile.gd
## Custom Resource für SÖLDNER-PROFILE (Templates)
##
## KORRIGIERT (30.10.2025): Array[String] zu PackedStringArray geändert.

class_name MercProfile extends Resource

# ============================================================================
# IDENTIFICATION
# ============================================================================
@export var id: String = "merc_id"
@export var merc_name: String = "Söldner"
@export var faction: String = "player" # player, enemy, civilian
@export_multiline var bio: String = "Söldner-Biografie"

# ============================================================================
# ATTRIBUTES (0-100)
# ============================================================================
@export_group("Attributes")
@export_range(1, 100) var health: int = 80       # Gesundheit (HP-Basis)
@export_range(1, 100) var agility: int = 70      # Agilität (AP, Bewegung)
@export_range(1, 100) var dexterity: int = 70    # Geschicklichkeit (Handling)
@export_range(1, 100) var strength: int = 60     # Stärke (Traglast, HP)
@export_range(1, 100) var wisdom: int = 70       # Weisheit (Lernen, Sichtweite)
@export_range(1, 100) var leadership: int = 50   # Führung (Moral)

# ============================================================================
# COMBAT SKILLS (0-100)
# ============================================================================
@export_group("Combat Skills")
@export_range(1, 100) var marksmanship: int = 75 # Treffsicherheit
@export_range(1, 100) var medical: int = 20      # Medizin
@export_range(1, 100) var explosives: int = 30   # Sprengstoff
@export_range(1, 100) var mechanical: int = 30   # Mechanik (Reparatur)

# ============================================================================
# STARTING GEAR & APPEARANCE
# ============================================================================
@export_group("Starting Gear")
@export var model_path: String = "res://Assets/Models/merc_placeholder.gltf"
@export var starting_weapon_id: String = "m9_pistol"
@export var starting_armor_id: String = "flak_jacket"
@export var starting_inventory: PackedStringArray = []

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func to_dict() -> Dictionary:
	return {
		"id": id,
		"merc_name": merc_name,
		"faction": faction,
		"bio": bio,
		
		"health": health,
		"agility": agility,
		"dexterity": dexterity,
		"strength": strength,
		"wisdom": wisdom,
		"leadership": leadership,
		
		"marksmanship": marksmanship,
		"medical": medical,
		"explosives": explosives,
		"mechanical": mechanical,
		
		"model_path": model_path,
		"starting_weapon_id": starting_weapon_id,
		"starting_armor_id": starting_armor_id,
		"starting_inventory": starting_inventory.duplicate(),
		
		"calculated_max_hp": calculate_max_hp(),
		"calculated_max_ap": calculate_max_ap(),
		"calculated_sight_range": calculate_sight_range()
	}

# ============================================================================
# CALCULATED STATS
# ============================================================================

func calculate_max_hp() -> int:
	var base_hp = 50.0
	var strength_bonus = float(strength) * 0.5
	return int(base_hp + strength_bonus)

func calculate_max_ap() -> int:
	return APUtility.calculate_max_ap(agility, 1.0, false)

func calculate_sight_range() -> float:
	return VisionUtility.calculate_sight_range(agility, wisdom, 1.0, false)

func get_display_info() -> String:
	return "%s (HP:%d AP:%d Mark:%d Agi:%d)" % [merc_name, calculate_max_hp(), calculate_max_ap(), marksmanship, agility]

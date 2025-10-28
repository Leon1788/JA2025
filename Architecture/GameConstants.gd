# res://Architecture/GameConstants.gd
## Zentrale Konstanten-Sammlung für das gesamte Spiel
## Diese Datei enthält KEINE Logic, nur Werte
## Änderungen hier beeinflussen alle Spielmechaniken

class_name GameConstants

# ============================================================================
# SPIEL-ZUSTAND ENUMS
# ============================================================================

enum GAME_STATE {
	MAIN_MENU,
	LAPTOP,
	STRATEGIC_MAP,
	TACTICAL_COMBAT,
	PAUSED,
	LOADING
}

enum TURN_STATE {
	WAITING,
	PLAYER_TURN,
	ENEMY_TURN,
	NPC_TURN,
	INTERRUPT_CHECK,
	TURN_END_CLEANUP
}

enum STANCE {
	STANDING,
	CROUCHING,
	PRONE
}

enum COVER_TYPE {
	NONE,
	HALF,
	FULL
}

enum DAMAGE_TYPE {
	BALLISTIC,
	EXPLOSIVE,
	MELEE,
	FIRE,
	POISON
}

# ============================================================================
# ACTION POINT (AP) SYSTEM
# ============================================================================

const BASE_AP_PER_TURN: int = 50

## AP-Kosten für Bewegung (pro Kachel)
const AP_MOVE_STANDING: int = 4
const AP_MOVE_CROUCHING: int = 6
const AP_MOVE_PRONE: int = 8

## AP-Kosten für Haltungswechsel
const AP_STANCE_CHANGE: int = 2

## AP-Kosten für Schüsse (Base)
const AP_SHOOT_SINGLE: int = 8
const AP_SHOOT_BURST: int = 10
const AP_SHOOT_FULL_AUTO: int = 15

## AP-Kosten für Lade-Aktion
const AP_RELOAD: int = 6

## AP-Kosten für Inventar-Aktion
const AP_EQUIP_ITEM: int = 3
const AP_USE_MEDICAL_ITEM: int = 4

# ============================================================================
# COMBAT & HIT CHANCE SYSTEM
# ============================================================================

## Basis-Trefferwahrscheinlichkeit (bevor Skills/Modifikatoren)
const BASE_HIT_CHANCE: float = 0.50

## Entfernungs-Penalty pro 5 Kacheln (additiv)
const DISTANCE_PENALTY_PER_TILE: float = 0.02

## Cover-Penalties
const COVER_PENALTY_HALF: float = 0.15
const COVER_PENALTY_FULL: float = 0.30

## Recoil-Effekte (nach jedem Schuss, kumulativ)
const RECOIL_PENALTY_BASE: float = 0.05
const RECOIL_PENALTY_BURST: float = 0.08
const RECOIL_PENALTY_AUTO: float = 0.12

## Haltungs-Modifikatoren für Hit-Chance
const STANCE_BONUS_PRONE: float = 0.15
const STANCE_BONUS_CROUCHING: float = 0.05
const STANCE_PENALTY_STANDING: float = 0.0

## Skill-Effekte (pro Punkt Marksmanship)
const MARKSMANSHIP_ACCURACY_BONUS_PER_POINT: float = 0.003

# Attachment-Boni (werden dazu addiert)
const ATTACHMENT_SCOPE_BONUS: float = 0.15
const ATTACHMENT_LASER_BONUS: float = 0.10

# ============================================================================
# DAMAGE & ARMOR SYSTEM
# ============================================================================

## Rüstungs-Reduktions-Faktor (0.0 = 100% Block, 1.0 = Keine Reduktion)
const ARMOR_DAMAGE_REDUCTION_LIGHT: float = 0.7
const ARMOR_DAMAGE_REDUCTION_MEDIUM: float = 0.5
const ARMOR_DAMAGE_REDUCTION_HEAVY: float = 0.3

## Körpertreffer-Zonen (Multiplikatoren)
const HITZONE_HEAD_MULTIPLIER: float = 1.5
const HITZONE_TORSO_MULTIPLIER: float = 1.0
const HITZONE_LIMBS_MULTIPLIER: float = 0.6
const HITZONE_LEGS_MULTIPLIER: float = 0.5

## Munitions-Penetration
const AMMO_PENETRATION_STANDARD: float = 1.0
const AMMO_PENETRATION_AP: float = 1.5  # Armor Piercing
const AMMO_PENETRATION_HOLLOW_POINT: float = 0.7

## Waffen-Zustand-Effekt (Condition 0-100%)
const WEAPON_CONDITION_MIN: int = 1
const WEAPON_CONDITION_MAX: int = 100
const WEAPON_MISFIRE_THRESHOLD: int = 20  # Unter 20% Condition

# ============================================================================
# VISION SYSTEM (LINE OF SIGHT / FOV)
# ============================================================================

## Basis-Sichtweite (Tiles)
const BASE_SIGHT_RANGE: int = 15

## Attribute-Einfluss auf Sicht (pro Punkt AGI/WIS)
const AGILITY_SIGHT_RANGE_PER_POINT: float = 0.1
const WISDOM_SIGHT_RANGE_PER_POINT: float = 0.15

## Licht-Modifikatoren
const DARKNESS_MODIFIER: float = 0.5
const ARTIFICIAL_LIGHT_BONUS: float = 1.2

## Night Vision Equipment
const NIGHT_VISION_SIGHT_BONUS: float = 0.9

## LOS-Blockage (0.0 = vollständig sichtbar, 1.0 = vollständig blockiert)
const LOS_OBSTACLE_WALL: float = 1.0
const LOS_OBSTACLE_PARTIAL: float = 0.3
const LOS_OBSTACLE_SOFT: float = 0.1

# ============================================================================
# INTERRUPT SYSTEM
# ============================================================================

## Unterbrecher-Schwellenwerte
const INTERRUPT_HP_THRESHOLD: float = 0.30  # <30% HP triggert Interrupt
const INTERRUPT_NOISE_THRESHOLD: float = 0.8  # Lautstärke (0.0-1.0)
const INTERRUPT_VISUAL_CHECK: bool = true  # Sicht auslöst Interrupt

## Interrupt-Reichweite (Tiles)
const INTERRUPT_SOUND_BASE_RADIUS: int = 20

## Silencer reduziert Sound
const SILENCER_SOUND_REDUCTION: float = 0.4

# ============================================================================
# MERC ATTRIBUTES (BASE VALUES)
# ============================================================================

## Min/Max für Attribute
const ATTRIBUTE_MIN: int = 1
const ATTRIBUTE_MAX: int = 100

## Health (HP)
const BASE_HEALTH_MIN: int = 30
const BASE_HEALTH_MAX: int = 100
const HEALTH_PER_STRENGTH: float = 0.5

## Moral
const BASE_MORALE: int = 50
const MORALE_MIN: int = 0
const MORALE_MAX: int = 100

## Fatigue
const BASE_FATIGUE: int = 0
const FATIGUE_ACCUMULATION_PER_TURN: int = 2
const FATIGUE_REDUCTION_PER_REST: int = 5

# ============================================================================
# WEAPON MODDING SYSTEM
# ============================================================================

enum ATTACHMENT_SLOT {
	MUZZLE,
	SCOPE,
	GRIP,
	UNDERBARREL,
	AMMO,
	STOCK
}

## Attachment-Effekte (als Base-Werte)
const ATTACHMENT_SCOPE_ACCURACY: float = 0.15
const ATTACHMENT_SILENCER_SOUND_REDUCTION: float = 0.6
const ATTACHMENT_SILENCER_VELOCITY_REDUCTION: float = 0.98  # 2% Damage Loss
const ATTACHMENT_MUZZLE_BRAKE_RECOIL_REDUCTION: float = 0.3
const ATTACHMENT_GRIP_RECOIL_REDUCTION: float = 0.2

# ============================================================================
# MAP & WORLD
# ============================================================================

## Strategic Map Größe
const STRATEGIC_MAP_WIDTH: int = 16
const STRATEGIC_MAP_HEIGHT: int = 16

## Tactical Map Größe (pro Sektor)
const TACTICAL_MAP_WIDTH: int = 160
const TACTICAL_MAP_HEIGHT: int = 160

## Tile Size (in Godot Units)
const TILE_SIZE: float = 1.0

## Isometric Kamera Winkel
const ISOMETRIC_CAMERA_ANGLE_X: float = deg_to_rad(45.0)
const ISOMETRIC_CAMERA_ANGLE_Y: float = deg_to_rad(45.0)

# ============================================================================
# TIME SYSTEM
# ============================================================================

## Game Time Ticks
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24

## Real-Time zu Game-Time (1 real second = ? game minutes)
## (wird im TimeManager als Variable, nicht konstant, da Spieler es ändern kann)
const TIME_WARP_SPEED_NORMAL: float = 1.0

# ============================================================================
# UI & INPUT
# ============================================================================

## Input-Verzögerung (um mehrfach-Klicks zu verhindern)
const INPUT_DEBOUNCE_TIME: float = 0.1

## UI-Animations-Geschwindigkeit (Sekunden)
const UI_ANIMATION_SPEED: float = 0.3

# ============================================================================
# SOUND SYSTEM
# ============================================================================

## Audio-Volume Ranges (0.0 - 1.0)
const AUDIO_VOLUME_MASTER: float = 1.0
const AUDIO_VOLUME_EFFECTS: float = 0.8
const AUDIO_VOLUME_MUSIC: float = 0.6
const AUDIO_VOLUME_VOICE: float = 0.9

## Sound Event Volumes
const SOUND_VOLUME_GUNSHOT: float = 1.0
const SOUND_VOLUME_GUNSHOT_SILENCED: float = 0.3
const SOUND_VOLUME_FOOTSTEP: float = 0.4
const SOUND_VOLUME_RELOAD: float = 0.5

# ============================================================================
# SAVE/LOAD & PERSISTENCE
# ============================================================================

## Save File Format
const SAVE_FILE_EXTENSION: String = ".json"
const SAVE_FILE_PATH: String = "user://saves/"

## Version für Kompatibilität
const SAVE_FORMAT_VERSION: int = 1

# ============================================================================
# DEBUG & DEVELOPER
# ============================================================================

## Debug-Flags (auf False setzen für Production)
const DEBUG_ENABLED: bool = true
const DEBUG_SHOW_AP_COSTS: bool = true
const DEBUG_SHOW_LOS_LINES: bool = false
const DEBUG_SHOW_HITCHANCE: bool = true
const DEBUG_INFINITE_AP: bool = false

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Gib die Beschreibung eines Stances zurück
static func get_stance_name(stance: STANCE) -> String:
	match stance:
		STANCE.STANDING:
			return "Standing"
		STANCE.CROUCHING:
			return "Crouching"
		STANCE.PRONE:
			return "Prone"
		_:
			return "Unknown"

## Gib AP-Kosten für einen Stance zurück
static func get_ap_cost_for_stance(stance: STANCE) -> int:
	match stance:
		STANCE.STANDING:
			return AP_MOVE_STANDING
		STANCE.CROUCHING:
			return AP_MOVE_CROUCHING
		STANCE.PRONE:
			return AP_MOVE_PRONE
		_:
			return 0

## Clamp Hit Chance zwischen 0.0 und 1.0
static func clamp_hit_chance(value: float) -> float:
	return clamp(value, 0.0, 1.0)

## Clamp Damage zwischen 0 und Max
static func clamp_damage(value: int, max_value: int = 999) -> int:
	return clamp(value, 0, max_value)

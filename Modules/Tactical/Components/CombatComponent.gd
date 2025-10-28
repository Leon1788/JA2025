# res://Modules/Tactical/Components/CombatComponent.gd
## Combat-Komponente - Verwaltet Waffen und Kampflogik
##
## Verantwortlichkeiten:
## - Schießen (Accuracy, Damage Calculation)
## - Waffen Management
## - Reload
## - Ammo Tracking

class_name CombatComponent extends IComponent

# ============================================================================
# PROPERTIES - COMBAT STATE
# ============================================================================

var equipped_weapon: Dictionary = {}  # Current weapon (weapon_id, damage_min, damage_max, etc.)
var current_ammo: int = 0
var max_ammo: int = 30

var shots_fired_this_turn: int = 0
var recoil_penalty: float = 0.0

# ============================================================================
# PROPERTIES - CHARACTER STATS
# ============================================================================

var marksmanship: int = 50  # 0-100

# ============================================================================
# PROPERTIES - WEAPON CONFIG
# ============================================================================

var can_fire: bool = true
var fire_rate_cooldown: float = 0.0

# ============================================================================
# SIGNALS
# ============================================================================

signal shot_fired(shooter: IEntity, target: IEntity, weapon: String, hit: bool)
signal shot_hit(shooter: IEntity, target: IEntity, damage: int, hitzone: int)
signal shot_missed(shooter: IEntity, target: IEntity)
signal weapon_equipped(weapon_name: String)
signal weapon_reloaded(weapon_name: String, ammo: int)
signal out_of_ammo()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	_debug_log("CombatComponent initialized")

func _process(delta: float) -> void:
	if not is_enabled:
		return
	
	# Fire-Rate Cooldown
	if fire_rate_cooldown > 0.0:
		fire_rate_cooldown -= delta
		can_fire = fire_rate_cooldown <= 0.0

# ============================================================================
# MAIN COMBAT INTERFACE
# ============================================================================

## Schieße auf ein Ziel
func shoot(target: MercEntity, weapon_name: String = "") -> bool:
	# Prüfe Preconditions
	if not can_fire:
		_debug_log("Fire rate cooldown active")
		return false
	
	if equipped_weapon.is_empty():
		_report_warning("No weapon equipped!")
		return false
	
	if current_ammo <= 0:
		out_of_ammo.emit()
		_debug_log("Out of ammo!")
		return false
	
	var soldier_state: SoldierState = entity.get_component("SoldierState")
	if soldier_state == null:
		_report_error("SoldierState not found!")
		return false
	
	# Berechne AP-Kosten
	var ap_cost = APUtility.calculate_shot_cost("single")
	if not soldier_state.spend_ap(ap_cost):
		_debug_log("Not enough AP to shoot")
		return false
	
	# Feuere Schuss
	var hit = _resolve_shot(target, soldier_state)
	
	shots_fired_this_turn += 1
	recoil_penalty = CombatUtility.calculate_recoil_penalty(shots_fired_this_turn, "single")
	
	current_ammo -= 1
	can_fire = false
	fire_rate_cooldown = 0.3  # Kurze Verzögerung zwischen Schüssen
	
	shot_fired.emit(entity, target, equipped_weapon.get("name", "Unknown"), hit)
	
	return true

## Führe Schuss-Berechnung durch
func _resolve_shot(target: MercEntity, shooter_state: SoldierState) -> bool:
	# Berechne Trefferwahrscheinlichkeit
	var hit_chance = CombatUtility.calculate_hit_chance(
		marksmanship,
		entity.global_position.distance_to(target.global_position),
		0,  # target_cover (TODO: Implement cover system)
		shooter_state.current_stance,
		target.get_stance(),
		equipped_weapon.get("attachments", {}),
		recoil_penalty,
		shooter_state.get_accuracy_modifier()
	)
	
	_debug_log("Shot: Hit Chance = %.1f%%" % (hit_chance * 100))
	
	# Würfeln
	var shot_hits = randf() < hit_chance
	
	if shot_hits:
		_on_shot_hit(target, shooter_state)
	else:
		_on_shot_missed(target)
	
	return shot_hits

## Verarbeite erfolgreichen Schuss
func _on_shot_hit(target: MercEntity, shooter_state: SoldierState) -> void:
	# Berechne Schaden
	var damage = DamageUtility.calculate_final_damage(
		equipped_weapon.get("damage_min", 10),
		equipped_weapon.get("damage_max", 30),
		equipped_weapon.get("condition", 100),
		target.armor_value,
		target.armor_type,
		randi() % 6,  # random hitzone (0=head, 1=torso, 2-3=arms, 4-5=legs)
		false,  # is_critical (TODO: Implement critical hits)
		equipped_weapon.get("ammo_type", "standard"),
		entity.global_position.distance_to(target.global_position)
	)
	
	target.take_damage(damage)
	shot_hit.emit(entity, target, damage, 1)  # TODO: Pass actual hitzone
	
	_debug_log("Shot HIT: %d damage" % damage)

## Verarbeite verfehlten Schuss
func _on_shot_missed(target: MercEntity) -> void:
	shot_missed.emit(entity, target)
	_debug_log("Shot MISSED")

# ============================================================================
# WEAPON MANAGEMENT
# ============================================================================

## Bestücke eine Waffe
func equip_weapon(weapon_data: Dictionary) -> void:
	equipped_weapon = weapon_data.duplicate()
	current_ammo = weapon_data.get("ammo", weapon_data.get("magazine_size", 30))
	max_ammo = weapon_data.get("magazine_size", 30)
	shots_fired_this_turn = 0
	recoil_penalty = 0.0
	
	weapon_equipped.emit(weapon_data.get("name", "Unknown"))
	_debug_log("Weapon equipped: %s" % weapon_data.get("name", "Unknown"))

## Lade Waffe nach
func reload(weapon_name: String = "") -> bool:
	if equipped_weapon.is_empty():
		_debug_log("No weapon equipped")
		return false
	
	var soldier_state: SoldierState = entity.get_component("SoldierState")
	if soldier_state == null:
		return false
	
	# AP-Kosten
	var ap_cost = GameConstants.AP_RELOAD
	if not soldier_state.spend_ap(ap_cost):
		_debug_log("Not enough AP to reload")
		return false
	
	current_ammo = max_ammo
	shots_fired_this_turn = 0
	recoil_penalty = 0.0
	
	weapon_reloaded.emit(equipped_weapon.get("name", "Unknown"), current_ammo)
	_debug_log("Weapon reloaded: %s" % equipped_weapon.get("name", "Unknown"))
	
	return true

## Gib Ammo-Prozentsatz zurück
func get_ammo_percent() -> float:
	if max_ammo == 0:
		return 0.0
	return float(current_ammo) / float(max_ammo)

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Prüfe ob Ziel treffbar ist
func can_shoot_target(target: MercEntity) -> bool:
	# Prüfe ob genug Ammo
	if current_ammo <= 0:
		return false
	
	var soldier_state: SoldierState = entity.get_component("SoldierState")
	if soldier_state == null:
		return false
	
	# Prüfe ob genug AP
	var ap_cost = APUtility.calculate_shot_cost("single")
	if not soldier_state.can_afford_ap(ap_cost):
		return false
	
	# Prüfe ob in Sichtweite (Vision Component)
	var vision = entity.get_component("VisionComponent")
	if vision and not vision.can_see(target):
		return false
	
	return true

## Berechne Hit-Chance ohne zu schießen
func calculate_hit_chance(target: MercEntity) -> float:
	var soldier_state: SoldierState = entity.get_component("SoldierState")
	if soldier_state == null:
		return 0.0
	
	return CombatUtility.calculate_hit_chance(
		marksmanship,
		entity.global_position.distance_to(target.global_position),
		0,  # target_cover
		soldier_state.current_stance,
		target.get_stance(),
		equipped_weapon.get("attachments", {}),
		recoil_penalty,
		soldier_state.get_accuracy_modifier()
	)

## Berechne erwarteten Schaden ohne zu schießen
func calculate_expected_damage(target: MercEntity) -> int:
	var damage_min = equipped_weapon.get("damage_min", 10)
	var damage_max = equipped_weapon.get("damage_max", 30)
	var avg_damage = (damage_min + damage_max) / 2
	
	# Anwende Armor
	var final_damage = DamageUtility.calculate_armor_reduction(
		avg_damage,
		target.armor_value,
		target.armor_type
	)
	
	return final_damage

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

## Setze Schuss-Zähler zurück (neuer Turn)
func reset_turn_state() -> void:
	shots_fired_this_turn = 0
	recoil_penalty = 0.0
	_debug_log("Turn state reset")

# ============================================================================
# COMPONENT INTERFACE
# ============================================================================

func on_enable() -> void:
	super.on_enable()
	_debug_log("CombatComponent enabled")

func on_disable() -> void:
	super.on_disable()
	_debug_log("CombatComponent disabled")

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> String:
	var info = "CombatComponent:\n"
	info += "  Weapon: %s\n" % equipped_weapon.get("name", "None")
	info += "  Ammo: %d/%d\n" % [current_ammo, max_ammo]
	info += "  Marksmanship: %d\n" % marksmanship
	info += "  Recoil Penalty: %.2f\n" % recoil_penalty
	info += "  Can Fire: %s" % can_fire
	return info

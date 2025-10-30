# res://Modules/Tactical/Components/CombatComponent.gd
## Combat-Komponente - Verwaltet Waffen und Kampflogik
##
## REFAKTORIERT (30.10.2025) für Packet 3:
## - Verwendet 'ItemInstance' statt eines rohen 'Dictionary' für die Waffe.
## - 'equip_weapon' umbenannt in 'equip_weapon_instance'.
## - 'unequip_weapon' hinzugefügt.
## - 'shoot' und 'reload' nutzen jetzt die ItemInstance und ihre 'effective_stats'.

class_name CombatComponent extends IComponent

# Importiere die Klassen, die wir benötigen
const ItemInstance = preload("res://Modules/Tactical/Inventory/ItemInstance.gd")
const SoldierState = preload("res://Modules/Tactical/Components/SoldierState.gd")

# ============================================================================
# PROPERTIES - COMBAT STATE
# ============================================================================

## Hält die 'ItemInstance' der Waffe, die aktiv in der Hand gehalten wird.
var equipped_weapon_instance: ItemInstance = null

## DEPRECATED (wird nicht mehr verwendet, aber zur Referenz behalten)
# var equipped_weapon: Dictionary = {}
# var current_ammo: int = 0
# var max_ammo: int = 30

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
signal weapon_unequipped() # NEU
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
	
	# REFAKTORIERT: Prüft ItemInstance statt Dictionary
	if equipped_weapon_instance == null:
		_report_warning("No weapon equipped!")
		return false
	
	# REFAKTORIERT: Prüft Munition auf der ItemInstance
	if equipped_weapon_instance.current_ammo <= 0:
		out_of_ammo.emit()
		_debug_log("Out of ammo!")
		return false
	
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		_report_error("SoldierState not found!")
		return false
	
	# REFAKTORIERT: Nutzt 'effective_stats' der Waffe für AP-Kosten
	var weapon_stats = equipped_weapon_instance.get_effective_stats()
	var ap_cost = weapon_stats.get("ap_cost_single", GameConstants.AP_SHOOT_SINGLE)
	
	if not soldier_state.spend_ap(ap_cost):
		_debug_log("Not enough AP to shoot")
		return false
	
	# Feuere Schuss
	var hit = _resolve_shot(target, soldier_state)
	
	shots_fired_this_turn += 1
	recoil_penalty = CombatUtility.calculate_recoil_penalty(shots_fired_this_turn, "single")
	
	# REFAKTORIERT: Reduziert Munition auf der ItemInstance
	equipped_weapon_instance.fire_shot()
	
	can_fire = false
	fire_rate_cooldown = 0.3  # Kurze Verzögerung zwischen Schüssen
	
	shot_fired.emit(entity, target, weapon_stats.get("weapon_name", "Unknown"), hit)
	
	return true

## Führe Schuss-Berechnung durch
func _resolve_shot(target: MercEntity, shooter_state: SoldierState) -> bool:
	if equipped_weapon_instance == null:
		return false

	# REFAKTORIERT: Nutzt 'effective_stats'
	var weapon_stats = equipped_weapon_instance.get_effective_stats()

	# Berechne Trefferwahrscheinlichkeit
	var hit_chance = CombatUtility.calculate_hit_chance(
		marksmanship,
		entity.global_position.distance_to(target.global_position),
		0,  # target_cover (TODO: Implement cover system)
		shooter_state.current_stance,
		target.get_stance(),
		weapon_stats, # Attachments sind bereits in effective_stats eingerechnet
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
	if equipped_weapon_instance == null:
		return

	# REFAKTORIERT: Nutzt 'effective_stats'
	var weapon_stats = equipped_weapon_instance.get_effective_stats()
	var target_state = target.get_component("SoldierState") as SoldierState
	
	if not target_state:
		_report_error("Ziel '%s' hat keinen SoldierState!" % target.name)
		return

	# Berechne Schaden
	var damage = DamageUtility.calculate_final_damage(
		weapon_stats.get("damage_min", 10),
		weapon_stats.get("damage_max", 30),
		equipped_weapon_instance.condition, # Nutze Echtzeit-Zustand
		target_state.armor_value, # Nutze Echtzeit-Rüstung des Ziels
		target_state.armor_type,
		randi() % 6,  # random hitzone (0=head, 1=torso, 2-3=arms, 4-5=legs)
		false,  # is_critical (TODO: Implement critical hits)
		weapon_stats.get("ammo_type", "standard"),
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

## NEU: Bestückt die Komponente mit einer ItemInstance
## (Ersetzt die alte 'equip_weapon'-Funktion)
func equip_weapon_instance(instance: ItemInstance) -> void:
	if instance == null:
		_report_warning("equip_weapon_instance: Ungültige ItemInstance übergeben.")
		unequip_weapon()
		return
		
	equipped_weapon_instance = instance
	
	# Setze Turn-spezifische Kampf-Stats zurück
	shots_fired_this_turn = 0
	recoil_penalty = 0.0
	
	var weapon_name = instance.get_effective_stats().get("weapon_name", "Unknown")
	weapon_equipped.emit(weapon_name)
	_debug_log("Weapon equipped: %s" % weapon_name)

## NEU: Entfernt die Waffe
func unequip_weapon() -> void:
	if equipped_weapon_instance == null:
		return # Nichts zu tun
		
	_debug_log("Weapon unequipped: %s" % equipped_weapon_instance.get_effective_stats().get("weapon_name", "Unknown"))
	equipped_weapon_instance = null
	weapon_unequipped.emit()

## Lade Waffe nach
func reload(weapon_name: String = "") -> bool:
	# REFAKTORIERT: Prüft ItemInstance
	if equipped_weapon_instance == null:
		_debug_log("No weapon equipped")
		return false
	
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return false
	
	# REFAKTORIERT: Nutzt 'effective_stats'
	var weapon_stats = equipped_weapon_instance.get_effective_stats()
	var ap_cost = weapon_stats.get("ap_cost_reload", GameConstants.AP_RELOAD)
	
	if not soldier_state.spend_ap(ap_cost):
		_debug_log("Not enough AP to reload")
		return false
	
	# REFAKTORIERT: Ruft Methode auf ItemInstance auf
	equipped_weapon_instance.reload()
	
	shots_fired_this_turn = 0
	recoil_penalty = 0.0
	
	weapon_reloaded.emit(weapon_stats.get("weapon_name", "Unknown"), equipped_weapon_instance.current_ammo)
	_debug_log("Weapon reloaded: %s" % weapon_stats.get("weapon_name", "Unknown"))
	
	return true

## Gib Ammo-Prozentsatz zurück
func get_ammo_percent() -> float:
	if equipped_weapon_instance == null:
		return 0.0
	return equipped_weapon_instance.get_ammo_percent()

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Prüfe ob Ziel treffbar ist
func can_shoot_target(target: MercEntity) -> bool:
	if equipped_weapon_instance == null:
		return false
		
	# Prüfe ob genug Ammo
	if equipped_weapon_instance.current_ammo <= 0:
		return false
	
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null:
		return false
	
	# Prüfe ob genug AP
	var weapon_stats = equipped_weapon_instance.get_effective_stats()
	var ap_cost = weapon_stats.get("ap_cost_single", GameConstants.AP_SHOOT_SINGLE)
	
	if not soldier_state.can_afford_ap(ap_cost):
		return false
	
	# Prüfe ob in Sichtweite (Vision Component)
	var vision = entity.get_component("VisionComponent")
	if vision and not (vision as VisionComponent).can_see(target):
		return false
	
	return true

## Berechne Hit-Chance ohne zu schießen
func calculate_hit_chance(target: MercEntity) -> float:
	var soldier_state: SoldierState = entity.get_component("SoldierState") as SoldierState
	if soldier_state == null or equipped_weapon_instance == null:
		return 0.0
	
	var weapon_stats = equipped_weapon_instance.get_effective_stats()
	var target_state = target.get_component("SoldierState") as SoldierState
	if not target_state:
		return 0.0

	return CombatUtility.calculate_hit_chance(
		marksmanship,
		entity.global_position.distance_to(target.global_position),
		0,  # target_cover (TODO)
		soldier_state.current_stance,
		target_state.get_stance(),
		weapon_stats, # Attachments sind bereits eingerechnet
		recoil_penalty,
		soldier_state.get_accuracy_modifier()
	)

## Berechne erwarteten Schaden ohne zu schießen
func calculate_expected_damage(target: MercEntity) -> int:
	if equipped_weapon_instance == null:
		return 0
		
	var weapon_stats = equipped_weapon_instance.get_effective_stats()
	var target_state = target.get_component("SoldierState") as SoldierState
	if not target_state:
		return 0

	var damage_min = weapon_stats.get("damage_min", 10)
	var damage_max = weapon_stats.get("damage_max", 30)
	var avg_damage = (damage_min + damage_max) / 2
	
	# Anwende Armor
	var final_damage = DamageUtility.calculate_armor_reduction(
		avg_damage,
		target_state.armor_value,
		target_state.armor_type
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
	if equipped_weapon_instance:
		var stats = equipped_weapon_instance.get_effective_stats()
		info += "  Weapon: %s\n" % stats.get("weapon_name", "None")
		info += "  Ammo: %d/%d\n" % [equipped_weapon_instance.current_ammo, stats.get("magazine_size", 0)]
	else:
		info += "  Weapon: None\n"
		info += "  Ammo: 0/0\n"
		
	info += "  Marksmanship: %d\n" % marksmanship
	info += "  Recoil Penalty: %.2f\n" % recoil_penalty
	info += "  Can Fire: %s" % can_fire
	return info

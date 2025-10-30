# res://Modules/Tactical/Components/SoldierState.gd
## Zentrale State-Komponente für jeden Merc
## 
## Speichert und verwaltet:
## - Health (HP)
## - Action Points (AP)
## - Stance (Standing, Crouching, Prone)
## - Status Effects (Bleeding, Wounded, etc.)
## - Faction (Player, Enemy, Civilian)
##
## Emittiert Signals bei Änderungen für UI/Systems
##
## HINZUGEFÜGT (30.10.2025): set_armor() Funktion für Packet 3 Refactoring.

class_name SoldierState extends IComponent

# ============================================================================
# PROPERTIES - HEALTH
# ============================================================================

var max_hp: int = 100
var current_hp: int = 100

var armor_value: int = 0
var armor_type: String = "medium"  # light, medium, heavy

var is_wounded: bool = false
var bleeding_intensity: float = 0.0  # 0.0 - 1.0

# ============================================================================
# PROPERTIES - ACTION POINTS
# ============================================================================

var max_ap: int = 50
var current_ap: int = 50

var last_action_ap_cost: int = 0

# ============================================================================
# PROPERTIES - STANCE & POSITION
# ============================================================================

var current_stance: int = GameConstants.STANCE.STANDING
var can_change_stance: bool = true

# ============================================================================
# PROPERTIES - FACTION & TEAM
# ============================================================================

var faction: String = "player"  # player, enemy, civilian
var team_id: String = ""  # z.B. "squad_01"

# ============================================================================
# PROPERTIES - STATUS EFFECTS
# ============================================================================

var status_effects: Dictionary = {}  # key = effect_name, value = { duration, intensity }
var morale: int = 50  # 0-100 (0=panicked, 100=brave)
var fatigue: int = 0  # 0-100 (0=fresh, 100=exhausted)

# ============================================================================
# SIGNALS
# ============================================================================

signal hp_changed(current: int, max: int)
signal ap_changed(current: int, max: int)
signal stance_changed(new_stance: int)
signal wounded(wound_type: String)
signal died()
signal status_effect_added(effect_name: String, duration: float)
signal status_effect_removed(effect_name: String)
signal morale_changed(new_morale: int)
signal fatigue_changed(new_fatigue: int)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	super._ready()
	_initialize_state()
	_debug_log("SoldierState initialized: HP=%d/AP=%d" % [current_hp, current_ap])

func _process(delta: float) -> void:
	if not is_enabled:
		return
	_update_status_effects(delta)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _initialize_state() -> void:
	# Reset zu Defaults (wird später mit Merc-Daten überschrieben)
	current_hp = max_hp
	current_ap = max_ap
	current_stance = GameConstants.STANCE.STANDING
	is_wounded = false
	bleeding_intensity = 0.0
	morale = 50
	fatigue = 0
	status_effects.clear()

# ============================================================================
# HEALTH & DAMAGE
# ============================================================================

## NEUE FUNKTION: Wird vom InventoryComponent aufgerufen
func set_armor(new_armor_value: int, new_armor_type: String) -> void:
	if armor_value != new_armor_value or armor_type != new_armor_type:
		armor_value = new_armor_value
		armor_type = new_armor_type
		_debug_log("Armor updated: %d (%s)" % [armor_value, armor_type])
		
		# TODO: armor_value und armor_type an MercEntity weitergeben,
		# damit take_damage() sie nutzen kann, falls die Berechnung dort stattfindet.
		# Aktuell scheint MercEntity die Werte von SoldierState zu lesen,
		# aber DamageUtility braucht sie. Sicherstellen, dass die Daten fließen.
		# Fürs Erste speichern wir sie hier.
		
		# Ah, MercEntity.take_damage ruft soldier_state.apply_damage auf.
		# Aber MercEntity.shoot ruft target.take_damage auf.
		# Die Rüstungswerte müssen auf der MercEntity ODER hier sein.
		# Wir behalten sie HIER, da dies der "State" ist.
		# CombatUtility/DamageUtility müssen diese Werte vom Ziel-SoldierState abfragen.
		
		# Anpassung: MercEntity.gd muss die Rüstungswerte hierher kopieren
		# oder (besser) SoldierState ist die Quelle der Wahrheit.
		# Wir entscheiden: SoldierState ist die Quelle der Wahrheit.
		if entity:
			(entity as MercEntity).armor_value = new_armor_value
			(entity as MercEntity).armor_type = new_armor_type


## Nimm Schaden
func apply_damage(damage_amount: int, hitzone: int = 1) -> void:
	if damage_amount <= 0:
		return
	
	current_hp -= damage_amount
	hp_changed.emit(current_hp, max_hp)
	
	_debug_log("Damage: -%d HP (now %d/%d)" % [damage_amount, current_hp, max_hp])
	
	# Prüfe auf Blutung
	if DamageUtility.should_cause_bleeding(damage_amount, hitzone, float(armor_value)):
		add_status_effect("bleeding", 30.0)  # 30 Sekunden bluten
	
	# Prüfe auf kritisch
	if current_hp <= 0:
		die()
	elif current_hp < max_hp * 0.3:
		add_status_effect("critical_hp", 0.0)  # Kein Timeout, bleibt bis geheilt

## Heile den Merc
func apply_healing(heal_amount: int) -> void:
	if heal_amount <= 0:
		return
	
	var old_hp = current_hp
	current_hp = mini(current_hp + heal_amount, max_hp)
	
	hp_changed.emit(current_hp, max_hp)
	_debug_log("Healing: +%d HP (was %d, now %d)" % [heal_amount, old_hp, current_hp])
	
	# Entferne bleeding wenn genug geheilt
	if current_hp > max_hp * 0.5:
		remove_status_effect("bleeding")

## Merc stirbt
func die() -> void:
	current_hp = 0
	hp_changed.emit(current_hp, max_hp)
	died.emit()
	_debug_log("Unit died!")
	
	# Deaktiviere Entity
	if entity:
		entity.deactivate()

# ============================================================================
# ACTION POINTS
# ============================================================================

## Gebe AP aus
func spend_ap(amount: int) -> bool:
	if amount < 0:
		_report_warning("AP amount must be >= 0, got %d" % amount)
		return false
	
	if current_ap < amount:
		_debug_log("Not enough AP! Need %d, have %d" % [amount, current_ap])
		return false
	
	current_ap -= amount
	last_action_ap_cost = amount
	ap_changed.emit(current_ap, max_ap)
	
	_debug_log("AP spent: -%d (now %d/%d)" % [amount, current_ap, max_ap])
	return true

## Stelle AP wieder her
func restore_ap(amount: int) -> void:
	if amount <= 0:
		return
	
	var old_ap = current_ap
	current_ap = mini(current_ap + amount, max_ap)
	ap_changed.emit(current_ap, max_ap)
	
	_debug_log("AP restored: +%d (was %d, now %d)" % [amount, old_ap, current_ap])

## Setze AP auf Maximum (neuer Turn)
func reset_ap_to_max() -> void:
	current_ap = max_ap
	ap_changed.emit(current_ap, max_ap)
	_debug_log("AP reset to max: %d" % max_ap)

## Berechne Max-AP basierend auf Attributen (wird vom Merc-Profil aufgerufen)
func calculate_max_ap(agility: int, is_wounded: bool = false) -> int:
	var calculated_max = APUtility.calculate_max_ap(agility, 1.0, is_wounded)
	max_ap = calculated_max
	current_ap = max_ap
	ap_changed.emit(current_ap, max_ap)
	return max_ap

## Prüfe ob genug AP für Aktion
func can_afford_ap(amount: int) -> bool:
	return current_ap >= amount

# ============================================================================
# STANCE SYSTEM
# ============================================================================

## Wechsle Haltung
func change_stance(new_stance: int) -> bool:
	if not can_change_stance:
		_debug_log("Cannot change stance right now")
		return false
	
	if new_stance == current_stance:
		return true  # Schon in dieser Haltung
	
	# AP-Kosten für Haltungswechsel
	var ap_cost = GameConstants.AP_STANCE_CHANGE
	if not spend_ap(ap_cost):
		_debug_log("Not enough AP to change stance")
		return false
	
	current_stance = new_stance
	stance_changed.emit(new_stance)
	
	_debug_log("Stance changed to: %s" % GameConstants.get_stance_name(new_stance))
	return true

## Gib aktuellen Stance zurück
func get_stance() -> int:
	return current_stance

## Prüfe ob in spezifischer Haltung
func is_in_stance(stance: int) -> bool:
	return current_stance == stance

# ============================================================================
# STATUS EFFECTS
# ============================================================================

## Füge Status-Effekt hinzu
func add_status_effect(effect_name: String, duration: float = 0.0) -> void:
	if effect_name in status_effects:
		return  # Schon aktiv
	
	status_effects[effect_name] = {
		"duration": duration,
		"remaining": duration,
		"intensity": 1.0
	}
	
	status_effect_added.emit(effect_name, duration)
	_debug_log("Status effect added: %s (duration: %.1f)" % [effect_name, duration])

## Entferne Status-Effekt
func remove_status_effect(effect_name: String) -> void:
	if effect_name not in status_effects:
		return
	
	status_effects.erase(effect_name)
	status_effect_removed.emit(effect_name)
	_debug_log("Status effect removed: %s" % effect_name)

## Prüfe ob Effekt aktiv
func has_status_effect(effect_name: String) -> bool:
	return effect_name in status_effects

## Update Status-Effekte (wird in _process aufgerufen)
func _update_status_effects(delta: float) -> void:
	var effects_to_remove = []
	
	for effect_name in status_effects.keys():
		var effect = status_effects[effect_name]
		
		# Skippe permanente Effekte (duration = 0)
		if effect["duration"] <= 0:
			continue
		
		effect["remaining"] -= delta
		
		if effect["remaining"] <= 0:
			effects_to_remove.append(effect_name)
	
	# Entferne abgelaufene Effekte
	for effect_name in effects_to_remove:
		remove_status_effect(effect_name)

# ============================================================================
# MORALE & FATIGUE
# ============================================================================

## Setze Moral
func set_morale(new_morale: int) -> void:
	morale = clampi(new_morale, 0, 100)
	morale_changed.emit(morale)

## Ändere Moral (relativ)
func modify_morale(amount: int) -> void:
	set_morale(morale + amount)

## Setze Ermüdung
func set_fatigue(new_fatigue: int) -> void:
	fatigue = clampi(new_fatigue, 0, 100)
	fatigue_changed.emit(fatigue)

## Erhöhe Ermüdung (bei Aktion)
func add_fatigue(amount: int) -> void:
	set_fatigue(fatigue + amount)

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

## Ist dieser Merc noch aktiv?
func is_alive() -> bool:
	return current_hp > 0

## Ist kritisch verwundet?
func is_critical() -> bool:
	return current_hp < max_hp * 0.3

## Prüfe Gesamt-Accuracy-Modifikator (kombiniert Fatigue + Morale)
func get_accuracy_modifier() -> float:
	var fatigue_mod = CombatUtility.calculate_fatigue_accuracy_modifier(fatigue)
	var morale_mod = CombatUtility.calculate_morale_accuracy_modifier(morale)
	return fatigue_mod * morale_mod

## Gib Health-Prozentsatz zurück (0.0 - 1.0)
func get_health_percent() -> float:
	if max_hp == 0:
		return 0.0
	return float(current_hp) / float(max_hp)

## Gib AP-Prozentsatz zurück (0.0 - 1.0)
func get_ap_percent() -> float:
	if max_ap == 0:
		return 0.0
	return float(current_ap) / float(max_ap)

# ============================================================================
# DEBUG & SERIALIZATION
# ============================================================================

## Gib Debug-Info aus
func get_debug_info() -> String:
	var info = "SoldierState:\n"
	info += "  HP: %d/%d\n" % [current_hp, max_hp]
	info += "  AP: %d/%d\n" % [current_ap, max_ap]
	# HINZUGEFÜGT: Zeigt die Rüstungswerte an
	info += "  Armor: %d (%s)\n" % [armor_value, armor_type]
	info += "  Stance: %s\n" % GameConstants.get_stance_name(current_stance)
	info += "  Faction: %s\n" % faction
	info += "  Effects: %d active\n" % status_effects.size()
	info += "  Morale: %d\n" % morale
	info += "  Fatigue: %d" % fatigue
	return info

## Serialisiere für Save-System
func to_dict() -> Dictionary:
	return {
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_ap": current_ap,
		"max_ap": max_ap,
		"stance": current_stance,
		"faction": faction,
		"morale": morale,
		"fatigue": fatigue,
		"status_effects": status_effects,
		"armor_value": armor_value,
		"armor_type": armor_type
	}

## Deserialisiere von Save-System
func from_dict(data: Dictionary) -> void:
	current_hp = data.get("current_hp", max_hp)
	max_hp = data.get("max_hp", 100)
	current_ap = data.get("current_ap", max_ap)
	max_ap = data.get("max_ap", 50)
	current_stance = data.get("stance", GameConstants.STANCE.STANDING)
	faction = data.get("faction", "player")
	morale = data.get("morale", 50)
	fatigue = data.get("fatigue", 0)
	armor_value = data.get("armor_value", 0)
	armor_type = data.get("armor_type", "medium")
	
	# Status Effects rekonstruieren
	status_effects.clear()
	var effects_data = data.get("status_effects", {})
	for effect_name in effects_data.keys():
		status_effects[effect_name] = effects_data[effect_name]

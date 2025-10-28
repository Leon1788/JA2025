# res://Architecture/EventBus.gd
## Zentrale Signal-Verteilung für das gesamte Spiel
## 
## WICHTIG: Das ist KEIN AutoLoad! 
## Es wird von jeder Szene als lokale Instanz erstellt
## z.B. TacticalScene erstellt ihren eigenen EventBus
##
## Dadurch bleiben Module voneinander entkoppelt
## Jede Szene/Modul kann unabhängig ihre Signals verwalten

class_name EventBus extends Node

# ============================================================================
# SPIEL-LEVEL SIGNALS
# ============================================================================

## Emittiert wenn Game State sich ändert (Menu → Combat, etc.)
signal game_state_changed(new_state: int)

## Emittiert wenn Spiel pausiert/unpausiert wird
signal game_paused(is_paused: bool)

## Emittiert wenn neues Game startet
signal game_started()

## Emittiert wenn Game endet
signal game_ended()

# ============================================================================
# ZEIT-SIGNALS
# ============================================================================

## Emittiert jede Minute Spielzeit
signal time_minute_tick(day: int, hour: int, minute: int)

## Emittiert jede Stunde Spielzeit
signal time_hour_tick(day: int, hour: int)

## Emittiert jeden Tag Spielzeit
signal time_day_tick(day: int)

# ============================================================================
# TAKTISCHER KAMPF - ALLGEMEIN
# ============================================================================

## Emittiert wenn Kampf startet
signal combat_started(combat_data: Dictionary)

## Emittiert wenn Kampf endet
signal combat_ended(victory: bool)

## Emittiert wenn eine Runde startet
signal turn_started(turn_state: int, actor: IEntity)

## Emittiert wenn eine Runde endet
signal turn_ended()

## Emittiert wenn Initiative bestimmt wird
signal initiative_calculated()

# ============================================================================
# TAKTISCHER KAMPF - ENTITY EVENTS
# ============================================================================

## Emittiert wenn Entity sich bewegt
signal entity_moved(entity: IEntity, old_position: Vector3, new_position: Vector3)

## Emittiert wenn Entity Aktion ausführt (schießt, lädt, etc.)
signal entity_action(entity: IEntity, action_name: String, success: bool)

## Emittiert wenn Entity Schaden nimmt
signal entity_took_damage(entity: IEntity, damage_amount: int, remaining_hp: int)

## Emittiert wenn Entity stirbt
signal entity_died(entity: IEntity)

## Emittiert wenn Entity Wunden bekommt
signal entity_wounded(entity: IEntity, wound_type: String)

## Emittiert wenn Entity heilt wird
signal entity_healed(entity: IEntity, heal_amount: int)

# ============================================================================
# TAKTISCHER KAMPF - COMBAT EVENTS
# ============================================================================

## Emittiert wenn eine Schießaktion passiert
signal shot_fired(shooter: IEntity, target: IEntity, weapon_name: String)

## Emittiert wenn ein Schuss trifft
signal shot_hit(shooter: IEntity, target: IEntity, damage: int, hit_zone: String)

## Emittiert wenn ein Schuss verfehlt
signal shot_missed(shooter: IEntity, target: IEntity, reason: String)

## Emittiert wenn eine Waffe nachgeladen wird
signal weapon_reloaded(entity: IEntity, weapon_name: String)

# ============================================================================
# TAKTISCHER KAMPF - AP & RESOURCE EVENTS
# ============================================================================

## Emittiert wenn AP ausgegeben werden
signal ap_spent(entity: IEntity, amount: int, remaining_ap: int)

## Emittiert wenn AP wiederhergestellt werden (z.B. neuer Turn)
signal ap_restored(entity: IEntity, amount: int)

## Emittiert wenn Haltung sich ändert
signal stance_changed(entity: IEntity, new_stance: int)

# ============================================================================
# TAKTISCHER KAMPF - INTERRUPT SYSTEM
# ============================================================================

## Emittiert wenn Interrupt geprüft wird
signal interrupt_check(actor: IEntity, trigger_type: String)

## Emittiert wenn Interrupt aktiviert wird
signal interrupt_triggered(actor: IEntity, interrupter: IEntity)

# ============================================================================
# TAKTISCHER KAMPF - VISION & INTELLIGENCE
# ============================================================================

## Emittiert wenn Entity entdeckt wird
signal entity_spotted(entity: IEntity, spotter: IEntity)

## Emittiert wenn Entity nicht mehr sichtbar ist
signal entity_lost_sight(entity: IEntity, lost_by: IEntity)

## Emittiert wenn Geräusch gemacht wird (für KI)
signal sound_event(position: Vector3, volume: float, source: IEntity)

# ============================================================================
# INVENTAR & EQUIPMENT
# ============================================================================

## Emittiert wenn Item ausgerüstet wird
signal item_equipped(entity: IEntity, item_name: String, slot: String)

## Emittiert wenn Item unausgerüstet wird
signal item_unequipped(entity: IEntity, item_name: String)

## Emittiert wenn Attachment an Waffe angebracht wird
signal attachment_added(entity: IEntity, weapon_name: String, attachment_name: String)

## Emittiert wenn Attachment von Waffe entfernt wird
signal attachment_removed(entity: IEntity, weapon_name: String, attachment_name: String)

# ============================================================================
# UI EVENTS
# ============================================================================

## Emittiert wenn ein Unit ausgewählt wird
signal unit_selected(entity: IEntity)

## Emittiert wenn Unit deselected wird
signal unit_deselected(entity: IEntity)

## Emittiert wenn Action-Menu geöffnet wird
signal action_menu_opened(entity: IEntity, position: Vector3)

## Emittiert wenn Action-Menu geschlossen wird
signal action_menu_closed()

## Emittiert wenn Spieler auf Tile klickt
signal tile_clicked(tile_pos: Vector3, click_data: Dictionary)

# ============================================================================
# STRATEGISCHES LEVEL
# ============================================================================

## Emittiert wenn Sektor erobert wird
signal sector_captured(sector_id: String, owner: String)

## Emittiert wenn Trupp sich bewegt
signal squad_movement_started(squad_id: String, target_sector: String)

## Emittiert wenn Trupp ankommt
signal squad_arrived(squad_id: String, sector_id: String)

## Emittiert wenn Loyalität sich ändert
signal loyalty_changed(town_id: String, new_loyalty: int)

## Emittiert wenn Einkommen erhalten wird
signal income_received(amount: int, source: String)

# ============================================================================
# ERROR EVENTS
# ============================================================================

## Emittiert wenn kritischer Fehler auftritt
signal critical_error(error_message: String)

## Emittiert wenn Warning auftritt
signal warning_occurred(warning_message: String)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Debug-Helper: Gib alle Signal-Namen aus
func debug_print_all_signals() -> void:
	if not GameConstants.DEBUG_ENABLED:
		return
	
	print("[EventBus] Available signals:")
	print("  Game Level: game_state_changed, game_paused, game_started, game_ended")
	print("  Time: time_minute_tick, time_hour_tick, time_day_tick")
	print("  Combat: combat_started, combat_ended, turn_started, turn_ended")
	print("  Entity: entity_moved, entity_action, entity_took_damage, entity_died")
	print("  Combat: shot_fired, shot_hit, shot_missed, weapon_reloaded")
	print("  AP: ap_spent, ap_restored, stance_changed")
	print("  Interrupt: interrupt_check, interrupt_triggered")
	print("  Vision: entity_spotted, entity_lost_sight, sound_event")
	print("  Inventory: item_equipped, item_unequipped, attachment_added, attachment_removed")
	print("  UI: unit_selected, unit_deselected, action_menu_opened, action_menu_closed, tile_clicked")
	print("  Strategic: sector_captured, squad_movement_started, squad_arrived, loyalty_changed, income_received")
	print("  Errors: critical_error, warning_occurred")

## Emission-Helfer für HitZones
static func get_hitzone_name(hitzone: int) -> String:
	match hitzone:
		0:
			return "HEAD"
		1:
			return "TORSO"
		2:
			return "LEFT_ARM"
		3:
			return "RIGHT_ARM"
		4:
			return "LEFT_LEG"
		5:
			return "RIGHT_LEG"
		_:
			return "UNKNOWN"

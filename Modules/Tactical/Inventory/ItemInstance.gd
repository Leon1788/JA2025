# res://Modules/Tactical/Inventory/ItemInstance.gd
## Custom Resource für eine ITEM-INSTANZ (Runtime)
##
## KORRIGIERT (30.10.2025): 'ItemInstance.new()' -> 'new()'
## KORRIGIERT (30.10.2025): .get() / .has() durch direkten Zugriff ersetzt.

class_name ItemInstance extends Resource

# Importiere die Klassen, die wir als Typen erwarten
const WeaponResource = preload("res://Architecture/Resources/WeaponResource.gd")
const AttachmentResource = preload("res://Architecture/Resources/AttachmentResource.gd")
const WeaponModSystem = preload("res://Modules/Inventory/WeaponModSystem.gd")

# ============================================================================
# RUNTIME STATE
# ============================================================================
@export var instance_id: String = ""
@export var base_item_id: String = ""
@export_range(0, 100) var condition: int = 100
@export var current_ammo: int = 0
@export var current_attachments: Dictionary = {}

# ============================================================================
# CACHED DATA
# ============================================================================
var base_weapon_data: Dictionary = {}
var effective_stats: Dictionary = {}

# ============================================================================
# KONSTRUKTOR (Factory Pattern)
# ============================================================================

static func from_weapon_resource(resource: WeaponResource) -> ItemInstance:
	if resource == null:
		DebugLogger.error("ItemInstance", "from_weapon_resource: 'resource' ist null.")
		return null
		
	var inst = new()
	
	inst.instance_id = "item_%s" % Time.get_ticks_usec()
	inst.base_item_id = resource.id
	inst.condition = 100
	inst.base_weapon_data = resource.to_dict()
	inst.current_ammo = resource.magazine_size
	inst.current_attachments = {}
	
	WeaponModSystem.recalculate_stats(inst)
	
	DebugLogger.log("ItemInstance", "Neue Instanz '%s' von '%s' erstellt." % [inst.instance_id, inst.base_item_id])
	return inst

# ============================================================================
# STATS & MODDING
# ============================================================================

func get_effective_stats() -> Dictionary:
	if effective_stats.is_empty():
		DebugLogger.warn("ItemInstance", "'effective_stats' ist leer für %s. Berechne neu." % instance_id)
		WeaponModSystem.recalculate_stats(self)
		
	return effective_stats

func add_attachment(attachment_resource: AttachmentResource, slot: String) -> bool:
	return WeaponModSystem.attach_mod(self, attachment_resource, slot)

func remove_attachment(slot: String) -> AttachmentResource:
	var removed_mod = WeaponModSystem.remove_mod(self, slot)
	return removed_mod as AttachmentResource

# ============================================================================
# AMMO & CONDITION
# ============================================================================

func reload() -> bool:
	if effective_stats.is_empty():
		DebugLogger.error("ItemInstance", "Kann nicht nachladen, 'effective_stats' sind leer.")
		return false
		
	var max_ammo = 30
	if effective_stats.has("magazine_size"):
		max_ammo = effective_stats["magazine_size"]
		
	current_ammo = max_ammo
	DebugLogger.log("ItemInstance", "%s nachgeladen auf %d Schuss." % [instance_id, current_ammo])
	return true

func fire_shot() -> bool:
	if current_ammo <= 0:
		DebugLogger.warn("ItemInstance", "%s hat keine Munition!" % instance_id)
		return false
		
	current_ammo -= 1
	return true

func get_ammo_percent() -> float:
	var max_ammo = 30
	if effective_stats.has("magazine_size"):
		max_ammo = effective_stats["magazine_size"]
		
	if max_ammo == 0:
		return 0.0
	return float(current_ammo) / float(max_ammo)

# ============================================================================
# SERIALIZATION (Für Save/Load)
# ============================================================================

func to_dict() -> Dictionary:
	var attachments_dict = {}
	for slot_name in current_attachments:
		var attachment: AttachmentResource = current_attachments[slot_name]
		attachments_dict[slot_name] = attachment.id

	return {
		"instance_id": instance_id,
		"base_item_id": base_item_id,
		"condition": condition,
		"current_ammo": current_ammo,
		"current_attachments_ids": attachments_dict
	}

static func from_dict(data: Dictionary) -> ItemInstance:
	var base_id = ""
	if data.has("base_item_id"):
		base_id = data["base_item_id"]
	
	if base_id.is_empty():
		DebugLogger.error("ItemInstance", "from_dict: 'base_item_id' fehlt in Daten.")
		return null

	var weapon_res = DataManager.get_weapon(base_id) as WeaponResource
	if weapon_res == null:
		DebugLogger.error("ItemInstance", "from_dict: Konnte WeaponResource '%s' nicht laden." % base_id)
		return null
		
	var inst = from_weapon_resource(weapon_res)
	
	if data.has("instance_id"):
		inst.instance_id = data["instance_id"]
	if data.has("condition"):
		inst.condition = data["condition"]
	if data.has("current_ammo"):
		inst.current_ammo = data["current_ammo"]
	
	inst.current_attachments.clear()
	var attachments_ids: Dictionary = {}
	if data.has("current_attachments_ids"):
		attachments_ids = data["current_attachments_ids"]
		
	for slot_name in attachments_ids:
		var attachment_id = attachments_ids[slot_name]
		var attachment_res = DataManager.get_attachment(attachment_id) as AttachmentResource
		if attachment_res:
			inst.current_attachments[slot_name] = attachment_res
		else:
			DebugLogger.warn("ItemInstance", "from_dict: Konnte Attachment '%s' beim Laden nicht finden." % attachment_id)

	WeaponModSystem.recalculate_stats(inst)
	
	DebugLogger.log("ItemInstance", "Instanz '%s' aus Savegame wiederhergestellt." % inst.instance_id)
	return inst

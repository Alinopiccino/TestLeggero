extends Resource
class_name CardData

# -----------------------------------------------------------------------------
# 🔙 Retro unificato (default per tutte le carte)
# -----------------------------------------------------------------------------
var card_back: Texture2D = preload("res://Assets/CardImages/BackMano3.png")
var card_back_field: Texture2D = preload("res://Assets/CardImagesFIELD/BackField3.png")
var card_back_preview: Texture2D = preload("res://Assets/CardImagesPreview/BackPreview3.png") # ✅ nuovo

var active_buffs: Array[Dictionary] = []                       # buff permanenti
var active_buffs_until_endphase: Array[Dictionary] = []        # scadono a fine turno
var active_buffs_until_battlephase: Array[Dictionary] = []     # scadono a fine battle phase
var active_buffs_until_battlestep: Array[Dictionary] = []      # scadono a fine battle step
var active_buffs_from_while_effects: Array[Dictionary] = []     # Buff temporanei While
var active_debuffs_from_while_effects: Array[Dictionary] = []   # Debuff temporanei While


var active_debuffs: Array[Dictionary] = []                    # permanenti
var active_debuffs_until_endphase: Array[Dictionary] = []     # scadono a fine turno
var active_debuffs_until_battlephase: Array[Dictionary] = []  # scadono a fine battle phase
var active_debuffs_until_battlestep: Array[Dictionary] = []   # scadono a fine battle step

# 🧩 Storico completo dei modificatori di statistiche (buff + debuff in ordine applicazione)
var all_stat_modifiers: Array[Dictionary] = []  # Ogni voce: {"source_card": Card, "type": "Buff"/"Debuff", "magnitude_atk": int, "magnitude_hp": int, "temp_effect": String}
# 🔑 Identità runtime (NON esportata)
var runtime_uid: int = 0
var voided_atk: int = 0 # ✅ 
# -----------------------------------------------------------------------------
# 📋 Informazioni base
# -----------------------------------------------------------------------------
@export var card_name: String
@export var tooltip_name: String = "" # ✅ nome descrittivo secondario per tooltip
@export var card_sprite: Texture2D
@export var card_field_sprite: Texture2D   # sprite alternativa sul campo
@export var card_sprite_preview: Texture2D # sprite preview (es. zoom/deck builder)
@export var card_deck_sprite: Texture2D
@export var card_rank: int = 3

@export var attack: int = 0
@export var health: int = 0
@export var armour: int = 0
@export var spell_multiplier: int = 0
@export var spell_duration: int = 0 #rappresenta anche durability per gli equip
@export var base_spell_power: int = 0 # ✅ nuovo: spell power intrinseco della carta
@export var tributes: int = 0
@export_enum("None", "sacrificeAllyCreature","AllyCreature_Water_or_SpellCaster") var activation_cost: String = "None" # ✅ nuovo: costo di attivazione dell'effetto




@export_enum("Fire", "Earth", "Water", "Wind") var card_attribute: String = "Fire"
@export_enum("Creature", "Spell") var card_type: String = "Creature"
@export_enum("None", "Humanoid", "Beast", "Undead", "Elemental", "Mech", "Demon", "Giant", "Monster") var creature_race: String = "None"
@export_enum("None", "Humanoid", "Beast", "Undead", "Elemental", "Mech", "Demon", "Giant", "Monster") var creature_race_2: String = "None"
@export_enum("Spellcaster", "Figher", "Trickster", "Defender", "Support", "None", "ContinuousSpell", "InstantSpell", "NormalSpell","EquipSpell") var card_class: String = "None"
@export_enum("Spellcaster", "Figher", "Trickster", "Defender", "Support", "None", "ContinuousSpell", "InstantSpell", "NormalSpell","EquipSpell") var card_class_2: String = "None" # ✅ nuovo
@export_group("Talents")
@export_enum("None", "Overkill", "Taunt", "Lifesteal", "Charge", "Berserker", "Haste", "Assault", "Regeneration", "Stun", "Flying", "Double Strike", "Elusive", "Mastery", "Magic Veil", "Phys Immune", "Magical Taunt", "Reactivity", "Freeze", "Ruthless","Deathtouch","Free Strike") var talent_1: String = "None"
@export_enum("None", "Overkill", "Taunt", "Lifesteal", "Charge", "Berserker", "Haste", "Assault", "Regeneration", "Stun", "Flying", "Double Strike", "Elusive", "Mastery", "Magic Veil", "Phys Immune", "Magical Taunt", "Reactivity", "Freeze", "Ruthless","Deathtouch","Free Strike") var talent_2: String = "None"
@export_enum("None", "Overkill", "Taunt", "Lifesteal", "Charge", "Berserker", "Haste", "Assault", "Regeneration", "Stun", "Flying", "Double Strike", "Elusive", "Mastery", "Magic Veil", "Phys Immune", "Magical Taunt", "Reactivity", "Freeze", "Ruthless","Deathtouch","Free Strike") var talent_3: String = "None"
@export_enum("None", "Overkill", "Taunt", "Lifesteal", "Charge", "Berserker", "Haste", "Assault", "Regeneration", "Stun", "Flying", "Double Strike", "Elusive", "Mastery", "Magic Veil", "Phys Immune", "Magical Taunt", "Reactivity", "Freeze", "Ruthless","Deathtouch","Free Strike") var talent_4: String = "None"
@export_enum("None", "Overkill", "Taunt", "Lifesteal", "Charge", "Berserker", "Haste", "Assault", "Regeneration", "Stun", "Flying", "Double Strike", "Elusive", "Mastery", "Magic Veil", "Phys Immune", "Magical Taunt", "Reactivity", "Freeze", "Ruthless","Deathtouch","Free Strike") var talent_5: String = "None"
@export_group("")  # 🔚 Chiude il gruppo
@export_enum("None", "Passive", "OnPlay", "OnDeath", "Activable", "ActivableAttack", "On_Trigger", "Aura", "Equip") var effect_type: String = "None"
@export_enum("None", "On_EndPhase", "On_UpKeepPhase", "On_Attack", "On_Direct_Damage_Self", "On_Retaliate", "On_Death", "On_Play", "On_Cast", "While_DEFpos", "While_NoOtherAlly") var trigger_type: String = "None" # ✅ NUOVO

@export_group("Thresholds")

@export_enum(
	"None","SelectionOverATK","SelectionOverHP","SelectionUnderATK","SelectionUnderHP", "ApplyToFire", "ApplyToEarth", "ApplyToWater" ,"ApplyToWind",
	"ApplyThresholdOverATK","ApplyThresholdUnderATK","ApplyThresholdOverHP","ApplyThresholdUnderHP", "ApplyToFrozen", "ApplyToUnderXmanaCost"
) var effect_1_threshold_type: String = "None"

@export_enum(
	"None","SelectionOverATK","SelectionOverHP","SelectionUnderATK","SelectionUnderHP", "ApplyToFire", "ApplyToEarth", "ApplyToWater" ,"ApplyToWind",
	"ApplyThresholdOverATK","ApplyThresholdUnderATK","ApplyThresholdOverHP","ApplyThresholdUnderHP", "ApplyToFrozen", "ApplyToUnderXmanaCost"
) var effect_2_threshold_type: String = "None"

@export_enum(
	"None","SelectionOverATK","SelectionOverHP","SelectionUnderATK","SelectionUnderHP", "ApplyToFire", "ApplyToEarth", "ApplyToWater" ,"ApplyToWind",
	"ApplyThresholdOverATK","ApplyThresholdUnderATK","ApplyThresholdOverHP","ApplyThresholdUnderHP", "ApplyToFrozen", "ApplyToUnderXmanaCost"
) var effect_3_threshold_type: String = "None"

@export_enum(
	"None","SelectionOverATK","SelectionOverHP","SelectionUnderATK","SelectionUnderHP", "ApplyToFire", "ApplyToEarth", "ApplyToWater" ,"ApplyToWind",
	"ApplyThresholdOverATK","ApplyThresholdUnderATK","ApplyThresholdOverHP","ApplyThresholdUnderHP", "ApplyToFrozen", "ApplyToUnderXmanaCost"
) var effect_4_threshold_type: String = "None"


# 🔢 Thresholds numerici corrispondenti
@export var effect_1_threshold: int = 0
@export var effect_2_threshold: int = 0
@export var effect_3_threshold: int = 0
@export var effect_4_threshold: int = 0

@export_group("") # 🔚 chiude il gruppo
@export_group("Effects")
@export var custom_effect_name: String = "None"
@export_enum("None", "Custom", "Damage", "Heal", "PreventDamage", "Destroy", "Bouncer", "ChangePosition", "Draw", "Buff", "BuffAtk" , "BuffHp", "BuffArmour", "Debuff", "DebuffAtk", "DebuffHp", "Freeze", "Stun", "Root", "Counter", "SpawnToken", "BuffTalent", "BuffSpellPower", "BuffFireSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower", "BuffWaterSpellPower", "AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWindMana", "AddWaterMana","PayMana_for","FloodedField") var effect_1: String = "None"
@export_enum("None", "Custom", "Damage", "Heal", "PreventDamage", "Destroy", "Bouncer", "ChangePosition", "Draw", "Buff", "BuffAtk" , "BuffHp", "BuffArmour", "Debuff", "DebuffAtk", "DebuffHp", "Freeze", "Stun", "Root", "Counter", "SpawnToken", "BuffTalent", "BuffSpellPower", "BuffFireSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower", "BuffWaterSpellPower", "AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWindMana", "AddWaterMana","PayMana_for","FloodedField") var effect_2: String = "None"
@export_enum("None", "Custom", "Damage", "Heal", "PreventDamage", "Destroy", "Bouncer", "ChangePosition", "Draw", "Buff", "BuffAtk" , "BuffHp", "BuffArmour", "Debuff", "DebuffAtk", "DebuffHp", "Freeze", "Stun", "Root", "Counter", "SpawnToken", "BuffTalent", "BuffSpellPower", "BuffFireSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower", "BuffWaterSpellPower", "AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWindMana", "AddWaterMana","PayMana_for","FloodedField") var effect_3: String = "None"
@export_enum("None", "Custom", "Damage", "Heal", "PreventDamage", "Destroy", "Bouncer", "ChangePosition", "Draw", "Buff", "BuffAtk" , "BuffHp", "BuffArmour", "Debuff", "DebuffAtk", "DebuffHp", "Freeze", "Stun", "Root", "Counter", "SpawnToken", "BuffTalent", "BuffSpellPower", "BuffFireSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower", "BuffWaterSpellPower", "AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWindMana", "AddWaterMana","PayMana_for","FloodedField") var effect_4: String = "None"
@export_enum("None", "Custom", "Damage", "Heal", "PreventDamage", "Destroy", "Bouncer", "ChangePosition", "Draw", "Buff", "BuffAtk" , "BuffHp", "BuffArmour", "Debuff", "DebuffAtk", "DebuffHp", "Freeze", "Stun", "Root", "Counter", "SpawnToken", "BuffTalent", "BuffSpellPower", "BuffFireSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower", "BuffWaterSpellPower", "AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWindMana", "AddWaterMana","PayMana_for","FloodedField") var effect_5: String = "None"
@export var effect_magnitude_1: int = 0
@export var effect_magnitude_2: int = 0
@export var effect_magnitude_3: int = 0
@export var effect_magnitude_4: int = 0 # ✅ nuovo valore secondario
@export_group("")

@export_enum("None", "Overkill", "Taunt", "Lifesteal", "Charge", "Berserker", "Haste", "Assault", "Regeneration", "Stun", "Flying", "Double Strike", "Elusive", "Mastery", "Magic Veil", "Phys Immune", "Magical Taunt", "Reactivity", "Freeze", "Ruthless","Deathtouch","Free Strike") var talent_from_buff: String = "None" # ✅ nuovo: talento temporaneo da buff
@export_enum("None", "Targeted", "AoE") var targeting_type: String = "None"
@export_enum("None", "AllCreatures", "AllATKCreatures", "AllDEFCreatures", "AllFireCreatures", "AllEarthCreatures", "AllWaterCreatures", "AllWindCreatures", "AllEnemyCreatures", "AllEnemyATKCreatures", "AllEnemyDEFCreatures", "AllCards", "AllAllyCreatures", "AllAllyDEFCreatures", "AllAllyATKCreatures", "Self", "SelfPlayer", "EnemyPlayer", "BothPlayers","AllSpells", "AllEnemySpells","LastPlayedCreature","JustTargetedCreature", "AttackingCreature") var t_subtype_1: String = "None"
@export_enum("None", "AllCreatures", "AllATKCreatures", "AllDEFCreatures", "AllFireCreatures", "AllEarthCreatures", "AllWaterCreatures", "AllWindCreatures", "AllEnemyCreatures", "AllEnemyATKCreatures", "AllEnemyDEFCreatures", "AllCards", "AllAllyCreatures", "AllAllyDEFCreatures", "AllAllyATKCreatures", "Self", "SelfPlayer", "EnemyPlayer", "BothPlayers","AllSpells", "AllEnemySpells","LastPlayedCreature","JustTargetedCreature", "AttackingCreature") var t_subtype_2: String = "None"
@export_enum("None", "AllCreatures", "AllATKCreatures", "AllDEFCreatures", "AllFireCreatures", "AllEarthCreatures", "AllWaterCreatures", "AllWindCreatures", "AllEnemyCreatures", "AllEnemyATKCreatures", "AllEnemyDEFCreatures", "AllCards", "AllAllyCreatures", "AllAllyDEFCreatures", "AllAllyATKCreatures", "Self", "SelfPlayer", "EnemyPlayer", "BothPlayers","AllSpells", "AllEnemySpells","LastPlayedCreature","JustTargetedCreature", "AttackingCreature") var t_subtype_3: String = "None"
@export_enum("None", "AllCreatures", "AllATKCreatures", "AllDEFCreatures", "AllFireCreatures", "AllEarthCreatures", "AllWaterCreatures", "AllWindCreatures", "AllEnemyCreatures", "AllEnemyATKCreatures", "AllEnemyDEFCreatures", "AllCards", "AllAllyCreatures", "AllAllyDEFCreatures", "AllAllyATKCreatures", "Self", "SelfPlayer", "EnemyPlayer", "BothPlayers", "AllSpells", "AllEnemySpells","LastPlayedCreature" ,"JustTargetedCreature", "AttackingCreature") var t_subtype_4: String = "None"
@export_enum("None", "Quick", "Normal") var effect_speed: String = "None"
@export_enum("None", "EndPhase", "BattlePhase", "BattleStep", "Enchant", "While", "This_Step") var temp_effect: String = "None"


@export_enum("None", "MagnitudeSpellPower", "SpellsPlayerGY", "ThresholdSpellPower") var scaling_1: String = "None" # ✅ nuovo
@export var scaling_amount_1: int = 0
@export_enum("None", "MagnitudeSpellPower", "SpellsPlayerGY", "ThresholdSpellPower") var scaling_2: String = "None" # ✅ nuovo
@export var scaling_amount_2: int = 0
@export_enum(
	"1", "2", "3", "4", "5", "Number_of_self_in_GY", "Number_of_fire_spells_in_GY", "Number_of_earth_spells_in_GY",
	"Cards_in_hand", "Creatures_on_field", "Allies_on_field", "Enemies_on_field"
) var repeats: String = "1"

# -----------------------------------------------------------------------------
# 🔥 COSTO MANA (fino a 5 slot)
# -----------------------------------------------------------------------------
@export_group("ManaCosts")
@export_enum("None", "Colorless", "Fire", "Earth", "Water", "Wind") var mana_cost_1: String = "None"
@export_enum("None", "Colorless", "Fire", "Earth", "Water", "Wind") var mana_cost_2: String = "None"
@export_enum("None", "Colorless", "Fire", "Earth", "Water", "Wind") var mana_cost_3: String = "None"
@export_enum("None", "Colorless", "Fire", "Earth", "Water", "Wind") var mana_cost_4: String = "None"
@export_enum("None", "Colorless", "Fire", "Earth", "Water", "Wind") var mana_cost_5: String = "None"
@export_enum("None", "Colorless", "Fire", "Earth", "Water", "Wind") var mana_cost_6: String = "None"
@export_enum("None", "Colorless", "Fire", "Earth", "Water", "Wind") var mana_cost_7: String = "None"

func get_mana_cost_array() -> Array[String]:
	var mana: Array[String] = []
	if mana_cost_1 != "None": mana.append(mana_cost_1)
	if mana_cost_2 != "None": mana.append(mana_cost_2)
	if mana_cost_3 != "None": mana.append(mana_cost_3)
	if mana_cost_4 != "None": mana.append(mana_cost_4)
	if mana_cost_5 != "None": mana.append(mana_cost_5)
	if mana_cost_6 != "None": mana.append(mana_cost_6)
	if mana_cost_7 != "None": mana.append(mana_cost_7)
	return mana

func get_mana_cost() -> int:
	return get_mana_cost_array().size()

# -----------------------------------------------------------------------------
# 📌 Valori originali (per reset/buff/debuff)
# -----------------------------------------------------------------------------
var original_attack: int
var original_health: int
var max_attack: int
var max_health: int
var original_effect_magnitude_1: int 
var original_effect_magnitude_2: int # ✅ nuovo
var original_effect_magnitude_3: int # ✅ nuovo
var original_effect_magnitude_4: int # ✅ nuovo
var original_spell_multiplier: int
var original_spell_duration: int

func init_original_stats():
	if original_attack == 0:
		original_attack = attack 
	if original_health == 0:
		original_health = health
	if original_effect_magnitude_1 == 0:
		original_effect_magnitude_1 = effect_magnitude_1
	if original_effect_magnitude_2 == 0:
		original_effect_magnitude_2 = effect_magnitude_2
	if original_effect_magnitude_3 == 0:
		original_effect_magnitude_3 = effect_magnitude_3
	if original_effect_magnitude_4 == 0:
		original_effect_magnitude_4 = effect_magnitude_4
	if original_spell_multiplier == 0:
		original_spell_multiplier = spell_multiplier
	if original_spell_duration == 0:
		original_spell_duration = spell_duration
		# 👉 max_health parte uguale all'original
	# ⚖️ Max ATK / HP iniziali solo se non già impostati e non debuffati
	if max_attack == 0:
		if voided_atk > 0:
			print("💀 [INIT] Carta debuffata → max_attack resta 0 (voided_atk:", voided_atk, ")")
			max_attack = 0
		else:
			max_attack = original_attack
	if max_health == 0:
		max_health = original_health
	
	print("ATK:", attack, "ORG ATK:", original_attack)
	print("🧙 Spell Mult:", spell_multiplier, "  Duration:", spell_duration)
# -----------------------------------------------------------------------------
# 🔄 Serializzazione
# -----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"card_name": card_name,
		"tooltip_name": tooltip_name,
		"card_sprite_path": card_sprite.resource_path if card_sprite else "",
		"card_field_sprite_path": card_field_sprite.resource_path if card_field_sprite else "",
		"card_sprite_preview_path": card_sprite_preview.resource_path if card_sprite_preview else "",
		"card_back_path": card_back.resource_path if card_back else "",
		"card_back_field_path": card_back_field.resource_path if card_back_field else "",
		"card_back_preview_path": card_back_preview.resource_path if card_back_preview else "",
		"attack": attack,
		"health": health,
		"armour": armour,
		"spell_multiplier": spell_multiplier,
		"spell_duration": spell_duration,
		"base_spell_power": base_spell_power,
		"tributes": tributes,
		"activation_cost": activation_cost,
		"card_attribute": card_attribute,
		"card_type": card_type,
		"creature_race": creature_race,
		"creature_race_2": creature_race_2,
		"card_class": card_class,
		"card_class_2": card_class_2,
		"talents": get_talents_array(),
		"effect_type": effect_type,
		"trigger_type": trigger_type,
		"effect_1_threshold_type": effect_1_threshold_type, # 🆕
		"effect_2_threshold_type": effect_2_threshold_type, # 🆕
		"effect_3_threshold_type": effect_3_threshold_type,
		"effect_4_threshold_type": effect_4_threshold_type,
		"effect_1_threshold": effect_1_threshold, # 🆕
		"effect_2_threshold": effect_2_threshold, # 🆕
		"effect_3_threshold": effect_3_threshold,
		"effect_4_threshold": effect_4_threshold,
		"custom_effect_name": custom_effect_name,
		"effect_1": effect_1,
		"effect_2": effect_2,
		"effect_3": effect_3,
		"effect_4": effect_4,
		"effect_magnitude_1": effect_magnitude_1,
		"effect_magnitude_2": effect_magnitude_2,
		"effect_magnitude_3": effect_magnitude_3,
		"effect_magnitude_4": effect_magnitude_4,
		"talent_from_buff": talent_from_buff,
		"targeting_type": targeting_type,
		"t_subtype_1": t_subtype_1,
		"t_subtype_2": t_subtype_2,
		"t_subtype_3": t_subtype_3,
		"t_subtype_4": t_subtype_4,
		"scaling_1": scaling_1,
		"scaling_amount_1": scaling_amount_1,
		"scaling_2": scaling_2,
		"scaling_amount_2": scaling_amount_2,
		"repeats": repeats,
		"effect_speed": effect_speed,
		"temp_effect": temp_effect,
		"original_attack": original_attack,
		"original_health": original_health,
		"max_attack": max_attack,
		"max_health": max_health,
		"voided_atk": voided_atk,
		"original_effect_magnitude_1": original_effect_magnitude_1,
		"original_effect_magnitude_2": original_effect_magnitude_2,
		"original_effect_magnitude_3": original_effect_magnitude_3,
		"original_effect_magnitude_4": original_effect_magnitude_4,
		"original_spell_multiplier": original_spell_multiplier,
		"original_spell_duration": original_spell_duration,
		"mana_cost": get_mana_cost_array(),
	}


static func from_dict(data: Dictionary) -> CardData:
	var cd = CardData.new()
	cd.card_name = data.get("card_name", "")
	cd.tooltip_name = data.get("tooltip_name", "")
	cd.card_sprite = load(data.get("card_sprite_path", "")) if data.has("card_sprite_path") else null
	cd.card_field_sprite = load(data.get("card_field_sprite_path", "")) if data.has("card_field_sprite_path") else null
	cd.card_sprite_preview = load(data.get("card_sprite_preview_path", "")) if data.has("card_sprite_preview_path") else null
	cd.card_back = preload("res://Assets/CardImages/BackMano3.png")
	cd.card_back_field = preload("res://Assets/CardImagesFIELD/BackField3.png")
	cd.card_back_preview = load(data.get("card_back_preview_path", "")) if data.has("card_back_preview_path") else preload("res://Assets/CardImagesPreview/BackPreview2.png")
	cd.attack = data.get("attack", 0)
	cd.health = data.get("health", 0)
	cd.armour = data.get("armour", 0)
	cd.spell_multiplier = data.get("spell_multiplier", 0)
	cd.spell_duration = data.get("spell_duration", 0)
	cd.base_spell_power = data.get("base_spell_power", 0)
	cd.tributes = data.get("tributes", 0)
	cd.activation_cost = data.get("activation_cost", "None") # ✅ nuovo
	cd.card_attribute = data.get("card_attribute", "Fire")
	cd.card_type = data.get("card_type", "Creature")
	cd.creature_race = data.get("creature_race", "None")
	cd.creature_race_2 = data.get("creature_race_2", "None")
	cd.card_class = data.get("card_class", "None")
	cd.card_class_2 = data.get("card_class_2", "None") # ✅ nuovo
	
	# 👇 Import talents array
	if data.has("talents"):
		var talents = data["talents"]
		if talents.size() > 0: cd.talent_1 = talents[0]
		if talents.size() > 1: cd.talent_2 = talents[1]
		if talents.size() > 2: cd.talent_3 = talents[2]
		if talents.size() > 3: cd.talent_4 = talents[3]
		if talents.size() > 4: cd.talent_5 = talents[4]

	cd.effect_type = data.get("effect_type", "None")
	cd.trigger_type = data.get("trigger_type", "None") # ✅ nuovo
	cd.effect_1_threshold_type = data.get("effect_1_threshold_type", "None") # 🆕
	cd.effect_2_threshold_type = data.get("effect_2_threshold_type", "None") # 🆕
	cd.effect_3_threshold_type = data.get("effect_3_threshold_type", "None")
	cd.effect_4_threshold_type = data.get("effect_4_threshold_type", "None")
	cd.effect_1_threshold = data.get("effect_1_threshold", 0) # 🆕
	cd.effect_2_threshold = data.get("effect_2_threshold", 0) # 🆕
	cd.effect_3_threshold = data.get("effect_3_threshold", 0)
	cd.effect_4_threshold = data.get("effect_4_threshold", 0)
	cd.custom_effect_name = data.get("custom_effect_name", "None")
	cd.effect_1 = data.get("effect_1", "None")
	cd.effect_2 = data.get("effect_2", "None") # ✅ nuovo
	cd.effect_3 = data.get("effect_3", "None")
	cd.effect_4 = data.get("effect_4", "None")
	cd.effect_magnitude_1 = data.get("effect_magnitude_1", 0)
	cd.effect_magnitude_2 = data.get("effect_magnitude_2", 0) # ✅ nuovo
	cd.effect_magnitude_3 = data.get("effect_magnitude_3", 0)
	cd.effect_magnitude_4 = data.get("effect_magnitude_4", 0) # ✅ nuovo
	cd.talent_from_buff = data.get("talent_from_buff", "None")
	cd.targeting_type = data.get("targeting_type", "None")
	cd.t_subtype_1 = data.get("t_subtype_1", "None") # ✅ nuovo
	cd.t_subtype_2 = data.get("t_subtype_2", "None") # ✅ nuovo
	cd.t_subtype_3 = data.get("t_subtype_3", "None") # ✅ nuovo
	cd.t_subtype_4 = data.get("t_subtype_4", "None") # ✅ nuovo
	cd.scaling_1 = data.get("scaling_1", "None")
	cd.scaling_amount_1 = data.get("scaling_amount_1", 0)
	cd.scaling_2 = data.get("scaling_2", "None")
	cd.scaling_amount_2 = data.get("scaling_amount_2", 0)
	cd.repeats = data.get("repeats", 1)
	cd.effect_speed = data.get("effect_speed", "None")
	cd.temp_effect = data.get("temp_effect", "None")

	# Mana cost array
	if data.has("mana_cost"):
		var mana = data["mana_cost"]
		if mana.size() > 0: cd.mana_cost_1 = mana[0]
		if mana.size() > 1: cd.mana_cost_2 = mana[1]
		if mana.size() > 2: cd.mana_cost_3 = mana[2]
		if mana.size() > 3: cd.mana_cost_4 = mana[3]
		if mana.size() > 4: cd.mana_cost_5 = mana[4]
		if mana.size() > 5: cd.mana_cost_6 = mana[5]
		if mana.size() > 6: cd.mana_cost_7 = mana[6]
		
	cd.original_attack = data.get("original_attack", cd.attack)
	cd.original_health = data.get("original_health", cd.health)
	cd.max_attack = data.get("max_attack", cd.attack)
	cd.max_health = data.get("max_health", cd.health)
	cd.voided_atk = data.get("voided_atk", 0)
	cd.original_effect_magnitude_1 = data.get("original_effect_magnitude_1", cd.effect_magnitude_1)
	cd.original_effect_magnitude_2 = data.get("original_effect_magnitude_2", cd.effect_magnitude_2)
	cd.original_effect_magnitude_3 = data.get("original_effect_magnitude_3", cd.effect_magnitude_2)
	cd.original_effect_magnitude_4 = data.get("original_effect_magnitude_4", cd.effect_magnitude_2) # ✅ nuovo
	cd.original_spell_multiplier = data.get("original_spell_multiplier", cd.spell_multiplier)
	cd.original_spell_duration = data.get("original_spell_duration", cd.spell_duration)

	return cd

# -----------------------------------------------------------------------------
# 🔀 Copia runtime
# -----------------------------------------------------------------------------
func make_runtime_copy() -> CardData:
	var copy = CardData.new()
	copy.card_name = card_name
	copy.tooltip_name = tooltip_name
	copy.card_sprite = card_sprite
	copy.card_field_sprite = card_field_sprite
	copy.card_sprite_preview = card_sprite_preview
	copy.card_back = card_back
	copy.card_back_field = card_back_field
	copy.card_back_preview = card_back_preview
	copy.attack = attack
	copy.health = health
	copy.armour = armour
	copy.spell_multiplier = spell_multiplier
	copy.spell_duration = spell_duration
	copy.base_spell_power = base_spell_power
	copy.tributes = tributes
	copy.activation_cost = activation_cost # ✅ nuovo
	copy.card_attribute = card_attribute
	copy.card_type = card_type
	copy.creature_race = creature_race
	copy.creature_race_2 = creature_race_2
	copy.card_class = card_class
	copy.card_class_2 = card_class_2 # ✅ nuovo
	copy.talent_1 = talent_1
	copy.talent_2 = talent_2
	copy.talent_3 = talent_3
	copy.talent_4 = talent_4
	copy.talent_5 = talent_5
	copy.effect_type = effect_type
	copy.trigger_type = trigger_type # ✅ nuovo
	copy.effect_1_threshold_type = effect_1_threshold_type # 🆕
	copy.effect_2_threshold_type = effect_2_threshold_type # 🆕
	copy.effect_1_threshold = effect_1_threshold # 🆕
	copy.effect_2_threshold = effect_2_threshold # 🆕
	copy.custom_effect_name = custom_effect_name
	copy.effect_1 = effect_1
	copy.effect_2 = effect_2
	copy.effect_3 = effect_3
	copy.effect_4 = effect_4 # ✅ nuovo
	copy.effect_magnitude_1 = effect_magnitude_1
	copy.effect_magnitude_2 = effect_magnitude_2
	copy.effect_magnitude_3 = effect_magnitude_3
	copy.effect_magnitude_4 = effect_magnitude_4 # ✅ nuovo
	copy.talent_from_buff = talent_from_buff
	copy.targeting_type = targeting_type
	copy.t_subtype_1 = t_subtype_1 # ✅ nuovo
	copy.t_subtype_2 = t_subtype_2 # ✅ nuovo
	copy.t_subtype_3 = t_subtype_3 # ✅ nuovo
	copy.t_subtype_4 = t_subtype_4 # ✅ nuovo
	copy.scaling_1 = scaling_1 # ✅ nuovo
	copy.scaling_amount_1 = scaling_amount_1
	copy.scaling_2 = scaling_2 # ✅ nuovo
	copy.scaling_amount_2 = scaling_amount_2
	copy.repeats = repeats
	copy.effect_speed = effect_speed
	copy.temp_effect = temp_effect
	copy.original_attack = original_attack
	copy.original_health = original_health
	copy.max_attack = max_attack
	copy.max_health = max_health
	copy.voided_atk = voided_atk
	copy.original_spell_multiplier = original_spell_multiplier
	copy.original_spell_duration = original_spell_duration
	copy.original_effect_magnitude_1 = original_effect_magnitude_1
	copy.original_effect_magnitude_2 = original_effect_magnitude_2 # ✅ nuov
	copy.original_effect_magnitude_3 = original_effect_magnitude_3 # ✅ nuov
	copy.original_effect_magnitude_4 = original_effect_magnitude_4 # ✅ nuov
	copy.mana_cost_1 = mana_cost_1
	copy.mana_cost_2 = mana_cost_2
	copy.mana_cost_3 = mana_cost_3
	copy.mana_cost_4 = mana_cost_4
	copy.mana_cost_5 = mana_cost_5
	copy.mana_cost_6 = mana_cost_6
	copy.mana_cost_7 = mana_cost_7
	
	return copy



func get_talents_array() -> Array[String]:
	var talents: Array[String] = []
	if talent_1 != "None": talents.append(talent_1)
	if talent_2 != "None": talents.append(talent_2)
	if talent_3 != "None": talents.append(talent_3)
	if talent_4 != "None": talents.append(talent_4)
	if talent_5 != "None": talents.append(talent_5)
	return talents



# -----------------------------------------------------------------------------
# 💀 Debuffs attivi (ora con struttura come i Buff)
# -----------------------------------------------------------------------------

func add_debuff(source_card: Card, debuff_type: String, atk_reduction: int = 0, hp_reduction: int = 0) -> void:
	if not is_instance_valid(source_card):
		push_warning("⚠️ add_debuff: source_card non valida")
		return

	# Determina se il debuff è temporaneo (EndPhase, BattlePhase, BattleStep)
	var temp_effect_type := "None"
	if source_card.card_data and source_card.card_data.has_method("get"):
		temp_effect_type = source_card.card_data.temp_effect

	# Seleziona l'array corretto
	var target_array: Array[Dictionary] = []
	match temp_effect_type:
		"EndPhase":
			target_array = active_debuffs_until_endphase
		"BattlePhase":
			target_array = active_debuffs_until_battlephase
		"BattleStep":
			target_array = active_debuffs_until_battlestep
		"While":
			target_array = active_debuffs_from_while_effects
		_:
			target_array = active_debuffs

	# 🔎 Se la stessa carta ha già applicato un debuff dello stesso tipo → aggiorna
	for d in target_array:
		if typeof(d) == TYPE_DICTIONARY and d.has("source_card") and d["source_card"] == source_card and d["type"] == debuff_type:
			d["magnitude_atk"] += atk_reduction
			d["magnitude_hp"] += hp_reduction
			print("🔁 Debuff aggiornato da", source_card.card_data.card_name, "→", debuff_type, "(", temp_effect_type, ")")

			# 🧩 Aggiorna anche l'ultimo record corrispondente in all_stat_modifiers (solo ATK)
			for i in range(all_stat_modifiers.size() - 1, -1, -1):
				var mod = all_stat_modifiers[i]
				if typeof(mod) == TYPE_DICTIONARY and mod.get("source_card") == source_card and mod.get("type") == "Debuff":
					if atk_reduction != 0:
						mod["magnitude_atk"] += atk_reduction
						all_stat_modifiers[i] = mod
						print("🔁 [ALL_MODIFIERS] Aggiornato record Debuff (-ATK:", atk_reduction, ")")
					break
			return

	# ✅ Se non esiste, creane uno nuovo
	var new_debuff: Dictionary = {
		"source_card": source_card,
		"type": debuff_type,
		"magnitude_atk": atk_reduction,
		"magnitude_hp": hp_reduction,
		"temp_effect": temp_effect_type
	}
	target_array.append(new_debuff)

	print("💀 Debuff aggiunto da", source_card.card_data.card_name, "→", debuff_type, "(", temp_effect_type, ")  -ATK:", atk_reduction, " -HP:", hp_reduction)

	# 🧩 Registra anche nello storico completo dei modificatori
	if atk_reduction != 0:
		# ⚠️ Evita di loggare debuff provenienti da carte Aura
		if source_card.card_data and source_card.card_data.effect_type != "Aura":
			var record = {
				"source_card": source_card,
				"type": debuff_type,
				"magnitude_atk": atk_reduction,
				"magnitude_hp": 0,  # ignoriamo completamente la parte HP
				"temp_effect": temp_effect_type
			}
			all_stat_modifiers.append(record)
			print("🧩 [ALL_MODIFIERS] Aggiunto nuovo record Debuff (-ATK:", atk_reduction, ")")
			debug_print_all_modifiers()
		else:
			print("🌫️ [ALL_MODIFIERS] Debuff da Aura ignorato nel log:", source_card.card_data.card_name)
	else:
		print("⚙️ Debuff senza variazione ATK → non registrato in all_stat_modifiers")



		
func remove_debuff_by_source(source_card: Card) -> void:
	if not is_instance_valid(source_card):
		return

	var all_groups = [
		active_debuffs,
		active_debuffs_until_endphase,
		active_debuffs_until_battlephase,
		active_debuffs_until_battlestep,
	]

	for group in all_groups:
		for d in group.duplicate():
			if typeof(d) == TYPE_DICTIONARY and d.has("source_card") and d["source_card"] == source_card:
				group.erase(d)
				print("💨 Debuff rimosso da", source_card.card_data.card_name)

	# 🔄 Rimuovi anche da all_stat_modifiers
	for mod in all_stat_modifiers.duplicate():
		if typeof(mod) == TYPE_DICTIONARY and mod.get("source_card") == source_card and mod.get("type") == "Debuff":
			all_stat_modifiers.erase(mod)
			print("🧩 [ALL_MODIFIERS] Debuff rimosso da", source_card.card_data.card_name)
			debug_print_all_modifiers()


func remove_debuff_type(debuff_type: String) -> void:
	var all_groups = [
		active_debuffs,
		active_debuffs_until_endphase,
		active_debuffs_until_battlephase,
		active_debuffs_until_battlestep,
	]

	for group in all_groups:
		for d in group.duplicate():
			if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == debuff_type:
				group.erase(d)
				print("💨 Debuff rimosso:", debuff_type)

	# 🔄 Rimuovi anche da all_stat_modifiers
	for mod in all_stat_modifiers.duplicate():
		if typeof(mod) == TYPE_DICTIONARY and mod.get("type") == "Debuff" and mod.get("magnitude_atk", 0) <= 0 and mod.get("magnitude_hp", 0) <= 0:
			# Filtra solo modifiche di tipo debuff effettivo (non buff)
			all_stat_modifiers.erase(mod)
			print("🧩 [ALL_MODIFIERS] Debuff rimosso dal log:", debuff_type)
			debug_print_all_modifiers()




func get_total_debuff_penalty() -> Dictionary:
	var total_atk = 0
	var total_hp = 0
	var all_groups = [
		active_buffs,
		active_buffs_until_endphase,
		active_buffs_until_battlephase,
		active_buffs_until_battlestep,
		active_buffs_from_while_effects,  # 👈
	]

	for group in all_groups:
		for d in group:
			if typeof(d) == TYPE_DICTIONARY:
				total_atk += d.get("magnitude_atk", 0)
				total_hp += d.get("magnitude_hp", 0)

	return {"atk": total_atk, "hp": total_hp}


func get_debuffs_array() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(active_debuffs)
	all.append_array(active_debuffs_until_endphase)
	all.append_array(active_debuffs_until_battlephase)
	all.append_array(active_debuffs_until_battlestep)
	return all


func clear_temporary_debuffs(phase: String) -> void:
	var target_group: Array[Dictionary] = []
	match phase:
		"EndPhase":
			target_group = active_debuffs_until_endphase
		"BattlePhase":
			target_group = active_debuffs_until_battlephase
		"BattleStep":
			target_group = active_debuffs_until_battlestep
		_:
			return

	for d in target_group.duplicate():
		if typeof(d) == TYPE_DICTIONARY:
			var debuff_type = d.get("type", "Unknown")
			var source_card = d.get("source_card", null)
			target_group.erase(d)
			print("💨 [" + phase + "] Rimozione debuff:", debuff_type)

			# 🧩 Rimuovi anche il corrispondente record da all_stat_modifiers
			for mod in all_stat_modifiers.duplicate():
				if typeof(mod) == TYPE_DICTIONARY \
				and mod.get("type") == "Debuff" \
				and mod.get("temp_effect") == phase \
				and mod.get("source_card") == source_card:
					all_stat_modifiers.erase(mod)
					print("🧩 [ALL_MODIFIERS] Rimosso debuff temporaneo da", source_card.card_data.card_name, "→", debuff_type, "(", phase, ")")
					debug_print_all_modifiers()



func clear_debuffs() -> void:
	active_debuffs.clear()
	active_debuffs_until_endphase.clear()
	active_debuffs_until_battlephase.clear()
	active_debuffs_until_battlestep.clear()
	active_debuffs_from_while_effects.clear()
	print("💨 Tutti i debuff rimossi")

	# 🔄 Pulisci anche all_stat_modifiers da tutti i Debuff
	for mod in all_stat_modifiers.duplicate():
		if typeof(mod) == TYPE_DICTIONARY and mod.get("type") == "Debuff":
			all_stat_modifiers.erase(mod)
	print("🧩 [ALL_MODIFIERS] Tutti i record Debuff rimossi")
	debug_print_all_modifiers()
# -----------------------------------------------------------------------------
# 💪 Buffs attivi (simile ai debuff)
# -----------------------------------------------------------------------------




func add_buff(source_card: Card, buff_type: String, atk_amount: int = 0, hp_amount: int = 0, armour_amount: int = 0) -> void:
	if not is_instance_valid(source_card):
		push_warning("⚠️ add_buff: source_card non valida")
		return

	var temp_effect_type := "None"
	if source_card.card_data and source_card.card_data.has_method("get"):
		temp_effect_type = source_card.card_data.temp_effect

	# Decidi in quale array aggiungere il buff
	var target_array: Array[Dictionary] = []
	match temp_effect_type:
		"EndPhase":
			target_array = active_buffs_until_endphase
		"BattlePhase":
			target_array = active_buffs_until_battlephase
		"BattleStep":
			target_array = active_buffs_until_battlestep
		"While":
			target_array = active_buffs_from_while_effects
		_:
			target_array = active_buffs

	# 🔎 Se la stessa carta ha già applicato un buff dello stesso tipo in questo gruppo → aggiorna
	for b in target_array:
		if typeof(b) == TYPE_DICTIONARY and b.has("source_card") and b["source_card"] == source_card and b["type"] == buff_type:
			b["magnitude_atk"] += atk_amount
			b["magnitude_hp"] += hp_amount
			b["magnitude_armour"] += armour_amount
			print("🔁 Buff aggiornato da", source_card.card_data.card_name, "→", buff_type, "(", temp_effect_type, ")")

			# 🧩 Aggiorna anche l'ultimo record corrispondente in all_stat_modifiers
			for i in range(all_stat_modifiers.size() - 1, -1, -1):
				var mod = all_stat_modifiers[i]
				if typeof(mod) == TYPE_DICTIONARY and mod.get("source_card") == source_card and mod.get("type") == "Buff":
					mod["magnitude_atk"] += atk_amount
					mod["magnitude_hp"] += hp_amount
					mod["magnitude_armour"] += armour_amount
					all_stat_modifiers[i] = mod
					print("🔁 [ALL_MODIFIERS] Aggiornato record buff esistente (+ATK:", atk_amount, ", +HP:", hp_amount, ", +ARM:", armour_amount, ")")
					break
			return

	# ✅ Se non esiste, creane uno nuovo
	var new_buff: Dictionary = {
		"source_card": source_card,
		"type": buff_type,
		"magnitude_atk": atk_amount,
		"magnitude_hp": hp_amount,
		"magnitude_armour": armour_amount,
		"temp_effect": temp_effect_type
	}

	# 🔸 Gestione BuffTalent
	if buff_type == "BuffTalent":
		if source_card.card_data and source_card.card_data.talent_from_buff != "None":
			var talent_to_add = source_card.card_data.talent_from_buff
			new_buff["talent"] = talent_to_add
			print("💪 [BUFF TALENT] Aggiunto talento", talent_to_add, "da", source_card.card_data.card_name)
		else:
			print("⚠️ BuffTalent ma la source non ha talent_from_buff valido")

	# Aggiungi il nuovo buff
	target_array.append(new_buff)

	# 🧩 Registra anche nello storico
	if atk_amount != 0 or hp_amount != 0 or armour_amount != 0:
		if source_card.card_data and source_card.card_data.effect_type != "Aura":
			var record = {
				"source_card": source_card,
				"type": buff_type,
				"magnitude_atk": atk_amount,
				"magnitude_hp": hp_amount,
				"magnitude_armour": armour_amount,
				"temp_effect": temp_effect_type
			}
			all_stat_modifiers.append(record)
			print("🧩 [ALL_MODIFIERS] Aggiunto nuovo record Buff (ATK:", atk_amount, ", HP:", hp_amount, ", ARM:", armour_amount, ")")
			debug_print_all_modifiers()
		else:
			print("🌫️ [ALL_MODIFIERS] Buff da Aura ignorato nel log:", source_card.card_data.card_name)

	print("✨ Nuovo buff aggiunto da", source_card.card_data.card_name, "→", buff_type, "(", temp_effect_type, ")")




func remove_buff_by_source(source_card: Card) -> void:
	if not is_instance_valid(source_card):
		return

	var all_groups = [
		active_buffs,
		active_buffs_until_endphase,
		active_buffs_until_battlephase,
		active_buffs_until_battlestep,
		active_buffs_from_while_effects
	]

	for group in all_groups:
		for b in group.duplicate():
			if typeof(b) == TYPE_DICTIONARY and b.has("source_card") and b["source_card"] == source_card:
				group.erase(b)
				print("💨 Buff rimosso da", source_card.card_data.card_name)

	# 🔄 Rimuovi anche da all_stat_modifiers
	for mod in all_stat_modifiers.duplicate():
		if typeof(mod) == TYPE_DICTIONARY and mod.get("source_card") == source_card and mod.get("type") == "Buff":
			all_stat_modifiers.erase(mod)
			print("🧩 [ALL_MODIFIERS] Buff rimosso da", source_card.card_data.card_name)
			debug_print_all_modifiers()

func remove_buff_type(buff_type: String) -> void:
	var all_groups = [
		active_buffs,
		active_buffs_until_endphase,
		active_buffs_until_battlephase,
		active_buffs_until_battlestep,
		active_buffs_from_while_effects
	]

	for group in all_groups:
		for b in group.duplicate():
			if typeof(b) == TYPE_DICTIONARY and b.get("type", "") == buff_type:
				group.erase(b)
				print("💨 Buff rimosso:", buff_type)

	# 🔄 Rimuovi anche da all_stat_modifiers
	for mod in all_stat_modifiers.duplicate():
		if typeof(mod) == TYPE_DICTIONARY and mod.get("type") == "Buff" and mod.get("magnitude_atk", 0) >= 0 and mod.get("magnitude_hp", 0) >= 0:
			all_stat_modifiers.erase(mod)
			print("🧩 [ALL_MODIFIERS] Buff rimosso dal log:", buff_type)
			debug_print_all_modifiers()



func get_total_buff_bonus() -> Dictionary:
	var total_atk = 0
	var total_hp = 0
	var total_armour = 0
	var all_groups = [
		active_buffs,
		active_buffs_until_endphase,
		active_buffs_until_battlephase,
		active_buffs_until_battlestep,
		active_buffs_from_while_effects,
	]

	for group in all_groups:
		for b in group:
			if typeof(b) == TYPE_DICTIONARY:
				total_atk += b.get("magnitude_atk", 0)
				total_hp += b.get("magnitude_hp", 0)
				total_armour += b.get("magnitude_armour", 0)

	return {"atk": total_atk, "hp": total_hp, "armour": total_armour}


func get_buffs_array() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(active_buffs)
	all.append_array(active_buffs_until_endphase)
	all.append_array(active_buffs_until_battlephase)
	all.append_array(active_buffs_until_battlestep)
	all.append_array(active_buffs_from_while_effects)
	return all

func clear_temporary_buffs(phase: String) -> void:
	var target_group: Array[Dictionary] = []
	match phase:
		"EndPhase":
			target_group = active_buffs_until_endphase
		"BattlePhase":
			target_group = active_buffs_until_battlephase
		"BattleStep":
			target_group = active_buffs_until_battlestep
		_:
			return

	for b in target_group.duplicate():
		if typeof(b) == TYPE_DICTIONARY:
			var buff_type = b.get("type", "Unknown")
			var source_card = b.get("source_card", null)
			target_group.erase(b)
			print("💨 [" + phase + "] Rimozione buff:", buff_type)

			# 🧩 Rimuovi anche il corrispondente record da all_stat_modifiers
			for mod in all_stat_modifiers.duplicate():
				if typeof(mod) == TYPE_DICTIONARY \
				and mod.get("type") == "Buff" \
				and mod.get("temp_effect") == phase \
				and mod.get("source_card") == source_card:
					all_stat_modifiers.erase(mod)
					print("🧩 [ALL_MODIFIERS] Rimosso buff temporaneo da", source_card.card_data.card_name, "→", buff_type, "(", phase, ")")
					debug_print_all_modifiers()


func clear_buffs() -> void:
	for group in [
		active_buffs,
		active_buffs_until_endphase,
		active_buffs_until_battlephase,
		active_buffs_until_battlestep,
		active_buffs_from_while_effects,  # 👈 aggiunto
	]:
		for b in group.duplicate():
			print("💨 [ClearBuffs] Rimozione buff:", b.get("type", "Unknown"))
			group.erase(b)

	# 🔄 Pulisci anche all_stat_modifiers da tutti i Buff
	for mod in all_stat_modifiers.duplicate():
		if typeof(mod) == TYPE_DICTIONARY and mod.get("type") == "Buff":
			all_stat_modifiers.erase(mod)
	print("🧩 [ALL_MODIFIERS] Tutti i record Buff rimossi")
	debug_print_all_modifiers()
		
func get_total_temporary_buff_bonus() -> Dictionary:  #SERVE PER CALCOLO VOIDED ATK QUANDO SCADE TEMP BUFF
	var total_atk = 0
	var total_hp = 0
	var temp_groups = [
		active_buffs_until_endphase,
		active_buffs_until_battlephase,
		active_buffs_until_battlestep,
		active_buffs_from_while_effects
	]
	for group in temp_groups:
		for b in group:
			if typeof(b) == TYPE_DICTIONARY:
				total_atk += b.get("magnitude_atk", 0)
				total_hp += b.get("magnitude_hp", 0)
	return {"atk": total_atk, "hp": total_hp}


func get_total_temporary_debuff_penalty() -> Dictionary:
	var total_atk = 0
	var total_hp = 0
	var temp_groups = [
		active_debuffs_until_endphase,
		active_debuffs_until_battlephase,
		active_debuffs_until_battlestep,
	]
	for group in temp_groups:
		for d in group:
			if typeof(d) == TYPE_DICTIONARY:
				total_atk += d.get("magnitude_atk", 0)
				total_hp += d.get("magnitude_hp", 0)
	return {"atk": total_atk, "hp": total_hp}


func get_all_talents() -> Array[String]:
	var all_talents = get_talents_array()

	# 🔎 Cerca talenti aggiunti tramite buff (permanenti o temporanei)
	var all_buff_groups = [
		active_buffs,
		active_buffs_until_endphase,
		active_buffs_until_battlephase,
		active_buffs_until_battlestep,
		active_buffs_from_while_effects
	]

	for group in all_buff_groups:
		for b in group:
			if typeof(b) == TYPE_DICTIONARY and b.has("talent"):
				var t = b["talent"]
				if t != "None" and t not in all_talents:
					all_talents.append(t)

	return all_talents


func debug_print_all_modifiers() -> void:
	print("\n🧾 [ALL_STAT_MODIFIERS] —", card_name, ":")
	if all_stat_modifiers.is_empty():
		print("   (nessun modificatore attivo)")
		return

	for mod in all_stat_modifiers:
		if typeof(mod) != TYPE_DICTIONARY:
			continue

		var src = mod.get("source_card")
		var src_name = "?"
		if is_instance_valid(src) and src.card_data:
			src_name = src.card_data.card_name

		var atk = mod.get("magnitude_atk", 0)
		var hp = mod.get("magnitude_hp", 0)
		var arm = mod.get("magnitude_armour", 0)
		var mod_type = mod.get("type", "Unknown")
		var prefix = ""

		if mod_type == "Buff":
			prefix = "🔥 Buff"
		elif mod_type == "Debuff":
			prefix = "💀 Debuff"
		else:
			prefix = "❓ Modificatore"

		# Costruisci testo ATK
		var atk_text = ""
		if atk > 0:
			atk_text = "+" + str(atk) + " ATK"
		elif atk < 0:
			atk_text = str(atk) + " ATK"

		# Costruisci testo HP
		var hp_text = ""
		if hp > 0:
			hp_text = "+" + str(hp) + " HP"
		elif hp < 0:
			hp_text = str(hp) + " HP"
	
		var arm_text = ""
		if arm > 0:
			arm_text = "+" + str(arm) + " ARM"
		elif arm < 0:
			arm_text = str(arm) + " ARM"

		var magnitude_text = ""
		if atk_text != "" and hp_text != "":
			magnitude_text = atk_text + ", " + hp_text
		elif atk_text != "":
			magnitude_text = atk_text
		elif hp_text != "":
			magnitude_text = hp_text
		else:
			magnitude_text = "(nessun effetto numerico)"

		print(prefix, " da ", src_name, ": ", magnitude_text)

	print("─────────────────────────────\n")


func to_light_dict() -> Dictionary:
	return {
		"tooltip": tooltip_name,
		"card_name": card_name
	}
	
static func from_light_dict(data: Dictionary) -> CardData:
	var base := CardDatabase.get_card(data["tooltip"])
	if base == null:
		push_error("❌ Carta non trovata: " + data["tooltip"])
		return null

	var copy := base.make_runtime_copy()
	copy.card_name = data.get("card_name", "")
	return copy

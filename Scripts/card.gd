extends Node2D

class_name Card

@export var card_data: CardData

@onready var attack_label = $Attack
@onready var health_label = $Health
@onready var spell_multiplier_label = $SpellMultiplier
@onready var spell_duration_label = $SpellDuration
@onready var card_sprite = $CardImage
@onready var highlight_border = $HighlightBorder
@onready var red_highlight_border = $RedHighlightBorder
@onready var action_border = $ActionBorder
@onready var green_highlight_border = $GreenHighlightBorder
@onready var talent_icons_container: HBoxContainer = $TalentIconsContainer
@onready var debuff_icons_container: VBoxContainer = $DebuffIconsContainer
@onready var pivot = $Pivot
@onready var bg = $Pivot/Background
@onready var art = $Pivot/Art
@onready var frame = $Pivot/Frame
@onready var card_shadow = $Pivot/CardShadow
@onready var border = $Pivot/Border

var last_mouse_pos := Vector2.ZERO
var mouse_velocity := Vector2.ZERO

@export var drag_tilt_strength := 0.15
@export var drag_tilt_max := 20.0
@export var drag_skew_strength := 0.0006
@export var drag_scale_strength := 0.04
@export var drag_scale_max := 0.08
@export var drag_squash_strength := 0.0005

var auto_time := 0.0
@export var auto_speed := 1.2
@export var auto_strength := 0.6

@export var max_tilt := 10.0
@export var art_strength := 20.0     # prima era 20
@export var bg_strength := 100.0      # più basso = più profondità
@export var smooth := 200.0           # leggermente più reattivo
var hover_start_mouse_pos: Vector2 = Vector2.ZERO
var mouse_distance := 0.0
var base_tilt := 0.0
var tilt_sign := 1.0
var original_pivot_scale : Vector2 = Vector2(0.4,0.4)
var tilt_active := false

var target_offset := Vector2.ZERO
var hover_center := Vector2.ZERO

var target_skew := 0.0
var target_scale := Vector2(0.4,0.4)

signal hovered
signal hovered_off
signal summoned_on_field(card, position)
signal card_left_field(card, reason, is_for_tribute_summ)
signal changed_position(card, new_position)
signal lost_while_condition(card)
signal damage_taken(card, damage_amount)
signal damage_dealt(source_card, damage_amount: int, damage_type: String)
signal direct_damage_fully_resolved(card: Card, damage_amount: int, damage_type: String)


var red_border_tween: Tween

var player_has_triggered = false
var effect_stack_index: int = -1
var effect_triggering_player_id: int = -1
var effect_negated = false
var attack_negated = false
var hover_enabled: bool = true
var was_enchained: bool = false  # ✅ Diventa true se la carta è stata usata in una chain

var has_a_target = false
var is_being_targeted = false
var being_targeted_by_cards: Array = []
var aura_affected_cards: Array = []  # 👈 Carte attualmente influenzate da questa aura

var has_an_attack_target = false
var is_being_attacked = false
var being_attacked_by_cards: Array = []

var targeted_stack_count: int = 0
var hover_timer: Timer
var healed: bool = false
var stunned: bool = false
var frozen: bool = false
var rooted: bool = false
var is_elusive: bool = false
var has_magic_veil: bool = false
#var is_phys_immune: bool = false
var stun_timer: int = 0  # ⏳ Numero di turni rimanenti di Stun
var freeze_timer: int = 0
var root_timer: int = 0
var card_unique_id: String = ""

var equipped_to: Card = null     
var enchanted_to: Card = null         # 👉 Se questa carta è un EquipSpell, a chi è legata
var equipped_spells: Array[Card] = []     # 👉 Se questa carta è una creatura, quali equip le sono legati
var enchant_spells: Array[Card] = []

var TALENT_ICONS := {
	"Overkill": preload("res://Assets/TalentSprites/OVERKILL SPRITE.png"),
	"Berserker": preload("res://Assets/TalentSprites/BERSERKER SPRITE.png"),
	"Haste": preload("res://Assets/TalentSprites/HASTE SPRITE.png"),
	"Regeneration": preload("res://Assets/TalentSprites/REGEN SPRITE.png"),
	"Stun": preload("res://Assets/TalentSprites/STUN SPRITE.png"),
	"Taunt": preload("res://Assets/TalentSprites/TAUNT SPRITE.png"),
	"Flying": preload("res://Assets/TalentSprites/FLYING SPRITE.png"),
	"Double Strike": preload("res://Assets/TalentSprites/DOUBLE STRIKE SPRITE.png"),
	"Mastery": preload("res://Assets/TalentSprites/MASTERY SPRITE.png"),
	"Magical Taunt": preload("res://Assets/TalentSprites/MAGICAL TAUNT SPRITE.png"),
	"Reactivity": preload("res://Assets/TalentSprites/REACTIVITY SPRITE.png"),
	"Durability": preload("res://Assets/TalentSprites/DURABILITY SPRITE.png"),  #PER EQUIP
	"Freeze": preload("res://Assets/TalentSprites/FREEZE SPRITE.png"),
	"Ruthless": preload("res://Assets/TalentSprites/RUTHLESS SPRITE.png"),
	"Deathtouch": preload("res://Assets/TalentSprites/DEATHTOUCH SPRITE.png"),
	"Free Strike": preload("res://Assets/TalentSprites/FREE STRIKE SPRITE.png"),
	#"Lifesteal": preload("res://Assets/TalentSprites/LIFESTEAL SPRITE.png"),
	#"Charge": preload("res://Assets/TalentSprites/CHARGE SPRITE.png")
}

var TALENT_OVERLAYS := {
	"Elusive": preload("res://Assets/TalentOverlays/ELUSIVE OVERLAY.png"),
	"Magic Veil": preload("res://Assets/TalentOverlays/MAGIC VEIL OVERLAY.png"),
	"Phys Immune": preload("res://Assets/TalentOverlays/PHYS IMMUNE OVERLAY.png")
	#"Divine Shield": preload("res://Assets/TalentOverlays/DIVINE SHIELD OVERLAY.png")
}

var DEBUFF_ICONS := {
	"Stunned": preload("res://Assets/DebuffSprites/STUNNED SPRITE.png"),
	"Frozen": preload("res://Assets/DebuffSprites/FROZEN SPRITE.png"),
	"Rooted": preload("res://Assets/DebuffSprites/ROOTED SPRITE.png")
}

var NEGATED_ICON := {
	"Negated": preload("res://Assets/DebuffSprites/NEGATED SPRITE.png")
}

func _process(delta):

	if not hover_enabled or card_is_in_playerGY:
		return

	if original_pivot_scale == Vector2.ZERO:
		original_pivot_scale = pivot.scale

	# 🔹 Highlight target con CTRL
	if highlight_border.visible:
		var modifier_pressed = Input.is_key_pressed(KEY_CTRL)
		highlight_linked_target(modifier_pressed)

	var is_dragging = get_meta("is_dragging", false)

	# -------------------------------------------------
	# DRAG PHYSICS
	# -------------------------------------------------

	if is_dragging:

		var mouse_pos = get_global_mouse_position()

		mouse_velocity = (mouse_pos - last_mouse_pos) / max(delta, 0.0001)
		last_mouse_pos = mouse_pos

		# ----------------
		# TILT
		# ----------------

		var tilt = clamp(mouse_velocity.x * drag_tilt_strength, -drag_tilt_max, drag_tilt_max)

		pivot.rotation_degrees = lerp(
			pivot.rotation_degrees,
			tilt,
			delta * 12.0
		)

		# ----------------
		# SKEW ORIZZONTALE
		# ----------------

		var skew_target = clamp(mouse_velocity.x * drag_skew_strength, -0.25, 0.25)

		pivot.skew = lerp(
			pivot.skew,
			skew_target,
			delta * 10.0
		)

		# ----------------
		# SQUASH DIREZIONALE VERTICALE
		# ----------------

		var vy = mouse_velocity.y

		var squash = clamp(vy * drag_squash_strength, -drag_scale_max, drag_scale_max)

		var target_scale := original_pivot_scale

		if vy < 0:
			target_scale.y = original_pivot_scale.y - abs(squash)
		else:
			target_scale.y = original_pivot_scale.y - abs(squash)

		target_scale.x = original_pivot_scale.x + abs(squash) * 0.5

		pivot.scale = pivot.scale.lerp(
			target_scale,
			delta * 10.0
		)




	# -------------------------------------------------
	# PARALLAX
	# -------------------------------------------------

	if tilt_active:
		update_auto_parallax(delta)
	else:
		target_offset = target_offset.lerp(Vector2.ZERO, delta * smooth)

	art.position = art.position.lerp(
		target_offset * 1.0,
		delta * smooth
	)

	frame.position = frame.position.lerp(
		target_offset * 0.5,
		delta * smooth
	)

	bg.position = bg.position.lerp(
		target_offset * 0.25,
		delta * smooth
	)

	# -------------------------------------------------
	# HOVER TILT
	# -------------------------------------------------

	if tilt_active and not is_dragging:

		var mouse_pos = get_global_mouse_position()
		var diff = mouse_pos - hover_center

		var tilt_x = clamp(diff.x / 200.0, -1.0, 1.0)

		pivot.rotation_degrees = lerp(
			pivot.rotation_degrees,
			base_tilt + tilt_x * 2.0,
			delta * smooth
		)

func set_card_data(data: CardData) -> void:
	card_data = data
	card_data.init_original_stats()  # ✅ inizializza i valori originali
	update_card_visuals()
	play_flip_animation()

func play_flip_animation() -> void:
	var anim = get_node_or_null("AnimationPlayer")
	if anim:
		anim.play("card_flip")
		
func play_flip_to_facedown():
	var anim = get_node_or_null("AnimationPlayer")
	if anim:
		anim.play("card_flip_to_facedown")
		#spell_multiplier_label.visible = false
		#spell_duration_label.visible = false
		#if is_instance_valid(talent_icons_container):
			#var dur_icon = talent_icons_container.get_node_or_null("DurabilityIcon")
			#var dur2_icon = talent_icons_container.get_node_or_null("DurationIcon")
			#if dur_icon:
				#dur_icon.visible = false
			#if dur2_icon:
				#dur2_icon.visible = false
				
		# Nascondi label spell
	if attack_label:
		attack_label.visible = false
	if health_label:
		health_label.visible = false
	if spell_multiplier_label:
		spell_multiplier_label.visible = false
	if spell_duration_label:
		spell_duration_label.visible = false

	# 🔒 Nascondi interamente il container e le icone
	if is_instance_valid(talent_icons_container):
		talent_icons_container.visible = false
		for child in talent_icons_container.get_children():
			child.queue_free()  # 🔥 distrugge le icone invece di nasconderle
	
	var infinity_icon = get_node_or_null("InfinityIcon")
	if is_instance_valid(infinity_icon):
		infinity_icon.visible = false


	
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	var card_owner = "Player"
	
	if is_enemy_card():
		card_owner = "Opponent"
			
	combat_manager.handle_spellpower_on_destroy(self, card_owner)
	
	combat_manager.remove_aura_effects(self)
		
	# 🕒 Ripristina durata/durabilità quando la carta viene girata facedown
	if card_data.card_class in ["EquipSpell", "ContinuousSpell"] or card_data.temp_effect == "Enchant":
		if card_data.original_spell_duration > 0 and card_data.original_spell_duration < 100:
			card_data.spell_duration = card_data.original_spell_duration
			spell_duration_label.text = str(card_data.spell_duration)
			if card_data.spell_duration == card_data.original_spell_duration:
				spell_duration_label.modulate = Color(0, 0, 0)  # Nero (uguale)
			print("⏳ Ripristinata durata base per", card_data.card_name, "→", card_data.spell_duration)


	## 🧩 Se la carta girata facedown è una Equip → rimuovi i buff dal target
	#if card_data.effect_type == "Equip" and equipped_to and is_instance_valid(equipped_to):
		#var target = equipped_to
		#print("💥 Equip", card_data.card_name, "girata facedown → rimuovo buff da", target.card_data.card_name)
		#
		## 🧹 1️⃣ Rimuovi eventuali buff logici applicati da questa equip
		#target.card_data.remove_buff_by_source(self)
#
		## 🧠 2️⃣ Confronta i talenti originali con gli attuali, ma filtra solo quelli applicati da QUESTA equip
		#var original_talents = target.card_data.get_talents_array()    # Talenti base permanenti
		#var current_talents = target.card_data.get_all_talents()       # Talenti attuali (inclusi da buff/equip)
		#
		## Recupera tutti i buff attivi per capire da quale carta provengono i talenti
		#var all_buffs = target.card_data.get_buffs_array()
#
		#for t in current_talents:
			## 🔍 Se il talento NON è tra gli originali...
			#if not (t in original_talents):
				## ...controlla se è stato conferito proprio da QUESTA equip
				#var granted_by_this_equip = false
				#for b in all_buffs:
					#if typeof(b) == TYPE_DICTIONARY and b.get("type", "") == "BuffTalent" \
					#and b.get("source_card") == self and b.get("talent", "") == t:
						#granted_by_this_equip = true
						#break
				#
				#if granted_by_this_equip:
					#print("🚫 Rimuovo talento conferito da equip girata facedown:", t)
#
					## 🔸 Rimuovi visivamente l'icona o l'overlay associato
					#if t in target.TALENT_ICONS:
						#target._remove_icon(t)
					#elif t in target.OVERLAY_TALENTS:
						#target.remove_talent_overlay(t)
#
					## 🔸 Rimuovi il talento dalla card_data se era stato applicato come buff diretto
					#if target.card_data.talent_from_buff == t:
						#target.card_data.talent_from_buff = "None"
#
		## 🔄 3️⃣ Aggiorna visivamente i talenti dopo la rimozione
		#target.update_talent_icons()
		#target.update_card_visuals()
#
		## 🔗 4️⃣ Scollega riferimenti equip
		#target.equipped_spells.erase(self)
		#equipped_to = null
	# 🧩 Se la carta girata facedown è una Equip → rimuovi tutti i suoi effetti dal target
	if card_data.effect_type == "Equip" and equipped_to and is_instance_valid(equipped_to):
		var target = equipped_to
		print("💥 Equip", card_data.card_name, "girata facedown → rimuovo effetti da", target.card_data.card_name)

		if combat_manager and combat_manager.has_method("remove_equip_effects"):
			combat_manager.remove_equip_effects(self, target)

		# 🔗 Scollega riferimenti equip
		target.equipped_spells.erase(self)
		equipped_to = null

	# 🧩 Se la carta girata facedown è una Enchant → rimuovi tutti i suoi effetti dal target
	if card_data.temp_effect == "Enchant" and enchanted_to and is_instance_valid(enchanted_to):
		var target = enchanted_to
		print("💥 Enchant", card_data.card_name, "girata facedown → rimuovo effetti da", target.card_data.card_name)

		if combat_manager and combat_manager.has_method("remove_enchant_effects"):
			combat_manager.remove_enchant_effects(self, target)

		# 🔗 Scollega riferimenti enchant
		target.enchant_spells.erase(self)
		enchanted_to = null



func play_flip_to_faceup():
	var anim = get_node_or_null("AnimationPlayer")
	if anim:
		anim.play("card_flip_to_faceup")
		await get_tree().create_timer(0.1).timeout

	if spell_duration_label:
		spell_duration_label.visible = true

	# 🔓 Riattiva il container talenti
	if is_instance_valid(talent_icons_container):
		talent_icons_container.visible = true
		update_talent_icons()
		
	var infinity_icon = get_node_or_null("InfinityIcon")
	if is_instance_valid(infinity_icon):
		infinity_icon.visible = true

	# 🆕 --- NUOVO BLOCCO: aggiorna last_played_card e applica Spell Power ---
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
	
	await combat_manager.apply_player_bonuses(self, multiplayer.get_unique_id())
	
	if combat_manager and card_manager:
		var is_local_card = not is_enemy_card()
		if is_local_card and card_is_in_slot:
			# 📋 Aggiorna last played card
			combat_manager.set_last_played_card(self, multiplayer.get_unique_id())
			# ⚡ Applica effetti Spell Power (BuffSpellPower, BuffFireSpellPower, ecc.)
			await card_manager.apply_spell_power_effects(self, false)
	# 🆕 --- FINE NUOVO BLOCCO ---

		# 🧩 --- NUOVO BLOCCO: registra carte trigger phase ---
	if card_data.trigger_type == "On_UpKeepPhase" and position_type != "facedown":
		var player_id = multiplayer.get_unique_id()
		combat_manager.trigger_upkeep_cards.append({
			"card": self,
			"owner_id": player_id,
		})
		print("🧩 [LOCAL FLIP] Aggiunta carta On_UpKeepPhase:", card_data.card_name, "| Owner ID:", player_id)
		print("📋 Lista On_UpKeepPhase aggiornata:", combat_manager.trigger_upkeep_cards.map(func(e): return e.card.card_data.card_name))

	elif card_data.trigger_type == "On_EndPhase" and position_type != "facedown":
		var player_id = multiplayer.get_unique_id()
		combat_manager.trigger_endphase_cards.append({
			"card": self,
			"owner_id": player_id,
		})
		print("🧩 [LOCAL FLIP] Aggiunta carta On_EndPhase:", card_data.card_name, "| Owner ID:", player_id)
		print("📋 Lista On_EndPhase aggiornata:", combat_manager.trigger_endphase_cards.map(func(e): return e.card.card_data.card_name))


	# ⚡ SOLO CLIENT LOCALE: se la carta ha effetto OnPlay, entra in selection mode
	if combat_manager and card_manager:
		# Verifica se questa carta appartiene al giocatore locale
		var is_local_card = not is_enemy_card()

		if is_local_card and card_data and (card_data.effect_type == "OnPlay" or card_data.effect_type == "Aura" or card_data.effect_type == "Equip") and card_is_in_slot :
			print("✨ Carta scoperta localmente con effetto OnPlay:", card_data.card_name)
			
			await get_tree().create_timer(0.3).timeout  # piccolo delay per sicurezza visiva

			# Se è una spell, entra in modalità effetto
			if card_data.card_type == "Spell":
				
				# 🧩 Controllo e gestione Activation Cost
				if not card_manager.check_activation_cost(self):
					print("🚫 Costo di attivazione non soddisfatto → effetto non attivabile:", card_data.card_name)
					return

				# 🩸 Se il costo è di sacrificio, avvia la selezione tributo
				if card_data.activation_cost == "sacrificeAllyCreature":
					print("🩸 Attivazione effetto richiede sacrificio → entro in tribute selection (1).")
					card_manager.start_tribute_selection(self, 1)
					return  # blocca qui per attendere la selezione


				# 🔮 Altrimenti, comportamento standard spell
				if card_data.targeting_type == "Targeted":
					card_manager.enter_selection_mode(self, "effect")

					# 🧩 DELAY AZIONE COME IN gioca_carta_subito()
					if not combat_manager.pending_action_after_chain:
						print("⏳ [Action Delay] Flip Targeted → azione passerà dopo chain.")
						card_manager.action_consume_pending = true
						combat_manager.pending_action_after_chain = true
						combat_manager.pending_action_owner_id = multiplayer.get_unique_id()

				else:
					card_manager.trigger_card_effect(self)

					# 🧩 Effetto Untargeted → delay automatico come in gioca_carta_subito()
					if not combat_manager.pending_action_after_chain:
						print("⏳ [Action Delay] Flip Untargeted → azione passerà dopo chain.")
						card_manager.action_consume_pending = true
						combat_manager.pending_action_after_chain = true
						combat_manager.pending_action_owner_id = multiplayer.get_unique_id()

			
	# 🧩 --- NUOVO BLOCCO: passa azione se non delayata ---
	if combat_manager and card_manager:
		if not combat_manager.pending_action_after_chain:
			var phase_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/PhaseManager")
			if phase_manager:
				var my_id = multiplayer.get_unique_id()
				var peers = multiplayer.get_peers()
				if peers.size() > 0:
					var other_id = peers[0]
					print("♻️ [Action Switch] Nessun effetto dopo flip → passo azione all'altro peer:", other_id)
					phase_manager.rpc("rpc_give_action", other_id)
					phase_manager.rpc_give_action(other_id)
			else:
				print("⚠️ PhaseManager non trovato — impossibile passare l'azione!")
		else:
			print("⏳ [Action Delay] Flip già delayato → passerà dopo la chain.")
			
		#if is_instance_valid(talent_icons_container):
			#var dur_icon = talent_icons_container.get_node_or_null("DurabilityIcon")
			#var dur2_icon = talent_icons_container.get_node_or_null("DurationIcon")
			#if dur_icon:
				#dur_icon.visible = true
			#if dur2_icon:
				#dur2_icon.visible = true
				
		#update_talent_icons()
				
func set_visible_faceup():
	$CardBack.visible = false
	$CardImage.visible = true

func set_visible_facedown():
	$CardBack.visible = true
	$CardImage.visible = false

func play_rotate_to_defense():
	var anim = get_node_or_null("AnimationPlayer")
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	if anim:
		var player_id = multiplayer.get_unique_id()
		rpc("rpc_play_rotation_animation", player_id, self.name, "card_rotate_pos_to_def")
		anim.play("card_rotate_pos_to_def")
		
		#if "Berserker" in card_data.get_all_talents():
			#print("💥 [Rotation] Berserker non può stare in difesa → autodistruzione tra 1s!")
			#await get_tree().create_timer(0.3).timeout
			#play_talent_icon_pulse("Berserker")
			#await get_tree().create_timer(0.7).timeout
			#var owner = "Player" if not is_enemy_card() else "Opponent"
			#combat_manager.destroy_card(self, owner)
#
		## 🚫 Se la carta ha Elusive → perde il talento quando va in difesa
		#if "Elusive" in card_data.get_all_talents():
			#print("👁️‍🗨️ [Rotation] Elusive perso:", card_data.card_name)
			#is_elusive = false
			#remove_talent_overlay("Elusive")

func play_rotate_to_attack():
	var anim = get_node_or_null("AnimationPlayer")
	if anim:
		var player_id = multiplayer.get_unique_id()
		rpc("rpc_play_rotation_animation", player_id, self.name, "card_rotate_pos_to_attack")
		anim.play("card_rotate_pos_to_attack")
		
		#if "Elusive" in card_data.get_all_talents():
			#is_elusive = true
			#_add_talent_overlay("Elusive")

#signal clicked


var original_position: Vector2 #serve per "alzare" le carte hoverate in mano
var position_in_hand
var card_is_in_slot: bool = false
var current_slot: Node = null
var card_is_in_playerGY: bool = false
var effect_triggered_this_turn: bool = false
var attacked_this_turn: bool = false
var position_type: String = "attack" # di default
var already_changed_position_this_turn: bool = false #RIFERTIO AL CHANGE IN PREPARATION PHASE

func set_position_type(pos_type: String) -> void:
	var had_previous_position := position_type != "" and position_type != null
	var previous_position_type = position_type
	position_type = pos_type

	match position_type:
		"defense":
			if previous_position_type == "attack" and rotation_degrees != 90:
				play_rotate_to_defense()
				emit_signal("changed_position", self, position_type)
				print("📣 [SIGNAL] changed_position →", card_data.card_name, "→", position_type)
			else:
				rotation_degrees = 90
			print("🛡️ Posizione impostata su DEFENSE per:", card_data.card_name)

		"attack":
			if previous_position_type == "defense" and rotation_degrees != 0:
				play_rotate_to_attack()
				emit_signal("changed_position", self, position_type)
				print("📣 [SIGNAL] changed_position →", card_data.card_name, "→", position_type)
			else:
				rotation_degrees = 0
			print("⚔️ Posizione impostata su ATTACK per:", card_data.card_name)

		"faceup":
			play_flip_to_faceup()
			print("📜 Posizione impostata su FACEUP per:", card_data.card_name)

		"facedown":
			play_flip_to_facedown()
			print("🂠 Posizione impostata su FACEDOWN per:", card_data.card_name)
#
	## 🟢 --- EMISSIONE SEGNALI SOLO SE ESISTEVA UNA POSIZIONE PRECEDENTE ---
	#if had_previous_position and previous_position_type != position_type:
		#emit_signal("changed_position", self, position_type)
		#print("📣 [SIGNAL] changed_position →", card_data.card_name, "→", position_type)







func _ready() -> void:

	# forza materiale unico per ogni carta
	if border and border.material:
		var new_mat = border.material.duplicate(true)   # deep duplicate
		border.material = new_mat

		if new_mat is ShaderMaterial:
			new_mat.set_shader_parameter("time_offset", randf() * 100.0)

	scale = Vector2(1, 1)
	#for child in get_children():
		#print("Child:", child.name)
	#print("READY card: ", self.name)
	#print("Attack label:", attack_label)
	#print("Health label:", health_label)
	scale = Vector2(1, 1)
	original_pivot_scale = pivot.scale
	card_shadow.visible = false
	
	
	var current = get_parent()
	while current and not current.has_method("connect_card_signals"):
		current = current.get_parent()

	if current:
		current.connect_card_signals(self)

	if card_data:
		update_card_visuals()

	# 🧩 Connetti la carta ai propri segnali di posizione
	if not is_connected("summoned_on_field", Callable(self, "_on_self_summoned_on_field")):
		connect("summoned_on_field", Callable(self, "_on_self_summoned_on_field"))
	if not is_connected("changed_position", _on_self_changed_position):
		connect("changed_position", Callable(self, "_on_self_changed_position"))
	if not is_connected("lost_while_condition", Callable(self, "_on_self_lost_while_condition")):
		connect("lost_while_condition", Callable(self, "_on_self_lost_while_condition"))
	if not is_connected("damage_taken", Callable(self, "_on_self_damage_taken")):
		connect("damage_taken", Callable(self, "_on_self_damage_taken"))
	if not is_connected("damage_dealt", Callable(self, "_on_self_damage_dealt")):
		connect("damage_dealt", Callable(self, "_on_self_damage_dealt"))
	if not is_connected("card_left_field", Callable(self, "_on_card_left_field")):
		connect("card_left_field", Callable(self, "_on_card_left_field"))
	if not is_connected("direct_damage_fully_resolved", Callable(self, "on_direct_damage_fully_resolved")):
		connect("direct_damage_fully_resolved", Callable(self, "on_direct_damage_fully_resolved"))
	hover_timer = Timer.new()
	hover_timer.wait_time = 0.5
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)
	
func update_card_visuals():
	#card_data.init_original_stats() #"BUG RITORNA A MAX STAT DOPO DEBUFF E CHIAMATA UPDATE  SE IL DEBUFF PORTA A 0"
		# 🔥 Controllo se la carta ha lo stun e ha perso vita
	#if card_data.active_debuffs.has("Stunned"):
		#if card_data.health < card_data.max_health:
			#card_data.remove_debuff("Stunned")
			#update_debuff_icons()
			#print("✅ Stun rimosso da", card_data.card_name, " perché ha subito danno")
			#print("📛 Debuff rimanenti su ", card_data.card_name, ":", card_data.active_debuffs)
			#
			## 👉 Notifica agli altri peer passando anche player_id
			#var player_id = multiplayer.get_unique_id()
			#rpc("rpc_remove_debuff", player_id, self.name, "Stunned")
			
	if not attack_label or not health_label:
		print("❌ Errore: attack_label o health_label non trovati!")
		return
	print("🎨 ATK:", card_data.attack, " / ORIG:", card_data.original_attack)
	print("🎨 HP:", card_data.health, " / ORIG:", card_data.original_health)
	
	is_elusive = "Elusive" in card_data.get_all_talents() and position_type == "attack"
	has_magic_veil = "Magic Veil" in card_data.get_all_talents()
	#is_phys_immune = "Phys Immune" in card_data.get_all_talents()
	
	if healed:
		play_heal_animation()
		healed = false
		
	if card_data.card_type == "Creature":

		# ✅ Colore ATTACK
		# ✅ Colore ATTACK
		if card_data.attack > card_data.original_attack:
			attack_label.modulate = Color(0, 0.7, 0)  # Verde (aumentato)
		elif card_data.attack < card_data.original_attack:
			if card_data.max_attack < card_data.original_attack:
				attack_label.modulate = Color(0.69, 0.30, 0.90)  # Viola scuro (#b04de6)
			else:
				attack_label.modulate = Color(0.8 , 0, 0)  # Rosso (ridotto)
		else:
			attack_label.modulate = Color(0, 0, 0)  # Nero (normale)

		# Colore HEALTH
		if card_data.health > card_data.original_health:
			health_label.modulate = Color(0, 0.7, 0)
		elif card_data.health == card_data.max_health: 
			if card_data.max_health < card_data.original_health: # VUOL DIRE CHE E' DEBUFFATO
				health_label.modulate = Color(0.69, 0.30, 0.90)  # Viola scuro (#b04de6)
			else:
				health_label.modulate = Color(0, 0, 0)
		elif card_data.health < card_data.max_health: #E' DANNEGGIATO A PRECINDERE DAI DEBUFF A MAX HEALTH
			health_label.modulate = Color(0.8, 0, 0)


		# ✅ Imposta testo diretto (non usare add_text)
		attack_label.text = str(card_data.attack)
		health_label.text = str(card_data.health)
		#print("🎨 ATK:", card_data.attack, " / ORIG:", card_data.original_attack, " / MAX:", card_data.max_attack)
		#print("🎨 HP:", card_data.health, " / ORIG:", card_data.original_health, " / MAX:", card_data.max_health)
	else:
		attack_label.text = ""
		health_label.text = ""
		


	if spell_multiplier_label and not card_is_in_slot:
		if card_data.spell_multiplier > 0:
			spell_multiplier_label.visible = true
			spell_multiplier_label.text = str(card_data.spell_multiplier)
			# ✅ Colore in base alla differenza dall'originale
			if card_data.spell_multiplier > card_data.original_spell_multiplier:
				spell_multiplier_label.modulate = Color(0,  0.7, 0)  # Verde (aumentata)
			elif card_data.spell_multiplier < card_data.original_spell_multiplier:
				spell_multiplier_label.modulate = Color(0.8, 0, 0)  # Rosso (ridotta)
			else:
				spell_multiplier_label.modulate = Color(0, 0, 0)  # Nero (uguale)

		else:
			spell_multiplier_label.visible = false


	if spell_duration_label:
		if card_data.spell_duration > 0 and card_data.spell_duration < 100:
			spell_duration_label.visible = true
			spell_duration_label.text = str(card_data.spell_duration)
					# ✅ Colore in base alla differenza dall'originale
			if card_data.spell_duration > card_data.original_spell_duration:
				spell_duration_label.modulate = Color(0,  0.7, 0)  # Verde (aumentata)
			elif card_data.spell_duration < card_data.original_spell_duration:
				spell_duration_label.modulate = Color(0.8, 0, 0)  # Rosso (ridotta)
			else:
				spell_duration_label.modulate = Color(0, 0, 0)  # Nero (uguale)
		else:
			spell_duration_label.visible = false
			
			
	var card_sprite = $CardImage
	
	if card_sprite:
		if card_is_in_slot and card_data.card_field_sprite:
			# 👇 Se la carta è sul campo, usa la sprite alternativa
			card_sprite.texture = card_data.card_field_sprite
		else:
		# 👇 Sprite normale di base
			card_sprite.texture = card_data.card_sprite

			

	# --- Sprite retro ---
	var card_back = $CardBack
	if card_back:
		if card_is_in_slot and card_data.card_back_field:
			card_back.texture = card_data.card_back_field
		else:
			card_back.texture = card_data.card_back
			
	#print("🧙 Spell Mult:", card_data.spell_multiplier, "  Duration:", card_data.spell_duration)
			
var is_hovered := false

func _on_area_2d_mouse_entered() -> void:
	if hover_enabled and not card_is_in_playerGY:
		is_hovered = true
		emit_signal("hovered", self)
		if not is_in_hand():
			highlight_border.visible = true
		hover_timer.start()

func _on_area_2d_mouse_exited() -> void:
	if hover_enabled and not card_is_in_playerGY :
		is_hovered = false
		emit_signal("hovered_off", self)
	highlight_border.visible = false
	highlight_linked_target(false)
	hover_timer.stop()

	var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
	if preview_manager:
		preview_manager.hide_preview()


func _unhandled_input(event):
	if not is_hovered:
		return

	# 🔹 Se premo o rilascio Ctrl/Alt durante l'hover, aggiorno highlight target
	if event is InputEventKey:
		if event.keycode in [KEY_CTRL]:
			if event.pressed:
				if Input.is_key_pressed(KEY_CTRL):
					highlight_linked_target(true)
			else:
				highlight_linked_target(false)

func _on_hover_timer_timeout():
	var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
	if preview_manager:
		#preview_manager.show_preview(self.card_data)
		preview_manager.show_preview(self) #POTREBBE DARE BUG, LO FACCIO SOLO PERCHE MI SERVE PER IL TOOLTIP DEBUFF CHE DEVE TRACKARE I TIMER
		
	
func is_in_hand() -> bool:
	return position_in_hand != null and not card_is_in_slot and not card_is_in_playerGY
#func _input_event(viewport, event, shape_idx):
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		#emit_signal("clicked")

func is_enemy_card():
	return false

func is_card():
	return true
	
func update_z_index():
	if highlight_border.visible or (get_parent().has_method("is_card_selected") and get_parent().is_card_selected(self)):
		z_index = 999  # oppure un valore molto alto tipo 100
	elif card_is_in_slot:
		z_index = 0
	elif position_in_hand != null:
		z_index = 1
	else:
		z_index = 2  # per eventuali altri casi
		


func animate_red_border_pulse():
	var red_border = $RedHighlightBorder
	if not is_instance_valid(red_border):
		return

	# Reset visibilità e stato
	red_border.visible = true
	red_border.scale = Vector2(0.8, 0.8)
	#red_border.modulate.a = 0.0  # Per fade-in  SE LO METTI FA EFFETTO BLINK IN SUCCESSIVI PULSE IN CHAIN

	# ❌ Uccidi eventuali tween precedenti
	if red_border_tween and is_instance_valid(red_border_tween):
		red_border_tween.kill()
		red_border_tween = null  # <-- assicura reset totale

	# ✅ Crea nuovo tween da zero
	red_border_tween = create_tween()

	# Dissolvenza (fade-in) lineare
	red_border_tween.tween_property(red_border, "modulate:a", 1.0, 0.02)\
		.set_trans(Tween.TRANS_LINEAR)

	# Pulse (1.0 → 1.3)
	red_border_tween.tween_property(red_border, "scale", Vector2(1, 1), 0.08)\
		.set_trans(Tween.TRANS_LINEAR)

	# Ritorno (1.3 → 1.0)
	red_border_tween.tween_property(red_border, "scale", Vector2(0.8, 0.8), 0.08)\
		.set_trans(Tween.TRANS_LINEAR)



@rpc("any_peer")
func rpc_animate_red_border_pulse():
	animate_red_border_pulse()
	print("RPC DI ANIMATE RED BORDER RICEVUTO")


const OVERLAY_TALENTS = ["Elusive", "Magic Veil", "Phys Immune"]

func update_talent_icons() -> void:
	if not is_instance_valid(talent_icons_container):
		return

	# 🧹 1️⃣ Pulisci le vecchie icone e overlay
	for child in talent_icons_container.get_children():
		child.queue_free()

	for overlay in get_children():
		if overlay.name.ends_with("_Overlay"):
			overlay.queue_free()

	# 🧩 2️⃣ Mostra talenti solo se la carta è una CREATURA
	if card_data.card_type == "Creature":
		# Raccogli tutti i talenti attivi (base + da buff)
		var active_talents: Array[String] = []
		
		# - Talenti base
		active_talents.append_array(card_data.get_talents_array())
		
		# - Talenti da buff logici
		# - Talenti da tutti i buff attivi (inclusi temporanei)
		var all_buff_groups = [
			card_data.active_buffs,
			card_data.active_buffs_until_endphase,
			card_data.active_buffs_until_battlephase,
			card_data.active_buffs_until_battlestep
		]

		for group in all_buff_groups:
			for b in group:
				if typeof(b) == TYPE_DICTIONARY and b.get("type", "") == "BuffTalent" and b.has("talent"):
					var t = b["talent"]
					if t != "None" and t not in active_talents:
						active_talents.append(t)

		# 🎨 Ricrea solo le icone/overlay dei talenti attivi
		for t in active_talents:
			if t == "None":
				continue

			if t in OVERLAY_TALENTS:
				_add_talent_overlay(t)
				continue

			if TALENT_ICONS.has(t):
				_add_icon(t)

	# 🛡️ 3️⃣ Mostra icona Durability / Duration se necessario (anche per non-creature)
	if is_instance_valid(talent_icons_container):
		var existing_dur_icon = talent_icons_container.get_node_or_null("DurabilityIcon")

		if card_data.spell_duration > 0:
			if existing_dur_icon == null:
				var icon := TextureRect.new()
				icon.expand = true
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(19, 19)
				icon.z_index = 15
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 👈 aggiungi questa riga
				
				# 🧙‍♂️ Mostra icona solo per spell continue o equip
				if card_data.card_class == "ContinuousSpell":
					icon.name = "DurationIcon"
					icon.texture = preload("res://Assets/TalentSprites/DURATION SPRITE.png")
					talent_icons_container.position = Vector2(-75, 26)

				elif card_data.card_class == "EquipSpell":
					icon.name = "DurabilityIcon"
					icon.texture = preload("res://Assets/TalentSprites/DURABILITY SPRITE.png")
					talent_icons_container.position = Vector2(-75, 26)
					
				else:
					icon.queue_free()
					return

				talent_icons_container.add_child(icon)
		else:
			var duration_icon = talent_icons_container.get_node_or_null("DurationIcon")
			if duration_icon:
				duration_icon.queue_free()
			var durability_icon = talent_icons_container.get_node_or_null("DurabilityIcon")
			if durability_icon:
				durability_icon.queue_free()



func update_debuff_icons() -> void:
	if not is_instance_valid(debuff_icons_container):
		return

	# 🔹 Rimuovi solo le icone che non sono più presenti nei debuff attivi
	for child in debuff_icons_container.get_children():
		if child is TextureRect:
			var debuff_name = child.name.replace("Icon", "")
			var still_active := false

			for d in card_data.get_debuffs_array():
				if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == debuff_name:
					still_active = true
					break

			if not still_active:
				remove_debuff_icon_with_tween(child)

	# 🔹 Aggiungi eventuali nuove icone per i debuff attivi
	for d in card_data.get_debuffs_array():
		if typeof(d) == TYPE_DICTIONARY:
			var debuff_type = d.get("type", "")
			if debuff_type != "" and DEBUFF_ICONS.has(debuff_type):
				if not debuff_icons_container.has_node(debuff_type + "Icon"):
					_add_debuff_icon(debuff_type)

func remove_debuff_icon_with_tween(icon: TextureRect) -> void:
	if not is_instance_valid(icon):
		return

	var tween = create_tween()
	# 🔥 Solo fade-out, senza shrink
	tween.tween_property(icon, "modulate:a", 0.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.finished.connect(func():
		if is_instance_valid(icon):
			icon.queue_free()
	)

func _add_debuff_icon(debuff_name: String) -> void:
	var tex: Texture2D = DEBUFF_ICONS[debuff_name]
	var icon := TextureRect.new()
	icon.name = debuff_name + "Icon"
	icon.texture = tex
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(19, 19)
	icon.z_index = 15
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debuff_icons_container.add_child(icon)
		# 👉 Anima subito il nuovo debuff
	play_debuff_icon_pulse(debuff_name)

func _add_icon(talent_name: String) -> void:
	var tex: Texture2D = TALENT_ICONS[talent_name]
	var icon := TextureRect.new()
	icon.name = talent_name + "Icon"
	icon.texture = tex
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(19, 19)
	icon.z_index = 15
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 👈 aggiunto
	talent_icons_container.add_child(icon)

func _remove_icon(talent_name: String) -> void:
	var icon := talent_icons_container.get_node_or_null(talent_name + "Icon")
	if icon:
		var tween = create_tween()
		tween.tween_property(icon, "modulate:a", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
		tween.finished.connect(func():
			if is_instance_valid(icon):
				icon.queue_free())
		print("💨 [ICON] Rimossa icona talento:", talent_name)
		
func _add_talent_overlay(talent_name: String) -> void:
	if has_node(talent_name + "_Overlay"):
		return
	
	if not TALENT_OVERLAYS.has(talent_name):
		push_warning("⚠️ Overlay non trovato per talento: " + talent_name)
		return
	
	var overlay := Sprite2D.new()
	overlay.name = talent_name + "_Overlay"
	overlay.texture = TALENT_OVERLAYS[talent_name]
	overlay.z_index = 4
	overlay.position = Vector2(0, 7)
	overlay.scale = Vector2(1.1, 1.1)
	overlay.modulate = Color(1, 1, 1, 0) # 🔥 Inizia invisibile
	
	add_child(overlay)
	
	# 🌟 Fade-in fluido lineare
	var appear_tween := create_tween()
	appear_tween.tween_property(overlay, "modulate:a", 1.0, 0.6)\
		.set_trans(Tween.TRANS_SINE)

	# Quando il fade-in è finito, avvia l’animazione appropriata
	appear_tween.finished.connect(func():
		if talent_name == "Magic Veil":
			start_magic_veil_animation(overlay)
		else:
			start_overlay_animation(overlay))
	
	
func start_magic_veil_animation(overlay: Sprite2D) -> void:
	if not is_instance_valid(overlay):
		return

	# Evita duplicati
	if overlay.has_meta("magic_tween"):
		var old_tween: Tween = overlay.get_meta("magic_tween")
		if is_instance_valid(old_tween):
			old_tween.kill()

	var tween = create_tween()
	overlay.set_meta("magic_tween", tween)
	tween.set_loops()  # 🔁 loop infinito

	# ✨ Fade-out → pausa → fade-in → pausa
	tween.tween_property(overlay, "modulate:a", 0.2, 2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_interval(0.2)  # ⏸️ pausa dopo spegnimento
	tween.tween_property(overlay, "modulate:a", 1, 2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(1)  # ⏸️ pausa dopo accensione



func start_overlay_animation(overlay: Sprite2D) -> void:
	if not is_instance_valid(overlay):
		return

	# Evita di duplicare tween
	if overlay.has_meta("pulse_tween"):
		var old_tween: Tween = overlay.get_meta("pulse_tween")
		if is_instance_valid(old_tween):
			old_tween.kill()

	var tween = create_tween()
	overlay.set_meta("pulse_tween", tween)
	tween.set_loops()  # 🔁 loop infinito

	# Fade-out → pausa → fade-in → pausa
	tween.tween_property(overlay, "modulate:a", 0.6, 3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.5)  # ⏸️ pausa dopo spegnimento
	tween.tween_property(overlay, "modulate:a", 1, 3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(1)  # ⏸️ pausa dopo accensione
	
func remove_talent_overlay(talent_name: String) -> void:
	var overlay := get_node_or_null(talent_name + "_Overlay")
	if overlay:
		overlay.queue_free()

func set_in_graveyard(state: bool) -> void:
	card_is_in_playerGY = state
	$CardImage.visible = not state
	$CardBack.visible = not state
	$Attack.visible = not state
	$Health.visible = not state
	$HighlightBorder.visible = not state
	$RedHighlightBorder.visible = not state
	$ActionBorder.visible = not state
	#$GreenHighlightBorder.visible = not state

	# ❌ Nascondi eventuali talent icon
	for child in get_children():
		if child is TextureRect and child.name.ends_with("Icon"):
			child.visible = not state

	# 🧹 Se la carta va nel cimitero, rimuovi anche Duration/Durability icons
	if state:
		if is_instance_valid(talent_icons_container):
			var duration_icon = talent_icons_container.get_node_or_null("DurationIcon")
			if duration_icon:
				duration_icon.queue_free()

			var durability_icon = talent_icons_container.get_node_or_null("DurabilityIcon")
			if durability_icon:
				durability_icon.queue_free()
		
		effect_negated = false
		set_negated_state(false)
			# 🔹 Rimuovi eventuali icone di debuff
	if is_instance_valid(debuff_icons_container):
		for child in debuff_icons_container.get_children():
			if child is TextureRect:
				child.queue_free()

		# 🔹 Svuota anche l’array dei debuff attivi nella card_data (opzionale ma consigliato)
		card_data.active_debuffs.clear()
		stunned = false
		frozen = false
		rooted = false
		stun_timer = 0
		freeze_timer = 0
		root_timer = 0

func play_talent_icon_pulse(talent_name: String) -> void:
	if not is_instance_valid(talent_icons_container):
		return

	var icon: TextureRect = talent_icons_container.get_node_or_null(talent_name + "Icon")
	if not is_instance_valid(icon):
		print("❌ Nessuna icona trovata per talento:", talent_name)
		return

	# Kill eventuali tween precedenti
	if icon.has_meta("pulse_tween"):
		var old_tween: Tween = icon.get_meta("pulse_tween")
		if is_instance_valid(old_tween):
			old_tween.kill()

	var tween = create_tween()
	icon.set_meta("pulse_tween", tween)

	# Reset base
	icon.scale = Vector2(1, 1)
	icon.modulate = Color(1, 1, 1, 1)

	## ✅ Se la carta è in defense, la ruoti momentaneamente a 0°
	#if icon.rotation_degrees == 90:
		##icon.rotation_degrees = 90  # parte allineata con la carta
#
		## Vai a 0° mentre cresce
		#tween.parallel().tween_property(icon, "rotation_degrees", -90, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#else:
		#icon.rotation_degrees = 0

	# ✅ Effetto ingrandimento + "glow"
	tween.parallel().tween_property(icon, "scale", Vector2(2, 2), 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(icon, "modulate", Color(2, 2, 2, 1), 0.3).set_trans(Tween.TRANS_SINE)  # più luminoso

	# ✅ Ritorno a stato normale
	tween.tween_property(icon, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.3).set_trans(Tween.TRANS_SINE)
	
func play_debuff_icon_pulse(debuff_name: String) -> void:
	if not is_instance_valid(debuff_icons_container):
		return

	var icon: TextureRect = debuff_icons_container.get_node_or_null(debuff_name + "Icon")
	if not is_instance_valid(icon):
		print("❌ Nessuna icona trovata per debuff:", debuff_name)
		return

	# Kill eventuali tween precedenti
	if icon.has_meta("pulse_tween"):
		var old_tween: Tween = icon.get_meta("pulse_tween")
		if is_instance_valid(old_tween):
			old_tween.kill()

	var tween = create_tween()
	icon.set_meta("pulse_tween", tween)

	# Reset base
	icon.scale = Vector2(1, 1)
	icon.modulate = Color(1, 1, 1, 1)

	# ✅ Effetto ingrandimento + "glow" (rosso/grigio, per enfatizzare il debuff)
	tween.parallel().tween_property(icon, "scale", Vector2(2, 2), 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(icon, "modulate", Color(2, 0.3, 0.3, 1), 0.3).set_trans(Tween.TRANS_SINE)

	# ✅ Ritorno a stato normale
	tween.tween_property(icon, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.3).set_trans(Tween.TRANS_SINE)


func play_heal_animation():
	var heal_sprite := Sprite2D.new()
	heal_sprite.texture = preload("res://Assets/EffectSprites/HEAL SPRITE PARTICLE.png")
	heal_sprite.scale = Vector2(0.5, 0.5)
	heal_sprite.modulate = Color(1, 1, 1, 1)
	heal_sprite.z_index = 50
	add_child(heal_sprite)
	heal_sprite.position = Vector2(0, -20)

	# 🔥 Direzione animazione in base alla rotazione della carta
	var move_vector: Vector2
	if int(round(rotation_degrees)) % 180 == 90:
		# Carta in difesa → muovi in orizzontale
		move_vector = Vector2(-50, 0)
	else:
		# Carta in attacco (o faceup normale) → muovi in verticale
		move_vector = Vector2(0, -50)

	var tween = create_tween()
	tween.tween_property(heal_sprite, "position", heal_sprite.position + move_vector, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(heal_sprite, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_LINEAR)

	tween.finished.connect(func():
		if is_instance_valid(heal_sprite):
			heal_sprite.queue_free()
	)


	
@rpc("any_peer")
func rpc_play_heal_animation(player_id: int, card_name: String):
	var card: Node = null
	var is_owner = multiplayer.get_unique_id() == player_id

	if is_owner:
		# 👉 Carta locale
		card = $"../CardManager".get_node_or_null(card_name)
	else:
		# 👉 Carta avversaria
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/CardManager")
		if enemy_field:
			card = enemy_field.get_node_or_null(card_name)

	if card:
		card.play_heal_animation()
	else:
		push_error("❌ Carta non trovata per heal animation:", card_name)
		
@rpc("any_peer")
func rpc_remove_debuff(player_id: int, card_name: String, debuff_name: String):
	var card: Node = null
	var is_owner = multiplayer.get_unique_id() == player_id

	if is_owner:
		card = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager/" + card_name)
	else:
		card = get_tree().get_current_scene().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card and card.is_card():
		card.card_data.remove_debuff_type(debuff_name)
		card.update_debuff_icons()
		print("❌ Debuff", debuff_name, "rimosso da", card.card_data.card_name, "su client", multiplayer.get_unique_id())
	else:
		push_error("❌ Carta non trovata per remove_debuff:", card_name, "su client", multiplayer.get_unique_id())


@rpc("any_peer")
func rpc_sync_stun_state(player_id: int, card_name: String, is_stunned: bool):
	var card: Node = null
	var is_owner = multiplayer.get_unique_id() == player_id

	if is_owner:
		card = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager/" + card_name)
	else:
		card = get_tree().get_current_scene().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card and card.is_card():
		card.stunned = is_stunned
		if not is_stunned:
			card.card_data.remove_debuff_type("Stunned")
			card.update_debuff_icons()
		print("🌀 [SYNC RPC] Stun sync su", card.card_data.card_name, "→", is_stunned)
	else:
		push_error("❌ Carta non trovata per sync_stun_state:", card_name)


@rpc("any_peer")
func rpc_sync_freeze_state(player_id: int, card_name: String, is_frozen: bool):
	var card: Node = null
	var is_owner = multiplayer.get_unique_id() == player_id

	if is_owner:
		card = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager/" + card_name)
	else:
		card = get_tree().get_current_scene().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card and card.is_card():
		card.frozen = is_frozen
		if not is_frozen:
			card.card_data.remove_debuff_type("Frozen")
			card.update_debuff_icons()
		print("🌀 [SYNC RPC] Freeze sync su", card.card_data.card_name, "→", is_frozen)
	else:
		push_error("❌ Carta non trovata per sync_freeze_state:", card_name)
		
@rpc("any_peer")
func rpc_sync_root_state(player_id: int, card_name: String, is_rooted: bool):
	var card: Node = null
	var is_owner = multiplayer.get_unique_id() == player_id

	if is_owner:
		card = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager/" + card_name)
	else:
		card = get_tree().get_current_scene().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card and card.is_card():
		card.rooted = is_rooted
		if not is_rooted:
			card.card_data.remove_debuff_type("Rooted")
			card.update_debuff_icons()
		print("🌀 [SYNC RPC] Root sync su", card.card_data.card_name, "→", is_rooted)
	else:
		push_error("❌ Carta non trovata per sync_root_state:", card_name)
		
func set_negated_state(is_negated: bool) -> void:
	if not is_instance_valid(talent_icons_container):
		return

	var spell_dur = get_node_or_null("SpellDuration")

	if is_negated:
		# 🧹 Rimuovi tutte le altre talent icon esistenti
		for child in talent_icons_container.get_children():
			child.queue_free()
		# 🧹 Rimuovi anche la SpellDuration (o nascondila)
		if is_instance_valid(spell_dur):
			spell_dur.visible = false
			print("🚫 [NEGATED] SpellDuration nascosto su", card_data.card_name)
		print("🚫 [NEGATED] Tutte le talent icon rimosse da", card_data.card_name)
		await get_tree().process_frame

		# 🔸 Crea e mostra l’icona Negated
		var icon := TextureRect.new()
		icon.name = "NegatedIcon"
		icon.texture = preload("res://Assets/DebuffSprites/NEGATED SPRITE.png")
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(50, 20)
		icon.z_index = 15
		talent_icons_container.add_child(icon)
		talent_icons_container.position = Vector2(-60, 28)

		# 🔥 Effetto visivo "pulse"
		play_talent_icon_pulse("Negated")



	else:
		# ✅ Rimuovi eventuale icona Negated
		var neg_icon = talent_icons_container.get_node_or_null("NegatedIcon")
		if neg_icon:
			var tween = create_tween()
			tween.tween_property(neg_icon, "modulate:a", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
			tween.finished.connect(func():
				if is_instance_valid(neg_icon):
					neg_icon.queue_free())
			print("✅ [NEGATED] Icona rimossa da", card_data.card_name)

		# ✅ Riattiva SpellDuration se esiste e la carta non è facedown
		if is_instance_valid(spell_dur) and position_type != "facedown":
			spell_dur.visible = true
			print("✅ [NEGATED] SpellDuration riattivato su", card_data.card_name)



func _aura_target_matches_subtype(affected: Node, subtype: String) -> bool:
	if subtype == "None":
		return true

	match subtype:
		# 🧍‍♂️ Tutte le creature
		"AllCreatures":
			return affected.card_data.card_type == "Creature"

		# 🤝 Alleate
		"AllAllyCreatures":
			return affected.card_data.card_type == "Creature" and affected.is_enemy_card() == self.is_enemy_card()

		# ⚔️ Nemiche
		"AllEnemyCreatures":
			return affected.card_data.card_type == "Creature" and affected.is_enemy_card() != self.is_enemy_card()

		# 🛡️ Nemiche in difesa
		"AllEnemyDEFCreatures":
			return affected.card_data.card_type == "Creature" and affected.is_enemy_card() != self.is_enemy_card() and affected.position_type == "defense"

		# ⚔️ Nemiche in attacco
		"AllEnemyATKCreatures":
			return affected.card_data.card_type == "Creature" and affected.is_enemy_card() != self.is_enemy_card() and affected.position_type == "attack"

		# 🛡️ Alleate in difesa
		"AllAllyDEFCreatures":
			return affected.card_data.card_type == "Creature" and affected.is_enemy_card() == self.is_enemy_card() and affected.position_type == "defense"

		# ⚔️ Alleate in attacco
		"AllAllyATKCreatures":
			return affected.card_data.card_type == "Creature" and affected.is_enemy_card() == self.is_enemy_card() and affected.position_type == "attack"

		# ✨ Tutti gli incantesimi
		"AllSpells":
			return affected.card_data.card_type == "Spell"

		# 🔥 Incantesimi nemici
		"AllEnemySpells":
			return affected.card_data.card_type == "Spell" and affected.is_enemy_card() != self.is_enemy_card()

		# 🌿 Incantesimi alleati
		"AllAllySpells":
			return affected.card_data.card_type == "Spell" and affected.is_enemy_card() == self.is_enemy_card()

		# 🧍‍♀️ Giocatore stesso
		"SelfPlayer":
			return affected.is_in_group("self_player") or affected.name == "PlayerField"

		# 🧍‍♂️ Giocatore nemico
		"EnemyPlayer":
			return affected.is_in_group("enemy_player") or affected.name == "EnemyField"

		# 👥 Entrambi i giocatori
		"BothPlayers":
			return affected.is_in_group("self_player") or affected.is_in_group("enemy_player")

		# 🪄 Ultima creatura giocata
		"LastPlayedCreature":
			return affected.card_data.card_type == "Creature" and affected.has_meta("last_played")

		# 🌋 --- NUOVI SUBTYPE ELEMENTALI GLOABLI ---
		"AllFireCreatures":
			return affected.card_data.card_type == "Creature" and affected.card_data.card_attribute == "Fire"

		"AllEarthCreatures":
			return affected.card_data.card_type == "Creature" and affected.card_data.card_attribute == "Earth"

		"AllWaterCreatures":
			return affected.card_data.card_type == "Creature" and affected.card_data.card_attribute == "Water"

		"AllWindCreatures":
			return affected.card_data.card_type == "Creature" and affected.card_data.card_attribute == "Wind"

		# 🔥🌪️🌿💧 Varianti Enemy-only
		"AllEnemyFireCreatures":
			return affected.card_data.card_type == "Creature" \
				and affected.card_data.card_attribute == "Fire" \
				and affected.is_enemy_card() != self.is_enemy_card()

		"AllEnemyEarthCreatures":
			return affected.card_data.card_type == "Creature" \
				and affected.card_data.card_attribute == "Earth" \
				and affected.is_enemy_card() != self.is_enemy_card()

		"AllEnemyWaterCreatures":
			return affected.card_data.card_type == "Creature" \
				and affected.card_data.card_attribute == "Water" \
				and affected.is_enemy_card() != self.is_enemy_card()

		"AllEnemyWindCreatures":
			return affected.card_data.card_type == "Creature" \
				and affected.card_data.card_attribute == "Wind" \
				and affected.is_enemy_card() != self.is_enemy_card()

		# 🤝 Varianti Ally-only
		"AllAllyFireCreatures":
			return affected.card_data.card_type == "Creature" \
				and affected.card_data.card_attribute == "Fire" \
				and affected.is_enemy_card() == self.is_enemy_card()

		"AllAllyEarthCreatures":
			return affected.card_data.card_type == "Creature" \
				and affected.card_data.card_attribute == "Earth" \
				and affected.is_enemy_card() == self.is_enemy_card()

		"AllAllyWaterCreatures":
			return affected.card_data.card_type == "Creature" \
				and affected.card_data.card_attribute == "Water" \
				and affected.is_enemy_card() == self.is_enemy_card()

		"AllAllyWindCreatures":
			return affected.card_data.card_type == "Creature" \
				and affected.card_data.card_attribute == "Wind" \
				and affected.is_enemy_card() == self.is_enemy_card()

		_:
			# fallback di sicurezza
			return true


func highlight_linked_target(show: bool = true) -> void:
	var target: Card = null

	# --- DIREZIONE ORIGINALE: Equip/Enchant → Creatura ---
	# --- EQUIP o ENCHANT → evidenzia SOLO la creatura collegata ---
	if card_data.effect_type == "Equip" and equipped_to and is_instance_valid(equipped_to):
		equipped_to.highlight_border.visible = show
		return

	elif card_data.temp_effect == "Enchant" and enchanted_to and is_instance_valid(enchanted_to):
		enchanted_to.highlight_border.visible = show
		return

	# --- CREATURA → evidenzia i suoi equip/enchant collegati SOLO se hoverata ---
	if card_data.card_type == "Creature" and is_hovered:
		for equip in equipped_spells:
			if is_instance_valid(equip):
				equip.highlight_border.visible = show

		for enchant in enchant_spells:
			if is_instance_valid(enchant):
				enchant.highlight_border.visible = show

	# --- 🧹 FIX: se sto disattivando (show == false), spengo solo i border collegati ---
	if not show:
		# ⚠️ NON spegnere il border della carta hoverata!
		if target and is_instance_valid(target):
			target.highlight_border.visible = false

		for equip in equipped_spells:
			if is_instance_valid(equip):
				equip.highlight_border.visible = false

		for enchant in enchant_spells:
			if is_instance_valid(enchant):
				enchant.highlight_border.visible = false




func _on_self_changed_position(card: Card, new_position: String) -> void:
	if card != self:
		return

	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")

	match new_position:
		"defense":
			if "Berserker" in card_data.get_all_talents():
				print("💥 [Rotation] Berserker non può stare in difesa → autodistruzione tra 1s!")
				await get_tree().create_timer(0.3).timeout
				play_talent_icon_pulse("Berserker")
				await get_tree().create_timer(0.7).timeout
				var owner = "Player" if not is_enemy_card() else "Opponent"
				combat_manager.destroy_card(self, owner)

			# 🚫 Se la carta ha Elusive → perde il talento quando va in difesa
			if "Elusive" in card_data.get_all_talents():
				print("👁️‍🗨️ [Rotation] Elusive perso:", card_data.card_name)
				is_elusive = false
				remove_talent_overlay("Elusive")
			
			if card_data.trigger_type == "While_DEFpos":
				await get_tree().create_timer(0.3).timeout
				print("🛡️ [AUTO] While_DEFpos attivato per", card_data.card_name)
				if combat_manager.chain_locked:
					print("⏸️ [QUEUE] Chain attiva → accodo effetto in triggered_effects_this_chain_link")
					combat_manager.triggered_effects_this_chain_link.append({
						"card": self,
						"owner_id": multiplayer.get_unique_id()
					})
				elif card_manager and card_manager.has_method("trigger_card_effect"):
					print("CHAIN NON E' LOCKED")
					card_manager.trigger_card_effect(self)

		"attack":
			
			if "Elusive" in card_data.get_all_talents():
				is_elusive = true
				_add_talent_overlay("Elusive")
			
			if card_data.trigger_type == "While_ATKpos":
				await get_tree().create_timer(0.3).timeout
				print("⚔️ [AUTO] While_ATKpos attivato per", card_data.card_name)
				if combat_manager.chain_locked:
					print("⏸️ [QUEUE] Chain attiva → accodo effetto in triggered_effects_this_chain_link")
					combat_manager.triggered_effects_this_chain_link.append({
						"card": self,
						"owner_id": multiplayer.get_unique_id()
					})
				elif card_manager and card_manager.has_method("trigger_card_effect"):
					print("CHAIN NON E' LOCKED")
					card_manager.trigger_card_effect(self)

	# 🧹 --- NUOVO BLOCCO: rileva perdita della condizione While ---
	if card_data.trigger_type == "While_DEFpos" and new_position != "defense":
		print("🧹 [WHILE LOST] Carta", card_data.card_name, "ha perso condizione While_DEFpos → emetto segnale")
		emit_signal("lost_while_condition", self)

	elif card_data.trigger_type == "While_ATKpos" and new_position != "attack":
		print("🧹 [WHILE LOST] Carta", card_data.card_name, "ha perso condizione While_ATKpos → emetto segnale")
		emit_signal("lost_while_condition", self)
		
	# 🌬️ --- NUOVO BLOCCO: perdita validità per AURA "AllAllyDEFCreatures" ---
	if new_position == "attack":

		# 🔍 Controlla SOLO le aure proprie (creature o spell del player)
		var own_aura_sources: Array = []
		own_aura_sources.append_array(combat_manager.player_creatures_on_field)
		own_aura_sources.append_array(combat_manager.player_spells_on_field)

		for possible_aura in own_aura_sources:
			if not is_instance_valid(possible_aura):
				continue
			if possible_aura.card_data.effect_type != "Aura":
				continue

			# ✅ Aura che influenza le creature alleate in DEFENSE
			if possible_aura.card_data.t_subtype_1 == "AllAllyDEFCreatures":
				for entry in possible_aura.aura_affected_cards:
					if entry.has("card") and entry.card == self:
						print("🧹 [AURA REMOVE] ", self.card_data.card_name, "ha perso condizione DEF → rimuovo SOLO i suoi effetti di", possible_aura.card_data.card_name)
						combat_manager.remove_aura_effects(possible_aura, self)
						break
		## 🌱 --- NUOVO BLOCCO: guadagna condizione per AURA "AllAllyDEFCreatures" ---
	elif new_position == "defense":
		if card_manager and card_manager.has_method("apply_existing_aura_effect"):
			print("🌱 [AURA APPLY] ", card_data.card_name, "ora in DEF → controllo aure attive...")
			card_manager.apply_existing_aura_effect(self)
			
func _on_self_summoned_on_field(card: Card, position: String) -> void:
	if card != self:
		return
	
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
	if card_data.get_mana_cost() >= 4 or card_data.tributes > 0:
		combat_manager.play_summon_camera_impact(1.0)

	match position:
		"defense":
			if card_data.trigger_type == "While_DEFpos":
				await get_tree().create_timer(0.3).timeout
				print("🛡️ [AUTO] While_DEFpos attivato su summon per", card_data.card_name)
				if combat_manager.chain_locked:
					print("⏸️ [QUEUE] Chain attiva → accodo effetto in triggered_effects_this_chain_link")
					combat_manager.triggered_effects_this_chain_link.append({
						"card": self,
						"owner_id": multiplayer.get_unique_id()
					})
				elif card_manager and card_manager.has_method("trigger_card_effect"):
					print("CHAIN NON E' LOCKED")
					card_manager.trigger_card_effect(self)

		"attack":
			if card_data.trigger_type == "While_ATKpos":
				await get_tree().create_timer(0.3).timeout
				print("⚔️ [AUTO] While_ATKpos attivato su summon per", card_data.card_name)
				if combat_manager.chain_locked:
					print("⏸️ [QUEUE] Chain attiva → accodo effetto in triggered_effects_this_chain_link")
					combat_manager.triggered_effects_this_chain_link.append({
						"card": self,
						"owner_id": multiplayer.get_unique_id()
					})
				elif card_manager and card_manager.has_method("trigger_card_effect"):
					print("CHAIN NON E' LOCKED")
					card_manager.trigger_card_effect(self)


			
	if card_data.trigger_type == "While_NoOtherAlly" or card_data.trigger_type == "IF_NoOtherAlly":
		await get_tree().create_timer(0.3).timeout
		print("🧩 [AUTO] While_NoOtherAlly check su summon per", card_data.card_name)
		if combat_manager == null:
			print("❌ CombatManager non trovato!")
			return

		# 🔍 Determina se la carta è nemica o del giocatore locale
		var ally_creatures = []
		if is_enemy_card():
			ally_creatures = combat_manager.opponent_creatures_on_field
		else:
			ally_creatures = combat_manager.player_creatures_on_field

		# ✅ Filtra solo le creature valide, escludendo se stessa
		var valid_allies = []
		for c in ally_creatures:
			if is_instance_valid(c) and c != self:
				valid_allies.append(c)

		# ✅ Se non ci sono altre creature alleate → condizione soddisfatta
		if valid_allies.size() == 0:
			print("✨ [TRIGGER] While_NoOtherAlly/IF_NoOtherAlly attivato per", card_data.card_name)

			if combat_manager.chain_locked:
				print("⏸️ [QUEUE] Chain attiva → accodo effetto in triggered_effects_this_chain_link")
				combat_manager.triggered_effects_this_chain_link.append({
					"card": self,
					"owner_id": multiplayer.get_unique_id()
				})
			else:
				if card_manager and card_manager.has_method("trigger_card_effect"):
					card_manager.trigger_card_effect(self)

# 🧩 --- NUOVO BLOCCO: While_FieldFlooded ---

	if card_data.trigger_type == "While_FieldFlooded":
		await get_tree().create_timer(0.3).timeout
		print("🌊 [AUTO] While_FieldFlooded check su summon per", card_data.card_name)

		if combat_manager == null:
			print("❌ CombatManager non trovato!")
			return

		# 🔍 Controllo field flooded (basta uno slot)
		var zones = get_tree().get_current_scene().get_node_or_null("PlayerField/PlayerZones")
		if not zones:
			return

		var field_is_flooded := true
		for slot in zones.get_children():
			if not slot.flooded:
				field_is_flooded = false
				break

		if field_is_flooded:
			print("✨ [TRIGGER] While_FieldFlooded attivato per", card_data.card_name)

			if combat_manager.chain_locked:
				print("⏸️ [QUEUE] Chain attiva → accodo effetto in triggered_effects_this_chain_link")
				combat_manager.triggered_effects_this_chain_link.append({
					"card": self,
					"owner_id": multiplayer.get_unique_id()
				})
			else:
				if card_manager and card_manager.has_method("trigger_card_effect"):
					card_manager.trigger_card_effect(self)

func _on_ally_summoned(summoned_card: Card) -> void:
	if not is_instance_valid(summoned_card):
		return
	if summoned_card == self:
		return

	# ⚖️ Controlla solo evocazioni sullo stesso lato
	if summoned_card.is_enemy_card() != self.is_enemy_card():
		return

	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	if combat_manager == null:
		return

	var ally_creatures = []
	if is_enemy_card():
		ally_creatures = combat_manager.opponent_creatures_on_field
	else:
		ally_creatures = combat_manager.player_creatures_on_field

	# 🧩 Se ora c'è almeno un’altra creatura oltre a sé stessa, condizione persa
	var valid_allies = []
	for c in ally_creatures:
		if is_instance_valid(c) and c != self:
			valid_allies.append(c)

	if valid_allies.size() > 0:
		print("❌ [WHILE LOST] While_NoOtherAlly/IF_no_otherAlly perso da", card_data.card_name, "perché è entrata", summoned_card.card_data.card_name)
		emit_signal("lost_while_condition", self)


func _on_self_lost_while_condition(card: Card) -> void:
	if card != self:
		return

	print("🧹 [WHILE CLEANUP SIGNAL] Ricevuto lost_while_condition da", card_data.card_name)

	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	if combat_manager and combat_manager.has_method("remove_while_effects_from_source"):
		combat_manager.remove_while_effects_from_source(self,null)


func _on_self_damage_dealt(source_card: Card, damage_amount: int, damage_type: String) -> void:
	if source_card != self:
		return
	
	print("💥 [DAMAGE DEALT SIGNAL] Carta", source_card.card_data.card_name, 
		"ha inflitto", damage_amount, "danni di tipo", damage_type)
	
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")

	# Effetto visivo base
	if combat_manager:
		combat_manager.play_damage_dealt_screen_shake(damage_amount)

	## ⚡️ Se infligge danno diretto e ha trigger_type On_Direct_Damage_Self → triggera il proprio effetto
	#if damage_type == "direct_damage" and card_data.trigger_type == "On_Direct_Damage_Self":
		#await get_tree().create_timer(0.3).timeout
		#print("⚡ [TRIGGER] On_Direct_Damage_Self attivato per", card_data.card_name)
#
		#if combat_manager == null:
			#print("❌ CombatManager non trovato! Interruzione.")
			#return
#
		#if combat_manager.chain_locked:
			#print("⏸️ [QUEUE] Chain attiva → accodo effetto in triggered_effects_this_chain_link")
			#combat_manager.triggered_effects_this_chain_link.append({
				#"card": self,
				#"owner_id": multiplayer.get_unique_id()
			#})
		#else:
			#if card_manager and card_manager.has_method("trigger_card_effect"):
				#print("🚀 [TRIGGER] Chain non locked → attivo effetto immediato")
				#card_manager.trigger_card_effect(self)
			#else:
				#print("⚠️ CardManager non disponibile o senza trigger_card_effect")





func _on_self_damage_taken(card: Card, damage_amount: int) -> void:
	if card != self:
		return
	if damage_amount > 0:
		print("💢 [DAMAGE SIGNAL] Carta", card.card_data.card_name, "ha subito", damage_amount, "danni.")
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	combat_manager.play_damage_shake(self, damage_amount)



func _on_card_left_field(card: Card, reason: String, is_for_tribute_summ: bool) -> void:
	print("📣 [CARD SIGNAL] _on_card_left_field →", card.card_data.card_name, 
		"motivo:", reason, "| is_for_tribute_summ:", is_for_tribute_summ)

	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	if combat_manager and combat_manager.has_method("notify_card_left_field_global"):
		combat_manager.notify_card_left_field_global(card, reason, is_for_tribute_summ)
	else:
		print("⚠️ [CARD SIGNAL] CombatManager non trovato — impossibile notificare left_field globale.")


func on_direct_damage_fully_resolved(attacking_card: Card, damage_amount: int, damage_type: String) -> void:
	# Si attiva solo se la carta che ha finito il combat è proprio questa
	if attacking_card != self:
		print("NON SONO IO")
		return

	if card_data.trigger_type != "On_Direct_Damage_Self":
		print("NON CE L'HA")
		return

	print("⚡ [TRIGGER - END COMBAT] On_Direct_Damage_Self attivato per", card_data.card_name,
		"→ Danno:", damage_amount, "| Tipo:", damage_type)

	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")

	if not is_instance_valid(self):
		print("⚠️ [TRIGGER CANCEL] Carta non più valida al termine del combat.")
		return

	if combat_manager and combat_manager.chain_locked:
		print("⏸️ [QUEUE] Chain attiva → accodo effetto On_Direct_Damage_Self")
		combat_manager.triggered_effects_this_chain_link.append({
			"card": self,
			"owner_id": multiplayer.get_unique_id()
		})
	elif card_manager and is_instance_valid(self):
		card_manager.trigger_card_effect(self,true)


func show_next_card_buffed_border(show: bool, on_field: bool = false) -> void:
	var border := get_node_or_null("NextCardBuffedBorder")
	if not border:
		return

	border.visible = show

	if show:
		if on_field:
			border.scale = Vector2(0.8, 0.78)
		else:
			border.scale = Vector2(1.0, 1.0)
			
	## ✨ animazione SOLO in mano
	#if not on_field:
		#start_overlay_animation(border)



func update_parallax(mouse_pos: Vector2):

	var diff = mouse_pos - hover_center

	var nx = clamp(diff.x / 150.0, -1.0, 1.0)
	var ny = clamp(diff.y / 200.0, -1.0, 1.0)

	target_offset = Vector2(-nx, -ny) * art_strength 
	
func update_auto_parallax(delta):

	auto_time += delta * auto_speed

	# 🌊 Idle animation
	var nx = sin(auto_time * 0.8)
	var ny = cos(auto_time * 0.45)

	var auto_offset = Vector2(nx, ny) * art_strength * auto_strength

	# 🖱 Mouse micro interaction
	var mouse_pos = get_global_mouse_position()
	var diff = mouse_pos - hover_center

	var mx = clamp(diff.x / 140.0, -1.0, 1.0)
	var my = clamp(diff.y / 160.0, -1.0, 1.0)

	var mouse_offset = Vector2(mx, my) * art_strength * 0.35

	# 🔹 Combine
	target_offset = auto_offset + mouse_offset

func reset_card(delta):

	pivot.rotation_degrees = lerp(pivot.rotation_degrees, 0.0, delta * smooth)
	target_offset = target_offset.lerp(Vector2.ZERO, delta * smooth)

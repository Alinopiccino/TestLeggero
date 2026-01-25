extends PopupPanel

signal position_chosen(position_type: String)

@onready var creature_options = $CreatureOptions
@onready var spell_options = $SpellOptions

@onready var attack_preview = $CreatureOptions/AttackWrapper/AttackPreview
@onready var defense_preview = $CreatureOptions/DefenseWrapper/DefensePreview
@onready var faceup_preview = $SpellOptions/FaceupWrapper/FaceupPreview
@onready var facedown_preview = $SpellOptions/FacedownWrapper/FacedownPreview

const PREVIEW_SCALE := Vector2(0.35, 0.35)
const WRAPPER_MIN_SIZE := Vector2(50, 150)
#const HIGHLIGHT_PREVIEW_SCALE := Vector2(0.4, 0.4)
var choice_made = false
var preview_card_sprite: Texture
var card_back_texture: Texture = preload("res://Assets/CardImagesPreview/BackPreview2.png")
var trigger_in_progress_owner_id = -1
func _ready():

	
	attack_preview.pressed.connect(func(): _emit_choice("attack"))
	defense_preview.pressed.connect(func(): _emit_choice("defense"))
	faceup_preview.pressed.connect(func(): _emit_choice("faceup"))
	facedown_preview.pressed.connect(func(): _emit_choice("facedown"))
	
	
	
		# 🧠 Connessioni hover
	attack_preview.mouse_entered.connect(func(): _highlight_preview(attack_preview, true))
	attack_preview.mouse_exited.connect(func(): _highlight_preview(attack_preview, false))

	defense_preview.mouse_entered.connect(func(): _highlight_preview(defense_preview, true))
	defense_preview.mouse_exited.connect(func(): _highlight_preview(defense_preview, false))

	faceup_preview.mouse_entered.connect(func(): _highlight_preview(faceup_preview, true))
	faceup_preview.mouse_exited.connect(func(): _highlight_preview(faceup_preview, false))

	facedown_preview.mouse_entered.connect(func(): _highlight_preview(facedown_preview, true))
	facedown_preview.mouse_exited.connect(func(): _highlight_preview(facedown_preview, false))
	
	# 🔥 Collegamento per quando il popup si chiude senza scelta
	self.popup_hide.connect(_on_popup_hide)

func _highlight_preview(button: TextureButton, hovered: bool):
	# Salva la posizione iniziale solo una volta
	if not button.has_meta("base_position"):
		button.set_meta("base_position", button.position)

	var base_position: Vector2 = button.get_meta("base_position")

	# Se c'è già un tween attivo, lo uccidiamo per evitare conflitti
	if button.has_meta("hover_tween") and button.get_meta("hover_tween").is_valid():
		button.get_meta("hover_tween").kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button.set_meta("hover_tween", tween)

	var scale_target := Vector2(0.40, 0.40)
	var base_scale := PREVIEW_SCALE

	var delta := (scale_target - base_scale) * button.get_size() * 0.5
	if button == defense_preview:
		delta = Vector2(-delta.y, delta.x)

	if hovered:
		tween.parallel().tween_property(button, "scale", scale_target, 0.12)
		tween.parallel().tween_property(button, "position", base_position - delta, 0.12)
		button.z_index = 100
	else:
		tween.parallel().tween_property(button, "scale", base_scale, 0.12)
		tween.parallel().tween_property(button, "position", base_position, 0.12)
		button.z_index = 0







func _emit_choice(choice: String):
	print("📝 Scelta fatta:", choice)
	choice_made = true
	emit_signal("position_chosen", choice)
	hide()

	var card_manager = $"../CardManager"
	var combat_manager = $"../CombatManager"
	if card_manager.pending_card_to_place and card_manager.pending_slot_to_place:
		var card_to_play = card_manager.pending_card_to_place
		var tributes_needed = card_to_play.card_data.tributes
		
		card_to_play.set_meta("position_type", choice)
		
		if choice == "facedown":
			if card_to_play.card_data.card_type == "Spell" and card_to_play.card_data.spell_duration == 1000:
				print("⛔ FieldSpell non può essere giocata face-down → rimessa in mano:", card_to_play.card_data.card_name)
				_return_card_to_hand(card_manager, card_to_play)
				return
		# ⚙️ 🔥 FILTRO OnPlay → AllCreatures (solo se NON facedown)
		if choice != "facedown":
			if card_to_play.card_data.card_class == "InstantSpell":
				print("⛔ InstantSpell non può essere giocata face-up → rimessa in mano:", card_to_play.card_data.card_name)
				_return_card_to_hand(card_manager, card_to_play)
				return
			# ⚙️ 🩸 Controllo Activation Cost (helper unificata)
			if (card_to_play.card_data.effect_type == "OnPlay" or card_to_play.card_data.effect_type == "Equip"):
				if not card_manager.check_activation_cost(card_to_play):
					print("🚫 Costo di attivazione non soddisfatto per:", card_to_play.card_data.card_name)
					_return_card_to_hand(card_manager, card_to_play)
					return
				
				# ✅ Controlli aggiuntivi se ha effetto targeted
				#if card_to_play.card_data.targeting_type == "Targeted":
					#var subtype = card_to_play.card_data.t_subtype_1
					#
					#match subtype:
						#"AllAllyCreatures":
							## Serve almeno 2 alleate → 1 sacrificata + 1 come target
							#if player_creatures.size() < 2:
								#print("❌ Non ci sono abbastanza creature alleate (servono almeno 2) per giocare:", card_to_play.card_data.card_name)
								#_return_card_to_hand(card_manager, card_to_play)
								#return
						#
						#"AllEnemyCreatures":
							## Serve almeno 1 alleata da sacrificare + 1 nemica come target
							#if player_creatures.size() < 1 or enemy_creatures.size() < 1:
								#print("❌ Servono almeno 1 alleata e 1 nemica per giocare:", card_to_play.card_data.card_name)
								#_return_card_to_hand(card_manager, card_to_play)
								#return
						#
						#"AllCreatures":
							## Serve almeno 1 alleata (sacrificio) + 1 altra (alleata o nemica)
							#if player_creatures.size() < 1 or (player_creatures.size() + enemy_creatures.size()) < 2:
								#print("❌ Servono almeno 1 alleata e 1 altra creatura (alleata o nemica) per giocare:", card_to_play.card_data.card_name)
								#_return_card_to_hand(card_manager, card_to_play)
								#return

			# ⚙️ 🎯 Controllo Targeting normale per una spell perche' creature anceh con effetti targeted possono partire sempre.(senza sacrificio)

			if (card_to_play.card_data.effect_type in ["OnPlay", "Equip"]) and card_to_play.card_data.targeting_type == "Targeted" and not card_to_play.card_data.card_type == "Creature":
				var is_attacker = true  # sei sempre tu che giochi la carta
				var valid_targets = combat_manager.get_valid_targets(card_to_play, is_attacker)

				if valid_targets.is_empty():
					print("❌ Nessun target valido per Spell ", card_to_play.card_data.card_name, "→ carta annullata e restituita in mano.")
					_return_card_to_hand(card_manager, card_to_play)
					return
				else:
					print("🎯 Trovati", valid_targets.size(), "target validi per", card_to_play.card_data.card_name)

				
		# 🟡 Se la carta richiede tributi o sacrifici → entra in modalità selezione
		if tributes_needed > 0:
			print("🪙 La carta", card_to_play.card_data.card_name, "richiede", tributes_needed, "tributi.")
			card_manager.start_tribute_selection(card_to_play, tributes_needed, true) # 👈 aggiungi questo argomento per while no other allies
		elif card_to_play.card_data.activation_cost == "sacrificeAllyCreature" and choice != "facedown":
			print("🩸 La carta", card_to_play.card_data.card_name, "richiede il sacrificio di 1 creatura alleata.")
			card_manager.start_tribute_selection(card_to_play, 1)
		else:
			# Nessun tributo o sacrificio → gioca subito
			card_manager.gioca_carta_subito(card_to_play, card_manager.pending_slot_to_place)

	card_manager.pending_card_to_place = null
	card_manager.pending_slot_to_place = null


# 🧩 Funzione helper per riportare la carta in mano e resettare lo stato
func _return_card_to_hand(card_manager, card_to_play):
	card_to_play.visible = true
	card_manager.player_hand_reference.add_card_to_hand(card_to_play, card_manager.DEFAULT_CARD_MOVE_SPEED)
	card_to_play.z_index = card_manager.Z_INDEX_HAND
	card_manager.pending_card_to_place = null
	card_manager.pending_slot_to_place = null
	card_manager.is_position_popup_open = false


func prepare_for_creature(card_data: CardData):
	$"../CardManager".is_position_popup_open = true
	creature_options.visible = true
	spell_options.visible = false

	# Usa preview se disponibile, altrimenti la sprite normale
	preview_card_sprite = card_data.card_sprite_preview
	attack_preview.texture_normal = preview_card_sprite
	defense_preview.texture_normal = preview_card_sprite
	defense_preview.rotation_degrees = 90

	# 🔥 Aggiorna le label ATK/HP
	attack_preview.get_node("AtkLabel").text = str(card_data.attack)
	attack_preview.get_node("HpLabel").text = str(card_data.health)

	defense_preview.get_node("AtkLabel").text = str(card_data.attack)
	defense_preview.get_node("HpLabel").text = str(card_data.health)
	
	attack_preview.get_node("AtkLabel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_preview.get_node("HpLabel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	defense_preview.get_node("AtkLabel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	defense_preview.get_node("HpLabel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	attack_preview.scale = PREVIEW_SCALE
	defense_preview.scale = PREVIEW_SCALE

	# 🔥 Posizioni
	attack_preview.position = Vector2(140, 105)
	defense_preview.position = Vector2(-40, 155)
	
	
	
func prepare_for_spell(card_data: CardData):
	$"../CardManager".is_position_popup_open = true
	creature_options.visible = false
	spell_options.visible = true

	# Usa preview se disponibile
	preview_card_sprite = card_data.card_sprite_preview
	faceup_preview.texture_normal = preview_card_sprite
	facedown_preview.texture_normal = card_back_texture
	
	if card_data.spell_multiplier > 0:
		faceup_preview.get_node("SpellMultiLabel").text = str(card_data.spell_multiplier)
	if card_data.spell_duration > 0 and card_data.spell_duration < 100:
		faceup_preview.get_node("SpellDurLabel").text = str(card_data.spell_duration)

	faceup_preview.get_node("SpellMultiLabel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	faceup_preview.get_node("SpellDurLabel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	faceup_preview.get_node("SpellMultiLabel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	faceup_preview.get_node("SpellDurLabel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	faceup_preview.get_node("SpellDurLabel").position = Vector2(540, 902)
	
	faceup_preview.scale = PREVIEW_SCALE
	facedown_preview.scale = PREVIEW_SCALE

	# 🔥 Posizioni
	faceup_preview.position = Vector2(-340, 105)
	facedown_preview.position = Vector2(90, 105)
	
	# 🧩 Ripristina visibilità etichette
	if faceup_preview.has_node("SpellMultiLabel"):
		faceup_preview.get_node("SpellMultiLabel").visible = true
	if faceup_preview.has_node("SpellDurLabel"):
		faceup_preview.get_node("SpellDurLabel").visible = true
	if facedown_preview.has_node("SpellMultiLabel"):
		facedown_preview.get_node("SpellMultiLabel").visible = true
	if facedown_preview.has_node("SpellDurLabel"):
		facedown_preview.get_node("SpellDurLabel").visible = true


func _on_popup_hide():
	var card_manager = $"../CardManager"
	card_manager.is_position_popup_open = false  # 👈 reset
	
	# 🔥 Se ho fatto una scelta, NON ripiazzare la carta
	if choice_made:
		print("✅ Popup chiuso dopo scelta corretta, tutto ok.")
		choice_made = false  # Reset per il prossimo uso del popup
		return
	
	# 🔥 Se invece NON ho fatto scelta → rimetti carta in mano
	if card_manager.pending_card_to_place and card_manager.pending_slot_to_place:
		print("🔙 Popup chiuso senza scelta: carta rimessa in mano.")
		
		var card = card_manager.pending_card_to_place
		card.visible = true
		card_manager.player_hand_reference.add_card_to_hand(card, card_manager.DEFAULT_CARD_MOVE_SPEED)
		card.z_index = card_manager.Z_INDEX_HAND
		
		# ✅ Annulla il drag manualmente
		card_manager.highlight_card(card, false)
		card_manager.currently_hovered_card = null

		# ✅ Disattiva la preview drag (CardPreviewManager)
		var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
		if preview_manager:
			preview_manager.dragging = false

		# 👇 Reset degli slot mana
		$"../ManaSlots".set_all_slots_using(false)

		card_manager.pending_card_to_place = null
		card_manager.pending_slot_to_place = null
		# 🧹 Pulizia: nascondi e svuota etichette spell
		if faceup_preview.has_node("SpellMultiLabel"):
			faceup_preview.get_node("SpellMultiLabel").text = ""
			faceup_preview.get_node("SpellMultiLabel").visible = false
		if faceup_preview.has_node("SpellDurLabel"):
			faceup_preview.get_node("SpellDurLabel").text = ""
			faceup_preview.get_node("SpellDurLabel").visible = false
		if facedown_preview.has_node("SpellMultiLabel"):
			facedown_preview.get_node("SpellMultiLabel").text = ""
			facedown_preview.get_node("SpellMultiLabel").visible = false
		if facedown_preview.has_node("SpellDurLabel"):
			facedown_preview.get_node("SpellDurLabel").text = ""
			facedown_preview.get_node("SpellDurLabel").visible = false
			

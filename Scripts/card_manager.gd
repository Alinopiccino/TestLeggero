extends Node2D

@export var card_field_path: NodePath
@onready var card_field = get_node(card_field_path)
@onready var player_selection_label = $"../PromptLabels/PlayerSelectionLabel"

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2
const COLLISION_MASK_ENEMY_HOVER = 64  # Layer 7
const DEFAULT_CARD_MOVE_SPEED = 0.1
const CARD_SMALLER_SCALE = 1.0 #dimensione carta nella zone
const CARD_SLOT_HOVER_SCALE = 0.155 #hovering quando e' nella zone
const Z_INDEX_SLOT = 0 # Quando è piazzata sul campo
const Z_INDEX_HAND = 20       # Quando è nella mano
const Z_INDEX_HOVER = 30    # Quando ci passi sopra col mouse o stai trascinando
const Z_INDEX_HIGHLIGHT_BORDER = 10
const Z_INDEX_DRAG = 50

var selection_purpose: String = ""  # può essere "attack" oppure "effect"
var selection_is_forced: bool = false
var is_position_popup_open: bool = false
var opponent_selection_mode_active: bool = false
var action_consume_pending: bool = false

var screen_size
var card_being_dragged
var currently_hovered_card: Node = null
var player_hand_reference
var selected_card
var last_hovered_enemy = null
var offset = Vector2()
var selection_mode_active = false
var pending_card_to_place = null
var pending_slot_to_place = null


signal card_entered_attack_position(card)
signal card_entered_defense_position(card)

var previous_button_state := {
	"resolve": false,
	"retaliate": false,
	"direct_attack": false,
	"go_to_combat": false,
	"to_damage_step": false
}

func _ready() -> void:
	#add_to_group("Cards")
	screen_size = get_viewport_rect().size
	player_hand_reference = $"../PlayerHand"
	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)
	$"../PlayerGY".connect("gy_clicked", on_player_gy_clicked) #chatGPT
func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos= get_global_mouse_position()
		card_being_dragged.position = mouse_pos - offset
		# Annulla drag con tasto destro solo mentre si trascina
		if Input.is_action_just_pressed("right_click"):
			cancel_drag()
		#card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x), clamp(mouse_pos.y, 0, screen_size.y))
		# Hover per le carte nemiche
	handle_enemy_hover()
	
func cancel_drag():

	var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
	if preview_manager:
		preview_manager.dragging = false
		
	if card_being_dragged:
		player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
		card_being_dragged.z_index = Z_INDEX_HAND
		if currently_hovered_card:
			highlight_card(currently_hovered_card, false)
		currently_hovered_card = null  # <-- AGGIUNGI QUESTA LINEA
		# Forza il re-hover se il mouse è ancora sopra
		#var hovered_card = raycast_check_for_card()
		#if hovered_card == card_being_dragged:
			#highlight_card(card_being_dragged, true)


		card_being_dragged = null
		
			# 🔥 Ripristina gli slot
	$"../ManaSlots".set_all_slots_using(false)

func on_player_gy_clicked(): #chatGPT
	print("Hai cliccato sul cimitero!")

func on_left_click_released():
	#print("card managare released")
	if card_being_dragged:
		finish_drag()
		
		
#func card_clicked(card): #fatta da CHATGPT
	#if card.card_is_in_slot:
		#if $"../TurnManager".player_creatures_on_field.has(card):
			## Hai cliccato una tua creatura
			#if $"../TurnManager".opponent_cards_on_field.size() == 0:
				#
				#await $"../TurnManager".direct_attack(card, "Player")
			#else:
				#select_card_for_battle(card)
		#elif $"../TurnManager".opponent_cards_on_field.has(card) and selected_card:
			## Hai cliccato una creatura nemica mentre una tua è selezionata
			#await $"../TurnManager".attack(selected_card, card, "Player")
			## Deseleziona dopo l'attacco
			#selected_card.position += Vector2(0, 20)
			#selected_card = null

func card_clicked(card):
	var cm = $"../CombatManager"
	var local_id = multiplayer.get_unique_id()
	var pm = $"../PhaseManager"
	var action_buttons = $"../ActionButtons"
	var mana_manager := $"../ManaSlots"
	if card.attacked_this_turn:
		print ("HA GIA' ATTACCATO")
	if not card.attacked_this_turn:
		print ("NONNN HA GIA' ATTACCATO")
	if tribute_selection_active:
		print ("tribute selection attiva, se ne occupa input manager")
		return
	# 🧱 BLOCCO GLOBALE: se non hai azioni disponibili, disabilita click (tranne in green-border context)
	var green_border_context_active: bool = (
		action_buttons.resolve_button.visible or
		action_buttons.go_to_combat_button.visible or
		action_buttons.to_damage_step_button.visible or
		action_buttons.enchain_label.visible
	)
	
	
	if action_buttons and action_buttons.hourglass_icon and action_buttons.hourglass_icon.visible and not green_border_context_active:
		print("⛔ Click disabilitato: sto aspettando qualcosa (clessidra attiva)")
		return
		
	if pm.player_action_count == 0 and not green_border_context_active:
		print("⛔ Click disabilitato: nessuna azione disponibile (player_action_count = 0)")
		return
	# 🧭 Controllo posizione esatta dell'action container
	if pm and pm.actions_container:
		var pos = pm.actions_container.position
		# Usa una soglia di tolleranza (es. ±20 px) per evitare falsi positivi
		if pos.distance_to(Vector2(270, 580)) > 20 and not green_border_context_active:
			pm.player_action_count == 0
			print("⛔ Click ignorato: actions_container non è in (270,580). Posizione attuale:", pos)
			print("Per sicurezza imposto anche le mie action a 0.")
			return
	
	if card == null:
		return
	if card.card_is_in_playerGY:
		return

	# 🔒 Se chain non vuota e l'ultima carta è mia e chain non è ancora locked → blocca click
	if cm.effect_stack.size() > 0 and not cm.chain_locked:
		var last_entry = cm.effect_stack.back()
		if last_entry.player_id == local_id:
			print("⛔ Click disabilitato: sei l’ultimo ad aver messo carta nella chain")
			return

	# 🔒 Se la chain è locked → nessuna carta cliccabile
	if card.card_is_in_slot and cm.chain_locked:
		print("⛔ Click ignorato: chain_locked attiva → carta in campo non cliccabile:", card.name)
		return

	# 🧱 BLOCCO: se hai già chained in questo step e non ci sono bottoni attivi
	if (
		(cm.effect_stack.size() == 0 and not cm.chain_locked)
		and
		(
			(cm.already_chained_in_this_go_to_combat and not action_buttons.to_damage_step_button.visible and not action_buttons.resolve_button.visible)
			or
			(cm.already_chained_in_this_go_to_damage_step and not action_buttons.resolve_button.visible and not action_buttons.go_to_combat_button.visible)
		)
	):
		print("⛔ Input carte disattivato (già chained e nessun bottone attivo)")
		return

	# 🧩 Caso speciale Retaliate/OK
	if (action_buttons.retaliate_button.visible or action_buttons.ok_button.visible) and card.card_is_in_slot:
		print("⛔ Click ignorato: Retaliate/OK attivi, nessuna carta può essere cliccata:", card.name)
		return

	# 🧩 Durante altri bottoni (Resolve, Go to Combat, To Damage Step)
	# permetti solo instant o quick (controllato da helper)
	var priority_context_active: bool = (
		action_buttons.resolve_button.visible or
		action_buttons.go_to_combat_button.visible or
		action_buttons.to_damage_step_button.visible
	)

	if priority_context_active and card.card_is_in_slot and not selection_mode_active:
		if not $"../ActionButtons".can_card_be_enchained(card, cm):
			print("⛔ Click ignorato: carta non valida durante fase prioritaria:", card.name)
			return

	## 🔒 BLOCCO GREEN BORDER: clic consentito solo se la carta ha il bordo verde o è valida per enchain
	#if green_border_context_active and card.card_is_in_slot and not tribute_selection_active:
		#if not $"../ActionButtons".can_card_be_enchained(card, cm):
			#print("⛔ Click ignorato: carta non valida per enchain:", card.name)
			#return

	# 🚫 Blocca click per spell OnPlay/OnCast se non in green-border context
	if card.card_is_in_slot and not green_border_context_active and card.card_data.card_type == "Spell" and (
		card.card_data.trigger_type == "On_Play" or 
		card.card_data.trigger_type == "On_Cast" or 
		card.card_data.trigger_type == "On_Attack"
	):
		print("⛔ Click ignorato: spell OnPlay/OnCast/OnATK ma green border non attivo:", card.name)
		return

	# ✅ Se passa i filtri
	print("✅ Input carte consentito")

	# 🟢 Marca la carta come enchained se in green-border context e rpc
	if green_border_context_active and card.card_is_in_slot:
		if $"../ActionButtons".can_card_be_enchained(card, cm):
			card.was_enchained = true
			print("🟢 Carta marcata come ENCHAINATA:", card.name)

			# 🔁 Invia la sincronizzazione solo all’altro peer
			var peers = multiplayer.get_peers()
			if peers.size() > 0:
				var other_peer_id = peers[0]
				var owner_id = multiplayer.get_unique_id()
				print("📡 Invio RPC di ENCHAIN a peer:", other_peer_id, "per carta:", card.name)
				rpc_id(other_peer_id, "rpc_mark_card_as_enchained", card.name, owner_id)



	# 🧡 Carta NEMICA
	if card.has_method("is_enemy_card") and card.is_enemy_card():
		if selection_mode_active and selected_card:
			print("✅ Attacco/Effetto eseguito su:", card.name)
			cm.enemy_card_selected(card)
			exit_selection_mode(true)
		else:
			print("👀 Hai cliccato una carta nemica ma non sei in selection mode.")
		return

	# 🧡 Carta propria
	if card.card_is_in_slot:
		var phase = pm.current_phase
		var Phase = pm.Phase

		# ⚙️ Gestione spell face-down (flip)

		if card.card_data.card_type == "Spell" and card.position_type == "facedown":
			print("🎭 Tentativo flip spell:", card.card_data.card_name)

			#QUESTI PRIMI DUE CHECK SERVONO SOPRATTUTTO ALLE CARTE NORMAL TARGETE O CON COSTI DI ATTIVAZIONE
			# 🧩 [1] Controllo valid targets se spell è Targeted
			if card.card_data.targeting_type == "Targeted":
				var valid_targets = cm.get_valid_targets(card, true)
				if valid_targets.is_empty():
					print("🚫 Flip negato: nessun target valido per spell Targeted:", card.card_data.card_name)
					return

			# 🧩 [2] Controllo costi di attivazione → Sacrifice Ally Creature
			if not check_activation_cost(card):
				print("🚫 Flip negato: costo di attivazione non soddisfatto per:", card.card_data.card_name)
				return

			# Caso 1️⃣ → normale: la carta può essere enchained
			if $"../ActionButtons".can_card_be_enchained(card, cm):
				print("✅ Flip consentito (enchinabile):", card.card_data.card_name)
				swap_spell_position(card)
				return

			# Caso 2️⃣ → eccezione: non enchinabile ma condizioni alternative rispettate
			elif (
				pm.player_action_count > 0
				and not cm.chain_locked
				and pm.current_phase == pm.Phase.MAIN
				and card.card_data.card_class != "InstantSpell"
				and not cm.setted_this_turn.any(func(e): return e.card == card)
			):
				print("✅ Flip consentito (eccezione in MAIN):", card.card_data.card_name)
				swap_spell_position(card)
				return


		# Creature: solo a seconda della fase
		match phase:
			Phase.PREPARATION:
				var combat_manager = $"../CombatManager"
				# 🔧 PRIMA controlliamo gli Equip in Preparation
				if card.card_data.effect_type == "Equip" \
				and card.position_type != "facedown" \
				and (card.equipped_to == null or not is_instance_valid(card.equipped_to)):
					
					if card.effect_triggered_this_turn:
						print("⏳ Left-click ignorato: Equip già triggerato questo turno:", card.name)
						return
					print("🔧 Equip attivato in Preparation:", card.name)

					if card.card_data.targeting_type == "Targeted":
						enter_selection_mode(card, "effect")
					else:
						trigger_card_effect(card)

					# ⏳ Delay azione fino alla fine della chain
					
					if not combat_manager.pending_action_after_chain:
						print("⏳ [Action Delay] Equip → azione passerà solo dopo chain.")
						action_consume_pending = true
						combat_manager.pending_action_after_chain = true
						combat_manager.pending_action_owner_id = multiplayer.get_unique_id()

					return

				# 🔄 SE NON È UN EQUIP → comportamento normale
				print("♻️ Cambio posizione della creatura:", card.name)
				if card.card_data.card_type == "Creature":
					if card.rooted:
						print("🚫 LA CARTA È ROOTED:", card.name, "| ⏳ root_timer =", card.root_timer)
						card.play_debuff_icon_pulse("Rooted")
						return

					# 🚫 NON può cambiare posizione se evocata questo turno
					var summoned_this_turn = combat_manager.summoned_this_turn.any(
						func(e): return e.card == card
					)

					if summoned_this_turn:
						return
					if not card.already_changed_position_this_turn:
						swap_creature_position(card, true)
						card.already_changed_position_this_turn = true
						await get_tree().create_timer(0.3).timeout

						var phase_manager = get_node_or_null("../PhaseManager")




						# Se l'avversario ha già passato ma può ancora rispondere (chain window)
						if phase_manager.enemy_has_passed_this_phase and combat_manager.check_opponent_has_response(true) and not action_buttons.enemy_auto_skip_resolve:  #IMPOSTAZIONE AUTO-APPROVE
							print("⏳ [Chain Window] Avversario ha passato la phase ma può rispondere → apro Resolve per cambio posizione.")
							await cm.wait_for_resolve_choice(true)
							print("✅ [Resolve] Cambio posizione approvato, chiudo Resolve.")

							# 🔹 Nascondi manualmente il bottone Resolve dopo l’approvazione

							if action_buttons:
								action_buttons.hide_resolve_button()
								print("🧹 [Resolve] Bottoni Resolve e quindi viene rimostrato pass phase.")

						# ♻️ Dopo (eventuale) Resolve, passa azione 
						#if not phase_manager.enemy_has_passed_this_phase and not combat_manager.pending_action_after_chain:
						if not combat_manager.pending_action_after_chain:
							var peers = multiplayer.get_peers()
							if peers.size() > 0:
								var other_id = peers[0]
								print("♻️ [Action Switch] Dopo cambio posizione → passo azione all’altro peer:", other_id)
								phase_manager.rpc("rpc_give_action", other_id, true)  # 👈 true = from_attack ma funziona anche per change pos
								phase_manager.rpc_give_action(other_id, true)
						else:
							print("🚫 [Action Hold] Avversario ha già passato → non passo azione (resta turno attivo per Resolve/chain).")

						
					return

			# Fase di battaglia
			Phase.BATTLE:
				# ⚡ HASTE BATTLE STEP: solo creature con Haste possono attaccare
				if pm.haste_battle_step:
					if "Haste" not in card.card_data.get_all_talents():
						print("⛔ HASTE STEP attivo: creatura senza Haste non può attaccare:", card.name)
						return
				print("⚔️ Battaglia: selezioniamo per attacco:", card.name)
				if pm.player_action_count == 0 and not green_border_context_active:
					print("⛔ Click disabilitato: nessuna azione disponibile (player_action_count = 0)")
					return
				
				if card not in $"../CombatManager".player_creatures_on_field:
					return  # non è una creatura tua

				if card not in $"../CombatManager".player_creature_that_attacked_this_turn:
					# ⚠️ 🔥 NUOVO CONTROLLO: carta con 0 ATK non può attaccare
					if card.card_data.attack <= 0:
						print("🚫 La carta", card.card_data.card_name, "non può attaccare (ATK = 0)")
						return
					# 🔒 Check STUNNED e ELUSIVE
					if card.is_elusive:
						print("🚫 LA CARTA È ELUSIVE:", card.name)
							
					if card.stunned and card.position_type == "attack":
						print("🚫 LA CARTA È STUNNATA:", card.name, "| ⏳ stun_timer =", card.stun_timer)
						card.play_debuff_icon_pulse("Stunned")
						return
						
					if card.frozen and card.position_type == "attack":
						print("🚫 LA CARTA È FREEZATA:", card.name, "| ⏳ freze_timer =", card.freeze_timer)
						card.play_debuff_icon_pulse("Frozen")
						return

					# 🔥 🔥 🔥 CONTROLLO DIFESA + CAUTELA
					if card.position_type == "defense":
						print("🚫 Carta in difesa senza CAUTELA non può attaccare:", card.name)
						return

					# 💰 --- Controlla eventuali carte nemiche con effetto PayMana_for su on_attack ---
					var mana_cost_total := 0
					for c in $"../CombatManager".opponent_creatures_on_field:
						if c.card_data.trigger_type == "On_Attack" \
						and c.card_data.t_subtype_1 == "EnemyPlayer" \
						and c.card_data.effect_1 == "PayMana_for":
							mana_cost_total += int(c.card_data.effect_magnitude_1)

					for s in $"../CombatManager".opponent_spells_on_field:
						if s.card_data.trigger_type == "On_Attack" \
						and s.card_data.t_subtype_1 == "EnemyPlayer" \
						and s.card_data.effect_1 == "PayMana_for":
							mana_cost_total += int(s.card_data.effect_magnitude_1)

					if mana_cost_total > 0:
						print("💰 Highlight mana richiesto per attacco | costo totale:", mana_cost_total)
						var required: Array[String] = []
						for i in range(mana_cost_total):
							required.append("Colorless")
						$"../ManaSlots".highlight_required_slots(required)
						card.set_meta("attack_mana_cost", mana_cost_total)
					else:
						card.set_meta("attack_mana_cost", 0)
						

					# ✅ Se non ci sono difensori → attacco diretto
					if $"../CombatManager".opponent_creatures_on_field.size() == 0:
						# 💸 Se c'è un costo mana, spendilo subito (attacco diretto)
						if mana_cost_total > 0:
							print("💸 Spendo", mana_cost_total, "mana per effetto on_attack (Direct Attack)")
							await get_tree().create_timer(0.25).timeout
							$"../ManaSlots".spend_highlighted_slots()
							await get_tree().create_timer(0.25).timeout
						$"../CombatManager".direct_attack(card)
					else:
						enter_selection_mode(card, "attack")

				return

			Phase.START, Phase.MAIN, Phase.END:
				print("⏸️ Click ignorato su creature in questa fase.")
				return
	else:
		start_drag(card)

func swap_creature_position(card, from_click: bool = false):
	var new_position = "defense" if card.position_type == "attack" else "attack"
	var player_id = multiplayer.get_unique_id()

	if new_position == "defense":
		card.play_rotate_to_defense()
		rpc("rpc_play_card_rotation", player_id, card.name, "card_rotate_pos_to_def", from_click)
		# ✅ Controlla se la carta ha il talento Berserker
		if "Berserker" in card.card_data.get_all_talents():
			print("💥 [Rotation] Berserker non può stare in difesa → autodistruzione tra 1s!")
			await get_tree().create_timer(0.3).timeout
			card.play_talent_icon_pulse("Berserker")
			await get_tree().create_timer(0.7).timeout
			var owner = "Player" if not card.is_enemy_card() else "Opponent"
			$"../CombatManager".destroy_card(card, owner)

		# 🚫 Se la carta ha Elusive → perde il talento quando va in difesa
		if "Elusive" in card.card_data.get_all_talents():
			print("👁️‍🗨️ [Rotation] Elusive perso:", card.card_data.card_name)
			card.is_elusive = false
			card.remove_talent_overlay("Elusive")

	else:
		card.play_rotate_to_attack()
		rpc("rpc_play_card_rotation", player_id, card.name, "card_rotate_pos_to_attack", from_click)

		if "Elusive" in card.card_data.get_all_talents():
			card.is_elusive = true
			card._add_talent_overlay("Elusive")

	card.set_position_type(new_position)
	rpc("rpc_set_creature_position", player_id, card.name, new_position)


	## 🟢 --- EMISSIONE SEGNALI ---
	#card.emit_signal("changed_position", card, new_position)
	#print("📣 [SIGNAL] changed_position →", card.card_data.card_name, "→", new_position)


func swap_spell_position(card):
	var new_position = "facedown" if card.position_type == "faceup" else "faceup"
	var player_id = multiplayer.get_unique_id()
#
	#if new_position == "facedown":
		#card.update_talent_icons()  #POTREBBE NON SERVIRE
		#card.play_flip_to_facedown()
		#rpc("rpc_play_card_rotation", player_id, card.name, "card_flip_face")
	#else:
		#card.update_talent_icons()
		#card.play_flip_to_faceup()
		#rpc("rpc_play_card_rotation", player_id, card.name, "card_flip_face")
		
	card.set_position_type(new_position)
	rpc("rpc_set_spell_position", player_id, card.name, new_position)
		# 👇 AGGIUNGI QUESTO BLOCCO

@rpc("any_peer")
func rpc_play_card_rotation(player_id: int, card_name: String, animation_name: String, from_click: bool = false):
	var card: Node = null
	var is_attacker = multiplayer.get_unique_id() == player_id

	if is_attacker:
		card = $"../CardManager".get_node_or_null(card_name)
	else:
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/CardManager")
		if enemy_field:
			card = enemy_field.get_node_or_null(card_name)

	if card:
		var anim = card.get_node_or_null("AnimationPlayer")
		if anim:
			anim.play(animation_name)
	else:
		push_error("❌ Carta non trovata per rotazione animata:", card_name)
		return

	# 💥 Effetto TALENT BERSERKER
	if animation_name == "card_rotate_pos_to_def" and "Berserker" in card.card_data.get_all_talents():
		print("💥 [Rotation RPC] Berserker non può essere messo in difesa → autodistruzione tra 1s!")
		await get_tree().create_timer(0.3).timeout
		card.play_talent_icon_pulse("Berserker")
		await get_tree().create_timer(0.7).timeout
		var owner = "Player" if not card.is_enemy_card() else "Opponent"
		$"../CombatManager".destroy_card(card, owner)

	# 👁️‍🗨️ TALENT ELUSIVE
	if animation_name == "card_rotate_pos_to_def" and "Elusive" in card.card_data.get_all_talents():
		print("👁️‍🗨️ [Rotation RPC] Elusive perso: la carta", card.card_data.card_name, "è ora visibile e attaccabile.")
		card.is_elusive = false
		card.remove_talent_overlay("Elusive")

	if animation_name == "card_rotate_pos_to_attack" and "Elusive" in card.card_data.get_all_talents():
		card.is_elusive = true
		card._add_talent_overlay("Elusive")

	## 🟩 --- Highlight per enchain anche dopo una rotazione ---
	#if multiplayer.get_unique_id() != player_id and from_click:
		#print("🟩 [RPC ROTATION] Attivo green highlight su carte chainabili (avversario)")
		#var action_buttons = get_tree().get_current_scene().get_node_or_null("PlayerField/ActionButtons")
		#if action_buttons:
			#action_buttons.highlight_cards_for_enchain(true)
			#action_buttons.show_label($"../PromptLabels/PlayerEnchainLabel")

	# --- 🧩 [NUOVO BLOCCO] Fase di approvazione (Resolve) ---
	var pm = $"../PhaseManager"
	var cm = $"../CombatManager"
	var action_buttons = get_tree().get_current_scene().get_node_or_null("PlayerField/ActionButtons")

	# Solo lato ricevente (chi NON ha fatto la rotazione) e solo se derivata da click
	if multiplayer.get_unique_id() != player_id and from_click:
		var no_on_change_pos_effect = true
		if pm.has_passed_this_phase and no_on_change_pos_effect and not action_buttons.auto_skip_resolve:  #IMPOSTAZIONE AUTO-APPROVE self perche' si accende a me il bottone
			action_buttons.highlight_cards_for_enchain(true)
			action_buttons.show_label($"../PromptLabels/PlayerEnchainLabel")
			if cm.check_opponent_has_response(false):
				print("⏳ [ENEMY] Attendo approvazione (Resolve) per rotazione di:", card.card_data.card_name)
				await cm.wait_for_resolve_choice(false)
				print("✅ [ENEMY] Rotazione approvata:", card.card_data.card_name)



	
		
		
@rpc("any_peer")
func rpc_set_creature_position(player_id: int, card_name: String, new_position: String):
	var card = get_card_reference(player_id, card_name)
	if card:
		card.set_position_type(new_position)
	else:
		push_error("❌ Carta non trovata per cambio posizione (creatura):", card_name)



@rpc("any_peer")
func rpc_set_spell_position(player_id: int, card_name: String, new_position: String):
	var card = get_card_reference(player_id, card_name)
	if card:
		card.set_position_type(new_position)
		
		# 🔥 NON chiamare più play_flip_animation! (che è quella vecchia)
		
		# Se la carta è già in uno stato opposto, fa partire la corretta animazione:
		var anim = card.get_node_or_null("AnimationPlayer")
		var spell_dur = card.get_node_or_null("SpellDuration")
		var spell_multi = card.get_node_or_null("SpellMultiplier")
		var talent_icons_container = card.get_node_or_null("TalentIconsContainer")
		var infinity_icon = card.get_node_or_null("InfinityIcon")
		
		if anim:	
			anim.stop()
			if new_position == "faceup":
				anim.play("card_flip_to_faceup")
				await get_tree().create_timer(0.1).timeout

				if is_instance_valid(spell_dur):
					spell_dur.visible = true
				if is_instance_valid(talent_icons_container):
					talent_icons_container.visible = true
					if card.has_method("update_talent_icons"):
						card.update_talent_icons()
				if is_instance_valid(infinity_icon):
					infinity_icon.visible = true

				# 🔹 AGGIORNA ULTIMA CARTA GIOCATA (come se fosse appena "attivata")
				var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
				var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
				
				await combat_manager.apply_player_bonuses(card, player_id)
				if combat_manager:
					combat_manager.last_played_card = {
						"card": card,
						"owner_id": player_id
					}
					print("🃏 [RPC SPELL FLIP] Carta girata faceup:", card.card_data.card_name, "| Owner:", player_id)

					# 🆕 --- NUOVO BLOCCO: Applica Spell Power immediato ---
					if card_manager:
						var is_enemy = (multiplayer.get_unique_id() != player_id)
						print("⚡ [RPC SPELL FLIP] Applico Spell Power effect (is_enemy=%s)" % str(is_enemy))
						var should_defer = (
							card.card_data.effect_type == "Activable"
							or card.card_data.trigger_type != "None"
							or card.card_data.card_type == "Spell"
						)
						await card_manager.apply_spell_power_effects(card, is_enemy, should_defer)
					# 🆕 --- FINE NUOVO BLOCCO ---

					# 🧩 --- NUOVO BLOCCO: registra carte trigger phase anche lato RPC ---
					if card.card_data.trigger_type == "On_UpKeepPhase" and card.position_type != "facedown":
						var owner_id = player_id
						combat_manager.trigger_upkeep_cards.append({
							"card": card,
							"owner_id": owner_id,
						})
						print("🧩 [RPC FLIP] Aggiunta carta On_UpKeepPhase:", card.card_data.card_name, "| Owner ID:", owner_id)
						print("📋 Lista On_UpKeepPhase aggiornata:", combat_manager.trigger_upkeep_cards.map(func(e): return e.card.card_data.card_name))

					elif card.card_data.trigger_type == "On_EndPhase" and card.position_type != "facedown":
						var owner_id = player_id
						combat_manager.trigger_endphase_cards.append({
							"card": card,
							"owner_id": owner_id,
						})
						print("🧩 [RPC FLIP] Aggiunta carta On_EndPhase:", card.card_data.card_name, "| Owner ID:", owner_id)
						print("📋 Lista On_EndPhase aggiornata:", combat_manager.trigger_endphase_cards.map(func(e): return e.card.card_data.card_name))


					# 🔥 Attiva i green highlight solo per il giocatore opposto
					# 🚫 Ma NON se la carta appena flippata ha effetto OnPlay, è un Equip o un'Enchant/Aura
					if multiplayer.get_unique_id() != player_id:
						var is_on_play = card.card_data.effect_type == "OnPlay"
						var is_equip = card.card_data.effect_type == "Equip"
						var is_enchant = card.card_data.temp_effect == "Enchant"
						var action_buttons = get_tree().get_current_scene().get_node_or_null("PlayerField/ActionButtons")
						if not (is_on_play or is_equip or is_enchant) and not action_buttons.auto_skip_resolve:
							
							print("🟩 [RPC SPELL FLIP] Attivo green highlight su carte chainabili (avversario)")
							if action_buttons:
								action_buttons.highlight_cards_for_enchain(true)
								action_buttons.show_label($"../PromptLabels/PlayerEnchainLabel")
						else:
							print("⏸️ [RPC SPELL FLIP] Skip highlight: carta automatica (OnPlay / Equip / Aura)")


				# 👇 Aggiorna UI e rimuovi overlay mana
				hide_spent_mana_icons(card)
				var owner := "Opponent"
				if player_id == multiplayer.get_unique_id():
					owner = "Player"
				rpc("rpc_hide_spent_mana_on_card", card_name, owner)
				
				
								# 👇 AGGIUNGI QUESTO BLOCCO QUI
						#hide_spent_mana_icons(card)
					
					# Invia RPC agli altri client

				
			elif new_position == "facedown":
				anim.play("card_flip_to_facedown")

				# 🧩 Nascondi elementi grafici
				if is_instance_valid(spell_dur):
					spell_dur.visible = false
				if is_instance_valid(talent_icons_container):
					talent_icons_container.visible = false
					if card.has_method("update_talent_icons"):
						card.update_talent_icons()
				if is_instance_valid(infinity_icon):
					infinity_icon.visible = false

				var combat_manager = $"../CombatManager"
					# 💀 Se la carta girata facedown aveva buff di tipo SpellPower → rimuovili
				var card_owner = "Player"
				if card.is_enemy_card():
					card_owner = "Opponent"

				combat_manager.handle_spellpower_on_destroy(card, card_owner)


				if combat_manager:
					combat_manager.remove_aura_effects(card)


			# 🕒 Ripristina durata/durabilità quando la carta viene girata facedown
				if card.card_data.card_class in ["EquipSpell", "ContinuousSpell"] or card.card_data.temp_effect == "Enchant":
					if card.card_data.original_spell_duration > 0 and card.card_data.original_spell_duration < 100:
						card.card_data.spell_duration = card.card_data.original_spell_duration
						spell_dur.text = str(card.card_data.spell_duration)
						if card.card_data.spell_duration == card.card_data.original_spell_duration:
							spell_dur.modulate = Color(0, 0, 0)  # Nero (uguale)
						print("⏳ Ripristinata durata base per", card.card_data.card_name, "→", card.card_data.spell_duration)

				## 🧩 Se la carta girata facedown è una Equip → rimuovi i buff dal target
				#if card.card_data.effect_type == "Equip" and card.equipped_to and is_instance_valid(card.equipped_to):
					#var target = card.equipped_to
					#print("💥 Equip", card.card_data.card_name, "girata facedown → rimuovo buff da", target.card_data.card_name)
					#
					## 🧹 1️⃣ Rimuovi eventuali buff logici applicati da questa equip
					#target.card_data.remove_buff_by_source(card)
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
								#and b.get("source_card") == card and b.get("talent", "") == t:
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
					#target.equipped_spells.erase(card)
					#card.equipped_to = null
				# 🧩 Se la carta girata facedown è una Equip → rimuovi tutti i suoi effetti dal target
				if card.card_data.effect_type == "Equip" and card.equipped_to and is_instance_valid(card.equipped_to):
					var target = card.equipped_to
					print("💥 Equip", card.card_data.card_name, "girata facedown → rimuovo effetti da", target.card_data.card_name)

					if combat_manager and combat_manager.has_method("remove_equip_effects"):
						combat_manager.remove_equip_effects(card, target)

					# 🔗 Scollega riferimenti equip
					target.equipped_spells.erase(card)
					card.equipped_to = null

			

				# 🧩 Se la carta girata facedown è una Enchant → rimuovi tutti i suoi effetti dal target
				if card.card_data.temp_effect == "Enchant" and card.enchanted_to and is_instance_valid(card.enchanted_to):
					var target = card.enchanted_to
					print("💥 Enchant", card.card_data.card_name, "girata facedown → rimuovo effetti da", target.card_data.card_name)

					if combat_manager and combat_manager.has_method("remove_enchant_effects"):
						combat_manager.remove_enchant_effects(card, target)

					# 🔗 Scollega riferimenti enchant
					target.enchant_spells.erase(card)
					card.enchanted_to = null



				#if is_instance_valid(talent_icons_container):
					#var dur_icon = talent_icons_container.get_node_or_null("DurabilityIcon")
					#var dur2_icon = talent_icons_container.get_node_or_null("DurationIcon")
					#if dur_icon:
						#dur_icon.visible = false
					#if dur2_icon:
						#dur2_icon.visible = false
					# ✅ Forza visibilità coerente del container talenti
#
#---------------- FORSE RIMETTERE QUESTO SOTTO EVITEREBBE BUG:
			#if new_position == "facedown":
				#if is_instance_valid(talent_icons_container):
					#talent_icons_container.visible = false
					#for child in talent_icons_container.get_children():
						#child.visible = false
			#elif new_position == "faceup":
				#if is_instance_valid(talent_icons_container):
					#talent_icons_container.visible = true
					#card.update_talent_icons()

	else:
		push_error("❌ Carta non trovata per cambio posizione (spell):", card_name)

func set_spell_position(card_name: String, new_position: String):
	var card = $"../CardManager".get_node_or_null(card_name)
	if not card:
		card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)
	if card:
		card.set_position_type(new_position)
		card.play_flip_animation()
	else:
		push_error("❌ Non trovata carta per flip posizione:", card_name)
		
func get_card_reference(player_id: int, card_name: String):
	var is_attacker = multiplayer.get_unique_id() == player_id

	if is_attacker:
		return $"../CardManager".get_node_or_null(card_name)
	else:
		return get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)


func card_right_clicked(card):
	var cm = $"../CombatManager"
	var local_id = multiplayer.get_unique_id()
	var pm = $"../PhaseManager"

	var action_buttons = $"../ActionButtons"
	var green_border_context_active: bool = (
		action_buttons.resolve_button.visible or
		action_buttons.go_to_combat_button.visible or
		action_buttons.to_damage_step_button.visible or
		action_buttons.enchain_label.visible
	)
	
	if action_buttons and action_buttons.hourglass_icon and action_buttons.hourglass_icon.visible and not green_border_context_active:
		print("⛔ Right-Click disabilitato: sto aspettando qualcosa (clessidra attiva)")
		return
		
	if pm.player_action_count == 0 and not green_border_context_active:
		print("⛔ Right-click disabilitato: nessuna azione disponibile (player_action_count = 0)")
		return
	
	if cm.effect_stack.size() > 0 and not cm.chain_locked:
		var last_entry = cm.effect_stack.back()
		if last_entry.player_id == local_id:
			print("⛔ Right-click disabilitato: sei l’ultimo ad aver messo carta nella chain")
			return
			
	if card.card_is_in_slot and $"../CombatManager".chain_locked:
		print("⛔ Right-Click ignorato: chain_locked attiva → carta in campo non cliccabile:", card.name)
		return
		
	if (
		(cm.already_chained_in_this_go_to_combat and not $"../ActionButtons".to_damage_step_button.visible and not $"../ActionButtons".resolve_button.visible)
		or
		(cm.already_chained_in_this_go_to_damage_step and not $"../ActionButtons".resolve_button.visible and not $"../ActionButtons".go_to_combat_button.visible)
	):
		print("⛔ Input Right-click carte disattivato (già chained e nessun bottone attivo)")
		return
	
	if card.card_is_in_playerGY or not card.card_is_in_slot:
		return

	if selection_mode_active and selected_card == card:
		if card.effect_triggered_this_turn or (card.has_node("ActionBorder") and card.get_node("ActionBorder").visible):
			print("⏳ Ignorato right-click: carta già triggerata in attesa di RESOLVE:", card.name)
			return

	# 🔒 BLOCCO GREEN BORDER


	#if green_border_context_active:
		#var card_class = card.card_data.card_class
		#var effect_type = card.card_data.effect_type
		#var effect_speed = card.card_data.effect_speed
		#var is_valid = (
			#card_class == "InstantSpell" or
			#(effect_type == "Activable" and effect_speed == "Quick")
		#)
#
		#if not is_valid or not card.has_node("GreenHighlightBorder") or not card.get_node("GreenHighlightBorder").visible:
			#print("⛔ Click ignorato: carta non ha il bordo verde visibile o non è valida per enchain:", card.name)
			#return

	if card.position_type == "facedown":
		print("🚫 Non puoi attivare effetti su una carta coperta:", card.name)
		return

	# ✅ ✅ NUOVO BLOCCO: Equip attivabili anche con right-click in Preparation
	var current_phase = $"../PhaseManager".current_phase
	var Phase = $"../PhaseManager".Phase
	if current_phase == Phase.PREPARATION:
		if card.card_data.effect_type == "Equip" and card.position_type != "facedown" \
		and (card.equipped_to == null or not is_instance_valid(card.equipped_to)):
			
			if card.effect_triggered_this_turn:
				print("⏳ Right-click ignorato: Equip già triggerato questo turno:", card.name)
				return

			print("🔧 Equip attivato (right-click) in Preparation:", card.name)

			if card.card_data.targeting_type == "Targeted":
				enter_selection_mode(card, "effect")
			else:
				trigger_card_effect(card)

			# ⏳ Delay azione fino alla fine della chain
			var combat_manager = $"../CombatManager"
			if not combat_manager.pending_action_after_chain:
				print("⏳ [Action Delay] Equip (right-click) → azione passerà solo dopo chain.")
				action_consume_pending = true
				combat_manager.pending_action_after_chain = true
				combat_manager.pending_action_owner_id = multiplayer.get_unique_id()

			return
	var combat_manager = $"../CombatManager"
	if card.card_data.effect_type == "Activable":
		if current_phase != Phase.MAIN:
			print("⛔ Effetto 'Activable' attivabile solo in MAIN Phase:", card.name)
			return
		if card.frozen:
			print("🚫 LA CARTA È FREEZATA:", card.name, "| ⏳ freze_timer =", card.freeze_timer)
			card.play_debuff_icon_pulse("Frozen")
			return
		if card.stunned and card.position_type == "attack":
			print("🚫 LA CARTA È STUNNATA:", card.name, "| ⏳ stun_timer =", card.stun_timer)
			card.play_debuff_icon_pulse("Stunned")
			return
		if card.effect_triggered_this_turn:
			print("⏳ Effetto 'Activable' già attivato questo turno:", card.name)
			return
			# Non può essere già in attesa di RESOLVE
		if card.has_node("ActionBorder") and card.get_node("ActionBorder").visible:
			print("⏳ Carta già in attesa di RESOLVE:", card.name)
			return
		print("⚔️ Attivato effetto 'Activable' in Main Phase:", card.name)
		# Attiva effetto (targeted o no)
		
	# 🧹 Pulisci sempre just_summoned_creature e just_played_spell a meno che questa nuova carta sia enchained
		combat_manager.rpc_clear_just_happened_arrays()
		combat_manager.rpc("rpc_clear_just_happened_arrays")
			
		if card.card_data.targeting_type == "Targeted":
			enter_selection_mode(card, "effect")
		else:
			trigger_card_effect(card)

		return
				
	# ✅ Nuovo blocco: ActivableAttack (attivabili solo in Battle Phase)
	if card.card_data.effect_type == "ActivableAttack":
		# Deve essere in Battle Phase
		if current_phase != Phase.BATTLE:
			print("⛔ Effetto 'ActivableAttack' attivabile solo in Battle Phase:", card.name)
			return

		# Non può aver già attaccato
		if cm.player_creature_that_attacked_this_turn.has(card):
			print("⛔ Non puoi attivare 'ActivableAttack': la carta ha già attaccato questo turno:", card.name)
			return

		# Non può aver già usato l’effetto
		if card.effect_triggered_this_turn:
			print("⏳ Effetto 'ActivableAttack' già attivato questo turno:", card.name)
			return
		if card.frozen:
			print("🚫 LA CARTA È FREEZATA:", card.name, "| ⏳ freze_timer =", card.freeze_timer)
			card.play_debuff_icon_pulse("Frozen")
			return
		if card.stunned and card.position_type == "attack":
			print("🚫 LA CARTA È STUNNATA:", card.name, "| ⏳ stun_timer =", card.stun_timer)
			card.play_debuff_icon_pulse("Stunned")
			return
		# Non può essere già in attesa di RESOLVE
		if card.has_node("ActionBorder") and card.get_node("ActionBorder").visible:
			print("⏳ Carta già in attesa di RESOLVE:", card.name)
			return

		print("⚔️ Attivato effetto 'ActivableAttack' in Battle Phase:", card.name)
		
		# Attiva effetto (targeted o no)
		if card.card_data.targeting_type == "Targeted":
			enter_selection_mode(card, "effect")
		else:
			trigger_card_effect(card)

		return


			
func trigger_card_effect(card, from_triggered_effect: bool = false, card_that_caused_trigger: Card = null, effect_index: int = 0):
	var combat_manager = $"../CombatManager"

		
	if not combat_manager.pending_action_after_chain:
		print("⏳ [Action Delay] Effetto Untargeted → azione passerà solo dopo chain.")
		action_consume_pending = true
		combat_manager.pending_action_after_chain = true
		combat_manager.pending_action_owner_id = multiplayer.get_unique_id()
		
	$"../ActionButtons".hide_go_to_combat_button()
	$"../ActionButtons".hide_to_damage_step_button()

	if $"../CombatManager".chain_locked:
		if $"../ActionButtons".player_selection_label.visible:
			$"../ActionButtons".hide_label($"../ActionButtons".player_selection_label)
		if $"../ActionButtons".enchain_label.visible:
			$"../ActionButtons".hide_label($"../ActionButtons".enchain_label)
		$"../ActionButtons".force_hide_all_green_borders()
		print("🧹 Pulizia visiva: nascosto Target/Enchain/GreenBorder per chain_locked")

	card.player_has_triggered = true
	card.z_index = 5



 #QUANDO SI METTONO QUESTI EFFECT INDEX AFFIANCO AI CONTROLLI TARGETED E' PERCHE' RIGUARDA MYSTIC BLADE
	if not card.card_data.targeting_type == "Targeted" or effect_index != 0: #QUANDO SI METTONO QUESTI EFFECT INDEX AFFIANCO AI CONTROLLI TARGETED E' PERCHE' RIGUARDA MYSTIC BLADE
		var tween := create_tween()
		tween.tween_property(card, "position:y", card.position.y - 10, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if $"../ActionButtons".resolve_button.visible:
		$"../ActionButtons".hide_resolve_button(true)

	var owner = "Player"
	if card.is_in_group("EnemyCards"):
		owner = "Opponent"

	rpc("show_action_border_on_card", card.name, owner)
	rpc("move_triggered_card", card.name, owner)

	print("🔔 Carta", card.name, "effetto triggerato!")
	await get_tree().create_timer(0.2).timeout

	# ✅ Gestione differenziata se viene da process_triggered_effects_this_chain_link
	if card.card_data.targeting_type != "Targeted" or effect_index != 0: #EFFECT INDEX E' PER MYSTICAL BLADE
		var player_id = multiplayer.get_unique_id()
		var effect = card.card_data.effect_1
		var magnitude = card.card_data.effect_magnitude_1
		var t_subtype = card.card_data.t_subtype_1
		if card.has_node("GreenHighlightBorder"):
			card.get_node("GreenHighlightBorder").visible = false
			
		if from_triggered_effect:
			print("⚡ [TRIGGER EFFECT] RPC apply_untargeted_TRIGGER_effect")

			var trigger_cause_name := ""
			if card_that_caused_trigger != null:
				trigger_cause_name = card_that_caused_trigger.name
				
			print("⚡ [TRIGGER EFFECT] Chiamo RPC apply_untargeted_TRIGGER_effect_here_and_replicate_client_opponent")
			$"../CombatManager".rpc("apply_untargeted_TRIGGER_effect_here_and_replicate_client_opponent", player_id, card.name, effect, magnitude, t_subtype, true, trigger_cause_name,effect_index)
			await $"../CombatManager".apply_untargeted_TRIGGER_effect_here_and_replicate_client_opponent(player_id, card.name, effect, magnitude, t_subtype, true, trigger_cause_name,effect_index)
		else:
			print("✨ [NORMAL EFFECT] Chiamo RPC apply_untargeted_effect_here_and_replicate_client_opponent")
			$"../CombatManager".rpc("apply_untargeted_effect_here_and_replicate_client_opponent", player_id, card.name, effect, magnitude, t_subtype)
			$"../CombatManager".apply_untargeted_effect_here_and_replicate_client_opponent(player_id, card.name, effect, magnitude, t_subtype)



		
	
	
	## ✅ Aggiungi questo
	#exit_selection_mode()

@rpc("any_peer")
func show_action_border_on_card(card_name: String, owner: String):
	var card: Node = null
	
	# SE IL PROPRIETARIO E' "Player", vuol dire che il Player ha attaccato
	# Allora io (client) devo guardare l'EnemyField, non il mio CardManager
	if owner == "Player":
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/CardManager")
		if enemy_field:
			card = enemy_field.get_node_or_null(card_name)
	else:
		# Se l'owner è "Opponent", cerco in CardManager normale
		card = $"../CardManager".get_node_or_null(card_name)

	if card and card.has_node("ActionBorder"):
		card.get_node("ActionBorder").visible = true
		card.get_node("ActionBorder").z_index = -2
	else:
		print("❌ show_action_border_on_card: Carta non trovata o ActionBorder mancante:", card_name)
		
@rpc("any_peer")
func hide_action_border_on_card(card_name: String, owner: String):
	var card: Node = null
	 # andrebbe messo nella move_back_triggered_card , che non ho, e che servira' per le trigger che stickano su board
	if owner == "Player":
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/CardManager")
		if enemy_field:
			card = enemy_field.get_node_or_null(card_name)
	else:
		card = $"../CardManager".get_node_or_null(card_name)

	if card and card.has_node("ActionBorder"):
		card.get_node("ActionBorder").visible = false
		card.get_node("ActionBorder").z_index = -1
		card.z_index = 0 
	else:
		print("❌ hide_action_border_on_card: Carta non trovata o ActionBorder mancante:", card_name)
		
@rpc("any_peer")
func move_triggered_card(card_name: String, owner: String):
	var card = null
	
	if owner == "Opponent":
		card = get_node_or_null(card_name)
	elif owner == "Player":
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/CardManager")
		if enemy_field:
			card = enemy_field.get_node_or_null(card_name)

	if card and card.card_is_in_slot:
		card.z_index = 5
		#card.position.y += 10
		var tween := create_tween()
		tween.tween_property(card, "position:y", card.position.y + 10, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		print("❌ move_triggered_card: Carta non trovata o non in campo:", card_name)
		
func select_card_for_battle(card):
	if selected_card and selected_card == card:
		exit_selection_mode(true)
	else:
		if selected_card:
			exit_selection_mode(true)
		enter_selection_mode(card, "attack")

#func select_card_for_trigger(card):
	#if selected_card:
		#if selected_card == card:
			#card.position.y += 20
			#selected_card = null
		#else:
			#selected_card.position.y += 20
			#selected_card = card
			#card.position.y -= 20
	#else:
		#selected_card = card
		#card.position.y -= 20
func enter_selection_mode(card, purpose: String):
	var player_id = multiplayer.get_unique_id()
	rpc("rpc_notify_selection_mode_start", player_id, card.name, purpose)
	selection_mode_active = true
	selection_purpose = purpose
	selected_card = card
	if purpose == "effect":
		add_selection_overlay(card)
	elif purpose == "attack":
		add_attack_overlay(card)   # 👈 aggiungi overlay attacco
		# 💰 Controlla se sul campo nemico ci sono carte che richiedono pagamento mana su attacco
		#var mana_cost_total := 0
		#for c in $"../CombatManager".opponent_creatures_on_field:
			#if c.card_data.trigger_type == "On_Attack" \
			#and c.card_data.t_subtype_1 == "EnemyPlayer" \
			#and c.card_data.effect_1 == "PayMana_for":
				#mana_cost_total += int(c.card_data.effect_magnitude_1)
#
		#for s in $"../CombatManager".opponent_spells_on_field:
			#if s.card_data.trigger_type == "On_Attack" \
			#and s.card_data.t_subtype_1 == "EnemyPlayer" \
			#and s.card_data.effect_1 == "PayMana_for":
				#mana_cost_total += int(s.card_data.effect_magnitude_1)
#
		#if mana_cost_total > 0:
			#print("💰 Highlight mana richiesto per attacco | costo totale:", mana_cost_total)
			#var required: Array[String] = []
			#for i in range(mana_cost_total):
				#required.append("Colorless")
			#$"../ManaSlots".highlight_required_slots(required)
			#card.set_meta("attack_mana_cost", mana_cost_total)
		#else:
			#card.set_meta("attack_mana_cost", 0)

	# 🔧 Salva lo stato attuale dei bottoni
	previous_button_state = {
		"resolve": $"../ActionButtons".resolve_button.visible,
		"retaliate": $"../ActionButtons".retaliate_button.visible,
		"direct_attack": $"../ActionButtons".direct_attack_button.visible,
		"go_to_combat": $"../ActionButtons".go_to_combat_button.visible,
		"to_damage_step": $"../ActionButtons".to_damage_step_button.visible
	}
	# 🔥 Verifica se può attaccare direttamente
	if purpose == "attack" and card.card_data.card_type == "Creature":
		var has_already_attacked = card in $"../CombatManager".player_creature_that_attacked_this_turn
		var enemy_has_defenders = false
		var enemy_has_flying_defenders = false
		var enemy_has_taunt = false

		for c in $"../CombatManager".opponent_creatures_on_field:
			if c.position_type == "defense":
				enemy_has_defenders = true
				# 🕊️ Se la creatura in difesa ha "Flying" (anche da buff)
				var talents = c.card_data.get_all_talents()
				if "Flying" in talents:
					enemy_has_flying_defenders = true

		
		for c in $"../CombatManager".opponent_creatures_on_field:
			if "Taunt" in c.card_data.get_all_talents():
				enemy_has_taunt = true
				break
				
		# 🔥 Aggiunto controllo fase
		var current_phase = $"../PhaseManager".current_phase
		var Phase = $"../PhaseManager".Phase

		# ✅ Condizione aggiornata:
		var can_direct_attack := false

		# caso normale (Battle Phase)
		if current_phase == Phase.BATTLE and not has_already_attacked and not enemy_has_defenders and not enemy_has_taunt:
			can_direct_attack = true

		# caso speciale: TALENT ASSAULT
		if "Assault" in card.card_data.get_all_talents() and not has_already_attacked and not enemy_has_defenders and not enemy_has_taunt:
			can_direct_attack = true

		# caso speciale: TALENT FLYING (anche da buff)
		var attacker_talents = card.card_data.get_all_talents()
		if "Flying" in attacker_talents and not has_already_attacked and not enemy_has_flying_defenders:
			can_direct_attack = true
		
		if can_direct_attack:
			$"../ActionButtons".show_direct_attack_button()
			
	if card.card_data.card_type == "Creature" or card.card_data.effect_type == "Activable" or card.card_data.effect_type == "OnPlay" or card.card_data.effect_type == "On_Trigger" or card.card_data.effect_type == "Equip":
		card.z_index = 19
		#card.position.y -= 10  # Alza la carta visivamente
		var tween := create_tween()
		tween.tween_property(card, "position:y", card.position.y - 10, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	card.action_border.visible = true
	print("🎯 Selection mode attiva con:", card.name)
	
	$"../ActionButtons".show_label(player_selection_label)
	$"../ActionButtons".highlight_cards_for_enchain(false)

	if purpose == "attack":
		player_selection_label.text = "[color=green]SELECT[/color] AN ENEMY TO ATTACK"
	elif purpose == "effect":
		player_selection_label.text = "[color=green]SELECT[/color] A TARGET FOR EFFECT"
	elif purpose == "tribute_selection":
		player_selection_label.text = "[color=green]SELECT[/color] TRIBUTES"


func exit_selection_mode(selection_resolved := false):
	var player_id = multiplayer.get_unique_id()
	rpc("rpc_notify_selection_mode_end", player_id)
	if selected_card:
		if selection_purpose == "effect":
			remove_selection_overlay(selected_card)
		elif selection_purpose == "attack":
			remove_attack_overlay(selected_card)   # 👈 rimuove icona attacco
			
		if not selection_resolved:
			$"../ManaSlots".set_all_slots_using(false) #QUESTO SERVE PER EVENTUALI SEELECTION CHE RICHIEDONO MANA
		# IN QUESTO CHECK QUI SOTTO HO AGIGUNTO ANCHE AND NOT SELECTION RESOLVED , ASSIEME AD AVER MESSO L'ARG TRUE IN ON DIRECT ATTACK CHOSEN NELLA CHIAMATA EXIT SELECTION
		if not (selected_card.card_data.effect_type == "Activable" or selected_card.card_data.effect_type == "OnPlay") and not selection_purpose == "Effect" and not selection_resolved:
			var tween := create_tween()
			tween.tween_property(selected_card, "position:y", selected_card.position.y + 10, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		selected_card.z_index = Z_INDEX_SLOT
		selected_card.action_border.visible = false
		selected_card.action_border.z_index = -1

	selection_is_forced = false
	selection_mode_active = false
	selection_purpose = ""

	var allow_restore_resolve = true

	# ❌ Blocca restore solo se la selezione ha avuto esito (target scelto)
	if selection_resolved and $"../CombatManager".chain_resolving_in_progress:
		allow_restore_resolve = false

	$"../ActionButtons".update_buttons_visibility(
		allow_restore_resolve and previous_button_state["resolve"],
		previous_button_state["retaliate"],
		previous_button_state["direct_attack"],
		previous_button_state["go_to_combat"],
		previous_button_state["to_damage_step"]
	)
	if not selection_resolved:
		$"../ActionButtons".update_pass_phase_button_state() #AGGIUNTO PER EVITARE BUG CHE QUANDO SI ANNULLA SELECITON CON CLICK DESTRO
														  #SI NASCONDE IL PASS PHASE

	$"../ActionButtons".hide_label(player_selection_label)
	print("❌ Selection mode disattivata")
	
# ⚡ HASTE BATTLE STEP: ri-evidenzia tutte le creature valide con Haste
	if not selection_resolved:
		var pm = $"../PhaseManager"
		var cm = $"../CombatManager"

		if pm.haste_battle_step and pm.current_phase == pm.Phase.BATTLE:
			for card in cm.player_creatures_on_field:
				# solo creature pronte ad attaccare
				if card.position_type != "attack":
					continue

				# deve avere Haste
				if "Haste" not in card.card_data.get_all_talents():
					continue

				# non deve essere bloccata
				if card.stunned or card.frozen:
					continue

				# bordo verde
				if card.has_node("GreenHighlightBorder"):
					card.get_node("GreenHighlightBorder").visible = true
			
	selected_card = null

@rpc("any_peer")
func rpc_notify_selection_mode_start(player_id: int, card_name: String, purpose: String):
	var is_owner = multiplayer.get_unique_id() == player_id
	if not is_owner:
		opponent_selection_mode_active = true
		print("📡 [SYNC] L'avversario è entrato in selection mode per:", purpose)

@rpc("any_peer")
func rpc_notify_selection_mode_end(player_id: int):
	var is_owner = multiplayer.get_unique_id() == player_id
	if not is_owner:
		opponent_selection_mode_active = false
		print("📡 [SYNC] L'avversario ha terminato la selection mode")



func unselect_selected_card():
	exit_selection_mode()

func start_drag(card):
	
	var cm = $"../CombatManager"
	if cm.effect_stack.size() > 0:
		print("🚫 Drag disabilitato: chain attiva")
		return
	
		# 👇 Nascondi preview attiva (se presente)
	# 🔒 Blocca la preview
	var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
	if preview_manager:
		preview_manager.hide_preview()
		preview_manager.dragging = true   # 👈 segnala che siamo in drag
		
	card_being_dragged = card
	card.scale = Vector2(1, 1)
	card.z_index = Z_INDEX_DRAG


	
	# Calcola l'offset tra il centro della carta e il mouse al momento del click
	var mouse_pos = get_global_mouse_position()
	var card_center = card.position
	offset = mouse_pos - card_center
	
	# 🔥 Cambia gli slot in "Using"
	var mana_costs = card.card_data.get_mana_cost_array()
	print("🔮 Mana richiesti da", card.card_data.card_name, ":", mana_costs)
	$"../ManaSlots".highlight_required_slots(mana_costs)

	#card.position = get_global_mouse_position()
	
func finish_drag():
	card_being_dragged.scale = Vector2(1, 1)
	var card_slot_found = raycast_check_for_card_slot()
	var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
	if preview_manager:
		preview_manager.dragging = false
	
	var phase_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/PhaseManager")
	if phase_manager.current_phase != phase_manager.Phase.MAIN:
		print("⛔ Non puoi giocare carte fuori dalla Main Phase! (fase attuale:", phase_manager.get_phase_name(), ")")
		player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
		card_being_dragged.z_index = Z_INDEX_HAND
		card_being_dragged = null
		$"../ManaSlots".set_all_slots_using(false)
		return

	var mana_costs = card_being_dragged.card_data.get_mana_cost_array()
	var mana_manager := $"../ManaSlots"

	if not mana_manager.can_pay_cost(mana_costs):
		print("❌ Mana insufficiente per", card_being_dragged.card_data.card_name)

		# 🔴 Lampeggia TUTTI gli slot richiesti
		mana_manager.flash_required_slots(mana_costs)

		# ↩️ Ritorna la carta in mano
		player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
		card_being_dragged.z_index = Z_INDEX_HAND
		card_being_dragged = null

		# 🔥 Reset highlight USING
		mana_manager.set_all_slots_using(false)
		return

	
	# ✅ Se siamo in MAIN PHASE, prosegue il normale piazzamento
	if card_slot_found and card_slot_found.card_in_slot == null: #ANCHE CHECK TRIBUTI SUBITO DOPO
		
		if card_being_dragged.card_data.card_type == card_slot_found.card_slot_type:
			#if card_being_dragged.card_data.effect_type == "OnPlay":
				#if card_being_dragged.card_data.t_subtype == "AllCreatures":
					#if $"../CombatManager".player_creatures_on_field.size() == 0 and $"../CombatManager".opponent_creatures_on_field.size() == 0:
						#print("non ci sono creature targettabili")
						#player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
						#card_being_dragged.z_index = Z_INDEX_HAND
						#card_being_dragged = null
						#
						#return


			# 🧩 Controllo tributi (vengono escluse le just summoned)
			var cm = $"../CombatManager"

			var valid_tribute_creatures = cm.player_creatures_on_field.filter(func(c):
				return not cm.summoned_this_turn.any(func(entry):
					return entry.card == c
				)
			)

			if card_being_dragged.card_data.tributes <= valid_tribute_creatures.size():
				# 🔥 Non posizionare subito! Salva e apri il popup
				pending_card_to_place = card_being_dragged
				pending_slot_to_place = card_slot_found

				var popup = $"../ChoosePositionPopup"
				if card_being_dragged.card_data.card_type == "Creature":
					popup.prepare_for_creature(pending_card_to_place.card_data)
				elif card_being_dragged.card_data.card_type == "Spell":
					popup.prepare_for_spell(pending_card_to_place.card_data)

				card_being_dragged.visible = false
				popup.popup_centered()

				card_being_dragged = null
				return
			else:
				# ❌ Mancano i tributi necessari (considerando solo creature valide)
				player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
				card_being_dragged.z_index = Z_INDEX_HAND

				

		else:

			
			player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
			card_being_dragged.z_index = Z_INDEX_HAND

	else:
		

			
		player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
		card_being_dragged.z_index = Z_INDEX_HAND

	card_being_dragged = null
	
	$"../ManaSlots".set_all_slots_using(false)


#func gioca_token(card: Node2D, slot: Node2D):
	#var card_to_place: Node2D = card
	#var slot_to_place: Node2D = slot
#
	#print("GIOCO TOKEN CAZOZOO")
	## Sicurezza per posizione (attack/defense o faceup/facedown)
	#var pos_type := "attack"
	#if card_to_place and card_to_place.has_meta("position_type"):
		#pos_type = card_to_place.get_meta("position_type")
#
	#await get_tree().process_frame
	## Imposta posizione di partenza personalizzata
	#match pos_type:
		#"attack":
			#card_to_place.global_position = Vector2(755.0, 500.0)
		#"defense":
			#card_to_place.global_position = Vector2(1100.0, 500.0)
		#"faceup":
			#card_to_place.global_position = Vector2(755.0, 500.0)
		#"facedown":
			#card_to_place.global_position = Vector2(1100.0, 500.0)
#
	#await get_tree().process_frame
	## Imposta dimensioni finali
	##card_to_place.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
	## Imposta dimensioni iniziali prima di mostrare
	#card_to_place.scale = Vector2(0.35, 0.35)
	#card_to_place.card_is_in_slot = true
	#card_to_place.current_slot = slot_to_place
	#
#
	## 🧹 Rimuovi hover
	#if currently_hovered_card == card_to_place:
		#currently_hovered_card = null
#
#
		## 🔁 Imposta rotazione se in difesa (prima di mostrarla)
	#if pos_type == "defense":
		#card_to_place.rotation_degrees = 90
	#
	#var back = card_to_place.get_node_or_null("CardBack")
	#var front = card_to_place.get_node_or_null("CardImage")
	### 🔀 Imposta rotazione / posizione se specificato  NON SERVE PERCHE FACCIO TUTTO PRIMA CHE LA CARTA SIA VISIBILE
	#if card_to_place.card_data.card_type == "Spell":
		#if card_to_place.has_meta("position_type"):
			#var pos = card_to_place.get_meta("position_type")
			#card_to_place.position_type = pos
#
			#
			#if back and front:
				#back.visible = (pos == "facedown")
				#front.visible = (pos == "faceup")
	#elif card_to_place.card_data.card_type == "Creature":
		#if card_to_place.has_meta("position_type"):
			#card_to_place.set_position_type(card_to_place.get_meta("position_type"))
		#
	#card_to_place.visible = true  #ORA LA CARTA E' PRONTA PER ESSERE MOSTRATA
	#if front.visible:
		#card_to_place.update_talent_icons()
		#
		## 🔠 Ingrandisci Attack e Health se presenti
	#var atk_label = card_to_place.get_node_or_null("Attack")
	#var hp_label = card_to_place.get_node_or_null("Health")
	#var spell_dur = card_to_place.get_node_or_null("SpellDuration")
	#var spell_multi = card_to_place.get_node_or_null("SpellMultiplier")
	#var talent_icons_container = card_to_place.get_node_or_null("TalentIconsContainer")
	## 👇 Applica subito la field texture se esiste
	## 👇 Applica subito la field texture se esiste
	#if card_to_place.card_data.card_field_sprite:
		#card_to_place.get_node("CardImage").texture = card_to_place.card_data.card_field_sprite
		#
		#if atk_label:
			#atk_label.scale = Vector2(1.01, 1.01)
			#atk_label.position = Vector2(-45, 20)
		#if hp_label:
			#hp_label.scale = Vector2(1.01, 1.01)
			#hp_label.position = Vector2(6, 20)
		#if spell_dur:
			#spell_dur.scale = Vector2(1.3, 1.3)
			#spell_dur.position = Vector2(7, 30)
			#if card_to_place.card_data.spell_duration >= 100:
				#var infinity_sprite := TextureRect.new()
				#infinity_sprite.texture = preload("res://Assets/TalentSprites/INFINITY SPRITE.png")
				#infinity_sprite.scale = Vector2(0.07, 0.07)
				#infinity_sprite.position = Vector2(0, 33)
				#infinity_sprite.name = "InfinityIcon"
#
				## Rimuovi la label e sostituiscila con la texture
				#var parent = spell_dur.get_parent()
				#if parent:
					#parent.remove_child(spell_dur)
					#parent.add_child(infinity_sprite)
				#
				#if card_to_place.position_type == "facedown":
					#infinity_sprite.visible = false
			#else:
				#spell_dur.visible = true
		#if spell_multi:
			#spell_multi.visible = false
			#
		#if card_to_place.position_type == "facedown":
			#spell_dur.visible = false
			#talent_icons_container.visible = false
#
		## 👇 Usa retro da campo invece del retro da mano
		#if card_to_place.card_data.card_back_field:
			#card_to_place.get_node("CardBack").texture = card_to_place.card_data.card_back_field
	#else:
		#card_to_place.get_node("CardImage").texture = card_to_place.card_data.card_sprite
		## 👇 Usa retro normale in questo caso
#
	#
#
#
#
	#
	## ✨ TWEEN → movimento verso lo slot + scala + flip (se facedown)
	#var tween := get_tree().create_tween()
	#tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#
	#tween.tween_property(card_to_place, "global_position", slot_to_place.global_position, DEFAULT_CARD_MOVE_SPEED)
	#tween.parallel().tween_property(card_to_place, "scale", Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE), DEFAULT_CARD_MOVE_SPEED)
#
#
	#await tween.finished
#
	## ✅ Posiziona localmente sullo slot
	#card_to_place.position = slot_to_place.position
	#card_to_place.z_index = Z_INDEX_SLOT
#
	## Blocca collisione dello slot
	#slot_to_place.get_node("Area2D/CollisionShape2D").disabled = true
	#slot_to_place.card_in_slot = card_to_place
##
#
	### 🔁 Rimuovi da Deck
	##if $"../Deck".has_method("remove_card_from_deck"):
		##$"../Deck".remove_card_from_deck(card_to_place.card_data)
	##elif $"../EnemyDeck".has_method("remove_card_from_deck"):
		##$"../EnemyDeck".remove_card_from_deck(card_to_place.card_data)
#
	## 📋 Aggiungi a campo corretto in base al lato
	#var combat_manager = $"../CombatManager"
	#var token_owner_id = card_to_place.get_meta("owner_id") if card_to_place.has_meta("owner_id") else multiplayer.get_unique_id()
	#var is_local_owner = (token_owner_id == multiplayer.get_unique_id())
#
	#if card_to_place.card_data.card_type == "Creature":
		#if is_local_owner:
			#combat_manager.player_creatures_on_field.append(card_to_place)
			#print("🧩 Token aggiunto a player_creatures_on_field (owner locale):", card_to_place.name)
			#apply_existing_aura_effect(card_to_place)
			#print("APPLICATO AURAS SUI TOKEN NEL LOCALE")
		#else:
			#combat_manager.opponent_creatures_on_field.append(card_to_place)
				## 🔄 7. Animazione flip (se desiderata)
			#var anim = card_to_place.get_node_or_null("AnimationPlayer")
			#if anim:
				#anim.play("card_flip")
			#print("🧩 Token aggiunto a opponent_creatures_on_field (owner remoto):", card_to_place.name)
			#apply_existing_aura_effect_per_rpc(card_to_place)
			##apply_existing_aura_effect(card_to_place)
			#print("APPLICATO AURAS SUI TOKEN NELL'ALTRO CLIENT")
			#
#
#
	## 🌀 Controlla le AURE attive del mio campo e applicale se la nuova carta è valida
#
#
#
#
#
	## 🧩 Se la carta ha effetto TriggerEndPhase → aggiungila alla lista globale
	#if card_to_place.card_data.trigger_type == "On_EndPhase":
		#var player_id = multiplayer.get_unique_id()
		#$"../CombatManager".trigger_endphase_cards.append({
			#"card": card_to_place,
			#"owner_id": player_id,
		#})
		#print("🧩 [LOCAL] Aggiunta carta On_EndPhase:", card_to_place.card_data.card_name, "| Owner ID:", player_id)
		#print("📋 Lista On_EndPhase aggiornata:", $"../CombatManager".trigger_endphase_cards.map(func(e): return e.card.card_data.card_name))
	## 🧩 Se la carta ha effetto TriggerEndPhase → aggiungila alla lista globale
#
		#
	### 🧳 Prepara dati per sync
	##var player_id = multiplayer.get_unique_id()
	##var card_data_dict = card_to_place.card_data.to_dict()
	##card_data_dict["card_name"] = card_to_place.name  # necessario per naming coerente
###
	### 📡 RPC → manda la carta al client avversario
	##rpc("play_card_here_and_for_clients_opponent", player_id, card_data_dict, slot_to_place.name, pos_type)
	##play_card_here_and_for_clients_opponent(player_id, card_data_dict, slot_to_place.name, pos_type)
#
#
#
#
	## 📡 RPC: mostra overlay mana al client avversario
	#var owner := "Player"
#
#
#
	## ✅ Reset pending vars (puoi farlo ora, dopo tween)
	#pending_card_to_place = null
	#pending_slot_to_place = null
	#
	#
	#if card_to_place.card_data.get_talents_array().has("Elusive") and pos_type == "defense":
		#print("Elusive giocato in difesa e' inutile")
		#card.is_elusive = false
		#card.remove_talent_overlay("Elusive")
	#
	#if card_to_place.card_data.get_talents_array().has("Assault") and pos_type == "attack":
		#print("ASSAULT MODE!")
		#
		#await get_tree().create_timer(0.3).timeout
		#enter_selection_mode(card_to_place, "attack")
	



	
func gioca_carta_subito(card: Node2D, slot: Node2D):
	var card_to_place: Node2D = card
	var slot_to_place: Node2D = slot

	# Sicurezza per posizione (attack/defense o faceup/facedown)
	var pos_type := "attack"
	if card_to_place and card_to_place.has_meta("position_type"):
		pos_type = card_to_place.get_meta("position_type")

	await get_tree().process_frame
	# Imposta posizione di partenza personalizzata
	match pos_type:
		"attack":
			card_to_place.global_position = Vector2(755.0, 500.0)
		"defense":
			card_to_place.global_position = Vector2(1100.0, 500.0)
		"faceup":
			card_to_place.global_position = Vector2(755.0, 500.0)
		"facedown":
			card_to_place.global_position = Vector2(1100.0, 500.0)

	await get_tree().process_frame
	# Imposta dimensioni finali
	#card_to_place.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
	# Imposta dimensioni iniziali prima di mostrare
	card_to_place.scale = Vector2(0.35, 0.35)
	card_to_place.card_is_in_slot = true
	card_to_place.current_slot = slot_to_place

	
	if $"../ActionButtons".enchain_label.visible:
		$"../ActionButtons".hide_label($"../ActionButtons".enchain_label)
	$"../ActionButtons".force_hide_all_green_borders()

	# 🧹 Rimuovi hover
	if currently_hovered_card == card_to_place:
		currently_hovered_card = null

	# Rimuovi dalla mano
	player_hand_reference.remove_card_from_hand(card_to_place)
		# 🔁 Imposta rotazione se in difesa (prima di mostrarla)
	if pos_type == "defense":
		card_to_place.rotation_degrees = 90
	
	var back = card_to_place.get_node_or_null("CardBack")
	var front = card_to_place.get_node_or_null("CardImage")
	## 🔀 Imposta rotazione / posizione se specificato  NON SERVE PERCHE FACCIO TUTTO PRIMA CHE LA CARTA SIA VISIBILE
	if card_to_place.card_data.card_type == "Spell":
		if card_to_place.has_meta("position_type"):
			var pos = card_to_place.get_meta("position_type")
			card_to_place.position_type = pos

			
			if back and front:
				back.visible = (pos == "facedown")
				front.visible = (pos == "faceup")
	elif card_to_place.card_data.card_type == "Creature":
		if card_to_place.has_meta("position_type"):
			card_to_place.set_position_type(card_to_place.get_meta("position_type"))
		
	card_to_place.visible = true  #ORA LA CARTA E' PRONTA PER ESSERE MOSTRATA
	if front.visible:
		card_to_place.update_talent_icons()
		
		# 🔠 Ingrandisci Attack e Health se presenti
	var atk_label = card_to_place.get_node_or_null("Attack")
	var hp_label = card_to_place.get_node_or_null("Health")
	var spell_dur = card_to_place.get_node_or_null("SpellDuration")
	var spell_multi = card_to_place.get_node_or_null("SpellMultiplier")
	var talent_icons_container = card_to_place.get_node_or_null("TalentIconsContainer")
	# 👇 Applica subito la field texture se esiste
	# 👇 Applica subito la field texture se esiste
	if card_to_place.card_data.card_field_sprite:
		card_to_place.get_node("CardImage").texture = card_to_place.card_data.card_field_sprite
		
		if atk_label:
			atk_label.scale = Vector2(1.01, 1.01)
			atk_label.position = Vector2(-45, 20)
		if hp_label:
			hp_label.scale = Vector2(1.01, 1.01)
			hp_label.position = Vector2(6, 20)
		if spell_dur:
			spell_dur.scale = Vector2(1.3, 1.3)
			spell_dur.position = Vector2(7, 30)
			if card_to_place.card_data.spell_duration >= 100:
				var infinity_sprite := TextureRect.new()
				infinity_sprite.texture = preload("res://Assets/TalentSprites/INFINITY SPRITE.png")
				infinity_sprite.scale = Vector2(0.06, 0.06)
				infinity_sprite.position = Vector2(0, 35)
				infinity_sprite.name = "InfinityIcon"
				infinity_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

				# Rimuovi la label e sostituiscila con la texture
				var parent = spell_dur.get_parent()
				if parent:
					parent.remove_child(spell_dur)
					parent.add_child(infinity_sprite)
				
				if card_to_place.position_type == "facedown":
					infinity_sprite.visible = false
			else:
				spell_dur.visible = true
		if spell_multi:
			spell_multi.visible = false
			
		if card_to_place.position_type == "facedown":
			spell_dur.visible = false
			talent_icons_container.visible = false

		# 👇 Usa retro da campo invece del retro da mano
		if card_to_place.card_data.card_back_field:
			card_to_place.get_node("CardBack").texture = card_to_place.card_data.card_back_field
	else:
		card_to_place.get_node("CardImage").texture = card_to_place.card_data.card_sprite
		# 👇 Usa retro normale in questo caso

	



	
	# ✨ TWEEN → movimento verso lo slot + scala + flip (se facedown)
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(card_to_place, "global_position", slot_to_place.global_position, DEFAULT_CARD_MOVE_SPEED)
	tween.parallel().tween_property(card_to_place, "scale", Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE), DEFAULT_CARD_MOVE_SPEED)


	await tween.finished

	# ✅ Posiziona localmente sullo slot
	card_to_place.position = slot_to_place.position
	card_to_place.z_index = Z_INDEX_SLOT

	# Blocca collisione dello slot
	slot_to_place.get_node("Area2D/CollisionShape2D").disabled = true
	slot_to_place.card_in_slot = card_to_place
#
	## 🔀 Imposta rotazione / posizione se specificato  NON SERVE PERCHE FACCIO TUTTO PRIMA CHE LA CARTA SIA VISIBILE
	#if card_to_place.card_data.card_type == "Spell":
		#if card_to_place.has_meta("position_type"):
			#var pos = card_to_place.get_meta("position_type")
			#card_to_place.position_type = pos
			#var back = card_to_place.get_node_or_null("CardBack")
			#var front = card_to_place.get_node_or_null("CardImage")
			#if back and front:
				#back.visible = (pos == "facedown")
				#front.visible = (pos == "faceup")
	#elif card_to_place.card_data.card_type == "Creature":
		#if card_to_place.has_meta("position_type"):
			#card_to_place.set_position_type(card_to_place.get_meta("position_type"))

	# 🔁 Rimuovi da Deck
	if $"../Deck".has_method("remove_card_from_deck"):
		$"../Deck".remove_card_from_deck(card_to_place.card_data)
	elif $"../EnemyDeck".has_method("remove_card_from_deck"):
		$"../EnemyDeck".remove_card_from_deck(card_to_place.card_data)

	# 📋 Aggiungi a campo locale
	if card_to_place.card_data.card_type == "Creature":
		$"../CombatManager".player_creatures_on_field.append(card_to_place)
	elif card_to_place.card_data.card_type == "Spell":
		$"../CombatManager".player_spells_on_field.append(card_to_place)

# 🔹 Aggiorna ultima carta giocata
	$"../CombatManager".set_last_played_card(card_to_place, multiplayer.get_unique_id())
	# 🌀 Controlla le AURE attive del mio campo e applicale se la nuova carta è valida


	# 🧩 Se la carta ha effetto TriggerUpkeepPhase → aggiungila alla lista globale
	if card_to_place.card_data.trigger_type == "On_UpKeepPhase" and card_to_place.position_type != "facedown":
		var player_id = multiplayer.get_unique_id()
		$"../CombatManager".trigger_upkeep_cards.append({
			"card": card_to_place,
			"owner_id": player_id,
		})
		print("🧩 [LOCAL] Aggiunta carta On_UpKeepPhase:", card_to_place.card_data.card_name, "| Owner ID:", player_id)
		print("📋 Lista On_UpKeepPhase aggiornata:", $"../CombatManager".trigger_upkeep_cards.map(func(e): return e.card.card_data.card_name))



	# 🧩 Se la carta ha effetto TriggerEndPhase → aggiungila alla lista globale
	if card_to_place.card_data.trigger_type == "On_EndPhase" and card_to_place.position_type != "facedown":
		var player_id = multiplayer.get_unique_id()
		$"../CombatManager".trigger_endphase_cards.append({
			"card": card_to_place,
			"owner_id": player_id,
		})
		print("🧩 [LOCAL] Aggiunta carta On_EndPhase:", card_to_place.card_data.card_name, "| Owner ID:", player_id)
		print("📋 Lista On_EndPhase aggiornata:", $"../CombatManager".trigger_endphase_cards.map(func(e): return e.card.card_data.card_name))
	# 🧩 Se la carta ha effetto TriggerEndPhase → aggiungila alla lista globale

		
	# 🧳 Prepara dati per sync
	var player_id = multiplayer.get_unique_id()
	var card_data_dict = card_to_place.card_data.to_light_dict()
	card_data_dict["card_name"] = card_to_place.name  # necessario per naming coerente


	# 📡 RPC → manda la carta al client avversario
	# 🧪 DEBUG — stima payload RPC play_card
	var rpc_payload := [
		player_id,
		card_data_dict,
		slot_to_place.name,
		pos_type
	]

	print("🧪 play_card RPC payload approx:",
		var_to_bytes(rpc_payload).size(), "bytes")
		
	rpc("play_card_here_and_for_clients_opponent", player_id, card_data_dict, slot_to_place.name, pos_type)
	play_card_here_and_for_clients_opponent(player_id, card_data_dict, slot_to_place.name, pos_type)

	# --- 🧩 NUOVO BLOCCO: controllo risposte avversarie (con filtro no_immediate_effect)
	var pm = $"../PhaseManager"
	var cm = $"../CombatManager"
	var combat_manager = $"../CombatManager"
	var action_buttons = $"../ActionButtons"
	var valid_targets := []
	if card.card_data.targeting_type == "Targeted":
		valid_targets = combat_manager.get_valid_targets(card, true)
		
	# 🧩 Definisci se la carta è “no immediate effect”
	var no_immediate_effect = (
		card.card_data.effect_type not in ["OnPlay", "Aura", "Equip"]
		or card.position_type == "facedown"
		or (
			card.card_data.effect_type in ["OnPlay", "Aura", "Equip"]
			and card.card_data.targeting_type == "Targeted"
			and valid_targets.is_empty()
		)
	)

	
	if pm.enemy_has_passed_this_phase and no_immediate_effect and not action_buttons.enemy_auto_skip_resolve: #IMPOSTAZIONE AUTO-APPROVE
		if cm.check_opponent_has_response(true): 
			print("⏳ [Chain Window] Avversario ha risposte potenziali → apro Resolve.")
			await cm.wait_for_resolve_choice(true)
			print("✅ Carta approvata dall'avversario, posso procedere.")
		else:
			print("✅ [Chain Window] Avversario non ha risposte → salto Resolve immediatamente.")


	## Evita di aprire la chain per carte con effetto immediato
	#var no_immediate_effect = (
		#card_to_place.card_data.effect_type not in ["OnPlay", "Aura", "Equip"]
	#)
#
	#if no_immediate_effect:
		#var opponent_has_response = false
		#var is_attacker = true  # opzionale, se vuoi differenziare logiche
#
		## 🔎 Controlla se l’avversario ha carte facedown o Quick
		#if is_attacker:
			#for cù in combat_manager.opponent_creatures_on_field:
				#if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
					#opponent_has_response = true
					#break
			#if not opponent_has_response:
				#for cù in combat_manager.opponent_spells_on_field:
					#if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
						#opponent_has_response = true
						#break
		#else:
			#for cù in combat_manager.player_creatures_on_field:
				#if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
					#opponent_has_response = true
					#break
			#if not opponent_has_response:
				#for c in combat_manager.player_spells_on_field:
					#if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
						#opponent_has_response = true
						#break
#
		## 💡 Se l’avversario ha potenziali risposte o ha già passato → apri Resolve
		#if opponent_has_response or (pm.enemy_has_passed_this_phase and no_immediate_effect):
		##if opponent_has_response:
			#print("🧩 [GiocaCartaSubito] Avversario ha possibili risposte → attendo Resolve.")
			#await cm.wait_for_resolve_choice(true)
			#print("✅ [GiocaCartaSubito] Carta approvata dopo Resolve.")
		#else:
			#print("⚡ [GiocaCartaSubito] Nessuna possibile risposta → procedo senza Resolve.")
	#else:
		#print("⚡ [GiocaCartaSubito] Carta con effetto immediato → skip Resolve.")





	# 💸 Spendi mana
	$"../ManaSlots".spend_highlighted_slots()
	var spent_types = $"../ManaSlots".get_last_spent_types()

	# 👁️ Mostra overlay mana solo se coperta
	if card_to_place.card_data.card_type == "Spell" and card_to_place.position_type == "facedown":
		spell_dur.visible = false
		spell_multi.visible = false
		show_spent_mana_icons(card_to_place, spent_types)

	# 📡 RPC: mostra overlay mana al client avversario
	var owner := "Player"
	rpc("rpc_show_spent_mana_on_card", card_to_place.name, owner, spent_types)

	# 🧹 Cleanup finale
	$"../ManaSlots".debug_print_slots()
	$"../ManaSlots".set_all_slots_using(false)

	# ✅ Reset pending vars (puoi farlo ora, dopo tween)
	pending_card_to_place = null
	pending_slot_to_place = null
	await cm.apply_player_bonuses(card_to_place, player_id)

	
	
	
	apply_existing_aura_effect(card_to_place)
	
	#-------------------------- QUI E' DOVE LA CARTA E' UFFICIALMENTE IN CAMPO
	
		# 🧩 NUOVO BLOCCO — attesa obbligatoria prima di qualunque trigger o effetto
	#print("⏳ Attendo fase di Resolve per la carta appena giocata:", card_to_place.card_data.card_name)
	#var combat_manager = $"../CombatManager"
	##await combat_manager.wait_for_resolve_choice(true)  # true = sono il giocatore che gioca la carta
	##await  combat_manager.final_resolve_ack_received
	#print("✅ Fase di Resolve completata, procedo con eventuali effetti o target") 
	#SI DA PER SCONTATTO CHE E' SELF PLAYER.
		# --- 💫 NUOVO BLOCCO: incremento Spell Power immediato ---
		
	if pos_type != "facedown":
		var should_defer = (
			card_to_place.card_data.effect_type == "Activable"
			or card_to_place.card_data.trigger_type != "None"
			or card_to_place.card_data.card_type == "Spell"
		)
		await apply_spell_power_effects(card_to_place, false, should_defer)


	if card_to_place.card_is_in_slot:
		if "Berserker" in card_to_place.card_data.get_all_talents() and pos_type == "defense":
			print("💥 [Spawn] Berserker non può stare in difesa → autodistruzione tra 1s!")
			await get_tree().create_timer(0.3).timeout
			card_to_place.play_talent_icon_pulse("Berserker")
			await get_tree().create_timer(0.7).timeout
			$"../CombatManager".destroy_card(card_to_place, owner)
			#return

		if "Elusive" in card_to_place.card_data.get_all_talents() and pos_type == "defense":
			print("Elusive giocato in difesa e' inutile")
			card_to_place.is_elusive = false
			card_to_place.remove_talent_overlay("Elusive")

		if "Assault" in card_to_place.card_data.get_all_talents() and pos_type == "attack":
			print("ASSAULT MODE!")
			await get_tree().create_timer(0.3).timeout
			selection_is_forced = true
			enter_selection_mode(card_to_place, "attack")
			# 🕒 Delay azione solo se non già delayata
			#var combat_manager = $"../CombatManager"
			if not combat_manager.pending_action_after_chain:
				print("⏳ [Action Delay] Assault → azione passerà solo dopo chain.")
				action_consume_pending = true
				combat_manager.pending_action_after_chain = true
				combat_manager.pending_action_owner_id = multiplayer.get_unique_id()
		
		# 🎯 EFFETTI OnPlay / Aura / Equip
		if (card_to_place.card_data.effect_type in ["OnPlay", "Aura", "Equip"]) and pos_type != "facedown":
			print("EFFETTO ATTIVO SUBITO")
			await get_tree().create_timer(0.3).timeout

			if card.card_data.targeting_type == "Targeted":

				if valid_targets.size() > 0:
					print("🎯 Target validi trovati:", valid_targets.size(), "→ entro in selection mode")
					enter_selection_mode(card, "effect")
					
					# 🕒 Delay azione solo se non già delayata
					if not combat_manager.pending_action_after_chain:
						print("⏳ [Action Delay] Effetto Targeted → azione passerà solo dopo chain.")
						action_consume_pending = true
						combat_manager.pending_action_after_chain = true
						combat_manager.pending_action_owner_id = multiplayer.get_unique_id()
			else:
				trigger_card_effect(card)

				# Effetto untargeted → entra subito in chain, quindi delay automatico
				#var combat_manager = $"../CombatManager"
				#if not combat_manager.pending_action_after_chain:
					#print("⏳ [Action Delay] Effetto Untargeted → azione passerà solo dopo chain.")
					#action_consume_pending = true
					#combat_manager.pending_action_after_chain = true
					#combat_manager.pending_action_owner_id = multiplayer.get_unique_id()

		# 🕒 Ora la carta è effettivamente in campo — emetti segnale di evocazione con posizione
		if card_to_place.card_data.card_type == "Creature" and card_to_place.has_meta("position_type"):
			#await get_tree().create_timer(0.3).timeout
			print("📣 [SIGNAL] summoned_on_field →", card_to_place.card_data.card_name)
			card_to_place.emit_signal("summoned_on_field", card_to_place, pos_type)
			$"../CombatManager".notify_summon_global(card_to_place)
	#CONSUMA AZIONE QUANDO GIOCATA, PERO' VIENE PAASSATA DOPO TUTTI GLI EVENTUALI TRIGGER
	# 🧩 Passa l'azione all'altro giocatore dopo aver giocato la carta
	# 🧩 CONSUMO AZIONE — solo se non è già stata delayata
	await get_tree().create_timer(0.3).timeout
	var phase_manager = get_node_or_null("../PhaseManager")
	if phase_manager:
		#var combat_manager = $"../CombatManager"
		if not combat_manager.pending_action_after_chain:
			var my_id = multiplayer.get_unique_id()
			var peers = multiplayer.get_peers()
			if peers.size() > 0:
				var other_id = peers[0]
				print("♻️ [Action Switch] Nessun effetto o selection → passo azione all'altro peer:", other_id)
				phase_manager.rpc("rpc_give_action", other_id)
				phase_manager.rpc_give_action(other_id)
		else:
			print("⏳ [Action Delay] Azione già in delay → verrà passata dopo la chain.")
	else:
		print("⚠️ PhaseManager non trovato — impossibile passare l'azione!")

	






@rpc("any_peer")
func rpc_show_spent_mana_on_card(card_name: String, owner: String, spent_types: Array[String]) -> void:
	await get_tree().process_frame  # 👈 aspetta un frame per dare tempo all'EnemyCard di spawnare
	
	var card: Node = null
	if owner == "Player":
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/CardManager")
		if enemy_field:
			card = enemy_field.get_node_or_null(card_name)
	else:
		card = $"../CardManager".get_node_or_null(card_name)

	if card:
		# 👇 Mostra overlay solo se facedown
		if card.card_data.card_type == "Spell" and card.position_type == "facedown":
			show_spent_mana_icons(card, spent_types)
		print("✨ Overlay mana mostrato su", card.name, "con:", spent_types)
	else:
		print("❌ rpc_show_spent_mana_on_card: carta non trovata:", card_name)

@rpc("any_peer") 
func play_card_here_and_for_clients_opponent(player_id, card_data_dict: Dictionary, slot_name: String, position_type: String):
	if multiplayer.get_unique_id() == player_id:
		# Questo evento è stato generato da noi → già gestito localmente
		return

	# 🔁 1. Ricostruisci i dati della carta
	var card_data = CardData.from_light_dict(card_data_dict)
	var card_scene = preload("res://Scene/EnemyCard.tscn")  # o EnemyCard.tscn se vuoi usare una scena diversa lato client
	var new_card = card_scene.instantiate()
	new_card.set_card_data(card_data)
	new_card.set_position_type(position_type)
	
			
	await get_tree().process_frame
	
	var area = new_card.get_node("Area2D")
	
	area.collision_layer = 5  # o quello che vuoi (tipo layer nemico)
	area.collision_mask = 64  # QUESTO È L'IMPORTANTE!! DEVE ESSERE 64
	#print("🛠 Area2D della carta nemica:")
	#print("   ➤ Layer:", area.collision_layer)
	#print("   ➤ Mask:", area.collision_mask)
	#print("   ➤ Shape enabled:", area.get_node("CollisionShape2D").disabled == false)
	area.get_node("CollisionShape2D").disabled = false
	# 🆕 Imposta il nome del nodo con il vero nome della carta
	if card_data and card_data.card_name != "":
		new_card.name = card_data.card_name
		print("LO RICHIAMO:",new_card.name)
	else:
		new_card.name = "Card_%s" % str(randi())
		print("LO RICHIAMO COME MI PARE")
	#print("🆔 Nome carta nemica:", new_card.name)
	##new_card.add_to_group("Cards")  # 🆕 Importante per il raycast
	#print("📦 Tipo carta ricostruita:", card_data.card_type)
	#print("🛠 Carta nemica instanziata:", new_card.name)
	#print("Layer:", new_card.get_node("Area2D").collision_layer)
	#print("Collision Shape Enabled:", new_card.get_node("Area2D/CollisionShape2D").disabled)

	# 📦 2. Aggiungi la carta al campo avversario
	var enemy_field = get_parent().get_parent().get_node("EnemyField")
	var card_manager = enemy_field.get_node("CardManager")
	card_manager.add_child(new_card)
	if card_manager.has_method("connect_card_signals"):
		card_manager.connect_card_signals(new_card)
	#print("👁 Parent della carta:", new_card.get_parent())
	#print("👁 Path completo:", new_card.get_path())
	##print("👁 is_in_group('Cards'):", new_card.is_in_group("Cards"))
	#print("👁 has is_card():", new_card.has_method("is_card") and new_card.is_card())

	# 🖐️ 3. Simula inserimento in mano per calcolare position_in_hand
	var enemy_hand = enemy_field.get_node("EnemyHand")
	enemy_hand.add_card_to_hand(new_card, 0.0)
	enemy_hand.remove_any_card()
	# Aspetta un frame per assicurarti che update_hand_positions() venga completato
	await get_tree().process_frame

	# Salva la posizione iniziale per l'animazione
	var start_position = new_card.position
	#enemy_hand.remove_card_by_position(start_position)
	# Rimuovi la carta dalla mano
	enemy_hand.remove_card_from_hand(new_card)

	# 🎯 4. Trova lo slot corretto
	#print("🔎 Cerco slot:", "EnemyZones/" + slot_name)
	#print("📦 enemy_field:", enemy_field)
	#print("📦 slot_node esiste?", enemy_field.has_node("EnemyZones/" + slot_name))
	var slot_path = "EnemyZones/" + slot_name  # NON fare invert_slot_name
	var card_slot = enemy_field.get_node_or_null(slot_path)

	if card_slot == null:
		push_error("❌ Slot nemico non trovato: EnemyZones/" + card_slot)
		return

	# 📦 5. Anima la carta verso lo slot
	new_card.position = start_position
	var tween = get_tree().create_tween()
	tween.tween_property(new_card, "position", card_slot.position, DEFAULT_CARD_MOVE_SPEED)
	if position_type == "defense":
		new_card.rotation_degrees = 0
		tween.parallel().tween_property(new_card, "rotation_degrees", 90, DEFAULT_CARD_MOVE_SPEED)

	# ✨ 6. Imposta le proprietà finali
	new_card.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
	new_card.z_index = 0

	# Imposta la relazione tra carta e slot
	new_card.card_is_in_slot = true
	print("✅ Dopo assegnazione → new_card.card_is_in_slot =", new_card.card_is_in_slot)
	new_card.current_slot = card_slot
	card_slot.card_in_slot = new_card  # non più "true" ma la carta

		# 🔠 Ingrandisci le label
	var atk_label = new_card.get_node_or_null("Attack")
	var hp_label = new_card.get_node_or_null("Health")
	var spell_dur = new_card.get_node_or_null("SpellDuration")
	var spell_multi = new_card.get_node_or_null("SpellMultiplier")
	var talent_icons_container = new_card.get_node_or_null("TalentIconsContainer")
		# 👇 Sprite alternativa se la carta è sul field

	if new_card.card_data.card_field_sprite:
		new_card.get_node("CardImage").texture = new_card.card_data.card_field_sprite
		

		if atk_label:
			atk_label.scale = Vector2(1.01, 1.01)
			atk_label.position = Vector2(-45, 20)
		if hp_label:
			hp_label.scale = Vector2(1.01, 1.01)
			hp_label.position = Vector2(6, 20)
		if spell_dur:
			spell_dur.scale = Vector2(1.3, 1.3)
			spell_dur.position = Vector2(7, 30)
			if new_card.card_data.spell_duration >= 100:
				var infinity_sprite := TextureRect.new()
				infinity_sprite.texture = preload("res://Assets/TalentSprites/INFINITY SPRITE.png")
				infinity_sprite.scale = Vector2(0.06, 0.06)
				infinity_sprite.position = Vector2(0, 35)
				infinity_sprite.name = "InfinityIcon"
				infinity_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

				# Rimuovi la label e sostituiscila con la texture
				var parent = spell_dur.get_parent()
				if parent:
					parent.remove_child(spell_dur)
					parent.add_child(infinity_sprite)
					
				if new_card.position_type == "facedown":
					infinity_sprite.visible = false
			else:
				spell_dur.visible = true
		if spell_multi:
			spell_multi.visible = false
	
		if new_card.position_type == "facedown":
			spell_dur.visible = false
			talent_icons_container.visible = false
			
		# 👇 Retro da campo
		if new_card.card_data.card_back_field:
			new_card.get_node("CardBack").texture = new_card.card_data.card_back_field

	else:
		new_card.get_node("CardImage").texture = new_card.card_data.card_sprite
		
		# 👇 Retro normale
		if new_card.card_data.card_back:
			new_card.get_node("CardBack").texture = new_card.card_data.card_back

	
	# 👇 Mostra eventuali talenti (uno o più)
	new_card.update_talent_icons()




	# Disattiva collisione dello slot
	card_slot.get_node("Area2D/CollisionShape2D").disabled = true
	

	# Aggiungi la carta alla lista di gioco lato client
	if card_data.card_type == "Creature":
		$"../CombatManager".opponent_creatures_on_field.append(new_card)
		print("📋 opponent_creatures_on_field post append:")
		for c in $"../CombatManager".opponent_creatures_on_field:
			print(" - ", c.name, "| is_card:", c.is_card(), "| is_enemy_card:", c.is_enemy_card())

	else:
		$"../CombatManager".opponent_spells_on_field.append(new_card)

	# 🔹 Aggiorna anche lato avversario
	$"../CombatManager".set_last_played_card(new_card, player_id)
	await $"../CombatManager".apply_player_bonuses(new_card, player_id)
	
	apply_existing_aura_effect_per_rpc(new_card)

	if new_card.card_data.card_type == "Creature":
		#await get_tree().create_timer(0.3).timeout
		print("📣 [SIGNAL] summoned_on_field →", new_card.card_data.card_name)
		new_card.emit_signal("summoned_on_field", new_card, position_type)
		$"../CombatManager".notify_summon_global(new_card)

	if new_card.card_data.trigger_type == "On_UpKeepPhase" and new_card.position_type != "facedown":
		var owner_id = player_id
		$"../CombatManager".trigger_upkeep_cards.append({
			"card": new_card,
			"owner_id": owner_id,
		})
		print("🧩 [ENEMY] Aggiunta carta On_UpKeepPhase:", new_card.card_data.card_name, "| Owner ID:", owner_id)
		print("📋 Lista On_UpKeepPhase aggiornata:", $"../CombatManager".trigger_upkeep_cards.map(func(e): return e.card.card_data.card_name))



	# 🧩 Se anche la carta nemica è TriggerEndPhase → aggiungila con l'ID del suo proprietario
	if new_card.card_data.trigger_type == "On_EndPhase" and new_card.position_type != "facedown":
		var owner_id = player_id  # questo è l'ID di chi l'ha giocata realmente
		$"../CombatManager".trigger_endphase_cards.append({
			"card": new_card,
			"owner_id": owner_id,
		})
		print("🧩 [ENEMY] Aggiunta carta On_EndPhase:", new_card.card_data.card_name, "| Owner ID:", owner_id)
		print("📋 Lista On_EndPhase aggiornata:", $"../CombatManager".trigger_endphase_cards.map(func(e): return e.card.card_data.card_name))




		## 🧩 ATTESA FASE DI RESOLVE LATO AVVERSARIO
	#print("⏳ [ENEMY] Attendo fase di Resolve per la carta appena ricevuta:", new_card.card_data.card_name)
	#var combat_manager = $"../CombatManager"
	#await combat_manager.wait_for_resolve_choice(false)
	#print("✅ [ENEMY] Resolve completata, carta pronta per eventuali effetti")

		# --- 💫 NUOVO BLOCCO: incremento Spell Power lato Enemy ---
	if position_type != "facedown":
		var should_defer = (
			new_card.card_data.effect_type == "Activable"
			or new_card.card_data.trigger_type != "None"
			or new_card.card_data.card_type == "Spell"
		)
		await apply_spell_power_effects(new_card, true, should_defer)
	
	
	# 🔄 7. Animazione flip (se desiderata)
	var anim = new_card.get_node_or_null("AnimationPlayer")
	if anim:
		anim.play("card_flip")
	
	
	# --- 🧩 [NUOVO BLOCCO] Fase di approvazione (Resolve) ---
	# --- 🧩 BLOCCO INSERITO: controllo risposte avversarie (con filtro no_immediate_effect) ---
	var pm = $"../PhaseManager"
	var cm = $"../CombatManager"
	var combat_manager = $"../CombatManager"
	var action_buttons = $"../ActionButtons"

	# Evita di aprire la chain per carte con effetto immediato
	if multiplayer.get_unique_id() != player_id:
		var valid_targets := []
		if new_card.card_data.targeting_type == "Targeted":
			valid_targets = combat_manager.get_valid_targets(new_card, false)
			
		# 🧩 Definisci se la carta è “no immediate effect”
		var no_immediate_effect = (
			new_card.card_data.effect_type not in ["OnPlay", "Aura", "Equip"]
			or new_card.position_type == "facedown"
			or (
				new_card.card_data.effect_type in ["OnPlay", "Aura", "Equip"]
				and new_card.card_data.targeting_type == "Targeted"
				and valid_targets.is_empty()
			)
		)

		# 👇 Mostra Resolve solo se io (lato ricevente) ho già passato la fase e voglio chainare
		if pm and pm.has_passed_this_phase and no_immediate_effect and not action_buttons.auto_skip_resolve: #IMPOSTAZIONE AUTO-APPROVE
			if cm.check_opponent_has_response(false):
				print("⏳ [ENEMY] Avversario ha risposte potenziali → attendo approvazione (Resolve) per carta:", new_card.card_data.card_name)
				await cm.wait_for_resolve_choice(false)
				print("✅ [ENEMY] Carta approvata:", new_card.card_data.card_name)
			else:
				print("✅ [ENEMY] Nessuna risposta disponibile → skip Resolve immediatamente per carta:", new_card.card_data.card_name)


	
	#if no_immediate_effect:
		#var opponent_has_response = false
		#var is_attacker = true  # opzionale, se vuoi differenziare logiche
#
		## 🔎 Controlla se l’avversario ha carte facedown o Quick
		#if is_attacker:
			#for c in combat_manager.opponent_creatures_on_field:
				#if c.position_type == "facedown" or (c.card_data.effect_speed == "Quick" and not c.effect_triggered_this_turn):
					#opponent_has_response = true
					#break
			#if not opponent_has_response:
				#for c in combat_manager.opponent_spells_on_field:
					#if c.position_type == "facedown" or (c.card_data.effect_speed == "Quick" and not c.effect_triggered_this_turn):
						#opponent_has_response = true
						#break
		#else:
			#for c in combat_manager.player_creatures_on_field:
				#if c.position_type == "facedown" or (c.card_data.effect_speed == "Quick" and not c.effect_triggered_this_turn):
					#opponent_has_response = true
					#break
			#if not opponent_has_response:
				#for c in combat_manager.player_spells_on_field:
					#if c.position_type == "facedown" or (c.card_data.effect_speed == "Quick" and not c.effect_triggered_this_turn):
						#opponent_has_response = true
						#break
#
		## 💡 Se l’avversario ha potenziali risposte → attendo Resolve
		#if opponent_has_response or (pm.has_passed_this_phase and no_immediate_effect):
			#print("🧩 [EnemyPlayCard] Avversario ha possibili risposte → attendo Resolve.")
			#await cm.wait_for_resolve_choice(true)
			#print("✅ [EnemyPlayCard] Carta approvata dopo Resolve.")
		#else:
			#print("⚡ [EnemyPlayCard] Nessuna possibile risposta → procedo senza Resolve.")
	#else:
		#print("⚡ [EnemyPlayCard] Carta con effetto immediato → skip Resolve.")

	
	
	if new_card.card_is_in_slot:
		if "Elusive" in new_card.card_data.get_all_talents() and position_type == "defense":
			print("RPC: Elusive giocato in difesa e' inutile")
			new_card.is_elusive = false
			new_card.remove_talent_overlay("Elusive")
			# 💥 Effetto Berserker: se viene messo in difesa → autodistruzione dopo 1s
		if "Berserker" in new_card.card_data.get_all_talents() and position_type == "defense":
			print("💥 [Enemy Spawn] Berserker non può stare in difesa → autodistruzione tra 1s!")
			await get_tree().create_timer(0.3).timeout
			new_card.play_talent_icon_pulse("Berserker")
			await get_tree().create_timer(0.7).timeout
			$"../CombatManager".destroy_card(new_card, "Opponent")




		
		
		
		

func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)

	
func on_hovered_over_card(card):  #HOVER PERL 
	if is_position_popup_open:
		return
	if card.card_is_in_slot:
		return
	if card.card_is_in_playerGY:
		return
	if card_being_dragged:
		return

	# 👉 Solo se la carta è diversa da quella già hoverata
	if currently_hovered_card != card:
		# Se c’era un’altra carta hoverata, la resetto
		if currently_hovered_card:
			highlight_card(currently_hovered_card, false)

		# Attivo hover sulla nuova carta
		highlight_card(card, true)
		currently_hovered_card = card
		#print("✅HOVER CARTA IN MANO → new_card.card_is_in_slot =", currently_hovered_card.card_is_in_slot)


func on_hovered_off_card(card):
	if is_position_popup_open:
		return
	if card.card_is_in_playerGY:
		return
	if card_being_dragged:
		return

	# 👉 Solo se sto uscendo dalla carta che avevo hoverato
	if currently_hovered_card == card:
		highlight_card(card, false)
		currently_hovered_card = null
		
#func on_hovered_off_card(card):
#
	#if card.card_is_in_playerGY:
		#if card_being_dragged:
			#return
			#if !card.card_is_in_slot && !card_being_dragged:
				#highlight_card(card, false)
				#var new_card_hovered = raycast_check_for_card()
				#if new_card_hovered:
					#highlight_card(new_card_hovered, true)
				#else:
					#is_hovering_on_card = false


func handle_enemy_hover():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_ENEMY_HOVER


	var result = space_state.intersect_point(parameters)


	
	if result.size() > 0:
		var enemy_card = result[0].collider.get_parent()
		if enemy_card and enemy_card.is_in_hand():
			return

		# Se siamo in selection mode → mostra bordo rosso
		#if selection_mode_active:
			#if last_hovered_enemy and last_hovered_enemy != enemy_card:
				#last_hovered_enemy.red_highlight_border.visible = false
#
			#if enemy_card and enemy_card.has_node("RedHighlightBorder"):
				#enemy_card.red_highlight_border.visible = true
#
			#last_hovered_enemy = enemy_card
			#return

		# Se non in selection mode → normale bordo bianco
		if enemy_card != last_hovered_enemy:
			if last_hovered_enemy:
				last_hovered_enemy.set_highlight(false)

			if enemy_card:
				enemy_card.set_highlight(true)

			last_hovered_enemy = enemy_card
	else:
		if last_hovered_enemy:
			last_hovered_enemy.set_highlight(false)
			if last_hovered_enemy.has_node("RedHighlightBorder"):
				last_hovered_enemy.red_highlight_border.visible = false
			last_hovered_enemy = null



#func highlight_card(card, hovered):
	##if not card.has_method("is_card") or not card.is_card():
		##return  # Non è una carta vera
#
	#if card.card_data.card_type == "Spell" and card.card_is_in_slot:
		#return
		#
	#
	## Cancella eventuali tween precedenti per non accumularli
	#if card.has_meta("hover_tween") and card.get_meta("hover_tween").is_valid():
		#card.get_meta("hover_tween").kill()
		#card.remove_meta("hover_tween")
#
	#var tween := create_tween()
	#tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#card.set_meta("hover_tween", tween)
	#if hovered:
		#card.z_index = Z_INDEX_HOVER
		#if card.card_is_in_slot:
			#card.scale = Vector2(CARD_SLOT_HOVER_SCALE, CARD_SLOT_HOVER_SCALE)
			#
		#else:
			#tween.tween_property(card, "scale", Vector2(0.25, 0.25), 0.15)
#
			#if not card.has_meta("original_position"):
				#card.set_meta("original_position", card.position)
#
			## 👇 Mettiamo entrambi i tween in parallelo
			#tween.parallel().tween_property(card, "scale", Vector2(0.25, 0.25), 0.15)
			#tween.parallel().tween_property(card, "position", card.position - Vector2(0, 40), 0.15)
			#
	#else:
		#if card.card_is_in_slot:
			#card.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
			##if card.card_data.card_type == "Creature":
			#card.z_index = Z_INDEX_HIGHLIGHT_BORDER  # normale
			##else:
				##card.z_index = Z_INDEX_SLOT - 1  # le magie stanno sotto le creature
#
		#else:
			#tween.tween_property(card, "scale", Vector2(0.2, 0.2), 0.15)
			#card.z_index = Z_INDEX_HAND
#
			## Ripristina la posizione originale con tween
			#if card.has_meta("original_position"):
				#var original_pos: Vector2 = card.get_meta("original_position")
				#tween.tween_property(card, "position", original_pos, 0.15)
				#card.remove_meta("original_position")
				
func highlight_card(card, hovered):
	if card.card_data.card_type == "Spell" and card.card_is_in_slot:
		return

	if card.card_is_in_slot:
		# logica highlight slot
		return

	# 🧹 Kill tween precedente
	if card.has_meta("hover_tween") and card.get_meta("hover_tween").is_valid():
		card.get_meta("hover_tween").kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	card.set_meta("hover_tween", tween)

	if hovered:
		if card.get_meta("is_hovering", false):
			return
		card.set_meta("is_hovering", true)

		tween.parallel().tween_property(card, "scale", Vector2(1.25, 1.25), 0.10)
		tween.parallel().tween_property(card, "position", card.original_position - Vector2(0, 60), 0.10)

		card.z_index = Z_INDEX_HOVER

	else:
		if not card.get_meta("is_hovering", false):
			return
		card.set_meta("is_hovering", false)

		card.z_index = Z_INDEX_HAND

		tween.parallel().tween_property(card, "scale", Vector2(1, 1), 0.10)
		tween.parallel().tween_property(card, "position", card.original_position, 0.10)

	
		
func raycast_check_for_card_slot():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
		
	return null

func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD

	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		for item in result:
			var node = item.collider
			while node:
				if node.is_in_group("Cards"):
					print("👀 Card trovata dal raycast:", node.name)
					return node
				node = node.get_parent()
	return null
func raycast_check_for_own_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD # <-- Questo già include le carte tue

	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		for item in result:
			var node = item.collider
			while node:
				if node.has_method("is_card") and node.is_card() and not node.is_enemy_card():
					return node
				node = node.get_parent()
	return null
	
func raycast_check_for_enemy_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_ENEMY_HOVER  # o un altro dedicato
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null
	
func get_card_with_highest_z_index(cards):
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index
	
	for i in range(1, cards.size()):
		var current_card = cards[1].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card =  current_card
			highest_z_index = current_card.z_index
	return highest_z_card
	
	
func get_click_target_with_highest_z_index(results):
	var highest_card = null
	var highest_z = -1

	for entry in results:
		var node = entry.collider
		print("🔍 Collider:", node.name)
		while node and not (node.has_method("is_card") and node.is_card()):
			node = node.get_parent()
			if node:
				print("➡️ Salgo a:", node.name)
		if node and node.z_index > highest_z:
			highest_z = node.z_index
			highest_card = node
	return highest_card
	
func change_card_position(card):
	# ❗TODO: quando implementi le posizioni (attacco/difesa), qui dovrai cambiare sprite/rotazione/dati.
	# Per ora facciamo solo una stampa di debug.
	print("🔄 (placeholder) Cambio posizione di:", card.name)
	
	
func update_green_highlight_borders():
	for card in $"../CombatManager".player_creatures_on_field + $"../CombatManager".player_spells_on_field:
		var card_type = card.card_data.get("card_type", "")
		var card_class = card.card_data.get("card_class", "")
		var effect_type = card.card_data.get("effect_type", "")
		var effect_speed = card.card_data.get("effect_speed", "")

		var is_quick_effect = (effect_type == "Activable" and effect_speed == "Quick")
		var is_instant_spell = (card_class == "InstantSpell")

		var should_highlight = (is_quick_effect or is_instant_spell) and not card.effect_triggered_this_turn

		if card.has_node("GreenHighlightBorder"):
			card.get_node("GreenHighlightBorder").visible = should_highlight

func show_spent_mana_icons(card: Node, spent_types: Array[String]) -> void:
	var container = Node2D.new()
	container.name = "SpentManaIcons"
	card.add_child(container)

	# 🔑 Parametri
	const MANA_ICON_SCALE := 0.2
	const BASE_ICON_SIZE := 64
	const MAX_PER_ROW := 3

	const HORIZONTAL_SPACING := 30
	const VERTICAL_SPACING := 30   

	# 👇 calcolo righe necessarie
	var rows_needed: int = int(ceil(float(spent_types.size()) / MAX_PER_ROW))
	var START_Y: float
	if rows_needed > 1:
		START_Y = -15.0
	else:
		START_Y = 0.0

	for i in range(spent_types.size()):
		var icon := Sprite2D.new()
		var tex = $"../ManaSlots".MANA_TEXTURES.get(spent_types[i], null)
		if tex:
			icon.texture = tex

		icon.scale = Vector2(MANA_ICON_SCALE, MANA_ICON_SCALE)

		var row: int = i / MAX_PER_ROW
		var col: int = i % MAX_PER_ROW

		var icons_in_this_row: int = min(MAX_PER_ROW, spent_types.size() - row * MAX_PER_ROW)
		var total_width: float = float((icons_in_this_row - 1) * HORIZONTAL_SPACING)
		var start_x: float = -total_width / 2.0

		icon.position = Vector2(start_x + col * HORIZONTAL_SPACING, START_Y + row * VERTICAL_SPACING)
		container.add_child(icon)

		var tween = get_tree().create_tween()
		icon.modulate.a = 0.0
		tween.tween_property(icon, "modulate:a", 1.0, 0.1)
		
func hide_spent_mana_icons(card: Node) -> void:
	var container := card.get_node_or_null("SpentManaIcons")
	if container:
		container.queue_free()
		print("🧹 SpentManaIcons rimossi da", card.name)


@rpc("any_peer")
func rpc_hide_spent_mana_on_card(card_name: String, owner: String) -> void:
	var card: Node = null
	
	if owner == "Player":
		# carta avversaria → io la vedo nell’EnemyField
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/CardManager")
		if enemy_field:
			card = enemy_field.get_node_or_null(card_name)
	else:
		card = $"../CardManager".get_node_or_null(card_name)

	if card:
		hide_spent_mana_icons(card)
	else:
		print("❌ rpc_hide_spent_mana_on_card: carta non trovata:", card_name)

func add_attack_overlay(card: Node2D) -> void:
	if not card or not card.card_is_in_slot:
		return

	# 🔄 Rimuovi overlay precedente se già esiste
	if card.has_node("AttackIcon"):
		card.get_node("AttackIcon").queue_free()
		await get_tree().process_frame

	var icon := Sprite2D.new()
	icon.name = "AttackIcon"
	icon.texture = preload("res://Assets/Combat/SPADA ICONA.png")
	icon.position = Vector2(0, -20)  # sopra la carta
	icon.z_index = 200
	card.add_child(icon)

	# Fissalo dritto (se la carta è in difesa ruotata)
	icon.rotation_degrees = -card.rotation_degrees

	# 📏 Usa dimensione fissa
	var base_scale := Vector2(0.04, 0.04)
	icon.scale = base_scale

	# ✨ Tween per farlo “pulsare leggermente” attorno alla scala base
	var tween = card.create_tween()
	card.set_meta("attack_icon_pulse_tween", tween)
	tween.set_loops()
	tween.tween_property(icon, "scale", base_scale * 1.2, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(icon, "scale", base_scale, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	print("⚔️ AttackIcon aggiunto su", card.name, "con scala fissa:", base_scale)



func add_selection_overlay(card: Node2D) -> void:
	if not card or not card.card_is_in_slot:
		return

	# 🔄 Rimuovi overlay precedente se già esiste
	if card.has_node("SelectionBorder"):
		card.get_node("SelectionBorder").queue_free()

	var border := Sprite2D.new()
	border.name = "SelectionBorder"
	border.texture = preload("res://Assets/Chains/Chain Border.png")
	border.position = Vector2(0, -10)
	border.z_index = 200
	card.add_child(border)

	# Fissalo dritto (se la carta è in difesa ruotata)
	border.rotation_degrees = -card.rotation_degrees

	# ✨ Tween per farlo “pulsare”
	var tween = card.create_tween()
	card.set_meta("selection_pulse_tween", tween)
	tween.set_loops()
	tween.tween_property(border, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(border, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func remove_selection_overlay(card: Node2D) -> void:
	if not card:
		return
	if card.has_meta("selection_pulse_tween"):
		var tween: Tween = card.get_meta("selection_pulse_tween")
		if tween and tween.is_valid():
			tween.kill()
		card.remove_meta("selection_pulse_tween")

	if card.has_node("SelectionBorder"):
		card.get_node("SelectionBorder").queue_free()

func remove_attack_overlay(card: Node2D) -> void:
	if not card:
		return
	if card.has_meta("attack_icon_pulse_tween"):
		var tween: Tween = card.get_meta("attack_icon_pulse_tween")
		if tween and tween.is_valid():
			tween.kill()
		card.remove_meta("attack_icon_pulse_tween")

	if card.has_node("AttackIcon"):
		card.get_node("AttackIcon").queue_free()

var tribute_selection_active: bool = false
var tribute_selection_required: int = 0
var tribute_selected_cards: Array = []
var tribute_card_to_summon: Node = null
var tribute_slot_to_summon: Node = null
var tribute_is_for_summon: bool = false

func start_tribute_selection(card_to_summon: Node, tributes_needed: int, is_for_tribute_summ: bool = false) -> void:
	tribute_selection_active = true
	tribute_selection_required = tributes_needed
	tribute_selected_cards.clear()
	tribute_card_to_summon = card_to_summon
	tribute_slot_to_summon = pending_slot_to_place
	
	
	tribute_is_for_summon = is_for_tribute_summ 
	print("🕯️ Inizio selezione tributi: servono", tributes_needed)

	# Entra in modalità selezione per sacrificio
	# Entra in modalità selezione per sacrificio
	var cm = $"../CombatManager"

	for card in cm.player_creatures_on_field:
		if card.is_card() and card.card_data.card_type == "Creature" and card.card_is_in_slot and not cm.summoned_this_turn.any(func(entry):
			return entry.card == card
		):
			card.action_border.visible = true


	enter_selection_mode(card_to_summon, "tribute_selection")
	
func finish_tribute_selection():
	print("💀 Sacrificio di", tribute_selected_cards.size(), "creature.")
	
	await get_tree().create_timer(0.3).timeout
	
	for tribute_card in tribute_selected_cards:
		if is_instance_valid(tribute_card):
			print("💀 Sacrifico come tributo:", tribute_card.card_data.card_name)

			for card in $"../CombatManager".player_creatures_on_field:
				card.action_border.visible = false

			var owner = "Player"
			$"../CombatManager".tribute_card(tribute_card, owner, tribute_is_for_summon) # 👈 passaggio del flag
			rpc("rpc_tribute_card", tribute_card.name, owner, tribute_is_for_summon)

			await get_tree().create_timer(0.3).timeout
	
	# Ripulisci stato
	tribute_selection_active = false
	tribute_selected_cards.clear()

	# Caso normale → la carta viene evocata giocandola
	if tribute_card_to_summon and tribute_slot_to_summon:
		gioca_carta_subito(tribute_card_to_summon, tribute_slot_to_summon)

	# 🪄 Caso speciale: carta flippata con costo di sacrificio
	elif tribute_card_to_summon and not tribute_slot_to_summon:
		print("✨ Carta flippata con costo di sacrificio → attivo effetto OnPlay:", tribute_card_to_summon.card_data.card_name)

		if tribute_card_to_summon.card_data.targeting_type == "Targeted":
			enter_selection_mode(tribute_card_to_summon, "effect")

			# 🧩 DELAY AZIONE IDENTICO A gioca_carta_subito()
			if not $"../CombatManager".pending_action_after_chain:
				print("⏳ [Action Delay] Flip Targeted (tribute) → azione passerà dopo chain.")
				action_consume_pending = true
				$"../CombatManager".pending_action_after_chain = true
				$"../CombatManager".pending_action_owner_id = multiplayer.get_unique_id()

		else:
			trigger_card_effect(tribute_card_to_summon)

			# 🧩 DELAY ACTION per Untargeted
			if not $"../CombatManager".pending_action_after_chain:
				print("⏳ [Action Delay] Flip Untargeted (tribute) → azione passerà dopo chain.")
				action_consume_pending = true
				$"../CombatManager".pending_action_after_chain = true
				$"../CombatManager".pending_action_owner_id = multiplayer.get_unique_id()

	# Cleanup finale
	tribute_card_to_summon = null
	tribute_slot_to_summon = null



@rpc("any_peer")
func rpc_tribute_card(card_name: String, owner: String, is_for_tribute_summ: bool = false):
	var card: Node = null
	var is_owner = owner == "Player"

	if is_owner:
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/CardManager")
		if enemy_field:
			card = enemy_field.get_node_or_null(card_name)
	else:
		card = $"../CardManager".get_node_or_null(card_name)

	if not card:
		print("❌ rpc_tribute_card: carta non trovata su questo client →", card_name)
		return

	var local_owner = "Opponent" if owner == "Player" else "Player"

	print("📡 RPC Tribute ricevuto →", card_name, "| owner remoto:", owner, "→ locale:", local_owner, "| is_for_tribute_summ:", is_for_tribute_summ)

	$"../CombatManager".tribute_card(card, local_owner, is_for_tribute_summ)



func apply_existing_aura_effect(card: Node2D):
	var combat_manager = $"../CombatManager"
	if not is_instance_valid(combat_manager):
		print("⛔ [AURA CHECK] CombatManager non valido → esco.")
		return
	if card.card_data.card_type != "Creature":
		print("⛔ [AURA CHECK] La carta non è una creatura:", card.card_data.card_name)
		return

	print("\n🧭 [AURA CHECK] Nuova carta giocata:", card.card_data.card_name, "| Tipo:", card.card_data.card_type, "| Enemy:", card.is_enemy_card())

	# ✅ Controlla sia player che opponent
	var aura_collections = [
		combat_manager.player_spells_on_field,
		combat_manager.opponent_spells_on_field
	]

	print("📦 [AURA DEBUG] player_spells:", combat_manager.player_spells_on_field.size(),
		"| opponent_spells:", combat_manager.opponent_spells_on_field.size())

	for aura_list in aura_collections:
		print("\n🔁 [AURA CHECK] Nuova lista da controllare → size:", aura_list.size())

		for aura_card in aura_list:
			print("🔎 [SCAN] Analizzo:", aura_card if is_instance_valid(aura_card) else "INVALID")
				# 🚫 Ignora carte coperte
			if aura_card.position_type == "facedown":
				print("🙈 [AURA SKIP] Carta coperta →", card.card_data.card_name, "non riceve aura.")
				continue
			if not is_instance_valid(aura_card):
				print("⛔ [SKIP] aura_card non valida (probabilmente rimossa o freed)")
				continue
			if aura_card.card_data.effect_type != "Aura":
				print("⛔ [SKIP] Non è un’aura →", aura_card.card_data.card_name, "| effect_type:", aura_card.card_data.effect_type)
				continue
			# 🚫 SKIP TOTALE se la carta è già influenzata da questa aura
			if aura_card.aura_affected_cards.any(
				func(entry):
					return typeof(entry) == TYPE_DICTIONARY and entry.card == card
			):
				print("⏭️ [AURA SKIP] ", card.card_data.card_name,
					"già influenzata da", aura_card.card_data.card_name)
				continue

			# 🔄 Cicla su tutti e 4 gli effetti
			for i in range(1, 5):
				var eff_name = aura_card.card_data.get("effect_%d" % i)
				if eff_name == "None":
					continue
				# 📊 Magnitude effettiva (ordine di priorità)
				var magnitude := 0.0

				# 1️⃣ Se esiste una magnitude aggiornata da spellpower, usala
				if aura_card.has_meta("current_effective_magnitude"):
					magnitude = aura_card.get_meta("current_effective_magnitude")
					print("💫 [AURA META] Magnitude aggiornata da spellpower:", magnitude)
				else:
					# 2️⃣ Altrimenti, controlla se l’aura ha salvato magnitude in una entry precedente
					for entry in aura_card.aura_affected_cards:
						if typeof(entry) == TYPE_DICTIONARY and entry.has("magnitude"):
							magnitude = entry.magnitude
							break
					# 3️⃣ Fallback finale → valore base da card_data
					if magnitude == 0.0:
						magnitude = aura_card.card_data.get("effect_magnitude_%d" % i)

				if magnitude == 0.0:
					continue

				# 🎯 Usa la helper di card.gd per il controllo del subtype
				var t_sub = aura_card.card_data.get("t_subtype_%d" % i)
				var valid_target = aura_card._aura_target_matches_subtype(card, t_sub)
				if not valid_target:
					print("🚫 [AURA APPLY] Target non valido per subtype:", t_sub, "→ skip", card.card_data.card_name)
					continue
				# ⚡ Applica effetto
				match eff_name:
					"Buff":
						print("🟩 Buff totale (ATK+HP):", magnitude)

						if magnitude > 0:
							var voided_atk = card.card_data.voided_atk

							# Calcola buff effettivo (non può essere negativo)
							var effective_buff = max(0, magnitude - voided_atk)

							# Aggiorna l’attacco e i massimali
							card.card_data.attack += effective_buff
							card.card_data.max_attack += effective_buff

							# HP sempre aumentano della magnitude completa
							card.card_data.health += magnitude
							card.card_data.max_health += magnitude

							# Riduci il voided atk in base al buff
							card.card_data.voided_atk = max(0, voided_atk - magnitude)

							print("⚖️ [AURA BUFF] Magnitude:", magnitude, 
								"| voided_atk prima:", voided_atk, 
								"| buff effettivo:", effective_buff, 
								"| voided_atk dopo:", card.card_data.voided_atk)

							card.card_data.add_buff(aura_card, "Buff", magnitude, magnitude)
							await get_tree().process_frame
							card.update_card_visuals()

							print("💪 [AURA BUFF] +", effective_buff, "ATK / +", magnitude, "HP su", card.card_data.card_name)

						## 🧹 Pulisce tooltips / voided
							#combat_manager.cleanup_voided_atk_and_tooltips(card)
					"BuffAtk":
						print("🟩 Buff totale (ATK+HP):", magnitude)

						if magnitude > 0:
							var voided_atk = card.card_data.voided_atk

							# Calcola buff effettivo (non può essere negativo)
							var effective_buff = max(0, magnitude - voided_atk)
							# Aggiorna l’attacco e i massimali
							card.card_data.attack += effective_buff
							card.card_data.max_attack += effective_buff

							# Riduci il voided atk in base al buff
							card.card_data.voided_atk = max(0, voided_atk - magnitude)

							print("⚖️ [AURA BUFF] Magnitude:", magnitude, 
								"| voided_atk prima:", voided_atk, 
								"| buff effettivo:", effective_buff, 
								"| voided_atk dopo:", card.card_data.voided_atk)

							card.card_data.add_buff(aura_card, "Buff", magnitude, magnitude)
							await get_tree().process_frame
							card.update_card_visuals()

							print("💪 [AURA BUFF] +", effective_buff, "ATK / +", magnitude, "HP su", card.card_data.card_name)

						#print("💪 [AURA BUFF ATK] +", effective_buff, "ATK su", card.card_data.card_name)
						#combat_manager.cleanup_voided_atk_and_tooltips(card)
						
					"BuffHp":
						print("🟦 Buff HP:", magnitude)


						card.card_data.health += magnitude
						card.card_data.max_health += magnitude
						card.card_data.add_buff(aura_card, "BuffHp", 0, magnitude)
						
					"BuffArmour":
						print("🛡️ [AURA BUFF ARMOUR] +", magnitude, "Armour su", card.card_data.card_name)
						card.card_data.armour += magnitude
						card.card_data.add_buff(aura_card, "BuffArmour", 0, 0, magnitude)

					# 💀 DEBUFF
					"Debuff":
						print("💀 [AURA] Debuff totale (ATK+HP):", magnitude)

						# 🔹 Calcolo riduzioni effettive prima del clamp
						var old_atk = card.card_data.attack
						var old_hp = card.card_data.health
						var old_max_atk = card.card_data.max_attack
						var old_max_hp = card.card_data.max_health

						card.card_data.attack = max(card.card_data.attack - magnitude, 0)
						card.card_data.health = max(card.card_data.health - magnitude, 0)
						card.card_data.max_attack = max(card.card_data.max_attack - magnitude, 0)
						card.card_data.max_health = max(card.card_data.max_health - magnitude, 0)

						# 🔸 Calcola quanto è stato effettivamente ridotto
						var atk_loss = old_atk - card.card_data.attack
						var hp_loss = old_hp - card.card_data.health

						# 💾 Aumenta il voided_atk del card_data per la parte non applicata
						var voided_increase = max(0, magnitude - atk_loss)
						card.card_data.voided_atk += voided_increase
						card.card_data.voided_atk = max(0, card.card_data.voided_atk) # sicurezza

						print("🕳️ Voided ATK incrementato di:", voided_increase, 
							"→ Totale:", card.card_data.voided_atk)

						card.card_data.add_debuff(aura_card, "Debuff", magnitude, magnitude)
						await get_tree().process_frame
						card.update_card_visuals()

						print("💀 [AURA DEBUFF] -", atk_loss, "ATK /", hp_loss, "HP su", card.card_data.card_name)
						print("🎨 ATK:", card.card_data.attack, " / ORIG:", card.card_data.original_attack, " / MAX:", card.card_data.max_attack)
						print("🎨 HP:", card.card_data.health, " / ORIG:", card.card_data.original_health, " / MAX:", card.card_data.max_health)

					"DebuffAtk":
						print("💀 [AURA] Debuff ATK:", magnitude)

						var old_atk = card.card_data.attack
						var old_max_atk = card.card_data.max_attack

						card.card_data.max_attack = max(card.card_data.max_attack - magnitude, 0)
						card.card_data.attack = max(card.card_data.attack - magnitude, 0)

						var atk_loss = old_atk - card.card_data.attack

						# 💾 Aumenta il voided_atk per la parte di debuff non applicata
						var voided_increase = max(0, magnitude - atk_loss)
						card.card_data.voided_atk += voided_increase
						card.card_data.voided_atk = max(0, card.card_data.voided_atk) # sicurezza

						print("🕳️ Voided ATK incrementato di:", voided_increase, 
							"→ Totale:", card.card_data.voided_atk)

						card.card_data.add_debuff(aura_card, "DebuffAtk", magnitude, 0)
						await get_tree().process_frame
						card.update_card_visuals()

						print("💀 [AURA DEBUFF ATK] -", atk_loss, "ATK su", card.card_data.card_name)
						print("🎨 ATK:", card.card_data.attack, " / ORIG:", card.card_data.original_attack, " / MAX:", card.card_data.max_attack)
						print("🎨 HP:", card.card_data.health, " / ORIG:", card.card_data.original_health, " / MAX:", card.card_data.max_health)


					"DebuffHp":
						print("💀 [AURA] Debuff HP:", magnitude)

						var old_hp = card.card_data.health
						var old_max_hp = card.card_data.max_health

						card.card_data.max_health = max(card.card_data.max_health - magnitude, 0)
						card.card_data.health = max(card.card_data.health - magnitude, 0)

						var hp_loss = old_hp - card.card_data.health
						
						card.card_data.add_debuff(aura_card, "DebuffHp", 0, magnitude)
						await get_tree().process_frame
						card.update_card_visuals()

						print("💀 [AURA DEBUFF HP] -", hp_loss, "HP su", card.card_data.card_name)
						print("🎨 ATK:", card.card_data.attack, " / ORIG:", card.card_data.original_attack, " / MAX:", card.card_data.max_attack)
						print("🎨 HP:", card.card_data.health, " / ORIG:", card.card_data.original_health, " / MAX:", card.card_data.max_health)

				card.update_card_visuals()

				# 🔗 Collega la carta all’aura se non già presente
				if not aura_card.aura_affected_cards.any(func(entry): return typeof(entry) == TYPE_DICTIONARY and entry.card == card):
					var new_entry = {
						"card": card,
						"magnitude": magnitude
					}

					aura_card.aura_affected_cards.append(new_entry)
					print("🔗 [AURA LINK] Aggiunta", card.card_data.card_name,
						"tra le carte influenzate da", aura_card.card_data.card_name,
						"(mag:", magnitude, ")")

		print("✅ [AURA CHECK COMPLETED] per", card.card_data.card_name)






func apply_existing_aura_effect_per_rpc(card: Node2D):
	var combat_manager = $"../CombatManager"
	if not is_instance_valid(combat_manager):
		print("⛔ [AURA CHECK] CombatManager non valido → esco.")
		return
	if card.card_data.card_type != "Creature":
		print("⛔ [AURA CHECK] La carta non è una creatura:", card.card_data.card_name)
		return

	print("\n🧭 [AURA CHECK] Nuova carta giocata:", card.card_data.card_name, "| Tipo:", card.card_data.card_type, "| Enemy:", card.is_enemy_card())

	# ✅ Controlla sia player che opponent
	var aura_collections = [
		combat_manager.player_spells_on_field,
		combat_manager.opponent_spells_on_field
	]

	print("📦 [AURA DEBUG] player_spells:", combat_manager.player_spells_on_field.size(),
		"| opponent_spells:", combat_manager.opponent_spells_on_field.size())

	for aura_list in aura_collections:
		print("\n🔁 [AURA CHECK] Nuova lista da controllare → size:", aura_list.size())

		for aura_card in aura_list:
			print("🔎 [SCAN] Analizzo:", aura_card if is_instance_valid(aura_card) else "INVALID")
				# 🚫 Ignora carte coperte
			if aura_card.position_type == "facedown":
				print("🙈 [AURA SKIP] Carta coperta →", card.card_data.card_name, "non riceve aura.")
				continue
			if not is_instance_valid(aura_card):
				print("⛔ [SKIP] aura_card non valida (probabilmente rimossa o freed)")
				continue
			if aura_card.card_data.effect_type != "Aura":
				print("⛔ [SKIP] Non è un’aura →", aura_card.card_data.card_name, "| effect_type:", aura_card.card_data.effect_type)
				continue


			# 🔄 Cicla su tutti e 4 gli effetti
			for i in range(1, 5):
				var eff_name = aura_card.card_data.get("effect_%d" % i)
				if eff_name == "None":
					continue
				# 📊 Magnitude effettiva (ordine di priorità)
				var magnitude := 0.0

				# 1️⃣ Se esiste una magnitude aggiornata da spellpower, usala
				if aura_card.has_meta("current_effective_magnitude"):
					magnitude = aura_card.get_meta("current_effective_magnitude")
					print("💫 [AURA META] Magnitude aggiornata da spellpower:", magnitude)
				else:
					# 2️⃣ Altrimenti, controlla se l’aura ha salvato magnitude in una entry precedente
					for entry in aura_card.aura_affected_cards:
						if typeof(entry) == TYPE_DICTIONARY and entry.has("magnitude"):
							magnitude = entry.magnitude
							break
					# 3️⃣ Fallback finale → valore base da card_data
					if magnitude == 0.0:
						magnitude = aura_card.card_data.get("effect_magnitude_%d" % i)

				if magnitude == 0.0:
					continue

				# 🎯 Usa la helper di card.gd per il controllo del subtype
				var t_sub = aura_card.card_data.get("t_subtype_%d" % i)
				var valid_target = aura_card._aura_target_matches_subtype(card, t_sub)
				if not valid_target:
					print("🚫 [AURA APPLY] Target non valido per subtype:", t_sub, "→ skip", card.card_data.card_name)
					continue
				# ⚡ Applica effetto
				match eff_name:
					"Buff":
						print("🟩 Buff totale (ATK+HP):", magnitude)

						if magnitude > 0:
							var voided_atk = card.card_data.voided_atk

							# Calcola buff effettivo (non può essere negativo)
							var effective_buff = max(0, magnitude - voided_atk)

							# Aggiorna l’attacco e i massimali
							card.card_data.attack += effective_buff
							card.card_data.max_attack += effective_buff

							# HP sempre aumentano della magnitude completa
							card.card_data.health += magnitude
							card.card_data.max_health += magnitude

							# Riduci il voided atk in base al buff
							card.card_data.voided_atk = max(0, voided_atk - magnitude)

							print("⚖️ [AURA BUFF] Magnitude:", magnitude, 
								"| voided_atk prima:", voided_atk, 
								"| buff effettivo:", effective_buff, 
								"| voided_atk dopo:", card.card_data.voided_atk)

							card.card_data.add_buff(aura_card, "Buff", magnitude, magnitude)
							await get_tree().process_frame
							card.update_card_visuals()

							print("💪 [AURA BUFF] +", effective_buff, "ATK / +", magnitude, "HP su", card.card_data.card_name)

						## 🧹 Pulisce tooltips / voided
							#combat_manager.cleanup_voided_atk_and_tooltips(card)
					"BuffAtk":
						print("🟩 Buff totale (ATK+HP):", magnitude)

						if magnitude > 0:
							var voided_atk = card.card_data.voided_atk

							# Calcola buff effettivo (non può essere negativo)
							var effective_buff = max(0, magnitude - voided_atk)
							# Aggiorna l’attacco e i massimali
							card.card_data.attack += effective_buff
							card.card_data.max_attack += effective_buff

							# Riduci il voided atk in base al buff
							card.card_data.voided_atk = max(0, voided_atk - magnitude)

							print("⚖️ [AURA BUFF] Magnitude:", magnitude, 
								"| voided_atk prima:", voided_atk, 
								"| buff effettivo:", effective_buff, 
								"| voided_atk dopo:", card.card_data.voided_atk)

							card.card_data.add_buff(aura_card, "Buff", magnitude, magnitude)
							await get_tree().process_frame
							card.update_card_visuals()

							print("💪 [AURA BUFF] +", effective_buff, "ATK / +", magnitude, "HP su", card.card_data.card_name)

						#print("💪 [AURA BUFF ATK] +", effective_buff, "ATK su", card.card_data.card_name)
						#combat_manager.cleanup_voided_atk_and_tooltips(card)
						
					"BuffHp":
						print("🟦 Buff HP:", magnitude)


						card.card_data.health += magnitude
						card.card_data.max_health += magnitude
						card.card_data.add_buff(aura_card, "BuffHp", 0, magnitude)
					"BuffArmour":
						print("🛡️ [AURA BUFF ARMOUR] +", magnitude, "Armour su", card.card_data.card_name)
						card.card_data.armour += magnitude
						card.card_data.add_buff(aura_card, "BuffArmour", 0, 0, magnitude)
					# 💀 DEBUFF
					"Debuff":
						print("💀 [AURA] Debuff totale (ATK+HP):", magnitude)

						# 🔹 Calcolo riduzioni effettive prima del clamp
						var old_atk = card.card_data.attack
						var old_hp = card.card_data.health
						var old_max_atk = card.card_data.max_attack
						var old_max_hp = card.card_data.max_health

						card.card_data.attack = max(card.card_data.attack - magnitude, 0)
						card.card_data.health = max(card.card_data.health - magnitude, 0)
						card.card_data.max_attack = max(card.card_data.max_attack - magnitude, 0)
						card.card_data.max_health = max(card.card_data.max_health - magnitude, 0)

						# 🔸 Calcola quanto è stato effettivamente ridotto
						var atk_loss = old_atk - card.card_data.attack
						var hp_loss = old_hp - card.card_data.health

						# 💾 Aumenta il voided_atk del card_data per la parte non applicata
						var voided_increase = max(0, magnitude - atk_loss)
						card.card_data.voided_atk += voided_increase
						card.card_data.voided_atk = max(0, card.card_data.voided_atk) # sicurezza

						print("🕳️ Voided ATK incrementato di:", voided_increase, 
							"→ Totale:", card.card_data.voided_atk)

						card.card_data.add_debuff(aura_card, "Debuff", magnitude, magnitude)
						await get_tree().process_frame
						card.update_card_visuals()

						print("💀 [AURA DEBUFF] -", atk_loss, "ATK /", hp_loss, "HP su", card.card_data.card_name)
						print("🎨 ATK:", card.card_data.attack, " / ORIG:", card.card_data.original_attack, " / MAX:", card.card_data.max_attack)
						print("🎨 HP:", card.card_data.health, " / ORIG:", card.card_data.original_health, " / MAX:", card.card_data.max_health)

					"DebuffAtk":
						print("💀 [AURA] Debuff ATK:", magnitude)

						var old_atk = card.card_data.attack
						var old_max_atk = card.card_data.max_attack

						card.card_data.max_attack = max(card.card_data.max_attack - magnitude, 0)
						card.card_data.attack = max(card.card_data.attack - magnitude, 0)

						var atk_loss = old_atk - card.card_data.attack

						# 💾 Aumenta il voided_atk per la parte di debuff non applicata
						var voided_increase = max(0, magnitude - atk_loss)
						card.card_data.voided_atk += voided_increase
						card.card_data.voided_atk = max(0, card.card_data.voided_atk) # sicurezza

						print("🕳️ Voided ATK incrementato di:", voided_increase, 
							"→ Totale:", card.card_data.voided_atk)

						card.card_data.add_debuff(aura_card, "DebuffAtk", magnitude, 0)
						await get_tree().process_frame
						card.update_card_visuals()

						print("💀 [AURA DEBUFF ATK] -", atk_loss, "ATK su", card.card_data.card_name)
						print("🎨 ATK:", card.card_data.attack, " / ORIG:", card.card_data.original_attack, " / MAX:", card.card_data.max_attack)
						print("🎨 HP:", card.card_data.health, " / ORIG:", card.card_data.original_health, " / MAX:", card.card_data.max_health)


					"DebuffHp":
						print("💀 [AURA] Debuff HP:", magnitude)

						var old_hp = card.card_data.health
						var old_max_hp = card.card_data.max_health

						card.card_data.max_health = max(card.card_data.max_health - magnitude, 0)
						card.card_data.health = max(card.card_data.health - magnitude, 0)

						var hp_loss = old_hp - card.card_data.health
						
						card.card_data.add_debuff(aura_card, "DebuffHp", 0, magnitude)
						await get_tree().process_frame
						card.update_card_visuals()

						print("💀 [AURA DEBUFF HP] -", hp_loss, "HP su", card.card_data.card_name)
						print("🎨 ATK:", card.card_data.attack, " / ORIG:", card.card_data.original_attack, " / MAX:", card.card_data.max_attack)
						print("🎨 HP:", card.card_data.health, " / ORIG:", card.card_data.original_health, " / MAX:", card.card_data.max_health)

				card.update_card_visuals()

				# 🔗 Collega la carta all’aura se non già presente
				if not aura_card.aura_affected_cards.any(func(entry): return typeof(entry) == TYPE_DICTIONARY and entry.card == card):
					var new_entry = {
						"card": card,
						"magnitude": magnitude
					}

					aura_card.aura_affected_cards.append(new_entry)
					print("🔗 [AURA LINK] Aggiunta", card.card_data.card_name,
						"tra le carte influenzate da", aura_card.card_data.card_name,
						"(mag:", magnitude, ")")

		print("✅ [AURA CHECK COMPLETED] per", card.card_data.card_name)


func apply_spell_power_effects(card_to_place: Node, is_enemy: bool = false, should_defer: bool = false, single_effect: String = "") -> void:
	# 🧙‍♂️ Applica o differisce l'effetto Spell Power
	# should_defer = true  →  non applica subito (verrà risolto in chain)
	# should_defer = false →  applica immediatamente (per effetti passivi / permanenti)

	if should_defer:
		print("⏳ [SPELL POWER] Effetto differito (should_defer = true) →", card_to_place.card_data.card_name)
		return
	
	var combat_manager = $"../CombatManager"
	var root = get_parent().get_parent()
		# ⛔ Evita di applicare l'effetto subito se la carta ha un trigger o è una spell attivabile

	# 🏷️ Determina il nome sorgente (tooltip_name > card_name)
	var source_name: String = ""
	if card_to_place.card_data.tooltip_name != "":
		source_name = card_to_place.card_data.tooltip_name
	else:
		source_name = card_to_place.card_data.card_name

	# 🔁 Scansiona tutti e 4 gli effetti definiti nella card_data
	for i in range(1, 5):
		var eff_name = card_to_place.card_data.get("effect_%d" % i)
		var t_sub = card_to_place.card_data.get("t_subtype_%d" % i)
		var magnitude = card_to_place.card_data.get("effect_magnitude_%d" % i)
				# ⚙️ Ricalcolo SCALING completo (così magnitude è sempre coerente)
		var scaling_type = card_to_place.card_data.get("scaling_%d" % i)
		var is_attacker = not is_enemy

		match scaling_type:
			"None":
				pass

			"SpellsPlayerGY":
				var gy_node

				# 🔍 Prende il cimitero del player che ha lanciato l'effetto
				if is_attacker:
					# Se io sono il giocatore che ha lanciato la carta, il mio GY è PlayerGY
					gy_node = get_parent().get_parent().get_node_or_null("PlayerField/PlayerGY")
				else:
					# Altrimenti prendo il GY dell'avversario (EnemyGY)
					gy_node = get_parent().get_parent().get_node_or_null("EnemyField/EnemyGY")

				var gy_cards = []
				if gy_node:
					gy_cards = gy_node.gy_cards
				else:
					print("⚠️ GY non trovato per scaling SpellsPlayerGY")

				var gy_spells = []
				for c in gy_cards:
					if c and c.card_type == "Spell":
						gy_spells.append(c)

				var gy_count = gy_spells.size()
				var scale_amount = card_to_place.card_data.get("scaling_amount_%d" % i)
				var bonus = gy_count * scale_amount
				magnitude += bonus
				print("📜 [SCALING SpellsPlayerGY #", i, "]",
					" | Spell in GY:", gy_count,
					" | Scaling Amount:", scale_amount,
					" | Bonus:", bonus,
					" | Magnitude finale:", magnitude)


			"CreaturesPlayerGY":
				# 🧮 scaling basato sul numero di Creature nel GY del giocatore
				var gy_node
				if is_attacker:
					gy_node = combat_manager.player_gy
				else:
					gy_node = combat_manager.enemy_gy

				var gy_cards = []
				if gy_node:
					gy_cards = gy_node.gy_cards

				var gy_creatures = []
				for c in gy_cards:
					if c and c.card_type == "Creature":
						gy_creatures.append(c)

				var gy_count = gy_creatures.size()
				var scale_amount = card_to_place.card_data.get("scaling_amount_%d" % i)
				var bonus = gy_count * scale_amount
				magnitude += bonus
				print("🦴 [SCALING CreaturesPlayerGY #", i, "]",
					" | Creature in GY:", gy_count,
					" | Scaling Amount:", scale_amount,
					" | Bonus:", bonus,
					" | Magnitude finale:", magnitude)

			"HandSize":
				# 🧮 scaling basato sul numero di carte in mano
				var hand_size = 0
				if is_attacker:
					hand_size = combat_manager.player_hand.size()
				else:
					hand_size = combat_manager.enemy_hand.size()

				var scale_amount = card_to_place.card_data.get("scaling_amount_%d" % i)
				var bonus = hand_size * scale_amount
				magnitude += bonus
				print("✋ [SCALING HandSize #", i, "]",
					" | Carte in mano:", hand_size,
					" | Scaling Amount:", scale_amount,
					" | Bonus:", bonus,
					" | Magnitude finale:", magnitude)

			_:
				print("⚠️ [SCALING] Tipo di scaling non riconosciuto:", scaling_type)

		# 👇 Filtro opzionale — che serve solo quando si applica un aumento di spellpower da effetto deferred
		if single_effect != "" and eff_name != single_effect:
			continue
			
		if eff_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWindSpellPower", "BuffEarthSpellPower", "BuffWaterSpellPower"]:
			print("🧭 CASSU Analizzo effetto %d: %s → Target: %s (magnitudine: %d)" % [i, eff_name, t_sub, magnitude])

			# 🔹 Determina lato del boost
			var apply_to_player = false
			var apply_to_enemy = false

			match t_sub:
				"SelfPlayer":
					if not is_enemy:
						apply_to_player = true
					else:
						apply_to_enemy = true
				"EnemyPlayer":
					if not is_enemy:
						apply_to_enemy = true
					else:
						apply_to_player = true
				"BothPlayers", "None":
					apply_to_player = true
					apply_to_enemy = true

			# ✨ Esegui l’aumento sul lato corretto
			if apply_to_player:
				_apply_single_spell_power_effect(combat_manager, eff_name, magnitude, false, source_name, card_to_place.card_data.temp_effect)
			if apply_to_enemy:
				_apply_single_spell_power_effect(combat_manager, eff_name, magnitude, true, source_name, card_to_place.card_data.temp_effect)




func _apply_single_spell_power_effect(combat_manager: Node, eff_name: String, magnitude: int, is_enemy: bool, source_name: String = "", temp_effect: String = "None"):
	var side_prefix = "Enemy" if is_enemy else "Player"
	var display_side = "Enemy" if is_enemy else "Player"
	print("⚙️GIOCATA CHIAMO update_all_aura_bonuses(ΔSP:", magnitude, ") per", eff_name)

	# 🔹 Determina il tipo di Spell Power
	var sp_type = "Generic"
	match eff_name:
		"BuffFireSpellPower": sp_type = "Fire"
		"BuffWaterSpellPower": sp_type = "Water"
		"BuffEarthSpellPower": sp_type = "Earth"
		"BuffWindSpellPower": sp_type = "Wind"

	# 🔹 Controlla se è temporaneo
	var is_temporary := (temp_effect == "EndPhase")
	if is_temporary:
		print("⏳ [TEMPORARY SP EFFECT] L'effetto di ", source_name, " è temporaneo (EndPhase).")

	# 🧾 Registra la sorgente nel CombatManager
	if source_name != "":
		if not combat_manager.spell_power_sources.has(sp_type):
			combat_manager.spell_power_sources[sp_type] = []
		combat_manager.spell_power_sources[sp_type].append({
			"source": source_name,
			"value": magnitude,
			"enemy": is_enemy,
			"temporary": is_temporary
		})

	# ✨ Esegue l’effetto visivo e logico (come prima)
	match eff_name:
		"BuffSpellPower":
			print("⚡ [%s FIELD] Generic Spell Power +%d" % [display_side, magnitude])
			await combat_manager.animate_spell_power_gain(side_prefix, magnitude)
			if is_enemy:
				combat_manager.enemy_SP += magnitude
				get_parent().get_parent().get_node("EnemyField/EnemySP").text = str(combat_manager.enemy_SP)
				combat_manager.update_all_aura_bonuses(magnitude, "Generic", true)
				combat_manager.update_all_enchant_bonuses(magnitude, "Generic", true)
			else:
				combat_manager.player_SP += magnitude
				$"../PlayerSP".text = str(combat_manager.player_SP)
				combat_manager.update_all_aura_bonuses(magnitude, "Generic", false)
				combat_manager.update_all_enchant_bonuses(magnitude, "Generic", false)

		"BuffFireSpellPower":
			print("🔥 [%s FIELD] Fire Spell Power +%d" % [display_side, magnitude])
			await combat_manager.animate_spell_power_gain(side_prefix + "Fire", magnitude)
			if is_enemy:
				combat_manager.enemy_FireSP += magnitude
				get_parent().get_parent().get_node("EnemyField/EnemyFireSP").text = str(combat_manager.enemy_FireSP)
				combat_manager.update_all_aura_bonuses(magnitude, "Fire", true)
				combat_manager.update_all_enchant_bonuses(magnitude, "Fire", true)
			else:
				combat_manager.player_FireSP += magnitude
				$"../PlayerFireSP".text = str(combat_manager.player_FireSP)
				combat_manager.update_all_aura_bonuses(magnitude, "Fire", false)
				combat_manager.update_all_enchant_bonuses(magnitude, "Fire", false)

		"BuffWindSpellPower":
			print("💨 [%s FIELD] Wind Spell Power +%d" % [display_side, magnitude])
			await combat_manager.animate_spell_power_gain(side_prefix + "Wind", magnitude)
			if is_enemy:
				combat_manager.enemy_WindSP += magnitude
				get_parent().get_parent().get_node("EnemyField/EnemyWindSP").text = str(combat_manager.enemy_WindSP)
				combat_manager.update_all_aura_bonuses(magnitude, "Wind", true)
				combat_manager.update_all_enchant_bonuses(magnitude, "Wind", true)
			else:
				combat_manager.player_WindSP += magnitude
				$"../PlayerWindSP".text = str(combat_manager.player_WindSP)
				combat_manager.update_all_aura_bonuses(magnitude, "Wind", false)
				combat_manager.update_all_enchant_bonuses(magnitude, "Wind", false)

		"BuffEarthSpellPower":
			print("🌱 [%s FIELD] Earth Spell Power +%d" % [display_side, magnitude])
			await combat_manager.animate_spell_power_gain(side_prefix + "Earth", magnitude)
			if is_enemy:
				combat_manager.enemy_EarthSP += magnitude
				get_parent().get_parent().get_node("EnemyField/EnemyEarthSP").text = str(combat_manager.enemy_EarthSP)
				combat_manager.update_all_aura_bonuses(magnitude, "Earth", true)
				combat_manager.update_all_enchant_bonuses(magnitude, "Earth", true)
			else:
				combat_manager.player_EarthSP += magnitude
				$"../PlayerEarthSP".text = str(combat_manager.player_EarthSP)
				combat_manager.update_all_aura_bonuses(magnitude, "Earth", false)
				combat_manager.update_all_enchant_bonuses(magnitude, "Earth", false)

		"BuffWaterSpellPower":
			print("💧 [%s FIELD] Water Spell Power +%d" % [display_side, magnitude])
			await combat_manager.animate_spell_power_gain(side_prefix + "Water", magnitude)
			if is_enemy:
				combat_manager.enemy_WaterSP += magnitude
				get_parent().get_parent().get_node("EnemyField/EnemyWaterSP").text = str(combat_manager.enemy_WaterSP)
				combat_manager.update_all_aura_bonuses(magnitude, "Water", true)
				combat_manager.update_all_enchant_bonuses(magnitude, "Water", true)
			else:
				combat_manager.player_WaterSP += magnitude
				$"../PlayerWaterSP".text = str(combat_manager.player_WaterSP)
				combat_manager.update_all_aura_bonuses(magnitude, "Water", false)
				combat_manager.update_all_enchant_bonuses(magnitude, "Water", false)


# card_manager.gd

func check_activation_cost(card: Card) -> bool:
	var cm = $"../CombatManager"
	if not cm:
		print("⚠️ check_activation_cost: CombatManager non trovato.")
		return false

	if not card or not card.card_data:
		print("⚠️ check_activation_cost: Carta non valida.")
		return false

	var cost_type = card.card_data.activation_cost

	match cost_type:
		# 🩸 Caso 1: Serve sacrificare una creatura alleata
		"sacrificeAllyCreature":
			var player_creatures = cm.player_creatures_on_field
			if player_creatures.is_empty():
				print("❌ Attivazione negata:", card.card_data.card_name, "| Nessuna creatura alleata da sacrificare.")
				return false
			return true

		# 💧 Caso 2: Serve avere almeno una creatura alleata di attributo WATER o classe SPELLCASTER
		"AllyCreature_Water_or_SpellCaster":
			var player_creatures = cm.player_creatures_on_field
			for c in player_creatures:
				if not c or not c.card_data:
					continue
				var data = c.card_data
				if data.card_attribute == "Water" or data.card_class == "Spellcaster" or data.card_class_2 == "Spellcaster":
					print("✅ Requisito soddisfatto: trovato alleato WATER o SPELLCASTER →", data.card_name)
					return true
			print("❌ Attivazione negata:", card.card_data.card_name, "| Nessuna creatura WATER o SPELLCASTER alleata sul campo.")
			return false

		# 🌊 NUOVO CASO: Field Flooded
		"FieldFlooded":
			# basta controllare un solo slot (se il field è globale)
			var zones = cm.get_tree().get_current_scene().get_node_or_null("PlayerField/PlayerZones")
			if not zones:
				print("⚠️ FieldFlooded: PlayerZones non trovate.")
				return false

			for slot in zones.get_children():
				if not slot.flooded:
					print("❌ Attivazione negata:", card.card_data.card_name, "| Il campo NON è flooded.")
					return false

			print("✅ Requisito FieldFlooded soddisfatto → campo allagato.")
			return true

		# 🟦 Nessun costo
		"None":
			return true

		# 🚫 Caso sconosciuto
		_:
			print("⚠️ Tipo di costo di attivazione non riconosciuto:", cost_type)
			return true

@rpc("any_peer")
func rpc_mark_card_as_enchained(card_name: String, owner_id: int):
	var local_id = multiplayer.get_unique_id()
	var card: Node = null

	# Se la carta appartiene a me → cerca nel mio CardManager
	if local_id == owner_id:
		card = $"../CardManager".get_node_or_null(card_name)
	else:
		# Altrimenti cerca nel campo nemico
		card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card:
		card.was_enchained = true
		print("🟢 [SYNC ENCHAIN] Carta marcata come enchained:", card.name, "su peer", local_id)

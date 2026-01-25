extends Node

enum Phase {
	START,
	UPKEEP, # 🆕 Nuova fase
	MAIN,
	PREPARATION,
	BATTLE,
	END
}
var player_is_attacker: bool = false
var player_is_defender: bool = false
var first_turn_done: bool = false # Per sapere se siamo ancora nel primo turno
var current_phase: Phase = Phase.START
var has_passed_this_phase = false
var enemy_has_passed_this_phase = false
var last_action_from_attack := false
var already_passed_phase := {} # Dictionary<Phase, bool>
@onready var actions_container = $"../ActionsContainer"
@onready var action_icon = actions_container.get_node("ActionIcon")
var player_action_count: int = 0
var enemy_action_count: int = 0

@onready var draw_prompt_label = $"../PromptLabels/DrawPromptLabel"
@onready var player_pass_button = $"../PlayerPassPhaseButton"
@onready var enemy_pass_button = $"../EnemyPassPhaseButton"
@onready var phase_indicators = {
	Phase.START: $"../PhaseIndicators/StartPhasePanel",
	Phase.UPKEEP: $"../PhaseIndicators/UpkeepPhasePanel", # 🆕
	Phase.MAIN: $"../PhaseIndicators/MainPhasePanel",
	Phase.PREPARATION: $"../PhaseIndicators/PrepPhasePanel",
	Phase.BATTLE: $"../PhaseIndicators/BattlePhasePanel",
	Phase.END: $"../PhaseIndicators/EndPhasePanel"
}

func _ready():
	player_pass_button.pressed.connect(func(): on_player_pass_button_pressed(true))
	player_pass_button.disabled = false
	player_pass_button.text = "Pass Phase"
	
	enemy_pass_button.modulate = Color(0, 0, 0, 0)  #invisibile ad inizio game
	enemy_pass_button.visible = false
	enemy_pass_button.disabled = false
	enemy_pass_button.text = "Pass Phase"
	enemy_pass_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	update_phase_indicators() # 🆕 Aggiungi questa riga qui!!
	
	print("🟢 Fase iniziale:", get_phase_name())

func on_player_pass_button_pressed(is_manual: bool = false, force: bool = false):
	
		# ⛔FAILSAFE Guard: già passato questa fase → ignora
	if already_passed_phase.get(current_phase, false):
		print("⛔ [PhaseManager] Pass già eseguito per", get_phase_name(), "→ ignoro chiamata duplicata.")
		return
		
	var input_manager = get_parent().get_node_or_null("InputManager")
	if input_manager and input_manager.inputs_disabled and player_action_count == 0 and not force:
		print("🔒 [ActionButtons] Input disabilitato → click ignorato (PlayerPass)")
		player_pass_button.focus_mode = Control.FOCUS_NONE
		player_pass_button.release_focus()
		return

	if $"../CardManager".selection_mode_active:
		player_pass_button.focus_mode = Control.FOCUS_NONE
		player_pass_button.release_focus()
		print("⛔ Non puoi passare la fase mentre sei in selection mode.")
		return

	# 🧹 Pulizia visiva globale
	var action_buttons = $"../ActionButtons"
	if action_buttons:
		if action_buttons.player_selection_label.visible:
			action_buttons.hide_label(action_buttons.player_selection_label)
		if action_buttons.enchain_label.visible:
			action_buttons.hide_label(action_buttons.enchain_label)
		action_buttons.force_hide_all_green_borders()
		print("🧹 Pulizia visiva: nascosti Target/Enchain/GreenBorder al passaggio di fase")

	has_passed_this_phase = true
	already_passed_phase[current_phase] = true
	print("FASE PASSATA")
	player_pass_button.disabled = true
	player_pass_button.release_focus()
	player_pass_button.focus_mode = Control.FOCUS_NONE

	if current_phase == Phase.END:
		player_pass_button.text = "ENDED"
	else:
		player_pass_button.text = "PASSED"

	print("✅ Hai passato la fase:", get_phase_name())

	# 📡 RPC al nemico
	rpc("notify_enemy_passed_phase")

	# ⚔️ Solo se è stato un click manuale → assegna l’action all’altro player
	# ma SOLO se l’altro non ha già passato.
	if is_manual:
		# Se entrambi hanno già passato → NON dare l’azione
		if both_players_passed():
			print("⏭️ Entrambi i giocatori hanno già passato — niente give_action (sarà gestito da set_phase).")
		else:
			var my_id = multiplayer.get_unique_id()
			var peers = multiplayer.get_peers()
			if peers.size() > 0:
				var other_id = peers[0]
				if my_id == other_id and peers.size() > 1:
					other_id = peers[1]
				print("🎯 [Manual Pass] Assegno azione al peer:", other_id)
				rpc("rpc_give_action", other_id)
				rpc_give_action(other_id)


	# Pulizia o azioni relative alla fase
	$"../CombatManager".on_pass_phase()

	if both_players_passed():
		await get_tree().create_timer(0.5).timeout
		go_to_next_phase()


@rpc("any_peer")
func notify_enemy_passed_phase():
	print("NOTIFICA RPC PASSED")
	enemy_has_passed_this_phase = true
	update_enemy_pass_button()
	rpc("update_enemy_pass_button_rpc")  # <-- chiama anche l'RPC!
	
	if both_players_passed():
		await get_tree().create_timer(0.5).timeout
		go_to_next_phase()

func update_enemy_pass_button():
	enemy_pass_button.visible = true # 👈 Ora visibile
	if current_phase == Phase.END:
		enemy_pass_button.text = "ENDED"
	else:
		enemy_pass_button.text = "PASSED"
	enemy_pass_button.disabled = true
	enemy_pass_button.modulate = Color(0.7, 0.7, 0.7, 1) # <-- Grigetto per indicare che ha passato
	
func set_phase(new_phase: Phase):
		# 🔁 Reset flag di passaggio per la nuova fase
	already_passed_phase[new_phase] = false
	player_pass_button.focus_mode = Control.FOCUS_ALL
	current_phase = new_phase
	has_passed_this_phase = false
	enemy_has_passed_this_phase = false
		
	update_phase_indicators()
	# Player pass button reset
	
	#player_pass_button.disabled = false
	player_pass_button.text = "Pass Phase"
	player_pass_button.modulate = Color(1, 1, 1, 1)

	# Enemy pass button reset
	enemy_pass_button.disabled = false
	enemy_pass_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_pass_button.text = "Pass Phase"
	enemy_pass_button.modulate = Color(1, 1, 1, 1)
	enemy_pass_button.visible = false  # 👈 Nascondi sempre a inizio fase
	
		# 👁️ Mostra/nasconde la label in base alla fase
	# ✅ RESET all'inizio della Start Phase
	if current_phase == Phase.START:
		print("🔄 Reset carte ed effetti all'inizio della START PHASE")
		var combat_manager = $"../CombatManager"

		# Reset flag delle carte in campo (sia player che opponent)
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field + combat_manager.player_spells_on_field + combat_manager.opponent_spells_on_field:
			card.effect_triggered_this_turn = false
			card.already_changed_position_this_turn = false

		# 🧹 RESET creature evocate nel turno precedente
		if not combat_manager.summoned_this_turn.is_empty():
			print("🧹 [START PHASE] Pulizia summoned_this_turn")
			combat_manager.summoned_this_turn.clear()
		# Reset liste di attacco/retaliate
		combat_manager.player_creature_that_attacked_this_turn.clear()
		combat_manager.setted_this_turn.clear()
		#combat_manager.player_creatures_that_retaliated_this_turn.clear()

		# ✅ DEBUG FLAGS CHECK
		var cm = $"../CombatManager"
		var ab = $"../ActionButtons"
		print("   [FLAGS CHECK - NEW TURN]")
		print("   effect_stack.size() =", cm.effect_stack.size())
		print("   chain_locked =", cm.chain_locked)
		print("   current_chain_position =", cm.current_chain_position)  # 🆕 aggiunto
		print("   already_chained_in_this_go_to_combat =", cm.already_chained_in_this_go_to_combat)
		print("   already_chained_in_this_go_to_damage_step =", cm.already_chained_in_this_go_to_damage_step)
		print("   resolve_button.visible =", ab.resolve_button.visible)
		print("   go_to_combat_button.visible =", ab.go_to_combat_button.visible)
		print("   to_damage_step_button.visible =", ab.to_damage_step_button.visible)
		print("   chained_this_battle_step =", cm.chained_this_battle_step)
		print("   any_combat_in_progress =", cm.any_combat_in_progress)
		print("   cards_waiting_for_go_to_combat =", cm.cards_waiting_for_go_to_combat.map(func(e): return e.card.name if e.card else "NULL"))
		print("   cards_waiting_for_to_damage_step =", cm.cards_waiting_for_to_damage_step.map(func(e): return e.card.name if e.card else "NULL"))

		#draw_prompt_label.visible = true
			# 🎴 AUTO DRAW + PASS per ogni giocatore
		await get_tree().create_timer(0.5).timeout  # piccola pausa per sicurezza sincronizzazione

		var my_id = multiplayer.get_unique_id()
		print("🃏 [AUTO DRAW] Inizio Start Phase - ID giocatore:", my_id)
		


		# ✅ Ogni player pesca una carta e passa automaticamente
		var deck = $"../Deck"
		if is_instance_valid(deck):
			# pesca solo se non hai già passato
			if not has_passed_this_phase:
				deck.draw_here_and_for_clients_opponent(my_id)
				deck.rpc("draw_here_and_for_clients_opponent", my_id)
				await get_tree().create_timer(0.2).timeout  # breve delay per animazione

		else:
			print("⚠️ [AUTO DRAW] Deck non trovato!")
			
		# 🔥 reset locale SUBITO
		$"../ManaSlots".reset_spent_slots()
		# 🔥 poi replica agli altri
		print("🚀 Invio RPC reset_mana dal player:", my_id)
		$"../ManaSlots".rpc("rpc_reset_mana", my_id)
		
		await get_tree().create_timer(0.2).timeout
		on_player_pass_button_pressed()
		
	else:
		draw_prompt_label.visible = false
	# 🧹 Auto-pass in UPKEEP phase (logica token simulata)
	if current_phase == Phase.UPKEEP:
		print("🧹 [UPKEEP] Rimozione dei token simulata...")

		var player_id = multiplayer.get_unique_id()
			# ⚡️ Esegui effetti On_UpkeepPhase prima dell'auto-pass
		await process_trigger_upkeep_phase_effects()
		
			
		await get_tree().create_timer(0.5).timeout
		#await get_tree().process_frame
		on_player_pass_button_pressed()
	
	# 👇 Assegna l’action in base alla fase
	if current_phase == Phase.MAIN:
		var defender_id: int
		if player_is_defender:
			defender_id = multiplayer.get_unique_id()
		else:
			defender_id = multiplayer.get_peers()[0]  # l’altro giocatore
		print("🛡️ [PhaseManager] Assegno l’action al DIFENSORE per la MAIN PHASE (peer_id =", defender_id, ")")
		rpc("rpc_give_action", defender_id)
		rpc_give_action(defender_id)

	elif current_phase == Phase.PREPARATION or current_phase == Phase.BATTLE:
		var attacker_id: int
		if player_is_attacker:
			attacker_id = multiplayer.get_unique_id()
		else:
			attacker_id = multiplayer.get_peers()[0]

		print("⚔️ [PhaseManager] Assegno l’action all’ATTACCANTE per la fase:", get_phase_name(), "(peer_id =", attacker_id, ")")

		rpc("rpc_give_action", attacker_id, false, true)
		await rpc_give_action(attacker_id, false, true)

		
		# 🧠CHECK AUTO-PASS IMMEDIATO ALL’INGRESSO DELLA PREPARATION o della BATTLE

		

		# ✅ Solo il client che È ATTACCANTE E HA L'ACTION
		if player_is_attacker and player_action_count == 1:
			var has_actions := player_has_any_actions(true)

			if not has_actions:
				await get_tree().create_timer(0.2).timeout  # UI/action pronte
				print("🧠 [PREPARATION] Attaccante senza azioni → auto-pass.")
				on_player_pass_button_pressed(true) # true = come click manuale
			else:
				print("🧠 [PREPARATION] Attaccante ha azioni → niente auto-pass.")
				player_pass_button.visible = true
				player_pass_button.disabled = false

	
	if current_phase == Phase.END:
		player_pass_button.text = "End Turn"
		enemy_pass_button.text = "End Turn"
		
				# =====================================
		# ⏭️ AUTO-PASS IMMEDIATO IN END PHASE
		# =====================================
		await get_tree().create_timer(0.5).timeout
		
		print("⏭️ [END PHASE ENTER] Auto-pass immediato.")
		on_player_pass_button_pressed(true) 
	else:
		player_pass_button.text = "Pass Phase"
		enemy_pass_button.text = "Pass Phase"
	
	print("🌟 Nuova fase:", get_phase_name())
	
	#await get_tree().create_timer(0.2).timeout
	## Mostra il bottone solo se il giocatore ha l’azione attiva
	#if player_action_count == 1:
		#player_pass_button.visible = true
		#player_pass_button.disabled = false
		#print("🟢 [PhaseManager] Bottone Pass Phase VISIBILE (hai l'azione).")
	#else:
		#player_pass_button.visible = false
		#print("🔴 [PhaseManager] Bottone Pass Phase NASCOSTO (non hai l'azione).")
	
@rpc("any_peer")
func rpc_give_action(peer_id: int, from_attack: bool = false, from_phase: bool = false):

	var my_id = multiplayer.get_unique_id()
	print("🎯 [RPC_GIVE_ACTION] Chiamata ricevuta → peer_id:", peer_id, "| from_attack =", from_attack)

	# Salviamo un flag per uso futuro (es. in continue_chain_after_resolve)
	last_action_from_attack = from_attack

	# 🔍 Recupera PhaseManager del client locale
	var phase_manager = self  # siamo già in PhaseManager.gd
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	print("🧽 [RPC_GIVE_ACTION] Pulizia degli status temporanei (This_Step).")
	combat_manager.clear_temporary_statuses()
	# 🛑 Se il player TARGET ha già passato la fase → NON assegnare azione
	if my_id == peer_id and phase_manager.has_passed_this_phase:
		print("⛔ [Action] NON assegno action → questo player ha già passato la fase.")
		player_action_count = 0
		enemy_action_count = 1
		
		return

	if my_id != peer_id and phase_manager.enemy_has_passed_this_phase:
		print("⛔ [Action] NON assegno action → il peer target ha già passato la fase.")
		player_action_count = 1
		enemy_action_count = 0
		
		#await get_tree().create_timer(0.5).timeout
		# Tocca a questo player quindi glis serve il bottone perche nemico ha passato
		# 🧠 CHECK: ho ancora azioni disponibili?
		var has_actions := player_has_any_actions(true)

		if not has_actions:
			print("🧠 [POST-ATTACK AUTO-PASS] Nemico ha passato e non ho più azioni → auto-pass.")
			on_player_pass_button_pressed(true) # true = come click manuale
		else:
			if player_action_count != 0:
				print("🟢 [POST-ATTACK] Nemico ha passato ma ho ancora azioni → mostro Pass Phase.")
				player_pass_button.visible = true
				player_pass_button.disabled = false
				player_pass_button.text = "Pass Phase"
				print("🟢 [PhaseManager] Bottone Pass Phase RIAPPARSO (hai l'azione).")
		
		# 🕒 Nascondi la clessidra se attiva
		var action_buttons = get_parent().get_node_or_null("ActionButtons")
		if action_buttons and action_buttons.hourglass_icon and action_buttons.hourglass_icon.visible:
			print("🕒 [PhaseManager] Clessidra visibile → la nascondo e stoppo animazione.")
			action_buttons.hourglass_icon.visible = false
			action_buttons.stop_hourglass_animation()
		return

	# 🟢 Altrimenti assegna normalmente
	var target_position: Vector2
	if my_id == peer_id:
		player_action_count = 1
		enemy_action_count = 0
		target_position = Vector2(270, 580)
		print("🎯 Action assegnata a questo client → Sei l'attaccante per la fase.")
		
	else:
		player_action_count = 0
		enemy_action_count = 1
		target_position = Vector2(270, 360)
		print("🛡️ Action assegnata al peer avversario → Sei difensore per la fase.")
		

	# 👁️ Mostra o nascondi il bottone Pass Phase in base a chi ha l'azione

#
	 #=====================================
	 #🧠 AUTO-PASS SU GIVE_ACTION (NON DA FASE)
	 #=====================================
	if my_id != peer_id and not from_phase:
		if from_attack:
			print("from attack faccio progredire piu' lento")
			await get_tree().create_timer(0.2).timeout  # sicurezza UI/Input per ora l'ho tolto ma se ci sono bug metti attesa

		var has_actions := player_has_any_actions(true)

		if not has_actions:
			print(
				"🧠 [AUTO-PASS]",
				"| LOCAL my_id =", my_id,
			)
			on_player_pass_button_pressed(false, true) #aggiunto FORCE = TRUE perche' senno dopo stop atk mi dice che input disabilitati
		else:
			print("🧠 [ACTION OK] Action ricevuta e azioni disponibili → nessun auto-pass.")
	
	


	if my_id == peer_id and player_action_count != 0 and not from_phase:
		if from_attack:
			print("from attack faccio progredire piu' lento")
			await get_tree().create_timer(0.2).timeout  # sicurezza UI/Input per ora l'ho tolto ma se ci sono bug metti attesa

		var has_actions := player_has_any_actions(true)

		if not has_actions:
			print(
				"🧠 [AUTO-PASS]",
				"| LOCAL my_id =", my_id,
			)
			on_player_pass_button_pressed(true, true)  #aggiunto FORCE = TRUE perche' senno dopo stop atk mi dice che input disabilitati
		else:
			print("🧠 [ACTION OK] Action ricevuta e azioni disponibili → nessun auto-pass e mostro pass phase.")
			player_pass_button.visible = true
			player_pass_button.disabled = false
			player_pass_button.text = "Pass Phase"
			print("🟢 SONO IO IL PEER [PhaseManager] Bottone Pass Phase RIAPPARSO (hai l'azione).")

			# 🕒 Nascondi la clessidra se attiva
			var action_buttons = get_parent().get_node_or_null("ActionButtons")
			if action_buttons and action_buttons.hourglass_icon and action_buttons.hourglass_icon.visible:
				print("🕒 [PhaseManager] Clessidra visibile → la nascondo e stoppo animazione.")
				action_buttons.hourglass_icon.visible = false
				action_buttons.stop_hourglass_animation()

	else:
		# Non è il turno attivo → nascondi il bottone A MENO CHE NON HO GIA' PASSATO e quindi failsafe se non ho azione
		if player_action_count == 0:
			player_pass_button.disabled = true
			if has_passed_this_phase:
				player_pass_button.visible = true
				print("🔴 [PhaseManager] Bottone Pass Phase MOSTRATO PERCHE TANTO HO PASSATO ( quindi e' PASSED ).")
			else:
				player_pass_button.visible = false
				print("🔴 [PhaseManager] Bottone Pass Phase NASCOSTO perche' non ha ancora passato (azione all'altro giocatore).")
		else:
			player_pass_button.visible = true
			player_pass_button.disabled = true
			print(" HO PASSATO QUINDI RIMANE VISIBILE")

	actions_container.visible = true

	if actions_container.position.distance_to(target_position) > 1.0:
		var tween = create_tween()
		tween.tween_property(actions_container, "position", target_position, 0.35)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
	else:
		actions_container.position = target_position

	var input_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/InputManager")
	if input_manager:
		input_manager.inputs_disabled = false
		print("🟢 [INPUT RESET] Input riabilitati DOPO AVER PASSATO ACTION. LO FACCIO PER EVITARE BUG E TANTO HO FAILSAFE IN BASE AL VECTOR DI ACITON CONTAINER")
		
	
	combat_manager.any_combat_in_progress = false
	print("RESET DI ANY COMBAT IN PROGRESS")
		# Non è il turno attivo → nascondi il bottone A MENO CHE NON HO GIA' PASSATO e quindi failsafe se non ho azione
	if player_action_count != 0 and not already_passed_phase[current_phase]:
		if player_pass_button.visible:
			player_pass_button.disabled = false


func get_phase_name() -> String:
	match current_phase:
		Phase.START: return "Start Phase"
		Phase.UPKEEP: return "Upkeep Phase" # 🆕
		Phase.MAIN: return "Main Phase"
		Phase.PREPARATION: return "Preparation Phase"
		Phase.BATTLE: return "Battle Phase"
		Phase.END: return "End Phase"
		_: return "Unknown Phase"
		
func go_to_next_phase():
	
		# 🧹 Pulisce sempre le just_summoned_creature a ogni cambio fase
	var combat_manager = $"../CombatManager"
	if combat_manager and not combat_manager.just_summoned_creature.is_empty():
		print("🧹 [PHASE CHANGE] Pulizia just_summoned_creature (nuova fase)")
		combat_manager.just_summoned_creature.clear()
	if combat_manager and not combat_manager.just_played_spell.is_empty():
		print("🧹 [PHASE CHANGE] Pulizia just_played_spell (nuova fase)")
		combat_manager.just_played_spell.clear()	
	if combat_manager and not combat_manager.just_targeted_creature.is_empty():
		print("🧹 [PHASE CHANGE] Pulizia just_targeted_creature (nuova fase)")
		combat_manager.just_targeted_creature.clear()
		
	if current_phase == Phase.END and both_players_passed(): #QUI TRIGGERI TUTTI GLI EFFETTI DI FINE TURNO
		var card_manager = $"../CardManager"
		var my_id = multiplayer.get_unique_id()


				# 🌀 ELUSIVE REFRESH a fine turno
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
			if not card.is_card():
				continue
			if "Elusive" in card.card_data.get_all_talents() and card.position_type == "attack":
				card.is_elusive = true
				#card.rpc("rpc_sync_elusive_state", my_id, card.name, false)
				if not card.has_node("Elusive_Overlay"):
					card._add_talent_overlay("Elusive")
				print("💫 Elusive confermato su", card.card_data.card_name)
		
			#MAGIC VEIL REFRESH
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
			if not card.is_card():
				continue
			if "Magic Veil" in card.card_data.get_all_talents():
				card.has_magic_veil = true
				#card.rpc("rpc_sync_elusive_state", my_id, card.name, false)
				if not card.has_node("Magic Veil_Overlay"):
					card._add_talent_overlay("Magic Veil")
				print("💫 MAGIC VEIL reimpostato su ", card.card_data.card_name)
		
		# 💥 Gestione STUN timer
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
			if not card.is_card():
				continue

			var is_stunned := false
			for d in card.card_data.active_debuffs:
				if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Stunned":
					is_stunned = true
					break

			if card.stunned:
				card.stun_timer -= 1
				print("⏳ Stun timer di", card.card_data.card_name, "ridotto a", card.stun_timer)

				if card.stun_timer <= 0:
					print("💥 Stun rimosso da", card.card_data.card_name, "(timer scaduto)")
					card.stunned = false
					card.rpc("rpc_sync_stun_state", my_id, card.name, false)
					card.card_data.remove_debuff_type("Stunned")
					card.update_debuff_icons()
					card.rpc("rpc_remove_debuff", my_id, card.name, "Stunned")


		# 💥 Gestione ROOT timer
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
			if not card.is_card():
				continue

			var is_rooted := false
			for d in card.card_data.active_debuffs:
				if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Rooted":
					is_rooted = true
					break

			if card.rooted:
				card.root_timer -= 1
				print("⏳ Root timer di", card.card_data.card_name, "ridotto a", card.root_timer)

				if card.root_timer <= 0:
					print("💥 Root rimosso da", card.card_data.card_name, "(timer scaduto)")
					card.rooted = false
					card.rpc("rpc_sync_root_state", my_id, card.name, false)
					card.card_data.remove_debuff_type("Rooted")
					card.update_debuff_icons()
					card.rpc("rpc_remove_debuff", my_id, card.name, "Rooted")
					
		# 💥 Gestione FREEZE timer
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
			if not card.is_card():
				continue

			var is_frozen := false
			for d in card.card_data.active_debuffs:
				if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Frozen":
					is_frozen = true
					break

			if card.frozen:
				card.freeze_timer -= 1
				print("⏳ Freeze timer di", card.card_data.card_name, "ridotto a", card.freeze_timer)

				if card.freeze_timer <= 0:
					print("💥 Freeze rimosso da", card.card_data.card_name, "(timer scaduto)")
					card.frozen = false
					card.rpc("rpc_sync_freeze_state", my_id, card.name, false)
					card.card_data.remove_debuff_type("Frozen")
					card.update_debuff_icons()
					card.rpc("rpc_remove_debuff", my_id, card.name, "Frozen")
		
		#await get_tree().create_timer(0.3).timeout
		# 🌿 REGENERATION alla fine di End Phase
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
			# 🔍 Verifica se la carta ha "Regeneration" come talento nativo o da buff
			var has_regen = "Regeneration" in card.card_data.get_all_talents()

			if has_regen:
				if card.card_data.health < card.card_data.max_health:
					print("🌿 Rigenerazione attiva su", card.card_data.card_name, " → vita ripristinata!")
					card.card_data.health = card.card_data.max_health
					card.update_card_visuals()
					card.play_talent_icon_pulse("Regeneration")

					# 🔔 Heal animation → manda RPC a entrambi
					card.play_heal_animation()  # locale
					card.rpc("rpc_play_heal_animation", my_id, card.name)


		# 💨 RIMOZIONE EFFETTI TEMPORANEI FINO A END PHASE (Buffs + Debuffs)
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
			if not card.is_card() or not card.card_data:
				continue

			var buffs_to_remove = card.card_data.active_buffs_until_endphase.duplicate()
			var debuffs_to_remove = card.card_data.active_debuffs_until_endphase.duplicate()

			# --- 🧩 Rimuovi BUFF temporanei come se fossero enchant/equip
			for buff in buffs_to_remove:
				if typeof(buff) != TYPE_DICTIONARY:
					continue
				var src_card = buff.get("source_card", null)
				if not is_instance_valid(src_card):
					continue

				print("💨 [END PHASE] Rimozione buff temporaneo da", src_card.card_data.card_name, "su", card.card_data.card_name)

				# Riusa la stessa logica avanzata di rimozione effetti
				combat_manager.remove_enchant_effects(src_card, card)

			# --- 🧩 Rimuovi DEBUFF temporanei allo stesso modo
			for debuff in debuffs_to_remove:
				if typeof(debuff) != TYPE_DICTIONARY:
					continue
				var src_card = debuff.get("source_card", null)
				if not is_instance_valid(src_card):
					continue

				print("💨 [END PHASE] Rimozione debuff temporaneo da", src_card.card_data.card_name, "su", card.card_data.card_name)
				combat_manager.remove_enchant_effects(src_card, card)
	
			# --- Pulizia dei gruppi temporanei per sicurezza
			card.card_data.active_buffs_until_endphase.clear()
			card.card_data.active_debuffs_until_endphase.clear()

			# --- Aggiorna UI finale
			card.update_card_visuals()
			card.get_node("Attack").text = str(card.card_data.attack)
			card.get_node("Health").text = str(card.card_data.health)

			print("✅ [END PHASE] Effetti temporanei rimossi da", card.card_data.card_name)


		# 💪 RIPRISTINO ATTACCO a fine turno
		for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
			if not card.is_card():
				continue
			if card.card_data.attack < card.card_data.max_attack:
				print("💪 Ripristino ATTACK di", card.card_data.card_name, "→", card.card_data.max_attack)
				card.card_data.attack = card.card_data.max_attack
				card.get_node("Attack").text = str(card.card_data.attack)
				card.update_card_visuals()
		
		#await get_tree().create_timer(0.3).timeout
		
		
				# ⚡️ ESECUZIONE DEGLI EFFETTI "TriggerEndPhase"

		# ⚡️ ESECUZIONE E ATTESA COMPLETA DEGLI EFFETTI "TriggerEndPhase"
		#for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field + combat_manager.player_spells_on_field + combat_manager.opponent_spells_on_field:
			#if not card.is_card():
				#continue
#
			#if card.card_data.effect_type == "TriggerEndPhase":
				#print("🕓 Attivo effetto TriggerEndPhase di", card.card_data.card_name)
#
				## 🔒 Solo il proprietario della carta deve attivare l’effetto
				#if not card.is_enemy_card():
					#if card.card_data.targeting_type == "Targeted":
						#await card_manager.enter_selection_mode(card, "effect")
					#else:
						#await card_manager.trigger_card_effect(card)
				#else:
					#print("⏳", card.card_data.card_name, "è dell'avversario — attendo risoluzione chain.")
#
				## 🧩 Tutti i client attendono la completa risoluzione
				#await combat_manager.await_effect_fully_resolved(card)



		await process_trigger_end_phase_effects()
		print("✅ Tutti gli effetti TriggerEndPhase completati — procedo alla riduzione delle duration.")
		# 🧿 RIDUZIONE DURATION DELLE CONTINUE SPELL ALLA FINE DELLA END PHASE

		for card in combat_manager.player_spells_on_field + combat_manager.opponent_spells_on_field:
			if not card.is_card():
				continue
			if card.card_data.card_class == "ContinuousSpell" and card.card_data.spell_duration < 100 and card.position_type != "facedown":
				card.card_data.spell_duration -= 1
				print("⏳ Durata di " , card.card_data.card_name, " ridotta a ", card.card_data.spell_duration)
				# Aggiorna eventuale visualizzazione (se hai una label di durata)
				#if card.has_node("SpellDuration"):
				card.get_node("SpellDuration").text = str(card.card_data.spell_duration)
				card.update_card_visuals()

			if card.card_data.card_class == "ContinuousSpell" and card.card_data.spell_duration <= 0 and card.position_type != "facedown" :
				print("💥 Continuous Spell", card.card_data.card_name, "è scaduta! Viene distrutta.")
				
				# ✅ Determina il proprietario corretto
				var card_owner: String = "Player"
				if card in combat_manager.opponent_spells_on_field or card in combat_manager.opponent_creatures_on_field:
					card_owner = "Opponent"
				
				# ✅ Esegui distruzione con parametro corretto
				combat_manager.destroy_card(card, card_owner)

		# 🔥 END TURN MANA OVERFLOW → pesca carta
		var mana_manager := $"../ManaSlots"

		if mana_manager:
			var available_mana = mana_manager.count_available_mana()

			if available_mana >= 2:
				print("🔥 [END TURN] Mana residuo =", available_mana, "→ consumo tutto e pesca 1")

				# 1️⃣ Consuma tutto il mana
				mana_manager.spend_all_available_mana()

				# 2️⃣ Pesca 1 carta
				var deck := $"../Deck"
				if deck:
					deck.draw_here_and_for_clients_opponent(multiplayer.get_unique_id())
					deck.rpc("draw_here_and_for_clients_opponent",multiplayer.get_unique_id()
					)
		await get_tree().create_timer(0.3).timeout
		# 💨 RIMOZIONE MANA TEMPORANEO A FINE END PHASE
		$"../ManaSlots".remove_temporary_mana_slots_for_phase("EndPhase")
		# 💨 RIMOZIONE SPELLPOWER TEMPORANEO A FINE END PHASE
		combat_manager.remove_temporary_spellpower_effects()
		
		
		
		# 💫 Dopo lo swap dei ruoli, assegna subito l’action al difensore
		await swap_roles()  # mantiene l’attesa dell’animazione

		# 🕹️ Identifica il difensore (quello che NON è attaccante dopo lo swap)
		var defender_id: int
		if player_is_defender:
			defender_id = multiplayer.get_unique_id()
		else:
			defender_id = multiplayer.get_peers()[0]

		print("🛡️ Assegno l’action al difensore per l’inizio del nuovo turno (peer_id =", defender_id, ")")

		rpc("rpc_give_action", defender_id)
		rpc_give_action(defender_id)

		
	match current_phase:
		Phase.START:
			var upkeep_possible := any_player_has_actions_for_phase(Phase.UPKEEP)

			if upkeep_possible:
				print("🕓 [PHASE] UPKEEP necessaria → presenti effetti upkeep.")
				set_phase(Phase.UPKEEP)
			else:
				print("⏭️ [PHASE SKIP] Nessun effetto UPKEEP → salto a MAIN.")
				set_phase(Phase.MAIN)
			
		Phase.UPKEEP:
			set_phase(Phase.MAIN)

		Phase.MAIN:
			var prep_possible := any_player_has_actions_for_phase(Phase.PREPARATION)

			if prep_possible:
				print("🛠️ [PHASE] PREPARATION necessaria → almeno un player può agire.")
				set_phase(Phase.PREPARATION)
			else:
				print("⏭️ [PHASE SKIP] PREPARATION inutile → verifico BATTLE.")

				var battle_possible := any_player_has_actions_for_phase(Phase.BATTLE)

				if battle_possible:
					print("⚔️ [PHASE] BATTLE possibile → salto PREP, entro in BATTLE.")
					set_phase(Phase.BATTLE)
				else:
					print("⏭️⏭️ [PHASE SKIP] Nessuna azione in PREP e BATTLE → salto a END.")
					set_phase(Phase.END)

		Phase.PREPARATION:
			var battle_possible := any_player_has_actions_for_phase(Phase.BATTLE)

			if battle_possible:
				print("⚔️ [PHASE] BATTLE possibile → entro in BATTLE.")
				set_phase(Phase.BATTLE)
			else:
				print("⏭️ [PHASE SKIP] Nessuna azione in BATTLE → salto a END.")
				set_phase(Phase.END)

		Phase.BATTLE:
			set_phase(Phase.END)
		Phase.END:
			set_phase(Phase.START)

func both_players_passed() -> bool:
	return has_passed_this_phase and enemy_has_passed_this_phase
	
func update_phase_indicators():
	for phase in Phase.values():
		var panel = phase_indicators.get(phase)
		if panel != null:
			var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.border_color = Color(0, 0, 0, 0) # Nessun bordo
				style.border_width_top = 0
				style.border_width_bottom = 0
				style.border_width_left = 0
				style.border_width_right = 0

	
	var active_panel = phase_indicators.get(current_phase)
	if active_panel != null:
		var active_style = active_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if active_style:
			active_style.border_color = Color(1, 0.5, 0, 1) # 🧡 Bordo arancione
			active_style.border_width_top = 4
			active_style.border_width_bottom = 4
			active_style.border_width_left = 4
			active_style.border_width_right = 4

func decide_starting_roles():
	if multiplayer.is_server():
		var random_choice = randi() % 2 # 0 o 1
		if random_choice == 0:
			player_is_attacker = true
			player_is_defender = false
		else:
			player_is_attacker = false
			player_is_defender = true

		await get_tree().process_frame
		rpc("sync_roles", player_is_attacker)
	else:
		pass  # il client aspetta il sync

	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout  # sicurezza rete

	var defender_id = multiplayer.get_unique_id() if player_is_defender else multiplayer.get_peers()[0]
	print("⚙️ Invio rpc_set_action_icon_state → defender_id =", defender_id)
	rpc_set_action_icon_state(defender_id)
	rpc("rpc_set_action_icon_state", defender_id)

	
@rpc("any_peer")
func rpc_set_action_icon_state(defender_peer_id: int):
	var my_id = multiplayer.get_unique_id()
	
	if my_id == defender_peer_id:
		# 👑 Questo client è il difensore (inizia con l'azione)
		player_is_attacker = false
		player_is_defender = true
		player_action_count = 1
		enemy_action_count = 0
		actions_container.visible = true
		actions_container.position = Vector2(270, 580)
		print("🛡️ Sei il DIFENSORE — player_action_count =", player_action_count, ", enemy_action_count =", enemy_action_count)
	else:
		# 👑 Questo client è l'attaccante
		player_is_attacker = true
		player_is_defender = false
		player_action_count = 0
		enemy_action_count = 1
		actions_container.visible = true
		actions_container.position = Vector2(270, 360)
		print("🎯 Sei l'ATTACCANTE — player_action_count =", player_action_count, ", enemy_action_count =", enemy_action_count)

	# 🔄 Aggiorna visivamente le icone di ruolo in base alle variabili appena impostate
	await update_role_icons()




	
@rpc("any_peer")
func sync_roles(host_is_attacker: bool):
	if multiplayer.is_server():
		player_is_attacker = host_is_attacker
		player_is_defender = not host_is_attacker
	else:
		player_is_attacker = not host_is_attacker
		player_is_defender = host_is_attacker
		
	await get_tree().process_frame
	print_role()
	await update_role_icons()
		
func swap_roles():
	var temp = player_is_attacker
	player_is_attacker = player_is_defender
	player_is_defender = temp
	print("♻️ Ruoli invertiti: Attaccante =", player_is_attacker, ", Difensore =", player_is_defender)
	#update_role_icons()
	await animate_role_swap()

func print_role():
	if player_is_attacker:
		print("🎯 Sei l'ATTACCANTE!")
		
	else:
		print("🛡️ Sei il DIFENSORE!")
		
func update_role_icons():
	print("⭐ DEBUG - update_role_icons (icone comuni, posizioni invertite per ruolo)")

	var attacker_icon = get_parent().get_node_or_null("AttackerIcon")
	var defender_icon = get_parent().get_node_or_null("DefenderIcon")

	if not attacker_icon or not defender_icon:
		print("❌ Icone 'AttackerIcon' o 'DefenderIcon' non trovate nella scena!")
		return

	# 🔹 Rende sempre entrambe visibili
	attacker_icon.visible = true
	defender_icon.visible = true
	await get_tree().process_frame
	
	# 🔹 Posiziona in base al ruolo del player
	if player_is_attacker:
		# Il player è attaccante → icona attaccante in basso, difensore in alto
		attacker_icon.position = Vector2(350, 550)
		defender_icon.position = Vector2(350, 330)
		print("🎯 Player = ATTACKER → attacker_icon (350,550), defender_icon (350,330)")
	else:
		# Il player è difensore → icona attaccante in alto, difensore in basso
		attacker_icon.position = Vector2(350, 330)
		defender_icon.position = Vector2(350, 550)
		print("🛡️ Player = DEFENDER → attacker_icon (350,330), defender_icon (350,550)")


func animate_role_swap():
	var parent = get_parent()
	if not parent:
		print("❌ Nodo padre non trovato per animazione swap!")
		return

	var attacker_icon = parent.get_node_or_null("AttackerIcon")
	var defender_icon = parent.get_node_or_null("DefenderIcon")
	if not attacker_icon or not defender_icon:
		print("❌ Icone comuni non trovate! (AttackerIcon / DefenderIcon)")
		return

	# 🔹 Salva le posizioni originali
	var attacker_start = attacker_icon.position
	var defender_start = defender_icon.position

	# 🔹 Calcola le destinazioni invertite
	var attacker_target = defender_start
	var defender_target = attacker_start

	# 🔹 Assicurati che siano visibili
	attacker_icon.visible = true
	defender_icon.visible = true

	# 🔹 Crea tween parallelo per lo scambio fluido
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(attacker_icon, "position", attacker_target, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(defender_icon, "position", defender_target, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished






func process_trigger_upkeep_phase_effects() -> void:
	var combat_manager = $"../CombatManager"
	var card_manager = $"../CardManager"
	var trigger_list = combat_manager.trigger_upkeep_cards

	if trigger_list.is_empty():
		print("✅ Nessuna carta TriggerUpkeepPhase da risolvere.")
		return

	print("⚡ Trovate", trigger_list.size(), "carte TriggerUpkeepPhase da risolvere.")

	# 🔁 Iteriamo su una copia della lista originale, per non modificarla
	var trigger_copy = trigger_list.duplicate(true)

	for entry in trigger_copy:
		var card = entry["card"]
		var owner_id = entry["owner_id"]

		if not card or not card.is_card():
			print("⚠️ Carta TriggerUpkeepPhase non valida o distrutta, la salto.")
			continue

		print("🕓 Risolvo TriggerUpkeepPhase di", card.card_data.card_name, "| Owner ID:", owner_id)

		var debug_names := []
		for e in trigger_list:
			if e.has("card") and e["card"] and e["card"].is_card():
				debug_names.append(e["card"].card_data.card_name + " (owner:" + str(e["owner_id"]) + ")")
		print("📋 Stato attuale TriggerUpkeep List:", debug_names)

		# 👑 Solo il proprietario della carta esegue l’effetto
		if owner_id == multiplayer.get_unique_id():
			if card.card_data.targeting_type == "Targeted":
				if card.card_data.t_subtype_1 == "AllCreatures":
					if $"../CombatManager".player_creatures_on_field.size() > 0 or $"../CombatManager".opponent_creatures_on_field.size() > 0:
						await card_manager.enter_selection_mode(card, "effect")
				elif card.card_data.t_subtype_1 == "AllEnemyCreatures":
					if $"../CombatManager".opponent_creatures_on_field.size() > 0:
						await card_manager.enter_selection_mode(card, "effect")
			else:
				await card_manager.trigger_card_effect(card)
		else:
			print("⏳ Attendo che il peer", owner_id, "risolva l’effetto di", card.card_data.card_name)

		await get_tree().create_timer(0.5).timeout
		await combat_manager.await_effect_fully_resolved(card)

		print("✅ Effetto TriggerUpkeepPhase completato per:", card.card_data.card_name)
		await get_tree().process_frame

	print("✅ Tutti gli effetti TriggerUpkeepPhase completati (nessuna rimozione dalla lista).")





func process_trigger_end_phase_effects() -> void:
	var combat_manager = $"../CombatManager"
	var card_manager = $"../CardManager"
	var trigger_list = combat_manager.trigger_endphase_cards

	if trigger_list.is_empty():
		print("✅ Nessuna carta TriggerEndPhase da risolvere.")
		return

	print("⚡ Trovate", trigger_list.size(), "carte TriggerEndPhase da risolvere.")

	# 🔁 Duplichiamo la lista per iterare in sicurezza (senza modifiche in corso)
	var trigger_copy = trigger_list.duplicate(true)

	for entry in trigger_copy:
		var card = entry["card"]
		var owner_id = entry["owner_id"]

		if not card or not card.is_card():
			print("⚠️ Carta TriggerEndPhase non valida o distrutta, la salto.")
			continue

		print("🕓 Risolvo TriggerEndPhase di", card.card_data.card_name, "| Owner ID:", owner_id)

		# 📋 DEBUG: mostra stato lista attuale
		var debug_names := []
		for e in trigger_list:
			if e.has("card") and e["card"] and e["card"].is_card():
				debug_names.append(e["card"].card_data.card_name + " (owner:" + str(e["owner_id"]) + ")")
		print("📋 Stato attuale TriggerEndPhase List:", debug_names)

		# 👑 Solo il proprietario della carta esegue l’effetto
		if owner_id == multiplayer.get_unique_id():
			if card.card_data.targeting_type == "Targeted":
				if card.card_data.t_subtype_1 == "AllCreatures":
					if $"../CombatManager".player_creatures_on_field.size() > 0 or $"../CombatManager".opponent_creatures_on_field.size() > 0:
						await card_manager.enter_selection_mode(card, "effect")
				elif card.card_data.t_subtype_1 == "AllEnemyCreatures":
					if $"../CombatManager".opponent_creatures_on_field.size() > 0:
						await card_manager.enter_selection_mode(card, "effect")
			else:
				await card_manager.trigger_card_effect(card)
		else:
			print("⏳ Attendo che il peer", owner_id, "risolva l’effetto di", card.card_data.card_name)

		await get_tree().create_timer(0.5).timeout
		await combat_manager.await_effect_fully_resolved(card)

		print("✅ Effetto TriggerEndPhase completato per:", card.card_data.card_name)
		await get_tree().process_frame

	print("✅ Tutti gli effetti TriggerEndPhase completati (nessuna rimozione dalla lista).")


func player_has_any_actions(is_player: bool, phase_override = null) -> bool:
	var combat_manager = $"../CombatManager"
	var phase_manager = $"../PhaseManager"

	var creatures = combat_manager.player_creatures_on_field if is_player else combat_manager.opponent_creatures_on_field
	var spells = combat_manager.player_spells_on_field if is_player else combat_manager.opponent_spells_on_field
	var phase_to_check = phase_override if phase_override != null else phase_manager.current_phase
	
	match phase_to_check:
		
		phase_manager.Phase.UPKEEP:
			# Se esiste almeno un TriggerUpkeepPhase su QUALSIASI field
			# allora la fase ha senso, altrimenti va skippata
			if not combat_manager.trigger_upkeep_cards.is_empty():
				return true
			return false
		# ============================
		# 🛠️ PREPARATION PHASE
		# ============================
		phase_manager.Phase.PREPARATION:

			# 🐣 Creature NON appena evocate
			# 🐣 Creature che POSSONO cambiare posizione
			for c in creatures:
				if not is_instance_valid(c):
					continue

				# ❌ appena evocata
				var summoned = combat_manager.summoned_this_turn.any(
					func(e): return e.card == c
				)
				if summoned:
					continue

				# ❌ ha già cambiato posizione questo turno
				if c.already_changed_position_this_turn:
					continue

				# ❌ rooted
				if c.rooted:
					continue

				# ✅ se arrivo qui → esiste almeno un'azione valida
				return true

			# 🧙 Equip face-up non ancora triggerati
			for s in spells:
				if not is_instance_valid(s):
					continue

				if s.card_data.card_class == "Equip" \
				and s.position_type != "facedown" \
				and not s.effect_triggered_this_turn:
					return true

			return false   # 👈 FIX OBBLIGATORIO


		# ============================
		# ⚔️ BATTLE PHASE
		# ============================
		phase_manager.Phase.BATTLE:

			for c in creatures:
				if not is_instance_valid(c):
					continue

				# Deve essere in ATTACK
				if c.position_type != "attack":
					continue

				# Non deve aver già attaccato
				if combat_manager.player_creature_that_attacked_this_turn.has(c):
					continue

				# Deve poter attaccare
				if c.stunned or c.frozen:
					continue

				return true

			return false

		#phase_manager.Phase.END: #sempre false perche' deve passare in automatico
			#return false

		# ============================
		# 🚫 ALTRE FASI
		# ============================
		_:
			return true

func any_player_has_actions_for_phase(phase: Phase) -> bool:
	if player_has_any_actions(true, phase):
		return true
	if player_has_any_actions(false, phase):
		return true
	return false

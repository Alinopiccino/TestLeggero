extends Node

const CARD_SMALLER_SCALE = 0.15
const DEFAULT_CARD_MOVE_SPEED = 0.3
const DEFAULT_CARD_MOVE_SPEED_ATTACK = 0.15
const DEFAULT_CARD_MOVE_SPEED_DIRECT_ATTACK = 0.25
const STARTING_LP = 5000
const BATTLE_ATTACK_OFFSET_Y = 160   #minore e', piu' in basso va
const DIRECT_ATTACK_OFFSET_Y = 1000   #minore e', piu' in basso va

var triggered_effects_processing := false
var pending_action_after_chain: bool = false
var pending_action_owner_id: int = -1
var action_given_from_attack: bool = false
var battle_timer
var opponent_creatures_on_field = []
var opponent_spells_on_field = []
var player_creatures_on_field = []
var player_spells_on_field = []
var player_creature_that_attacked_this_turn = []
#var player_creatures_that_retaliated_this_turn = []
var trigger_endphase_cards: Array[Dictionary] = []
var trigger_upkeep_cards: Array[Dictionary] = []
var triggered_effects_this_chain_link: Array = []
var cards_to_destroy_after_chain: Array = []
var last_played_card: Dictionary = {}  # {"card": Node, "owner_id": int}
var just_summoned_creature: Array = []
var just_played_spell: Array = []
var player_bonuses: Array[Dictionary] = []

var flying_was_useful := false
var setted_this_turn: Array = []
var summoned_this_turn: Array = []

var just_targeted_creature: Array = []
var player_creature_card_slots = []
var player_LP
var enemy_LP
var player_SP
var enemy_SP

# 🧠 Tiene traccia degli status attivi
var player_statuses: Array = []
var enemy_statuses: Array = []
# 🔄 Cache delle icone già create (per evitare duplicati)
var status_icons := {
	"player": {},
	"enemy": {}
}

const STATUS_ICONS := {
	"Protection": "res://Assets/SCUDO ICONA.png",
	#"freeze": "res://Assets/UI/freeze_icon.png",        # esempio futuro
	#"stun": "res://Assets/UI/stun_icon.png",            # esempio futuro
	#"lifesteal": "res://Assets/UI/lifesteal_icon.png"   # esempio futuro
}

var player_FireSP: int = 0
var enemy_FireSP: int = 0
var player_WindSP: int = 0
var enemy_WindSP: int = 0
var player_EarthSP: int = 0
var enemy_EarthSP: int = 0
var player_WaterSP: int = 0
var enemy_WaterSP: int = 0

var graveyard_z_index = 100
#var is_opponent_turn = false
signal retaliate_choice_received
signal resolve_choice_received
signal to_damage_step_chosen
signal self_resolve_choice_finished
signal final_resolve_ack_received


var cards_waiting_for_go_to_combat: Array = []
var cards_waiting_for_to_damage_step: Array = []
var effect_stack: Array = []
var current_chain_index: int = 0
var current_chain_position: int = -1
var currently_targeted_cards: Array = []

var chained_this_battle_step := false
var already_chained_in_this_go_to_combat := false
var already_chained_in_this_go_to_damage_step := false

var received_retaliate_choice_value: bool = false
var opponent_pressed_go_to_combat: bool = false
var attacker_pressed_to_damage_step: bool = false
var chain_resolving_in_progress: bool = false
var chain_locked := false  # false = la catena è aperta, true = la catena è in risoluzione
#var is_consecutive_cards := false
var simulate_resolve:  bool = false
var any_combat_in_progress: bool = false
var defender_can_retaliate: bool = false

var gtc_shown: bool = false

# 🔹 Tiene traccia di chi ha aumentato lo Spell Power
var spell_power_sources := {
	"Generic": [],
	"Fire": [],
	"Water": [],
	"Earth": [],
	"Wind": []
}


const CHAIN_TEXTURES = {
	1: preload("res://Assets/Chains/Chain 1.png"),
	2: preload("res://Assets/Chains/Chain 2.png"),
	3: preload("res://Assets/Chains/Chain 3.png"),
	4: preload("res://Assets/Chains/Chain 4.png"),
	5: preload("res://Assets/Chains/Chain 5.png"),
	6: preload("res://Assets/Chains/Chain 6.png"),
	7: preload("res://Assets/Chains/Chain 7.png"),
	8: preload("res://Assets/Chains/Chain 8.png"),
	9: preload("res://Assets/Chains/Chain 9.png"),
}

func _ready() -> void:
	battle_timer = $"../BattleTimer"
	battle_timer.one_shot = true
	battle_timer.wait_time = 1.0
	
	player_creature_card_slots.append($"../PlayerZones/CreatureSlot1")
	player_creature_card_slots.append($"../PlayerZones/CreatureSlot2")
	player_creature_card_slots.append($"../PlayerZones/CreatureSlot3")
	player_creature_card_slots.append($"../PlayerZones/CreatureSlot4")
	player_creature_card_slots.append($"../PlayerZones/CreatureSlot5")
	$"../ActionButtons".connect("direct_attack_chosen", Callable(self, "_on_direct_attack_chosen"))
	$"../ActionButtons".connect("go_to_combat_chosen", Callable(self, "_on_go_to_combat_chosen"))
	$"../ActionButtons".connect("to_damage_step_chosen", Callable(self, "_on_to_damage_step_chosen"))
	
	print("\n=== CombatManager READY DEBUG ===")
	print(" cards_waiting_for_go_to_combat: ", cards_waiting_for_go_to_combat)
	print(" cards_waiting_for_to_damage_step: ", cards_waiting_for_to_damage_step)
	print(" effect_stack: ", effect_stack)
	print(" current_chain_index: ", current_chain_index)
	print(" current_chain_position: ", current_chain_position)
	print(" chained_this_battle_step: ", chained_this_battle_step)
	print(" already_chained_in_this_go_to_combat: ", already_chained_in_this_go_to_combat)
	print(" already_chained_in_this_go_to_damage_step: ", already_chained_in_this_go_to_damage_step)
	print(" received_retaliate_choice_value: ", received_retaliate_choice_value)
	print(" opponent_pressed_go_to_combat: ", opponent_pressed_go_to_combat)
	print(" attacker_pressed_to_damage_step: ", attacker_pressed_to_damage_step)
	print(" chain_resolving_in_progress: ", chain_resolving_in_progress)
	print(" chain_locked: ", chain_locked)
	print(" simulate_resolve: ", simulate_resolve)
	print(" any_combat_in_progress: ", any_combat_in_progress)
	print("================================\n")
	

func _on_direct_attack_chosen():
	var selected_card = $"../CardManager".selected_card
	if selected_card:
		$"../CardManager".exit_selection_mode(true) # EVITA BUG CHE QUANDO FAI ATK DIRETTO NON SI NASCONDE SELECTION LABEL
		await direct_attack(selected_card)  # già esistente
		$"../CardManager".selected_card = null
		$"../CardManager".selection_mode_active = false
		

func _on_go_to_combat_chosen():
	emit_signal("resolve_choice_received")

	## FIX: se siamo in un attacco diretto, notifichiamo esplicitamente l’attaccante
	#if cards_waiting_for_go_to_combat.size() > 0:
		#var entry = cards_waiting_for_go_to_combat[0]
		#var card = entry.card
		#if card and card.has_an_attack_target == false:  # attacco diretto → non ha un target
			#var attacker_id = multiplayer.get_peers()[0]
			#rpc_id(attacker_id, "notify_opponent_pressed_go_to_combat")
			#rpc_id(attacker_id, "receive_resolve_choice")
	
func _on_to_damage_step_chosen():
	emit_signal("to_damage_step_chosen")

func wait_for_retaliate_choice(is_attacker: bool, defender_can_retaliate: bool = true) -> bool:
	var action_buttons = $"../ActionButtons"
	var input_manager = $"../InputManager"
	
	if not is_attacker:
		# 🔥 Sono il difensore
		if defender_can_retaliate:
			print("⏳ Sono il difensore, mostro Retaliate/OK")
			
			action_buttons.show_buttons()

			await action_buttons.retaliate_chosen

			action_buttons.hide_buttons()

			# 🔥 Mando la scelta all'attaccante
			var other_player_id = multiplayer.get_peers()[0]
			rpc_id(other_player_id, "receive_retaliate_choice", action_buttons.player_wants_to_retaliate)
			if action_buttons.player_wants_to_retaliate:
				rpc_id(other_player_id, "show_enemy_retaliate_visual")
			else:
				rpc_id(other_player_id, "show_enemy_ok_visual")

			print("✅ Ho scelto:", action_buttons.player_wants_to_retaliate)
			return action_buttons.player_wants_to_retaliate
		else:
			# Difensore NON può retaliate → rispondiamo subito senza bottoni
			await get_tree().process_frame
			var other_player_id = multiplayer.get_peers()[0]
			rpc_id(other_player_id, "show_enemy_ok_visual")  # ✅ Mostra comunque feedback visivo
			rpc_id(other_player_id, "receive_retaliate_choice", false)
			
			return false
	else:
		# 🔥 Sono l’attaccante → attendo passivamente
		if defender_can_retaliate:   #POTREBBE ESSERE CAUSA BUG RARO DI UN INPUT CHE RIMANE DISABILITATO DOPO UNA CHAIN/PERDITE DI TARGET DURING COMBAT
			print("⏳ Sono l'attaccante, aspetto il difensore...")
			input_manager.inputs_disabled = true  # 🔒 blocca input mentre aspetta
			await self.retaliate_choice_received
			input_manager.inputs_disabled = false  # 🔓 riattiva dopo
			return received_retaliate_choice_value
		else:
			# 🔥 Il difensore non può retaliate → NON aspettare, torna subito
			return false

func wait_for_combat_confirmation(is_attacker: bool, defending_card: Card = null) -> void:
	var action_buttons = $"../ActionButtons"
	var input_manager = $"../InputManager"
	var opponent_has_response = false

	# ⛔ Se in questo battle step si è già chainato, NON si checkano più risposte
	#if $"../CombatManager".already_chained_in_this_go_to_combat or $"../CombatManager".already_chained_in_this_go_to_damage_step or $"../CombatManager".chained_this_battle_step:
	if $"../CombatManager".chained_this_battle_step:
		print("⛔ Già chainato in questo battle step → skip response check")
		print("   [FLAGS CHECK - SKIP RESPONSE]")
		print("   any_combat_in_progress =", any_combat_in_progress)
		print("   already_chained_in_this_go_to_combat =", $"../CombatManager".already_chained_in_this_go_to_combat)
		print("   already_chained_in_this_go_to_damage_step =", $"../CombatManager".already_chained_in_this_go_to_damage_step)
		print("   chained_this_battle_step =", $"../CombatManager".chained_this_battle_step)
		print("   current_chain_position =", $"../CombatManager".current_chain_position)  # 🆕 aggiunto
		return
		
	# 🔥 AUTO-RESOLVE CHECK (PRIORITARIO)
	var responder_wants_skip: bool
	if is_attacker:
		# sto attaccando → risponde l'avversario
		responder_wants_skip = action_buttons.enemy_auto_skip_resolve
	else:
		# sto difendendo → rispondo io
		responder_wants_skip = action_buttons.auto_skip_resolve

	if responder_wants_skip:
		print("⚡ [AUTO-RESOLVE] Responder ha auto-resolve attivo → salto GO TO COMBAT senza controlli")
		return
		
	# 🔎 Controllo se il difensore ha carte Quick o facedown
	if is_attacker:
		for card in $"../CombatManager".opponent_creatures_on_field:
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break
		if not opponent_has_response:
			for card in $"../CombatManager".opponent_spells_on_field:
				if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
					opponent_has_response = true
					break
	else:
		for card in $"../CombatManager".player_creatures_on_field:
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break
		if not opponent_has_response:
			for card in $"../CombatManager".player_spells_on_field:
				if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
					opponent_has_response = true
					break

	# 🔥 Se il difensore NON ha risposte → salta conferma
	if not opponent_has_response:
		print("⚡ Difensore non ha risposte → saltiamo GO TO COMBAT")
		return

	if is_attacker: #POTREBBE ESSERE CAUSA BUG RARO DI UN INPUT CHE RIMANE DISABILITATO DOPO UNA CHAIN/PERDITE DI TARGET DURING COMBAT
		print("⏳ Sono l'attaccante, aspetto che il difensore prema GO TO COMBAT...")
		input_manager.inputs_disabled = true
		#await self.resolve_choice_received #RIMOSSO PER BUG SEGUENTE:
		await action_buttons.go_to_combat_chosen #AGGIUNTO PER FIXARE BUG ATTACCKI DIRETTI DOPO CHAIN CHE NON ASPETTAVANO SU ATTACKER CLIENT
		print("PREMUTO PORCODIOOOOOO")
		input_manager.inputs_disabled = false
	else:
		print("🟢 Sono il difensore, mostro GO TO COMBAT")
		input_manager.inputs_disabled = false
		action_buttons.show_go_to_combat_button()
		await action_buttons.go_to_combat_chosen
		action_buttons.hide_go_to_combat_button()

		await get_tree().process_frame  # 🔄 garantisce che le UI si aggiornino

		# 🔍 Verifica se può retaliate
		var selected_card = defending_card
		var can_retaliate := false
		var other_player_id = multiplayer.get_peers()[0]

		#if selected_card == null and defending_card == null:
			#print("ATTACCO DIRETTO NON SEGUO STA LOGICA DI MERDAS")
			#pass  # Attacco diretto: lascia che il difensore possa reagire

		if can_retaliate:
			print("🛡️ Difensore può contrattaccare → attendo scelta RETALIATE/OK")
			action_buttons.show_buttons()
			await action_buttons.retaliate_chosen
			action_buttons.hide_buttons()

			if action_buttons.player_wants_to_retaliate:
				rpc_id(other_player_id, "show_enemy_retaliate_visual")
			else:
				rpc_id(other_player_id, "show_enemy_ok_visual")

		# ✅ SOLO ORA il difensore ha finito tutte le sue scelte
		$"../CombatManager".opponent_pressed_go_to_combat = true
		rpc_id(other_player_id, "notify_opponent_pressed_go_to_combat")
		rpc_id(other_player_id, "receive_resolve_choice")



func wait_for_to_damage_step(is_attacker: bool) -> void:
	var action_buttons = $"../ActionButtons"
	var input_manager = $"../InputManager"

	# ⛔ Se in questo battle step si è già chainato, NON si checkano più risposte
	#if $"../CombatManager".already_chained_in_this_go_to_combat or $"../CombatManager".already_chained_in_this_go_to_damage_step or $"../CombatManager".chained_this_battle_step:
	if $"../CombatManager".chained_this_battle_step:
		print("⛔ Già chainato in questo battle step → skip response check")
				# 🔍 DEBUG extra
		print("   [FLAGS CHECK - SKIP RESPONSE]")
		print("   already_chained_in_this_go_to_combat =", $"../CombatManager".already_chained_in_this_go_to_combat)
		print("   already_chained_in_this_go_to_damage_step =", $"../CombatManager".already_chained_in_this_go_to_damage_step)
		print("   chained_this_battle_step =", $"../CombatManager".chained_this_battle_step)
		
		# 🔍 DEBUG sugli array di attesa
		print("   cards_waiting_for_go_to_combat =", $"../CombatManager".cards_waiting_for_go_to_combat)
		print("   cards_waiting_for_to_damage_step =", $"../CombatManager".cards_waiting_for_to_damage_step)

		return
		
	# 🔥 AUTO-RESOLVE CHECK (PRIORITARIO)
	var responder_wants_skip: bool
	if is_attacker:
		# sono io che posso rispondere
		responder_wants_skip = action_buttons.auto_skip_resolve
	else:
		# può rispondere l'attaccante (avversario)
		responder_wants_skip = action_buttons.enemy_auto_skip_resolve

	if responder_wants_skip:
		print("⚡ [AUTO-RESOLVE] TO DAMAGE STEP → salto controlli e attese")
		return

	if is_attacker:
		var other_player_id = multiplayer.get_peers()[0]  # ✅ DICHIARAZIONE NECESSARIA
#
		## 🔎 Verifica se l'attaccante ha carte con effetto Quick o facedown
		var has_quick_response = false
#
		for card in player_creatures_on_field:
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				has_quick_response = true
				break

		if not has_quick_response:
			for card in player_spells_on_field:
				if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
					has_quick_response = true
					break
#
		#if not has_quick_response:
			#print("⚡ Attaccante non ha Quick o carte coperte → passa automaticamente alla damage step.")
			#emit_signal("to_damage_step_chosen")
			#rpc_id(other_player_id, "receive_to_damage_step_chosen")
			#rpc_id(other_player_id, "hide_enemy_response_buttons")
			#return
			
		if not has_quick_response:
			print("⚡ Attaccante non ha Quick o carte coperte → passa automaticamente alla damage step.")
			
			# 🔔 Comunica al difensore
			
			rpc_id(other_player_id, "receive_to_damage_step_chosen")
			rpc_id(other_player_id, "hide_enemy_response_buttons")

			# 🔔 Simula anche lato attaccante (così il difensore riceve il segnale)
			await get_tree().process_frame
			emit_signal("to_damage_step_chosen")
			
			return
		
		
		print("🟢 Sono l'attaccante, mostro TO DAMAGE STEP")
		action_buttons.show_to_damage_step_button()
		await action_buttons.to_damage_step_chosen
		action_buttons.hide_to_damage_step_button()

		emit_signal("to_damage_step_chosen")
		rpc_id(other_player_id, "receive_to_damage_step_chosen")
		rpc_id(other_player_id, "hide_enemy_response_buttons")

	else:
	# 🔍 Controllo se l'attaccante ha carte Quick o facedown
		var opponent_has_response := false
		for card in opponent_creatures_on_field:
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break
		if not opponent_has_response:
			for card in opponent_spells_on_field:
				if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
					opponent_has_response = true
					break

		if opponent_has_response:
			print("⏳ Difensore attende TO DAMAGE STEP da attaccante")
			await self.to_damage_step_chosen

func wait_for_resolve_choice(is_attacker: bool) -> void:
	var action_buttons = $"../ActionButtons"
	var input_manager = $"../InputManager"
	# 🛠️ Verifica se l'avversario può rispondere
	var opponent_has_response = false
	print("👁️ Waiting on resolve_choice_received su CombatManager ID:", get_instance_id())
	
	if is_attacker:
		# 🔥 Controllo carte dell'avversario
		for card in $"../CombatManager".opponent_creatures_on_field:
			print("🧪 [QuickCheck] Card:", card.name, "| speed:", card.card_data.effect_speed, "| triggered:", card.effect_triggered_this_turn)
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break
		for card in $"../CombatManager".opponent_spells_on_field:
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break
	else:
		# 🔥 Controllo carte mie (sono il difensore)
		for card in $"../CombatManager".player_creatures_on_field:
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break
		for card in $"../CombatManager".player_spells_on_field:
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break

	# 🔥 Se l'avversario NON può rispondere → saltiamo subito  # serve per l'ultima carta della chain, o comunque quando oppo non ha
	#  piu' niente
	if not opponent_has_response and not chain_locked:
		

		var other_player_id = multiplayer.get_peers()[0]

		# ✅ Comportamento UNIFICATO: mostro comunque bottone RESOLVE e attendo
		if is_attacker:
			print("⚡ Nessuna risposta possibile da parte dell'avversario.")
			print("⏳ COMPORTAMENTO UNIFICATO SONO ATK")
			$"../ActionButtons".show_enemy_resolve_button()
			await self.resolve_choice_received
		else:

			print("⚡ Non posso piu' rispondere per concatenare")
			print("🟢 COMPORTAMENTO UNIFICATO SONO DEF")
			$"../ActionButtons".show_resolve_button()
			await $"../ActionButtons".resolve_chosen
			$"../ActionButtons".hide_resolve_button()
			rpc_id(other_player_id, "receive_resolve_choice")
		return
		

	if is_attacker:   #POTREBBE ESSERE CAUSA BUG RARO DI UN INPUT CHE RIMANE DISABILITATO DOPO UNA CHAIN/PERDITE DI TARGET DURING COMBAT
		print("⏳ Sono l'attaccante, aspetto che il difensore prema Resolve...")
		input_manager.inputs_disabled = true
		await self.resolve_choice_received
		input_manager.inputs_disabled = false
		print("INPUT RIABILITATI")
	else:
		print("⏳ Sono il difensore, mostro il bottone Resolve")
		input_manager.inputs_disabled = false
		action_buttons.show_resolve_button()
		await action_buttons.resolve_chosen
		action_buttons.hide_resolve_button()

		await get_tree().process_frame
		var other_player_id = multiplayer.get_peers()[0]
		rpc_id(other_player_id, "receive_resolve_choice")


func show_action_border_both_sides(card):
	card.action_border.visible = true
	var owner = "Player"
	if card.is_in_group("EnemyCards"):
		owner = "Opponent"
	rpc("show_action_border_on_card", card.name, owner)

	
	#player_LP = STARTING_LP
	#$"../PlayerLP".text = str(player_LP)
	#enemy_LP = STARTING_LP
	#$"../EnemyLP".text = str(enemy_LP)

func on_pass_phase():
	remove_untriggered_spells()

	if $"../CardManager".selection_mode_active:
		$"../CardManager".unselect_selected_card()
	
	#player_creature_that_attacked_this_turn.clear()
	#player_creatures_that_retaliated_this_turn.clear()
	
	



func enemy_card_selected(defending_card):
	var selected_card = $"../CardManager".selected_card
	var purpose = $"../CardManager".selection_purpose
	#$"../CardManager".selection_mode_active = false
	# 🔥 BLOCCO: non puoi targettare te stesso
	if selected_card and defending_card and selected_card == defending_card:
		print("🚫 Non puoi targettare te stesso:", defending_card.name)
		return
		
		# ❗ Blocca se il target non è valido (es: carta ancora in mano)
	if not defending_card.card_is_in_slot:
		print("🚫 Carta selezionata non è sul campo:", defending_card.name)
		return
	# 🔥 Se stiamo ATTACCANDO (selected_card è una CREATURE), blocca targeting su proprie carte SOLO SE NON è un effetto
	if purpose == "attack":
		if selected_card and selected_card.card_data.card_type == "Creature":
			var is_targeted_effect = selected_card.card_data.effect_type == "Activable" and selected_card.card_data.targeting_type == "Targeted"
			
			# ❌ Blocca sempre il targeting di proprie carte (creature o spell)
			var is_my_card = $"../CombatManager".player_creatures_on_field.has(defending_card) or $"../CombatManager".player_spells_on_field.has(defending_card)
			if is_my_card:
				print("🚫 Non puoi attaccare le tue carte:", defending_card.name)
				return
			# ✅ Target valido, mostra red border
				# 🔥 Accendi bordo rosso sulla carta difendente
			if defending_card.has_node("RedHighlightBorder"):
				defending_card.red_highlight_border.visible = true
				defending_card.animate_red_border_pulse()  #BUG IL PULSE NON APPARE SULLA CARTA DOPO NELLA CHAIN
				# Manda l’RPC solo all’altro peer
				#var other_player_id = multiplayer.get_peers()[0]
				#defending_card.rpc_id(other_player_id, "rpc_animate_red_border_pulse") 	#CAUSA BUG NELL'ALTRO CLIENT VIENE MOSTRATO UN REDBORDER IN PIU' SULLE CARTE NEMICHE
				# 🔁 Fai vedere il bordo rosso anche all'altro client
				var target_card_name = defending_card.name
				var target_owner_id: int
				if defending_card.is_enemy_card():
					target_owner_id = multiplayer.get_peers()[0]
				else:
					target_owner_id = multiplayer.get_unique_id()

				rpc("show_red_border_on_card", target_card_name, target_owner_id)

			
			
			$"../ActionButtons".hide_go_to_combat_button()
			$"../ActionButtons".hide_to_damage_step_button()
			# 🔒 Pulizia visiva: spegni tutti i green border e label
			$"../ActionButtons".hide_label($"../ActionButtons".player_selection_label)
			$"../ActionButtons".hide_label($"../ActionButtons".enchain_label)
			#$"../ActionButtons".highlight_cards_for_enchain(false)
			$"../ActionButtons".force_hide_all_green_borders()

				# 💸 Spendi mana richiesto per eventuali trigger nemici on_attack
		if selected_card and selected_card.has_meta("attack_mana_cost"):
			var cost = int(selected_card.get_meta("attack_mana_cost"))
			if cost > 0:
				print("💸 Spendo", cost, "mana per effetto on_attack")
				$"../ManaSlots".spend_highlighted_slots()
				selected_card.set_meta("attack_mana_cost", 0)
			
		if selected_card and selected_card.card_data.card_type == "Creature" and defending_card in $"../CombatManager".opponent_creatures_on_field:
			attack(selected_card, defending_card)
			
		# 🧩 Registra la creatura appena targettata da attacco
		if defending_card and defending_card.card_data.card_type == "Creature":
			var entry = {"card": defending_card, "owner_id": multiplayer.get_unique_id()}
			var card_name = defending_card.name
			var owner_id = multiplayer.get_unique_id()

			$"../CombatManager".just_targeted_creature.clear()
			$"../CombatManager".just_targeted_creature.append(entry)
			await get_tree().process_frame
			# 🔁 SINCRONIZZA subito (in stile overlay)
			rpc("rpc_sync_just_targeted_creature", card_name, owner_id)
			await get_tree().process_frame
			print("📡 [SYNC] rpc_sync_just_targeted_creature inviato →", defending_card.card_data.card_name)

			print("🎯 [CombatManager] Creatura appena targettata da attacco:", defending_card.card_data.card_name)
			
		# ✅ Exit selection mode DOPO attacco
		$"../CardManager".exit_selection_mode(true)
		## 🧩 Se era pending, ora passo l’azione all’altro peer
		#var card_manager = $"../CardManager"
		#if card_manager and card_manager.action_consume_pending:
			#var phase_manager = get_node_or_null("../PhaseManager")
			#if phase_manager:
				#var peers = multiplayer.get_peers()
				#if peers.size() > 0:
					#var other_id = peers[0]
					#print("✅ [Action Consume] Attacco completato → passo azione all’altro peer:", other_id)
					#phase_manager.rpc("rpc_give_action", other_id)
					#phase_manager.rpc_give_action(other_id)
			#card_manager.action_consume_pending = false
			# 🔁 Spegni red highlight se la carta attaccante è morta
		if selected_card.card_data.health <= 0 and defending_card.has_node("RedHighlightBorder"):
			defending_card.get_node("RedHighlightBorder").visible = false
			rpc("hide_red_border_on_card", defending_card.name)
			# Pulizia
		selected_card = null
		$"../CardManager".selected_card = null
		print("ATTACCO")

	# 🔥 NUOVO: Evita di bersagliare spell se effetto è Damage
	if purpose == "effect":
		var valid = false
		
		if selected_card.card_data.effect_1 == "Damage" and defending_card.card_data.card_type == "Spell":
			print("🚫 Non puoi danneggiare una spell:", defending_card.name)
			return
			
		var subtype = selected_card.card_data.t_subtype_1
		if selected_card.card_data.targeting_type == "Targeted":

			var cm = $"../CombatManager"
			var valid_targets = cm.get_valid_targets(selected_card, true)
			if defending_card not in valid_targets:
				print("🚫 Target non valido per", selected_card.card_data.card_name, "→", defending_card.card_data.card_name)
				return

		# ✅ Target valido → Mostra red border
		if defending_card.has_node("RedHighlightBorder"):
			defending_card.red_highlight_border.visible = true
			defending_card.animate_red_border_pulse()
			# 🔁 Mostra bordo rosso anche sull’altro client
			var target_card_name = defending_card.name
			var target_owner_id: int
			if defending_card.is_enemy_card():
				target_owner_id = multiplayer.get_peers()[0]
			else:
				target_owner_id = multiplayer.get_unique_id()
			rpc("show_red_border_on_card", target_card_name, target_owner_id)

		# 🔒 Pulizia visiva
		$"../ActionButtons".hide_go_to_combat_button()
		$"../ActionButtons".hide_to_damage_step_button()
		$"../ActionButtons".hide_label($"../ActionButtons".player_selection_label)
		$"../ActionButtons".hide_label($"../ActionButtons".enchain_label)
		$"../ActionButtons".force_hide_all_green_borders()

		# 🧩 Registra la creatura appena targettata (se è una creature)
		if defending_card and defending_card.card_data.card_type == "Creature":
			var entry = {"card": defending_card, "owner_id": multiplayer.get_unique_id()}
			var card_name = defending_card.name
			var owner_id = multiplayer.get_unique_id()

			$"../CombatManager".just_targeted_creature.clear()
			$"../CombatManager".just_targeted_creature.append(entry)
			await get_tree().process_frame
			rpc("rpc_sync_just_targeted_creature", card_name, owner_id)
			print("📡 [SYNC] rpc_sync_just_targeted_creature inviato →", defending_card.card_data.card_name)
			await get_tree().process_frame

		# 🪄 Applica effetto
		apply_targeted_effect(selected_card, defending_card)

		# 🧹 Pulizia finale
		$"../ActionButtons".hide_label($"../ActionButtons".player_selection_label)
		$"../CardManager".trigger_card_effect(selected_card)
		$"../CardManager".selection_mode_active = false
		selected_card = null
		$"../CardManager".selected_card = null
		return






func apply_targeted_effect(selected_card, defending_card):
		# 🔥 Prima di applicare l’effetto, rimuovi il selection overlay
	if $"../CardManager".selection_purpose == "effect":
		$"../CardManager".remove_selection_overlay(selected_card)
	if selected_card.card_data.effect_type != "On_Trigger":
		selected_card.effect_triggered_this_turn = true
		#print("✅ Effetto impostato come già triggerato:", source_card.card_data.card_name)
	else:
		print("⛔ Effetto On_Trigger → non impostato come triggerato:", selected_card.card_data.card_name)
			# Segna che ha "attaccato" con questo effetto
	if selected_card.card_data.effect_type == "ActivableAttack":
		if not player_creature_that_attacked_this_turn.has(selected_card):
			player_creature_that_attacked_this_turn.append(selected_card)
			selected_card.attacked_this_turn = true
			print("📝 Aggiunta a player_creature_that_attacked_this_turn:", selected_card.name)
	#selected_card.action_border.z_index = 35
	var player_id = multiplayer.get_unique_id()
	var source_card_name = selected_card.name
	var target_card_name = defending_card.name
	var effect = selected_card.card_data.effect_1
	var magnitude = selected_card.card_data.effect_magnitude_1
	var source_owner_id = multiplayer.get_unique_id()
	var target_owner_id = source_owner_id if not defending_card.is_enemy_card() else multiplayer.get_peers()[0]

	selected_card.has_a_target = true
	defending_card.is_being_targeted = true  #APPLY TARGETING
	if selected_card not in defending_card.being_targeted_by_cards:
		defending_card.being_targeted_by_cards.append(selected_card)
		currently_targeted_cards.append(defending_card)
		print("✅ Aggiunta", defending_card.name, "a currently_targeted_cards.")

		# Mostra il contenuto attuale dello stack
		var current_names := []
		for c in currently_targeted_cards:
			current_names.append(c.name)
		print("📦 Stack currently_targeted_cards:", current_names)
		
		
		defending_card.targeted_stack_count = defending_card.being_targeted_by_cards.size()
		print("📊 Local Target count per ", defending_card.name, ":", defending_card.targeted_stack_count)
		print("🎯 [APPLY TARGET] Targeting su:", defending_card.name)
		var names = []
		for c in defending_card.being_targeted_by_cards:
			names.append(c.name)
		print("🔗 Ora è bersagliata da:", names)
	
	print("📤 [LOCAL] Targeting set →", source_card_name, "(owner:", source_owner_id, ") →", target_card_name, "(owner:", target_owner_id, ")")
	rpc("sync_targeting_flags", source_card_name, target_card_name, source_owner_id, target_owner_id)
	
	
	rpc("apply_effect_here_and_replicate_client_opponent", player_id, source_card_name, target_card_name, effect, magnitude, target_owner_id)
	apply_effect_here_and_replicate_client_opponent(player_id, source_card_name, target_card_name, effect, magnitude, target_owner_id)
	rpc("show_red_border_on_card", target_card_name, target_owner_id)

	

@rpc("any_peer")
func sync_targeting_flags(source_card_name: String, target_card_name: String, source_owner_id: int, target_owner_id: int):
	var local_id = multiplayer.get_unique_id()

	var source_card: Node = null
	var target_card: Node = null

	# 📦 Ricostruzione SOURCE card
	if local_id == source_owner_id:
		source_card = $"../CardManager".get_node_or_null(source_card_name)
	else:
		source_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + source_card_name)

	# 🎯 Ricostruzione TARGET card
	if local_id == target_owner_id:
		target_card = $"../CardManager".get_node_or_null(target_card_name)
	else:
		target_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + target_card_name)

	target_card = target_card as Card
	
	# ✅ Impostazione flag se entrambi trovati
	if source_card and target_card:
		source_card.has_a_target = true
		target_card.is_being_targeted = true
		if source_card not in target_card.being_targeted_by_cards:
			target_card.being_targeted_by_cards.append(source_card)
			currently_targeted_cards.append(target_card)
			print("✅ Aggiunta", target_card.name, "a currently_targeted_cards.")

			# Mostra il contenuto attuale dello stack
			var current_names := []
			for c in currently_targeted_cards:
				current_names.append(c.name)
			print("📦 Stack currently_targeted_cards:", current_names)

			target_card.targeted_stack_count = target_card.being_targeted_by_cards.size()
			print("📊 SYNC Target count per ", target_card.name, ":", target_card.targeted_stack_count)
			print("🎯 [APPLY TARGET] Targeting su:", target_card.name)
			var names = []
			for c in target_card.being_targeted_by_cards:
				names.append(c.name)
			print("🔗 SYNC Ora è bersagliata da:", names)
		#print("🔗 Targeting sync →", source_card.name, "(owner:", source_owner_id, ") →", target_card.name, "(owner:", target_owner_id, ")")
		# 🧹 RIMUOVI targeting (target_card_name == "")
	elif source_card and target_card_name == "":
		print("🧹 [SYNC] Rimozione targeting da:", source_card.name)
		var still_targets_any = false

		for card in get_tree().get_nodes_in_group("Cards"):
			if source_card in card.being_targeted_by_cards:
				card.being_targeted_by_cards.erase(source_card)
				if not currently_targeted_cards.is_empty():
					var removed_card = currently_targeted_cards.pop_back()
					print("🧹 Rimossa dal pulse stack:", removed_card.name)

					# Mostra la nuova ultima carta, se c’è
					if not currently_targeted_cards.is_empty():
						var last_card = currently_targeted_cards.back()
						print("🔴 PULSE:", last_card.name, "è ORA l'ULTIMA in currently_targeted_cards → pulse!")
						if typeof(last_card) == TYPE_DICTIONARY:
							print("⚠️ Pulse su placeholder:", last_card["name"])
						else:
							last_card.animate_red_border_pulse()

					# Stampa tutte le rimanenti
					var remaining_names := []
					for c in currently_targeted_cards:
						remaining_names.append(c.name)
					print("📦 Pulse stack rimanente:", remaining_names)
				else:
					print("⚠️ Pulse stack vuoto → nessuna carta da rimuovere.")
					
				card.targeted_stack_count = card.being_targeted_by_cards.size()
				print("📉 SYNC Target count aggiornato per", card.name, ":", card.targeted_stack_count)
				print("🔄 Rimosso", source_card.name, "da", card.name)
				if card.being_targeted_by_cards.size() == 0:
					card.is_being_targeted = false
			if card.being_targeted_by_cards.has(source_card):
				still_targets_any = true

		if not still_targets_any:
			source_card.has_a_target = false  # ✅ QUI ORA LO AGGIORNIAMO
			print("✅ [SYNC] source_card.has_a_target = false per", source_card.name)
	
func direct_attack(attacking_card):  #CONSUMA AZIONE
	if attacking_card.card_data.card_type != "Creature":   #chatgpt, le spell non possono attaccare
		return        

	#player_creature_that_attacked_this_turn.append(attacking_card)
	#attacking_card.attacked_this_turn = true
	attacking_card.action_border.visible = true
	attacking_card.has_an_attack_target = true
	if attacking_card.attack_negated:
		attacking_card.attack_negated = false
		print("ATTACK NEGATED A FALSE DIRECT ATK")
	show_action_border_both_sides(attacking_card)
	var owner = "Player"
	if attacking_card.is_in_group("EnemyCards"):
		owner = "Opponent"
	rpc("show_action_border_on_card", attacking_card.name, owner)
	
	show_attack_overlay(attacking_card.name, multiplayer.get_unique_id())
	rpc("show_attack_overlay", attacking_card.name, multiplayer.get_unique_id()) #AGGIUNTO PER BUG DIRECT ATK OVERLAY

	await get_tree().process_frame
	var player_id = multiplayer.get_unique_id()
	##attacking_card.card_data.init_original_stats() "BUG QUANDO MAX HEALTH/ATK E' A 0 "
	#var card_data_dict = attacking_card.card_data.to_dict()
	var slot_name = attacking_card.current_slot.name
	
# 🔍 Calcola se Flying è utile PRIMA di inviare l'RPC TALENT FLYING
	
	var attacker_talents = attacking_card.card_data.get_all_talents()

	if "Flying" in attacker_talents:
		for c in opponent_creatures_on_field:
			if c.position_type == "defense":
				flying_was_useful = true
				break

	#if "Flying" in attacker_talents and flying_was_useful:
		#attacking_card.play_talent_icon_pulse("Flying")
		#await get_tree().create_timer(1.0).timeout
	print("🧪 direct attack RPC payload approx:",
		var_to_bytes({
			"a": attacking_card.name,
			"s": slot_name,
			"f": flying_was_useful
			}).size(), "bytes"
	)
	# ✅ Invia come parametro extra
	rpc("direct_attack_here_and_replicate_client_opponent",player_id,attacking_card.name,slot_name,flying_was_useful)
	direct_attack_here_and_replicate_client_opponent(player_id,attacking_card.name,slot_name,flying_was_useful)

	
		# ✅ Reset di sicurezza della catena E' PER SICUREZZA.
	if chain_locked:
		print("🔓 Reset di sicurezza chain_locked = false dopo attack")
		chain_locked = false
	
	

func attack(attacking_card, defending_card): 
	$"../CardManager".selected_card = null
	#if not "Ruthless" in attacking_card.card_data.get_all_talents():
		#player_creature_that_attacked_this_turn.append(attacking_card)
		#attacking_card.attacked_this_turn = true
	
	attacking_card.action_border.visible = true  # 🔥 Ora accendiamo anche qua
	if attacking_card.attack_negated:
		attacking_card.attack_negated = false
		print("ATTACK NEGATED A FALSE")
	show_action_border_both_sides(attacking_card)
	# 🧹 Rimuovi overlay di selezione (spada)
	$"../CardManager".remove_attack_overlay(attacking_card)
	# 👇 Aggiungi overlay attacco
	add_attack_overlay(attacking_card)
	
	var owner = "Player"
	if attacking_card.is_in_group("EnemyCards"):
		owner = "Opponent"
	rpc("show_action_border_on_card", attacking_card.name, owner)
	rpc("show_attack_overlay", attacking_card.name, multiplayer.get_unique_id())
	
	await get_tree().process_frame


	var player_id = multiplayer.get_unique_id() 
	##attacking_card.card_data.init_original_stats() "BUG QUANDO MAX HEALTH/ATK E' A 0 "
	#var attacking_card_data = attacking_card.card_data.to_dict()
	#attacking_card_data["card_name"] = attacking_card.name  # 👈 aggiungi questo
#
	##defending_card.card_data.init_original_stats() "BUG QUANDO MAX HEALTH/ATK E' A 0 "
	#var defending_card_data = defending_card.card_data.to_dict()
	#defending_card_data["card_name"] = defending_card.name

	var target_owner_id: int
	if defending_card.is_enemy_card():
		target_owner_id = multiplayer.get_peers()[0]
	else:
		target_owner_id = multiplayer.get_unique_id()
	#defending_card_data["owner_id"] = target_owner_id
	
	var slot_name = attacking_card.current_slot.name

	attacking_card.has_an_attack_target = true
	defending_card.is_being_attacked = true
	if attacking_card not in defending_card.being_attacked_by_cards:
		defending_card.being_attacked_by_cards.append(attacking_card)
		print ("LOCAL, Carta attaccata:", defending_card.name, "da:", attacking_card.name)


	var attacker_id = multiplayer.get_unique_id()
	var defender_id = multiplayer.get_peers()[0] if defending_card.is_enemy_card() else attacker_id
	rpc("sync_attack_flags", attacking_card.name, defending_card.name, attacker_id, defender_id)
	
	var attacker_talents = attacking_card.card_data.get_all_talents()

	if "Flying" in attacker_talents:
		for c in opponent_creatures_on_field:
			if "Taunt" in c.card_data.get_all_talents():
				# Se sto attaccando una creatura NON-Taunt, allora Flying è stato utile
				if not ("Taunt" in defending_card.card_data.get_all_talents()):
					flying_was_useful = true
				break

	print("🧪 attack RPC payload approx:",
		var_to_bytes({
			"a": attacking_card.name,
			"d": defending_card.name,
			"o": target_owner_id,
			"s": slot_name,
			"f": flying_was_useful
			}).size(), "bytes"
	)
	rpc(
		"attack_here_and_replicate_client_opponent",player_id,attacking_card.name,defending_card.name,target_owner_id,slot_name,flying_was_useful)
	attack_here_and_replicate_client_opponent(player_id,attacking_card.name,defending_card.name,target_owner_id,slot_name,flying_was_useful)
	
	

@rpc("any_peer")
func apply_untargeted_effect_here_and_replicate_client_opponent(player_id, source_card_name: String, effect: String, magnitude: int, t_subtype: String = "", is_triggered: bool = false):
	var is_attacker = multiplayer.get_unique_id() == player_id
	var source_card

	if is_attacker:
		source_card = $"../CardManager".get_node_or_null(source_card_name)
	else:
		source_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + source_card_name)

	#if not source_card:
		#push_error("❌ Source card non trovata per untargeted effect:", source_card_name)
		#return
	# 🔥 Rimuovi subito il selection overlay se c'era
	if $"../CardManager".selection_purpose == "effect":
		$"../CardManager".remove_selection_overlay(source_card)

	if source_card.has_node("ActionBorder"):
		source_card.get_node("ActionBorder").visible = true
	# ✅ Imposta effect_triggered_this_turn SOLO se non è un effetto On_Trigger
	if source_card.card_data.effect_type != "On_Trigger":
		source_card.effect_triggered_this_turn = true
		#print("✅ Effetto impostato come già triggerato:", source_card.card_data.card_name)
	else:
		print("⛔ Effetto On_Trigger → non impostato come triggerato:", source_card.card_data.card_name)
		
	if source_card.card_data.effect_type == "ActivableAttack":
		if not player_creature_that_attacked_this_turn.has(source_card):
			player_creature_that_attacked_this_turn.append(source_card)
			source_card.attacked_this_turn = true
			print("📝 Aggiunta a player_creature_that_attacked_this_turn:", source_card.name)
	
		# 🔮 Controllo scaling Spell Power anche per effetti untargeted

	var combat_manager = $"../CombatManager"
	
	if effect_stack.is_empty():
		current_chain_position = 0
		print("🔁 [RESET] Nuova chain → current_chain_position reimpostata a 0")
		# 📌 REGISTRAZIONE STACK GLOBALE
	# ✅ Reset automatico: la prima carta della chain non può essere enchained BUG CHE FA PASSARE ACTION SU CARTE CHAINATE PER PRIME TIPO HOLE
	#if effect_stack.is_empty() and source_card.was_enchained:
		#print("♻️ [RESET FIX] Prima carta della chain → reset was_enchained su", source_card.name)
		#source_card.was_enchained = false
		
	var entry = {
		"card_name": source_card_name,
		"player_id": player_id,
		"chain_position": current_chain_index,
		"was_enchained": source_card.was_enchained,
		"has_keep_going": source_card.card_data.has_keep_going,
	}
	effect_stack.append(entry)
	print("🟢 Carta", source_card_name, "entra nella chain. was_enchained =", source_card.was_enchained)
	
	var placeholder = {
		"is_placeholder": true,
		"name": "[Untargeted] " + source_card_name,
		"effect": effect,
		"magnitude": magnitude,
		"chain_index": source_card.effect_stack_index,
		"was_enchained": source_card.was_enchained,
		"has_keep_going": source_card.card_data.has_keep_going,
	}
	print("🟢 Placeholder", source_card_name, "entra nella chain. was_enchained =", source_card.was_enchained)
	currently_targeted_cards.append(placeholder)
	print("➕ Aggiunto placeholder per effetto untargeted:", effect, "dalla carta", source_card_name)
	var current_names := []
	for c in currently_targeted_cards:
		current_names.append(c.name)
	print("📦 Stack currently_targeted_cards:", current_names)
	
	# ✅ Mostra chain overlay solo se:
	# - NON è un On_Trigger, oppure
	# - È un On_Trigger MA con trigger_type = On_UpKeepPhase o On_EndPhase
	if source_card.card_data.effect_type != "On_Trigger" \
	or (source_card.card_data.effect_type == "On_Trigger"
		and source_card.card_data.trigger_type in ["On_UpKeepPhase", "On_EndPhase"]):
		add_chain_overlay(source_card, effect_stack.size())
	else:
		print("⛔ [SKIP OVERLAY] On_Trigger non di fase → niente chain overlay per", source_card.card_data.card_name)
		# ✅ Se è la prima carta della chain ed esistono carte in attesa gia' in battle → segna chaining attivo
	if current_chain_index == 0 and (cards_waiting_for_go_to_combat.size() > 0 or cards_waiting_for_to_damage_step.size() > 0):
		print("🔗 Prima carta nella chain con carte in attesa gia' in battle → chained_this_battle_step = true")
		chained_this_battle_step = true
	
	
	
## 👇 CHECK CONSECUTIVE CARDS
	#if effect_stack.size() >= 2:
		#var last = effect_stack[effect_stack.size() - 1]
		#var second_last = effect_stack[effect_stack.size() - 2]
		#if last.player_id == second_last.player_id:
			#print("🔁 Consecutive cards dello stesso player → blocco auto-chain")
			#is_consecutive_cards = true
			#rpc("sync_is_consecutive_cards", true)
		#else:
			#is_consecutive_cards = false
			#rpc("sync_is_consecutive_cards", false)
	#else:
		#is_consecutive_cards = false
		#rpc("sync_is_consecutive_cards", false)
	
	print("➕ Effetto aggiunto allo stack:", entry)
	print("📦 Effetti nello stack:")
	for e in effect_stack:
		print("- Card:", e.card_name, "| Player:", e.player_id, "| Pos:", e.chain_position)
	print("📏 Dimensione attuale stack:", effect_stack.size())
	source_card.effect_stack_index = current_chain_index
	source_card.effect_triggering_player_id = player_id
	current_chain_position = current_chain_index  # 👈 aggiungi questa riga
	print("🔢 [SET] current_chain_position impostata a:", current_chain_position)
	current_chain_index += 1
	
	#PRIMA DI PROCEDERE ASPETTA I RESOLVE
	# 🧩 Attende il resolve solo se NON è un On_Trigger,
	# oppure SE è un On_Trigger ma con trigger_type = On_EndPhase o On_UpKeepPhase
	# --- 🧩 Controllo se l’avversario ha risposte ---
	var cm = $"../CombatManager"
	var action_buttons = $"../ActionButtons"
	#var opponent_has_response = false
	#var is_attacker = true  # opzionale, puoi differenziare in base al contesto

	var opponent_has_response = check_opponent_has_response(is_attacker)


	# --- 🧩 Procedi solo se la carta non è un On_Trigger immediato ---
	if source_card.card_data.effect_type != "On_Trigger" \
	or (source_card.card_data.effect_type == "On_Trigger"
		and source_card.card_data.trigger_type in ["On_UpKeepPhase", "On_EndPhase"]):

		var responder_wants_skip: bool
		if is_attacker:
			# io ho attivato → sta rispondendo il nemico
			responder_wants_skip = action_buttons.enemy_auto_skip_resolve
		else:
			# effetto arrivato dal nemico → sto rispondendo io
			responder_wants_skip = action_buttons.auto_skip_resolve

		# Solo se l'avversario ha risposte → attendo Resolve
		if opponent_has_response and not responder_wants_skip:  #AUTO-APPROVE
			print("🧩 [ChainResolve] Avversario ha possibili risposte → attendo Resolve.")
			chain_resolving_in_progress = true
			await wait_for_resolve_choice(is_attacker)

			var my_chain_pos = source_card.effect_stack_index
			var my_player_id = multiplayer.get_unique_id()

			while true:
				var still_has_higher_own_cards = false
				for e in effect_stack:
					if e.player_id == my_player_id and e.chain_position > my_chain_pos:
						still_has_higher_own_cards = true
						break
				if still_has_higher_own_cards:
					print("⏸️ Attendo: ci sono altre carte mie da risolvere prima (chain più in alto)...")
					await wait_for_resolve_choice(is_attacker)
				else:
					break

			await self.final_resolve_ack_received
			chain_resolving_in_progress = false

			while current_chain_position != source_card.effect_stack_index:
				print("⏸️ [WAIT TURN] Attendo che sia il mio turno per risolvere → io:", source_card.effect_stack_index, "attuale:", current_chain_position)
				await self.final_resolve_ack_received

			print("✅ [ChainResolve] Resolve completata per:", source_card.card_data.card_name)
		else:
			print("⚡ [ChainResolve] Nessuna risposta → salto attesa Resolve.")
	else:
		print("⚡ [ON_TRIGGER AUTO] Salto attesa dei resolve/ack per:", source_card.card_data.card_name, "→ trigger:", source_card.card_data.trigger_type)




	
	
	# 👇 sostituisci tutto quel blocco con questo:
	for i in range(1, 6):
		var effect_name = source_card.card_data.get("effect_%d" % i)
		magnitude = source_card.card_data.get("effect_magnitude_%d" % i)
		t_subtype = source_card.card_data.get("t_subtype_%d" % i)
		var scaling_type = source_card.card_data.get("scaling_%d" % i)

		if effect_name == "None" or effect_name == "":
			continue  # ⏭️ nessun effetto valido in questo slot

		# 🧮 SCALING SPELL POWER

		var spell_power_total = 0

		# 1️⃣ Spell Power base
		if is_attacker:
			spell_power_total = combat_manager.player_SP
		else:
			spell_power_total = combat_manager.enemy_SP

		# 2️⃣ Spell Power per attributo
		var attr = source_card.card_data.card_attribute
		if attr != "" and attr != "None":
			match attr:
				"Fire":
					if is_attacker:
						spell_power_total += combat_manager.player_FireSP
					else:
						spell_power_total += combat_manager.enemy_FireSP
				"Water":
					if is_attacker:
						spell_power_total += combat_manager.player_WaterSP
					else:
						spell_power_total += combat_manager.enemy_WaterSP
				"Earth":
					if is_attacker:
						spell_power_total += combat_manager.player_EarthSP
					else:
						spell_power_total += combat_manager.enemy_EarthSP
				"Wind":
					if is_attacker:
						spell_power_total += combat_manager.player_WindSP
					else:
						spell_power_total += combat_manager.enemy_WindSP

		# 3️⃣ Aggiungi spell power base della carta
		spell_power_total += source_card.card_data.base_spell_power

		print("✨ [SPELL POWER TOTAL]", source_card.card_data.card_name,
			"| Attributo:", attr,
			"| SP Totale:", spell_power_total)


		# 4️⃣ Applica scaling se richiesto
		match scaling_type:
			"None":
				pass

			"MagnitudeSpellPower":
				var bonus = source_card.card_data.spell_multiplier * spell_power_total
				magnitude += bonus
				print("🔮 [SCALING SpellPower #", i, "]",
					" Carta:", source_card.card_data.card_name,
					" | SP Totale:", spell_power_total,
					" | Mult:", source_card.card_data.spell_multiplier,
					" | Bonus:", bonus,
					" | Magnitude finale:", magnitude)

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
				var scale_amount = source_card.card_data.get("scaling_amount_%d" % i)
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
				var scale_amount = source_card.card_data.get("scaling_amount_%d" % i)
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

				var scale_amount = source_card.card_data.get("scaling_amount_%d" % i)
				var bonus = hand_size * scale_amount
				magnitude += bonus
				print("✋ [SCALING HandSize #", i, "]",
					" | Carte in mano:", hand_size,
					" | Scaling Amount:", scale_amount,
					" | Bonus:", bonus,
					" | Magnitude finale:", magnitude)

			_:
				print("⚠️ [SCALING] Tipo di scaling non riconosciuto:", scaling_type)

		var cards_to_destroy = []
		var temp_effect_type = ""
		temp_effect_type = source_card.card_data.temp_effect
		
		if source_card.card_is_in_slot and not source_card.effect_negated and not source_card.card_data.targeting_type == "Targeted":
			# --- 🔮 Se non è Self / Player effect, usa helper get_valid_targets ---
			if not t_subtype in ["Self", "SelfPlayer", "EnemyPlayer", "BothPlayers","MyNextNormalSpell", "None"]:
				var valid_targets = $"../CombatManager".get_valid_targets(source_card, is_attacker, t_subtype)


				if valid_targets.is_empty():
					print("⚠️ Nessun target valido trovato per effetto untargeted di:", source_card.card_data.card_name, "| subtype:", t_subtype)
				else:
					print("🎯 Target validi trovati per", source_card.card_data.card_name)

				for card in valid_targets:
					if not is_instance_valid(card):
						continue
					if check_magic_veil(card, source_card):
						continue
					if card.card_data.health <= 0 and not card.card_data.card_type == "Spell":
						continue

					apply_simple_effect_to_card(card, effect_name, magnitude, source_card, player_id)
					await handle_card_destruction_check(card, cards_to_destroy)
					card.update_card_visuals()
					rpc("update_card_stats", card.name, card.card_data.attack, card.card_data.health)

				register_continuous_aura_targets(source_card, magnitude, is_attacker, t_subtype)

			# --- 🎯 Altrimenti, gestisci manualmente i casi logici ---
			else:
				match t_subtype:
					"Self":
						print("🪞 [UNTARGETED SELF] Applico effetto", effect_name, "su", source_card.card_data.card_name)
						if is_instance_valid(source_card) and not source_card.effect_negated:
							apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id)
							source_card.update_card_visuals()
							await handle_card_destruction_check(source_card, [])
						else:
							print("❌ [UNTARGETED SELF] Carta non valida o negata, effetto saltato.")

					"SelfPlayer":
						if is_attacker:
							if effect_name == "GainLP":
								player_LP += magnitude
								$"../PlayerLP".text = str(player_LP)

							elif effect_name == "Damage":
								# ➤ Danno al player locale (SelfPlayer)
								var protected = check_and_consume_protection(false)  # false = colpisce il player
								if protected:
									print("🩹 Nessun danno SelfPlayer inflitto (Protection attiva).")
								else:
									player_LP = max(0, player_LP - magnitude)
									$"../PlayerLP".text = str(player_LP)
									source_card.emit_signal("damage_dealt", source_card, magnitude, "direct_damage")
									print("💥 SelfPlayer infligge", magnitude, "danni al player (rimasti:", player_LP, ")")

							elif effect_name == "PreventDamage":  # 🛡️ nuovo effetto
								var is_next_damage = magnitude == 1
								show_player_status_icon("Protection", true, false, temp_effect_type, is_next_damage)
								print("🛡️ [PreventDamage] Protezione attiva sul player (attaccante)")

							elif effect_name in ["AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWaterMana", "AddWindMana"]:
								var mana_manager_path = "../ManaSlots"
								var mana_manager = get_node_or_null(mana_manager_path)
								if mana_manager == null:
									push_error("❌ ManaSlotManager non trovato in " + mana_manager_path)
									return

								var mana_type = ""
								match effect_name:
									"AddColorlessMana": mana_type = "Colorless"
									"AddFireMana": mana_type = "Fire"
									"AddEarthMana": mana_type = "Earth"
									"AddWaterMana": mana_type = "Water"
									"AddWindMana": mana_type = "Wind"

								for j in range(magnitude):
									var single_slot: Array[String] = [mana_type]
									mana_manager.add_extra_mana_slots(single_slot, source_card.card_data.temp_effect)
									await get_tree().create_timer(0.05).timeout

							elif effect_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWaterSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower"]:
								apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id)

						else:
							if effect_name == "GainLP":
								enemy_LP += magnitude
								get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)

							elif effect_name == "Damage":
								# ➤ Danno al nemico (SelfPlayer per il difensore)
								var protected = check_and_consume_protection(true)  # true = colpisce enemy
								if protected:
									print("🩹 Nessun danno SelfPlayer inflitto al nemico (Protection attiva).")
								else:
									enemy_LP = max(0, enemy_LP - magnitude)
									get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)
									print("💥 SelfPlayer infligge", magnitude, "danni al nemico (rimasti:", enemy_LP, ")")

							elif effect_name == "PreventDamage":  # 🛡️ nuovo effetto
								var is_next_damage = magnitude == 1
								show_player_status_icon("Protection", true, true, temp_effect_type, is_next_damage)
								print("🛡️ [PreventDamage] Protezione attiva sull’enemy player")

							elif effect_name in ["AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWaterMana", "AddWindMana"]:
								var enemy_mana_manager_path = "EnemyField/ManaSlots"
								var enemy_mana_manager = get_parent().get_parent().get_node_or_null(enemy_mana_manager_path)
								if enemy_mana_manager == null:
									push_error("❌ Enemy ManaSlotManager non trovato in " + enemy_mana_manager_path)
									return

								var mana_type = ""
								match effect_name:
									"AddColorlessMana": mana_type = "Colorless"
									"AddFireMana": mana_type = "Fire"
									"AddEarthMana": mana_type = "Earth"
									"AddWaterMana": mana_type = "Water"
									"AddWindMana": mana_type = "Wind"

								for j in range(magnitude):
									var single_slot: Array[String] = [mana_type]
									enemy_mana_manager.add_extra_mana_slots(single_slot, source_card.card_data.temp_effect)
									await get_tree().create_timer(0.05).timeout

							elif effect_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWaterSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower"]:
								apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id)


					"EnemyPlayer":
						if is_attacker:
							if effect_name == "GainLP":
								enemy_LP += magnitude
								get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)

							elif effect_name == "Damage":
								# ➤ Danno al nemico (target = enemy)
								var protected = check_and_consume_protection(true)
								if protected:
									print("🩹 Nessun danno EnemyPlayer inflitto (Protection attiva).")
								else:
									enemy_LP = max(0, enemy_LP - magnitude)
									get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)
									print("💥 EnemyPlayer infligge", magnitude, "danni al nemico (rimasti:", enemy_LP, ")")

							elif effect_name == "PreventDamage":  # 🛡️ nuovo effetto
								var is_next_damage = magnitude == 1
								show_player_status_icon("Protection", true, true, temp_effect_type, is_next_damage)
								print("🛡️ [PreventDamage] Protezione attiva sull’enemy player (attaccante)")

							elif effect_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWaterSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower"]:
								apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id)

						else:
							if effect_name == "GainLP":
								player_LP += magnitude
								$"../PlayerLP".text = str(player_LP)

							elif effect_name == "Damage":
								# ➤ Danno al player locale (target = player)
								var protected = check_and_consume_protection(false)
								if protected:
									print("🩹 Nessun danno EnemyPlayer subìto (Protection attiva).")
								else:
									player_LP = max(0, player_LP - magnitude)
									$"../PlayerLP".text = str(player_LP)
									print("💥 EnemyPlayer subisce", magnitude, "danni (rimasti:", player_LP, ")")

							elif effect_name == "PreventDamage":  # 🛡️ nuovo effetto
								var is_next_damage = magnitude == 1
								show_player_status_icon("Protection", true, false, temp_effect_type, is_next_damage)
								print("🛡️ [PreventDamage] Protezione attiva sul player (difensore)")

							elif effect_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWaterSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower"]:
								apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id)
					"MyNextNormalSpell":
						print("MY NEXT NORMAL SPELL AGGIUNGO CONDITION NORMAL AL BUFF NEXT SPELL")
						apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id)
					"None", _:
						print("APPLICO EFFETTO NONE")
						apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id)
		else:
			print("❌ Effetto annullato: carta non più in campo o negata →", source_card.name)
			
			# 💥 Distruzione automatica della carta annullata
			if is_instance_valid(source_card) and source_card.card_is_in_slot:
				var owner = "Player" if not source_card.is_enemy_card() else "Opponent"
				print("💥 [AUTO-DESTROY] Distruggo", source_card.card_data.card_name, "poiché il suo effetto è stato annullato.")
				destroy_card(source_card, owner)



	if source_card.card_data.effect_type == "On_Trigger":
		if not source_card.card_data.trigger_type in ["On_UpKeepPhase", "On_EndPhase"]:
		
						# 🔎 Check rapido se l'avversario ha carte Quick o facedown (solo per On_Trigger)
			#opponent_has_response = false
			if is_attacker:
				for card in combat_manager.opponent_creatures_on_field:
					if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
						opponent_has_response = true
						break
				if not opponent_has_response:
					for card in combat_manager.opponent_spells_on_field:
						if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
							opponent_has_response = true
							break
			else:
				for card in combat_manager.player_creatures_on_field:
					if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
						opponent_has_response = true
						break
				if not opponent_has_response:
					for card in combat_manager.player_spells_on_field:
						if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
							opponent_has_response = true
							break

			var responder_wants_skip: bool
			if is_attacker:
				# io ho attivato → sta rispondendo il nemico
				responder_wants_skip = action_buttons.enemy_auto_skip_resolve
			else:
				# effetto arrivato dal nemico → sto rispondendo io
				responder_wants_skip = action_buttons.auto_skip_resolve

			if opponent_has_response and not responder_wants_skip: #AUTO-APPROVE
				print("🧩 [ON_TRIGGER] L'avversario ha possibili risposte → attendo con bottone Resolve")
				chain_resolving_in_progress = true
				await wait_for_resolve_choice(is_attacker)

				var my_chain_pos = source_card.effect_stack_index
				var my_player_id = multiplayer.get_unique_id()

				while true:
					var still_has_higher_own_cards = false
					for e in effect_stack:
						if e.player_id == my_player_id and e.chain_position > my_chain_pos:
							still_has_higher_own_cards = true
							break
					if still_has_higher_own_cards:
						print("⏸️ Attendo altre carte mie da risolvere prima (chain più in alto)...")
						await wait_for_resolve_choice(is_attacker)
					else:
						break

				await self.final_resolve_ack_received
				chain_resolving_in_progress = false

				while current_chain_position != source_card.effect_stack_index:
					print("⏸️ [WAIT TURN] Attendo turno di risoluzione → io:", source_card.effect_stack_index, "attuale:", current_chain_position)
					await self.final_resolve_ack_received
			else:
				print("⚡ [ON_TRIGGER] Nessuna possibile risposta → risolvo direttamente senza attesa Resolve")
				#await wait(0.5)  # piccolo delay visivo opzionale
				
	if not chain_locked and current_chain_position >= 0:
		print("CHAIN LOCKED IMPOSTATA A TRUE")
		chain_locked = true
	
	await wait(0.5)  # piccolo delay visivo opzionale
		#nascondi eventuali border/label gia' presenti
		#$"../ActionButtons".highlight_cards_for_enchain(false)
	$"../ActionButtons".force_hide_all_green_borders()
	$"../ActionButtons".hide_label($"../PromptLabels/PlayerEnchainLabel")
	$"../ActionButtons".hide_label($"../PromptLabels/PlayerSelectionLabel")
	
	#
	#await wait(1.0)


	#if source_card.card_is_in_slot and not source_card.effect_negated:
	if source_card.card_is_in_slot:
		if source_card.has_node("ActionBorder"):
			source_card.get_node("ActionBorder").visible = false
		rpc("hide_action_border_on_card", source_card.name)

		if source_card.card_data.card_type == "Spell" and source_card.card_data.card_class != "ContinuousSpell" and source_card.card_data.card_class != "EquipSpell" and not source_card in cards_to_destroy_after_chain:
			if source_card.effect_negated:
				source_card.effect_negated = false
				source_card.set_negated_state(false)
				print("Reset effect negated prima di andare a GY")
			var owner = "Player" if is_attacker else "Opponent"
			destroy_card(source_card, owner)
		# ⚡ NOVITÀ: ContinuousSpell o EquipSpell negate → vengono distrutte
		elif source_card.card_data.card_type == "Spell" and source_card.effect_negated and (source_card.card_data.card_class == "ContinuousSpell" or source_card.card_data.card_class == "EquipSpell"):
			source_card.effect_negated = false
			source_card.set_negated_state(false)
			print("💥 Continuous/Equip Spell negata → distrutta:", source_card.card_data.card_name)
			var owner = "Player" if is_attacker else "Opponent"
			destroy_card(source_card, owner)
		# 🔥 Muovi la carta indietro con un tween animato
		else:
			var tween = get_tree().create_tween()
			if is_attacker:
				tween.tween_property(source_card, "position:y", source_card.position.y + 10, 0.2) # Se io sono chi ha triggerato → torna giù
			else:
				tween.tween_property(source_card, "position:y", source_card.position.y - 10, 0.2) # Se io sono il client → sale su!
				

		source_card.z_index = 0
		
		await get_tree().process_frame
		if source_card.has_node("ActionBorder"):

			source_card.get_node("ActionBorder").z_index = -1
			source_card.get_node("ActionBorder").visible = false
			var ab = source_card.get_node("ActionBorder")

		var owner = "Player" if is_attacker else "Opponent"
		rpc("hide_action_border_on_card", source_card.name, owner)
		# 🔇 Spegnimento visivo bottoni RESOLVE e ENEMY RESOLVE
	$"../ActionButtons".hide_resolve_button()
	$"../ActionButtons".hide_enemy_response_buttons()
	
		# 👇 Rimuovi overlay di questa carta
	remove_chain_overlay(source_card)
	# 🔚 Rimuovo il placeholder se presente #PARTE CHE POTREBBE DARE BUG QUESTA DEL PLACEHOLDER REMOVAL
	if not currently_targeted_cards.is_empty():
		var last = currently_targeted_cards.back()
		if typeof(last) == TYPE_DICTIONARY and last.has("is_placeholder") and last["is_placeholder"]:
			currently_targeted_cards.pop_back()
			print("🧹 Rimossa placeholder dal pulse stack:", last["name"])
			for c in currently_targeted_cards:
				current_names.append(c.name)
			print("📦 Stack currently_targeted_cards:", current_names)
		# mostra il nuovo ultimo in stack se esiste
			if not currently_targeted_cards.is_empty():
				var new_last = currently_targeted_cards.back()
				if is_instance_valid(new_last):
					new_last.animate_red_border_pulse()
				else:
					print("⚠️ [Fallback] Ultima carta in currently_targeted_cards non più valida.")
			else:
				print("⚠️ [Fallback] Nessuna carta disponibile in currently_targeted_cards per animare il bordo rosso.")


	var is_last = is_last_effect_in_chain(source_card)

	if is_last \
		and not any_combat_in_progress \
		and cards_waiting_for_go_to_combat.is_empty() \
		and cards_waiting_for_to_damage_step.is_empty():
		
		print("✅ Questa è l'ULTIMA carta da risolvere → mostro bottone PASS PHASE")
		
		# Mostra localmente
		$"../ActionButtons".rpc_show_pass_phase_button()
	#continue_chain_after_resolve(source_card.effect_stack_index)
	#if not source_card.card_is_in_slot or source_card.effect_negated:
		#simulate_resolve = true
		
	# ⚙️ Risolve eventuali effetti accodati durante la chain
	await process_triggered_effects_this_chain_link()

	# 🕓 Attende in sicurezza finché il flag triggered_effects_processing non torna false
	while $"../CombatManager".triggered_effects_processing:
		await get_tree().process_frame

	await get_tree().create_timer(0.5).timeout #IMPORTANTE NON TOCCARE
	print("✅ Tutti gli effetti post-chain terminati, procedo con continue_chain_after_resolve.")
	await continue_chain_after_resolve(source_card.effect_stack_index, simulate_resolve)

	await resolve_field_spell_conflict(source_card) #TERRENO MARCHIATE CON 1000 DUR

	
@rpc("any_peer")
func apply_effect_here_and_replicate_client_opponent(player_id, source_card_name: String, target_card_name: String, effect: String, magnitude: int, target_owner_id: int):
	var is_attacker = multiplayer.get_unique_id() == player_id

	# 👑 Imposta il peer che sta attualmente risolvendo il trigger

	
	var source_card
	var target_card

	print("  - player_id =", player_id)
	print("  - target_owner_id =", target_owner_id)
	print("👤 Il mio ID locale è:", multiplayer.get_unique_id())
	
	# 🔥 Ricostruzione source_card
	if is_attacker:
		source_card = $"../CardManager".get_node_or_null(source_card_name)
	else:
		source_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + source_card_name)

	var local_player_id = multiplayer.get_unique_id()

	if target_owner_id == local_player_id:
		target_card = $"../CardManager".get_node_or_null(target_card_name)
	else:
		target_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + target_card_name)
	
	
		# 🔥 Rimuovi subito il selection overlay se c'era
	if $"../CardManager".selection_purpose == "effect":
		$"../CardManager".remove_selection_overlay(source_card)
	# ✅ Sicurezza: target_card deve essere in campo
	#if target_card and not target_card.card_is_in_slot:
		#target_card = null
#
#
	#if not source_card or not target_card:
		#push_error("❌ Effetto non replicato: source o target card non trovata.")
		#return

	if source_card.has_node("ActionBorder"):
		source_card.get_node("ActionBorder").visible = true

	# ✅ Imposta effect_triggered_this_turn SOLO se non è un effetto On_Trigger
	if source_card.card_data.effect_type != "On_Trigger":
		source_card.effect_triggered_this_turn = true
		#print("✅ Effetto impostato come già triggerato:", source_card.card_data.card_name)
	else:
		print("⛔ Effetto On_Trigger → non impostato come triggerato:", source_card.card_data.card_name)
	
	if source_card.card_data.effect_type == "ActivableAttack":
		if not player_creature_that_attacked_this_turn.has(source_card):
			player_creature_that_attacked_this_turn.append(source_card)
			source_card.attacked_this_turn = true
			print("📝 Aggiunta a player_creature_that_attacked_this_turn:", source_card.name)
	
	if effect_stack.is_empty():
		current_chain_position = 0
		print("🔁 [RESET] Nuova chain → current_chain_position reimpostata a 0")
		
	#if effect_stack.is_empty() and source_card.was_enchained:
		#print("♻️ [RESET FIX] Prima carta della chain → reset was_enchained su", source_card.name)
		#source_card.was_enchained = false
	# 📌 REGISTRAZIONE STACK GLOBALE
	var entry = {
		"card_name": source_card_name,
		"player_id": player_id,
		"chain_position": current_chain_index,
		"was_enchained": source_card.was_enchained,
		"has_keep_going": source_card.card_data.has_keep_going,
	}
	print("🟢 Carta", source_card_name, "entra nella chain. was_enchained =", source_card.was_enchained)
	effect_stack.append(entry)
	add_chain_overlay(source_card, effect_stack.size())
			# ✅ Se è la prima carta della chain ed esistono carte in attesa gia' in battle → segna chaining attivo
	if current_chain_index == 0 and (cards_waiting_for_go_to_combat.size() > 0 or cards_waiting_for_to_damage_step.size() > 0):
		print("🔗 Prima carta nella chain con carte in attesa gia' in battle → chained_this_battle_step = true")
		chained_this_battle_step = true
	
## 👇 CHECK CONSECUTIVE CARDS
	#if effect_stack.size() >= 2:
		#var last = effect_stack[effect_stack.size() - 1]
		#var second_last = effect_stack[effect_stack.size() - 2]
		#if last.player_id == second_last.player_id:
			#print("🔁 Consecutive cards dello stesso player → blocco auto-chain")
			#is_consecutive_cards = true
			#rpc("sync_is_consecutive_cards", true)
		#else:
			#is_consecutive_cards = false
			#rpc("sync_is_consecutive_cards", false)
	#else:
		#is_consecutive_cards = false
		#rpc("sync_is_consecutive_cards", false)
	
	
	
	print("➕ Effetto aggiunto allo stack:", entry)
	print("📦 Effetti nello stack:")
	for e in effect_stack:
		print("- Card:", e.card_name, "| Player:", e.player_id, "| Pos:", e.chain_position)
	print("📏 Dimensione attuale stack:", effect_stack.size())
	source_card.effect_stack_index = current_chain_index
	source_card.effect_triggering_player_id = player_id
	current_chain_position = current_chain_index  # 👈 aggiungi questa riga
	print("🔢 [SET] current_chain_position impostata a:", current_chain_position)
	current_chain_index += 1
	
		## 🛑 PRIMA DI PROCEDERE ASPETTA IL RESOLVE (VECCHIA LOGICA CON WAITING SEMPRE)
	#chain_resolving_in_progress = true
	#await wait_for_resolve_choice(is_attacker)
	#
#
	## ⚠️ Se esistono altre carte del mio stesso player con chain_position più alta → aspetta ancora
	#var my_chain_pos = source_card.effect_stack_index
	#var my_player_id = multiplayer.get_unique_id()
#
	#while true:
		#var still_has_higher_own_cards = false
		#for e in effect_stack:
			#if e.player_id == my_player_id and e.chain_position > my_chain_pos:
				#still_has_higher_own_cards = true
				#break
		#if still_has_higher_own_cards:
			#print("⏸️ Attendo: ci sono altre carte mie da risolvere prima (chain più in alto)...")
			#await wait_for_resolve_choice(is_attacker)  # ✅ aspetta davvero il resolve dell'altro player
		#else:
			#break
			#
	#await self.final_resolve_ack_received # attende anche eventuale concatenazione nostra
	#chain_resolving_in_progress = false
	

			## 🛑 Aspetto che sia il mio turno nel LIFO per risolvere
	#while current_chain_position != source_card.effect_stack_index:
		#print("⏸️ [WAIT TURN] Attendo che sia il mio turno per risolvere → io:", source_card.effect_stack_index, "attuale:", current_chain_position)
		#await self.final_resolve_ack_received

#NUOVA LOGICA SENZA WAITING UNNECESSARY:-------------

	var opponent_has_response = check_opponent_has_response(is_attacker)
	var action_buttons = $"../ActionButtons"

	# --- 🧩 Procedi solo se la carta non è un On_Trigger immediato ---
	if source_card.card_data.effect_type != "On_Trigger" \
	or (source_card.card_data.effect_type == "On_Trigger"
		and source_card.card_data.trigger_type in ["On_UpKeepPhase", "On_EndPhase"]):

		var responder_wants_skip: bool
		if is_attacker:
			# io ho attivato → sta rispondendo il nemico
			responder_wants_skip = action_buttons.enemy_auto_skip_resolve
		else:
			# effetto arrivato dal nemico → sto rispondendo io
			responder_wants_skip = action_buttons.auto_skip_resolve

		if opponent_has_response and not responder_wants_skip:
			print("🧩 [ChainResolve] Avversario ha possibili risposte → attendo Resolve.")
			chain_resolving_in_progress = true
			await wait_for_resolve_choice(is_attacker)

			var my_chain_pos = source_card.effect_stack_index
			var my_player_id = multiplayer.get_unique_id()

			while true:
				var still_has_higher_own_cards = false
				for e in effect_stack:
					if e.player_id == my_player_id and e.chain_position > my_chain_pos:
						still_has_higher_own_cards = true
						break
				if still_has_higher_own_cards:
					print("⏸️ Attendo: ci sono altre carte mie da risolvere prima (chain più in alto)...")
					await wait_for_resolve_choice(is_attacker)
				else:
					break

			await self.final_resolve_ack_received
			chain_resolving_in_progress = false

			while current_chain_position != source_card.effect_stack_index:
				print("⏸️ [WAIT TURN] Attendo che sia il mio turno per risolvere → io:", source_card.effect_stack_index, "attuale:", current_chain_position)
				await self.final_resolve_ack_received

			print("✅ [ChainResolve] Resolve completata per:", source_card.card_data.card_name)
		else:
			await wait(0.5)
			print("⚡ [ChainResolve] Nessuna risposta → salto attesa Resolve.")
	else:
		print("⚡ [ON_TRIGGER AUTO] Salto attesa dei resolve/ack per:", source_card.card_data.card_name, "→ trigger:", source_card.card_data.trigger_type)
		
	if source_card.card_is_in_slot and not source_card.effect_negated and target_card.card_is_in_slot:
		var skip_effect := false  # 👈 nuovo flag



		if check_magic_veil(target_card, source_card): #ATTENZIONE QUESTO CHECK  POTREBBE CAUSARE BUG
			#FA ANCHE IL THRESHOLD SOLO PER IL PRIMO EFF PERCHE' NON E' DENTRO L'IF NOT SKIP EFFECT
			print("✨ [MAGIC VEIL] Effetto annullato su", target_card.name)
			skip_effect = true


		# ⚔️ Applica gli effetti (anche multipli) solo se non annullati
		if not skip_effect:

			# 🔁 Elenco degli effetti e magnitudo presenti nella carta
			var effects_to_apply: Array = []
			var magnitudes_to_apply: Array = []

			if source_card.card_data.effect_1 != "None":
				effects_to_apply.append(source_card.card_data.effect_1)
				magnitudes_to_apply.append(source_card.card_data.effect_magnitude_1)

			if source_card.card_data.effect_2 != "None" and not (source_card.card_data.targeting_type_2 != "Targeted" and source_card.card_data.effect_type_2 == "On_Trigger"):  #PROTEZIONE VERSO LA MYSTICAL BLADE
				effects_to_apply.append(source_card.card_data.effect_2)
				magnitudes_to_apply.append(source_card.card_data.effect_magnitude_2)

			# (Facoltativo futuro)
			#if source_card.card_data.effect_3 != "None":
				#effects_to_apply.append(source_card.card_data.effect_3)
				#magnitudes_to_apply.append(source_card.card_data.effect_magnitude_3)

			# 🔁 Calcola quante volte ripetere l’effetto
			var repeat_count = 1

			match source_card.card_data.repeats:
				"1", "2", "3", "4", "5":
					repeat_count = int(source_card.card_data.repeats)

				"Number_of_self_in_GY":
					var gy_node
					if is_attacker:
						gy_node = get_parent().get_parent().get_node_or_null("PlayerField/PlayerGY")
					else:
						gy_node = get_parent().get_parent().get_node_or_null("EnemyField/EnemyGY")

					if gy_node:
						var count_same = 0
						print("🧩 [DEBUG] Controllo ripetizioni per:", source_card.card_data.tooltip_name)
						print("📜 Carte nel GY:", gy_node.gy_cards.size())

						for c in gy_node.gy_cards:
							if c == null:
								print("   ⚠️ Carta NULL trovata nel GY, salto.")
								continue

							# ✅ confronto sempre per tooltip_name, che è il nome logico
							print("   🔍 GY card:", c.tooltip_name, "| cerco:", source_card.card_data.tooltip_name)
							if c.tooltip_name == source_card.card_data.tooltip_name:
								count_same += 1
								print("   ✅ Match trovato con", c.tooltip_name)

						repeat_count = count_same + 1
						print("🔁 Totale copie trovate nel GY:", count_same, "→ repeat_count impostato a:", repeat_count)
					else:
						print("⚠️ Nessun nodo GY trovato → repeat_count resta 1")



				"Number_of_fire_spells_in_GY":
					var gy_node
					if is_attacker:
						gy_node = get_parent().get_parent().get_node_or_null("PlayerField/PlayerGY")
					else:
						gy_node = get_parent().get_parent().get_node_or_null("EnemyField/EnemyGY")
					if gy_node:
						var count_fire = 0
						for c in gy_node.gy_cards:
							if c and c.card_type == "Spell" and c.card_data.card_attribute == "Fire":
								count_fire += 1
						repeat_count = count_fire

				"Number_of_earth_spells_in_GY":
					var gy_node
					if is_attacker:
						gy_node = get_parent().get_parent().get_node_or_null("PlayerField/PlayerGY")
					else:
						gy_node = get_parent().get_parent().get_node_or_null("EnemyField/EnemyGY")
					if gy_node:
						var count_earth = 0
						for c in gy_node.gy_cards:
							if c and c.card_type == "Spell" and c.card_data.card_attribute == "Earth":
								count_earth += 1
						repeat_count = count_earth

				"Cards_in_hand":
					if is_attacker:
						repeat_count = $"../CombatManager".player_hand.size()
					else:
						repeat_count = $"../CombatManager".enemy_hand.size()

				"Creatures_on_field":
					if is_attacker:
						repeat_count = $"../CombatManager".player_creatures_on_field.size()
					else:
						repeat_count = $"../CombatManager".opponent_creatures_on_field.size()

				"Allies_on_field":
					if is_attacker:
						repeat_count = $"../CombatManager".player_creatures_on_field.size()
					else:
						repeat_count = $"../CombatManager".opponent_creatures_on_field.size()

				"Enemies_on_field":
					if is_attacker:
						repeat_count = $"../CombatManager".opponent_creatures_on_field.size()
					else:
						repeat_count = $"../CombatManager".player_creatures_on_field.size()

				_:
					repeat_count = 1

			print("🔁 Numero di ripetizioni calcolato per", source_card.card_data.card_name, ":", repeat_count)
			
			# 🔄 Ripetizione completa del blocco di effetti
			for rep in range(repeat_count):
				print("🔂 [REPEAT", rep + 1, "/", repeat_count, "] Effetti di", source_card.card_data.card_name, "su", target_card.card_data.card_name)
				# 🔥 Applica tutti gli effetti in sequenza
				for i in range(effects_to_apply.size()):
					if not is_instance_valid(target_card) or not target_card.card_is_in_slot:
						print("⛔ Target non più valida, interruzione della sequenza effetti.")
						break

					var current_effect = effects_to_apply[i]
					var current_magnitude = magnitudes_to_apply[i]


					# 🔍 Controllo scaling Spell Power
					var scaling_property = "None"
					if i == 0:
						scaling_property = source_card.card_data.scaling_1
					elif i == 1:
						scaling_property = source_card.card_data.scaling_2

					if scaling_property == "MagnitudeSpellPower":
			# 🔮 Controllo scaling Spell Power anche per effetti untargeted

						var combat_manager = $"../CombatManager"
						if combat_manager == null:
							push_warning("⚠️ CombatManager non trovato, scaling ignorato per effetto untargeted")
						else:
							var spell_power_total = 0

							# 🧮 1️⃣ Spell Power base
							if is_attacker:
								spell_power_total = combat_manager.player_SP
							else:
								spell_power_total = combat_manager.enemy_SP

							var attr = source_card.card_data.card_attribute  # es. "Fire", "Water", ecc.
							if attr != "" and attr != "None":
								match attr:
									"Fire":
										if is_attacker:
											spell_power_total += combat_manager.player_FireSP
										else:
											spell_power_total += combat_manager.enemy_FireSP
									"Water":
										if is_attacker:
											spell_power_total += combat_manager.player_WaterSP
										else:
											spell_power_total += combat_manager.enemy_WaterSP
									"Earth":
										if is_attacker:
											spell_power_total += combat_manager.player_EarthSP
										else:
											spell_power_total += combat_manager.enemy_EarthSP
									"Wind":
										if is_attacker:
											spell_power_total += combat_manager.player_WindSP
										else:
											spell_power_total += combat_manager.enemy_WindSP

							# ⚡ 3️⃣ Somma anche il valore base della carta
							spell_power_total += source_card.card_data.base_spell_power

							var bonus = source_card.card_data.spell_multiplier * spell_power_total
							current_magnitude = current_magnitude + bonus

							print("🔮 [SPELL POWER SCALING] Totale:", spell_power_total,
								" | Mult:", source_card.card_data.spell_multiplier,
								" | Bonus:", bonus,
								" | Magnitude finale:", current_magnitude)

					print("✨ Applico effetto:", current_effect, "→ Magnitude:", current_magnitude)
					var effect_index = i + 1  # 1 o 2
					var passes_threshold = check_threshold_condition(source_card, target_card, effect_index)



					if not passes_threshold:
						print("🚫 [THRESHOLD] Condizione non soddisfatta → effetto", current_effect, "skippato su", target_card.card_data.card_name)
					else:
						match current_effect:
							"Damage":
								target_card.card_data.health = max(0, target_card.card_data.health - current_magnitude)
								target_card.get_node("Health").text = str(target_card.card_data.health)
								target_card.update_card_visuals()	# 🔔 Segnale di danno inflitto (da attaccante a creatura)
								source_card.emit_signal("damage_dealt", source_card, current_magnitude, "to_creature")
								target_card.emit_signal("damage_taken", target_card, current_magnitude)
								if target_card.card_data.health < target_card.card_data.max_health:
									if target_card.card_data.active_debuffs.has("Stunned"):
										print("✅ Stun rimosso da", target_card.card_data.card_name)
										target_card.stunned = false
										target_card.card_data.remove_debuff("Stunned")
										target_card.update_debuff_icons()
										target_card.rpc("rpc_remove_debuff", player_id, target_card.name, "Stunned")
										target_card.stun_timer = 0
								

							"Heal":
								var old_health = target_card.card_data.health
								var max_health = target_card.card_data.max_health

								# 💚 Aumenta la salute ma non oltre la salute massima
								target_card.card_data.health = clamp(target_card.card_data.health + magnitude, 0, max_health)

								# 🔢 Calcola quanto è stato effettivamente curato
								var healed_amount = target_card.card_data.health - old_health
								if healed_amount > 0:
									print("💚 [Effect] Heal:", target_card.card_data.card_name, "+", healed_amount, "HP (max:", max_health, ")")
									target_card.play_heal_animation()  # 🎬 animazione locale

								await get_tree().process_frame
								target_card.update_card_visuals()


							"Buff":
								var voided_atk = target_card.card_data.voided_atk
								var effective_buff = max(0, current_magnitude - voided_atk)

								print("⚖️ [BUFF] Magnitude:", current_magnitude, "| voided_atk prima:", voided_atk, "→ Buff effettivo:", effective_buff)

								target_card.card_data.attack += effective_buff
								target_card.card_data.max_attack += effective_buff
								target_card.card_data.health += current_magnitude
								target_card.card_data.max_health += current_magnitude

								# 🔄 Aggiorna voided_atk (riducilo di quanto il buff “copre”)
								target_card.card_data.voided_atk = max(0, voided_atk - current_magnitude)

								target_card.card_data.add_buff(source_card, "Buff", current_magnitude, current_magnitude)
								target_card.update_card_visuals()

								print("💪 [BUFF] +", effective_buff, "ATK / +", current_magnitude, "HP su", target_card.card_data.card_name)


							"BuffAtk":
								var voided_atk = target_card.card_data.voided_atk
								var effective_buff = max(0, current_magnitude - voided_atk)

								print("⚖️ [BUFF ATK] Magnitude:", current_magnitude, "| voided_atk prima:", voided_atk, "→ Buff effettivo:", effective_buff)

								target_card.card_data.attack += effective_buff
								target_card.card_data.max_attack += effective_buff

								# 🔄 Aggiorna voided_atk anche qui
								target_card.card_data.voided_atk = max(0, voided_atk - current_magnitude)

								target_card.card_data.add_buff(source_card, "BuffAtk", current_magnitude, 0)
								target_card.update_card_visuals()

								print("💪 [BUFF ATK] +", effective_buff, "ATK su", target_card.card_data.card_name)

								

							"BuffHp":
								target_card.card_data.health += current_magnitude
								target_card.card_data.max_health += current_magnitude
								target_card.card_data.add_buff(source_card, "BuffHp", 0, current_magnitude)
								target_card.update_card_visuals()
								print("💪 [BUFF HP] +", current_magnitude, "HP su", target_card.card_data.card_name)

							"BuffArmour":
								target_card.card_data.armour += current_magnitude
								target_card.card_data.add_buff(source_card, "BuffArmour", 0, 0, current_magnitude)
								target_card.update_card_visuals()
								print("🛡️ [BUFF ARMOUR] +", current_magnitude, "Armour su", target_card.card_data.card_name)

							"Debuff":
								# 🔹 Calcolo riduzioni effettive prima del clamp
								var old_atk = target_card.card_data.attack
								var old_hp = target_card.card_data.health
								var old_max_atk = target_card.card_data.max_attack
								var old_max_hp = target_card.card_data.max_health

								target_card.card_data.attack = max(target_card.card_data.attack - current_magnitude, 0)
								target_card.card_data.health = max(target_card.card_data.health - current_magnitude, 0)
								target_card.card_data.max_attack = max(target_card.card_data.max_attack - current_magnitude, 0)
								target_card.card_data.max_health = max(target_card.card_data.max_health - current_magnitude, 0)

								# 🔸 Calcola quanto è stato effettivamente ridotto
								var atk_loss = old_atk - target_card.card_data.attack
								var hp_loss = old_hp - target_card.card_data.health

								target_card.card_data.add_debuff(source_card, "Debuff", atk_loss, hp_loss)
								await get_tree().process_frame
								target_card.update_card_visuals()
								print("💀 [DEBUFF] -", atk_loss, "ATK /", hp_loss, "HP su", target_card.card_data.card_name)
								print("🎨 ATK:", target_card.card_data.attack, " / ORIG:", target_card.card_data.original_attack, " / MAX:", target_card.card_data.max_attack)
								print("🎨 HP:", target_card.card_data.health, " / ORIG:", target_card.card_data.original_health, " / MAX:", target_card.card_data.max_health)

							"DebuffAtk":
								var old_atk = target_card.card_data.attack
								var old_max_atk = target_card.card_data.max_attack
								print("🕒 Prima del DebuffAtk → ATK:", target_card.card_data.attack, " / MAX:", target_card.card_data.max_attack, " / in_slot:", target_card.card_is_in_slot)
								target_card.card_data.max_attack = max(target_card.card_data.max_attack - current_magnitude, 0)
								target_card.card_data.attack = max(target_card.card_data.attack - current_magnitude, 0)
								

								var atk_loss = old_atk - target_card.card_data.attack

								target_card.card_data.add_debuff(source_card, "DebuffAtk", atk_loss, 0)
								await get_tree().process_frame
								target_card.update_card_visuals()
								print("💀 [DEBUFF ATK] -", atk_loss, "ATK su", target_card.card_data.card_name)
								print("🎨 ATK:", target_card.card_data.attack, " / ORIG:", target_card.card_data.original_attack, " / MAX:", target_card.card_data.max_attack)
								print("🎨 HP:", target_card.card_data.health, " / ORIG:", target_card.card_data.original_health, " / MAX:", target_card.card_data.max_health)

							"DebuffHp":
								var old_hp = target_card.card_data.health
								var old_max_hp = target_card.card_data.max_health

								target_card.card_data.max_health = max(target_card.card_data.max_health - current_magnitude, 0)
								target_card.card_data.health = max(target_card.card_data.health - current_magnitude, 0)
								

								var hp_loss = old_hp - target_card.card_data.health

								target_card.card_data.add_debuff(source_card, "DebuffHp", 0, hp_loss)
								await get_tree().process_frame
								target_card.update_card_visuals()
								print("💀 [DEBUFF HP] -", hp_loss, "HP su", target_card.card_data.card_name)
								print("🎨 ATK:", target_card.card_data.attack, " / ORIG:", target_card.card_data.original_attack, " / MAX:", target_card.card_data.max_attack)
								print("🎨 HP:", target_card.card_data.health, " / ORIG:", target_card.card_data.original_health, " / MAX:", target_card.card_data.max_health)
							"Destroy":
								if target_card.has_node("RedHighlightBorder"):
									target_card.red_highlight_border.visible = true

								# 🔍 Controlla se la carta è ancora nello stack (sta risolvendo un effetto)
								var is_in_stack := false
								for e in effect_stack:
									if e.card_name == target_card.name:
										is_in_stack = true
										break

								if is_in_stack:
									print("⚠️ Carta", target_card.name, "sta risolvendo un effetto → differisco distruzione (post-chain).")

									if not cards_to_destroy_after_chain.has(target_card):
										cards_to_destroy_after_chain.append(target_card)

										# 🧾 Mostra la lista completa aggiornata
										var pending_names := []
										for c in cards_to_destroy_after_chain:
											if is_instance_valid(c):
												pending_names.append(c.name)
											else:
												pending_names.append("[invalid]")

										print("📜 [POST-CHAIN LISTA ATTUALE] Carte da distruggere dopo chain:", pending_names)
								else:
									var owner = "Player" if target_card.is_enemy_card() == false else "Opponent"
									destroy_card(target_card, owner)
									break
							"Bouncer":
								var owner = "Player" if not target_card.is_enemy_card() else "Opponent"
								await apply_bouncer_effect(target_card, owner)
							
							"ChangePosition":
								if not is_instance_valid(target_card):
									break

								# 🔹 Se la carta è una spell e non è facedown → la gira faceup (come rivelazione)
								if target_card.card_data.card_type == "Spell":
									if target_card.position_type == "faceup":
										print("🔄 [CHANGE POSITION] Carta", target_card.card_data.card_name, "è una Spell facedown → la giro faceup")
										target_card.set_position_type("facedown")
									else:
										print("ℹ️ [CHANGE POSITION] Carta", target_card.card_data.card_name, "è già faceup → nessun cambio")
								
								# 🔹 Se la carta è una creatura → cambia tra attack e defense
								elif target_card.card_data.card_type == "Creature":
									if target_card.position_type == "attack":
										print("🔁 [CHANGE POSITION] Carta", target_card.card_data.card_name, "da ATK → DEF")
										target_card.set_position_type("defense")
										if target_card.has_an_attack_target:
											print("STOPPO ANCHE ATTACCO")
											stop_attack(target_card)
									elif target_card.position_type == "defense":
										print("🔁 [CHANGE POSITION] Carta", target_card.card_data.card_name, "da DEF → ATK")
										target_card.set_position_type("attack")
									else:
										print("⚠️ [CHANGE POSITION] Carta", target_card.card_data.card_name, "non in posizione valida per cambio (posizione:", target_card.position_type, ")")
								
								else:
									print("⚠️ [CHANGE POSITION] Carta", target_card.card_data.card_name, "non è né Spell né Creature → nessun effetto applicato")

								await get_tree().process_frame
								target_card.update_card_visuals()
							
							"Freeze":
								var is_frozen := false
								for d in target_card.card_data.active_debuffs:
									if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Frozen":
										is_frozen = true
										break

								if is_frozen:
									print("❄️ Freeze rinnovato su", target_card.card_data.card_name)
									target_card.frozen = true
									target_card.freeze_timer = 1
									target_card.play_debuff_icon_pulse("Frozen")

								else:
									print("❄️ Effetto Freeze applicato a", target_card.card_data.card_name)
									target_card.frozen = true
									target_card.freeze_timer = 1
									target_card.card_data.add_debuff(source_card, "Frozen")
									target_card.update_debuff_icons()
									
								if target_card.has_an_attack_target:
									print("STOPPO ANCHE ATTACCO")
									stop_attack(target_card)

							"Stun":
								var is_stunned := false
								for d in target_card.card_data.active_debuffs:
									if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Stunned":
										is_stunned = true
										break

								var force_one_turn := false
								if source_card.card_data.temp_effect == "EndPhase":
									force_one_turn = true
									print("💫 [ENDPHASE] Forzo durata Stun = 1")

								if is_stunned:
									print("💫 Stun rinnovato su", target_card.card_data.card_name)
									target_card.stunned = true
									target_card.stun_timer = 1 if force_one_turn else 2
									target_card.play_debuff_icon_pulse("Stunned")
								else:
									print("💫 Effetto Stun applicato a", target_card.card_data.card_name)
									target_card.stunned = true
									target_card.stun_timer = 1 if force_one_turn else 2
									target_card.card_data.add_debuff(source_card, "Stunned")
									target_card.update_debuff_icons()
									
								if target_card.has_an_attack_target:
									print("STOPPO ANCHE ATTACCO")
									stop_attack(target_card)

							"Root":
								var is_rooted := false
								for d in target_card.card_data.active_debuffs:
									if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Rooted":
										is_rooted = true
										break

								if is_rooted:
									print("🌿 Root rinnovato su", target_card.card_data.card_name)
									target_card.rooted = true
									target_card.root_timer = 1
									target_card.play_debuff_icon_pulse("Rooted")
								else:
									print("🌿 Effetto Root applicato a", target_card.card_data.card_name)
									target_card.rooted = true
									target_card.root_timer = 1
									target_card.card_data.add_debuff(source_card, "Rooted")
									target_card.update_debuff_icons()

							"BuffTalent":
								var talent_to_add = source_card.card_data.talent_from_buff
								if talent_to_add != "None":
									print("✨ [BUFF TALENT] Aggiungo talento", talent_to_add, "a", target_card.card_data.card_name)

									# 🧠 Salva PRIMA se il talento era già presente
									var already_had_talent = talent_to_add in target_card.card_data.get_all_talents()

									# 📦 Aggiungi SEMPRE il buff logico
									target_card.card_data.add_buff(source_card, "BuffTalent", 0, 0)

									# 📎 Aggiungi il nome del talento nel dizionario del buff
									for b in target_card.card_data.active_buffs:
										if b["source_card"] == source_card and b["type"] == "BuffTalent":
											b["talent"] = talent_to_add
											break

									# 🎨 Aggiungi visivamente l'icona o overlay SOLO se non c’era già
									if not already_had_talent:
										if target_card.TALENT_ICONS.has(talent_to_add):
											target_card._add_icon(talent_to_add)
											target_card.play_talent_icon_pulse(talent_to_add)
										elif talent_to_add in target_card.OVERLAY_TALENTS:
											target_card._add_talent_overlay(talent_to_add)
										print("💪 Talento", talent_to_add, "applicato come buff a", target_card.card_data.card_name)
									else:
										print("⚖️", target_card.card_data.card_name, "aveva già il talento", talent_to_add, "(aggiunto solo buff logico)")

									target_card.update_card_visuals()
								else:
									print("⚠️ Nessun talent_from_buff definito in", source_card.card_data.card_name)
							"Draw":
								print("🃏 Effetto Draw → pesca", current_magnitude)
								if multiplayer.get_unique_id() == player_id:
									print("CHIAMATA LOCAL PLAYER")
									var deck = get_tree().get_current_scene().get_node_or_null("PlayerField/Deck")
									if deck:
										for m in range(current_magnitude):
											deck.draw_card()
											await get_tree().create_timer(0.2).timeout
									else:
										print("DECK NON TROVATO")
								else:
									print("CHIAMATA ALTRO PLAYER")
									var deck = get_tree().get_current_scene().get_node_or_null("EnemyField/EnemyDeck")
									if deck:
										for m in range(current_magnitude):
											deck.draw_card()
											await get_tree().create_timer(0.2).timeout
							"None", _:
								print("⚠️ Effetto ignorato o non definito:", current_effect)

					# 🕓 Pausa solo se la carta ripete più di una volta
				if repeat_count > 1:
					await get_tree().create_timer(0.25).timeout
					
					
			# 💫 Se è una carta con temp_effect == "Enchant", lega la fonte al target
			if source_card.card_data.temp_effect == "Enchant":
				if target_card and target_card.card_is_in_slot:
					print("💫 [ENCHANT] Lego ", source_card.card_data.card_name, " a ", target_card.card_data.card_name)

					# 🔗 Legame bidirezionale
					source_card.enchanted_to = target_card
					if not target_card.enchant_spells.has(source_card):
						target_card.enchant_spells.append(source_card)

					# ✅ Log di stato
					print("🔗 Enchant ", source_card.card_data.card_name, " collegato a ", target_card.card_data.card_name)

				else: #MISS TARGET PER ENCHANT
					# ❌ Target non valida → distruggi subito l’enchant
					print("⚠️ Enchant ", source_card.card_data.card_name, " non può legarsi: target non in slot o rimosso.")
					source_card.enchanted_to = null

					# 💥 Distruzione immediata
					var owner_enchant = "Player" if not source_card.is_enemy_card() else "Opponent"
					destroy_card(source_card, owner_enchant)



			# ⚙️ Dopo aver applicato gli effetti, se è una Equip Spell → lega o degrada la carta
			if source_card.card_data.effect_type == "Equip":
				if target_card and target_card.card_is_in_slot:
					print("⚙️ EQUIP: Lego ", source_card.card_data.card_name, " a ", target_card.card_data.card_name)

					# 🔗 Legame bidirezionale
					source_card.equipped_to = target_card
					if not target_card.equipped_spells.has(source_card):
						target_card.equipped_spells.append(source_card)

					# 🛠️ Durabilità minima
					source_card.card_data.spell_duration = max(1, source_card.card_data.spell_duration)

					print("🔗 Equip ", source_card.card_data.card_name, " collegata a ", target_card.card_data.card_name, " durabilità:", source_card.card_data.spell_duration)
					# 🔥 QUI: trigger When_Equipped sulla creatura
					
					# 🔥 Trigger ONLY se la creatura è del player locale
					if not target_card.is_enemy_card():
						_trigger_when_equipped_effect(target_card, source_card)
					
				else: #LOGICA MISS TARGET PER EQUIP
					# ❌ Target non valida o non in slot
					print("⚠️ Equip ", source_card.card_data.card_name, " non può legarsi: target non in slot o rimossa.")
					source_card.equipped_to = null

					# 🔻 Riduci durabilità
					source_card.card_data.spell_duration -= 1
					source_card.update_card_visuals()
					print("🕒 Durabilità equip ", source_card.card_data.card_name, " ora:", source_card.card_data.spell_duration)
					# 💥 Se la durabilità è 0 o meno → distruggi la spell con la tua funzione ufficiale
					if source_card.card_data.spell_duration <= 0:
						print("💥 Equip ", source_card.card_data.card_name, " si distrugge per durabilità 0")

						var owner_equip = "Player" if not source_card.is_enemy_card() else "Opponent"
						destroy_card(source_card, owner_equip)



	else:
		print("❌ Effetto annullato: carta non più in campo o negata →", source_card.name)
		
		# 💥 Distruzione automatica della carta annullata
		if is_instance_valid(source_card) and source_card.card_is_in_slot:
			var owner = "Player" if not source_card.is_enemy_card() else "Opponent"
			print("💥 [AUTO-DESTROY] Distruggo", source_card.card_data.card_name, "poiché il suo effetto è stato annullato.")
			destroy_card(source_card, owner)
	
	#await wait(0.5)
	if not chain_locked and current_chain_position >= 0:
		print("CHAIN LOCKED IMPOSTATA A TRUE")
		chain_locked = true
	
	await wait(0.5) #IMPORTANTE CREDO
		#nascondi eventuali border/label gia' presenti.
		#$"../ActionButtons".highlight_cards_for_enchain(false)
	$"../ActionButtons".force_hide_all_green_borders()
	$"../ActionButtons".hide_label($"../PromptLabels/PlayerEnchainLabel")
	$"../ActionButtons".hide_label($"../PromptLabels/PlayerSelectionLabel")
	
	if target_card.card_data.health == 0 and target_card.card_data.card_type == "Creature":
		var owner = "Player" if target_card.is_enemy_card() == false else "Opponent"
		destroy_card(target_card, owner)
	
	#if target_card.has_node("RedHighlightBorder"):
		#target_card.red_highlight_border.visible = false
#
	#rpc("hide_red_border_on_card", target_card.name)
	if target_card.has_node("RedHighlightBorder"):
		target_card.red_highlight_border.visible = false
		#if target_card.targeted_stack_count <= 0:
			#target_card.red_highlight_border.visible = false
			#rpc("hide_red_border_on_card", target_card.name)
			#print("🔻 Nascondo red border su", target_card.name)
		#else:
			#print("⛔ NON nascondo red border su", target_card.name, "perché target_count =", target_card.targeted_stack_count)
			
			#------------------------
			#if currently_targeted_cards.size() > 0 and target_card == currently_targeted_cards.back():
				#print("🔴 PULSE:", target_card.name, "è l'ULTIMA in currently_targeted_cards → pulse!")
				#target_card.animate_red_border_pulse()
			#else:
				#print("⚠️ NO PULSE:", target_card.name, "NON è l'ultima in currently_targeted_cards.")

			#if target_card.targeted_stack_count > 1:
				#target_card.animate_red_border_pulse()  #BUG IL PULSE NON APPARE SULLA CARTA DOPO NELLA CHAIN
			#AGGIUNGI ANIMAZIONE REDBORDER	
	
	
	#if source_card.card_is_in_slot and not source_card.effect_negated:
	if source_card.card_is_in_slot:
		if source_card.card_data.card_type == "Spell" and source_card.card_data.card_class != "ContinuousSpell" and source_card.card_data.card_class != "EquipSpell" and not source_card in cards_to_destroy_after_chain:
			if source_card.effect_negated:
				source_card.effect_negated = false
				print("Reset effect negated prima di andare a GY")
			var owner = "Player" if is_attacker  else "Opponent"
			destroy_card(source_card, owner)
			
		# 🔥 Muovi la carta indietro con un tween animato
		else:
			var tween = get_tree().create_tween()
			if is_attacker:
				tween.tween_property(source_card, "position:y", source_card.position.y + 10, 0.2)
			else:
				tween.tween_property(source_card, "position:y", source_card.position.y - 10, 0.2)

			await tween.finished  # ⏳ Aspetta fine animazione
			
		source_card.z_index = 0
		
		await get_tree().process_frame
		if source_card.has_node("ActionBorder"):

			source_card.get_node("ActionBorder").z_index = -1
			source_card.get_node("ActionBorder").visible = false
			var ab = source_card.get_node("ActionBorder")
		if source_card.has_node("NextCardBuffedBorder"):
			source_card.get_node("NextCardBuffedBorder").visible = false
		var owner = "Player" if is_attacker else "Opponent"
		rpc("hide_action_border_on_card", source_card.name, owner)
	

	# ✅ Solo se siamo il client attivo, spegni selection mode dopo aver finito
	if is_attacker:
		$"../CardManager".exit_selection_mode(true)
		
	$"../ActionButtons".hide_resolve_button()
	$"../ActionButtons".hide_enemy_response_buttons()
		# 👇 Rimuovi overlay di questa carta
	remove_chain_overlay(source_card)

	# 🔚 Rimozione del targeting dopo applicazione effetto
	if source_card and target_card:
		if source_card in target_card.being_targeted_by_cards:
			target_card.being_targeted_by_cards.erase(source_card)  
			if not currently_targeted_cards.is_empty():
				var removed_card = currently_targeted_cards.pop_back()
				print("🧹 Rimossa dal pulse stack:", removed_card.name)

				# Mostra la nuova ultima carta, se c’è
				if not currently_targeted_cards.is_empty():
					var last_card = currently_targeted_cards.back()
					print("🔴 PULSE:", last_card.name, "è ORA l'ULTIMA in currently_targeted_cards → pulse!")
					if typeof(last_card) == TYPE_DICTIONARY:
						print("⚠️ Pulse su placeholder:", last_card["name"])
					else:
						last_card.animate_red_border_pulse()

				# Stampa tutte le rimanenti
				var remaining_names := []
				for c in currently_targeted_cards:
					remaining_names.append(c.name)
				print("📦 Pulse stack rimanente:", remaining_names)
			else:
				print("⚠️ Pulse stack vuoto → nessuna carta da rimuovere.")
			target_card.targeted_stack_count = target_card.being_targeted_by_cards.size()
			print("🧹 Rimosso ", source_card.name, "dai targeting di ", target_card.name)
			print("🧹 Aggiorno Target count di card ",target_card.name, ":", target_card.targeted_stack_count )

			# 🧾 Debug: mostra chi rimane
			var remaining = []
			for c in target_card.being_targeted_by_cards:
				remaining.append(c.name)
			print("🔍 Rimangono target su", target_card.name, ":", remaining)

		if target_card.being_targeted_by_cards.size() == 0:
			target_card.targeted_stack_count = 0
			target_card.is_being_targeted = false
			print("CARTA NON E' PIU' TARGETED, TARGET COUNT A 0")
	#continue_chain_after_resolve(source_card.effect_stack_index)
	#if not source_card.card_is_in_slot or source_card.effect_negated or not target_card.card_is_in_slot:
		#simulate_resolve = true
		# ✅ Mostra PASS PHASE se stack completamente vuoto
	var is_last = is_last_effect_in_chain(source_card)

	if is_last \
		and not any_combat_in_progress \
		and cards_waiting_for_go_to_combat.is_empty() \
		and cards_waiting_for_to_damage_step.is_empty():
		
		print("✅ Questa è l'ULTIMA carta da risolvere → mostro bottone PASS PHASE")
		
		 #Mostra localmente
		$"../ActionButtons".rpc_show_pass_phase_button()
		
		## Mostra anche sull’altro peer
		#var other_id = get_tree().get_multiplayer().get_peers()[0]
		#rpc_id(other_id, "rpc_show_pass_phase_button")
		
	await process_triggered_effects_this_chain_link()

	# 🕓 Attende in sicurezza finché il flag triggered_effects_processing non torna false
	while $"../CombatManager".triggered_effects_processing:
		await get_tree().process_frame

	await get_tree().create_timer(0.5).timeout #IMPORTANTE NON TOCCARE
	print("✅ Tutti gli effetti post-chain terminati, procedo con continue_chain_after_resolve.")
	await continue_chain_after_resolve(source_card.effect_stack_index, simulate_resolve)
	


		## Mostra anche sul client opposto
		#var other_id = multiplayer.get_peers()[0]
		#rpc_id(other_id, "rpc_show_pass_phase_button")

	

@rpc("any_peer")
func direct_attack_here_and_replicate_client_opponent(player_id: int,attacking_card_name: String,slot_name: String,flying_was_useful: bool = false):
	var is_attacker = multiplayer.get_unique_id() == player_id
	var attacking_card
	var attack_pos_y
	var direct_damage_done := 0

	if is_attacker:
		var my_slot = $"../PlayerZones".get_node_or_null(slot_name)
		if my_slot and my_slot.card_in_slot:
			attacking_card = my_slot.card_in_slot
			attack_pos_y = 100
	else:
		var enemy_slot = get_parent().get_parent().get_node_or_null("EnemyField/EnemyZones/" + slot_name)
		if enemy_slot and enemy_slot.card_in_slot != null:
			attacking_card = enemy_slot.card_in_slot
			attack_pos_y = 980
	
			
	#if attacking_card == null:  #DEBUG
		#push_error("❌ Carta attaccante non trovata per attacco diretto.")
		#return
	var offset = 0
	if is_attacker:
		offset = -10
	else:
		offset = 10
		
	attacking_card.position.y += offset
	attacking_card.has_an_attack_target = true
	player_creature_that_attacked_this_turn.append(attacking_card)
	attacking_card.attacked_this_turn = true
	# 🌀 Se la carta ha Elusive, disattivalo temporaneamente
	if attacking_card.is_elusive:
		print("🚫", attacking_card.card_data.card_name, " perde temporaneamente Elusive per questo attacco.")
		attacking_card.remove_talent_overlay("Elusive")
		attacking_card.is_elusive = false
		
		# 🔄 Replica su entrambi i client
		#rpc("rpc_remove_talent_overlay", player_id, attacking_card.name, "Elusive")
	
	# 🔥 Accendi il bordo visivamente anche lato client
	if attacking_card and attacking_card.has_node("ActionBorder"):
		attacking_card.get_node("ActionBorder").visible = true
						
	# ✈️ Mostra l'animazione solo se Flying è presente ed è utile
	var attacker_talents = attacking_card.card_data.get_all_talents()
	if "Flying" in attacker_talents and flying_was_useful:
		attacking_card.play_talent_icon_pulse("Flying")
		await get_tree().create_timer(1.0).timeout  # piccola attesa per far vedere il pulse
		
	attacking_card.card_is_in_slot = true
	attacking_card.has_an_attack_target = true #QUESTI 3 RIGHE SONO FALLBACK PER NON FARE SKIPPARE IN AUTOMATICO
	print("FALLBACK FIX ATK DIRETTO")

		#AUTO-APPROVE
	# 🛑 STOP: Attendi GO TO COMBAT (se difensore ha risposta)
	if attacking_card == null or not attacking_card.card_is_in_slot or attacking_card.attack_negated or attacking_card.position_type == "defense":
		print("⛔ [AUTO] Carta attaccante non più valida → salta GO TO COMBAT")
	else:
		cards_waiting_for_go_to_combat.append({
			"card": attacking_card,
			"player_id": player_id
		})
		print("🕒 Aggiunta in attesa GO TO COMBAT:", attacking_card.name, "| Player:", player_id)
		await wait_for_combat_confirmation(is_attacker)
		cards_waiting_for_go_to_combat = cards_waiting_for_go_to_combat.filter(func(e): return e.card != attacking_card)
		print("📉 Rimossa da attesa GO TO COMBAT:", attacking_card.name)

	#already_chained_in_this_go_to_combat = false
	#var other_player_id = multiplayer.get_peers()[0]
	#rpc_id(other_player_id, "sync_chained_flags", false, already_chained_in_this_go_to_damage_step)


	# 🛑 STOP: Attendi TO DAMAGE STEP (se attaccante ha risposta)
	if attacking_card == null or not attacking_card.card_is_in_slot or attacking_card.attack_negated or attacking_card.position_type == "defense":
		print("⛔ [AUTO] Carta attaccante non più valida → salta TO DAMAGE STEP")
	else:
		cards_waiting_for_to_damage_step.append({
			"card": attacking_card,
			"player_id": player_id
		})
		print("🕒 Aggiunta in attesa TO DAMAGE STEP:", attacking_card.name, "| Player:", player_id)
		await wait_for_to_damage_step(is_attacker)

	## 🛑 Aspetta che la chain sia completamente risolta **e** che l'oppo abbia premuto GO TO COMBAT,
	## oppure che l'attaccante abbia forzato il passaggio alla damage step
		if chained_this_battle_step:
			while (chain_locked or not effect_stack.is_empty() or not opponent_pressed_go_to_combat) and not attacker_pressed_to_damage_step:
				await get_tree().process_frame
		
		cards_waiting_for_to_damage_step = cards_waiting_for_to_damage_step.filter(func(e): return e.card != attacking_card)
		print("📉 Rimossa da attesa TO DAMAGE STEP:", attacking_card.name)
	

	

	#already_chained_in_this_go_to_damage_step = false
	#rpc_id(other_player_id, "sync_chained_flags", already_chained_in_this_go_to_combat, false)
	print("ATTACCOOOOO")

	if attacking_card.card_is_in_slot and not attacking_card.attack_negated and enemy_LP > 0:
		print("ATTACCO PROSEGUE")
		var attack_pos = Vector2(attacking_card.current_slot.position.x, attack_pos_y)


		var num_strikes = 1
		if "Double Strike" in attacking_card.card_data.get_all_talents():
			num_strikes = 2

		for i in range(num_strikes):
			# ✅ Validità prima del colpo
			if not attacking_card.card_is_in_slot or attacking_card.attack_negated:
				print("⛔ Attaccante non valido → stop strike", i)
				break
			if attacking_card.card_data.health <= 0:
				print("💀 Attaccante morto → stop strike", i)
				break
			if attacking_card.stunned or attacking_card.frozen:
				print("⚡️ Attaccante stunnato/freezato → stop strike", i)
				break
			if (enemy_LP <= 0 or player_LP <= 0):
				print("💀 Giocatore già sconfitto → stop strike", i)
				break

			# ⚔️ Animazione avanti
			attacking_card.z_index = 100
			var tween_attack = create_tween()
			tween_attack.tween_property(attacking_card, "position", attack_pos, 0.15)
			await tween_attack.finished
			

			# 💥 Danno diretto ai LP
			if multiplayer.get_unique_id() == player_id:
				# ➤ Sto infliggendo danno al nemico
				if not attacking_card.stunned and not attacking_card.frozen:
					var protected = check_and_consume_protection(true)  # enemy is true = colpisce enemy
					if protected:
						print("🩹 Nessun danno inflitto: Protection attiva.")
					else:
						enemy_LP = max(0, enemy_LP - attacking_card.card_data.attack)
						get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)
						attacking_card.emit_signal("damage_dealt", attacking_card, attacking_card.card_data.attack, "direct_damage")
						print("💥 Direct attack infligge", attacking_card.card_data.attack, "danni al nemico (rimasti:", enemy_LP, ")")
						direct_damage_done += attacking_card.card_data.attack  # 👈 memorizza danno
			else:
				# ➤ Sto subendo danno io
				if not attacking_card.stunned and not attacking_card.frozen:
					var protected = check_and_consume_protection(false)  # enemy is false = colpisce player
					if protected:
						print("🩹 Nessun danno subìto: Protection attiva.")
					else:
						player_LP = max(0, player_LP - attacking_card.card_data.attack)
						$"../PlayerLP".text = str(player_LP)
						attacking_card.emit_signal("damage_dealt", attacking_card, attacking_card.card_data.attack, "direct_damage")
						print("💥 Direct attack subisce", attacking_card.card_data.attack, "danni (rimasti:", player_LP, ")")
						direct_damage_done += attacking_card.card_data.attack  # 👈 memorizza danno





			# 💨 Tween indietro come in attack_here_and_replicate_client_opponent
			var tween_back = create_tween()
			tween_back.tween_property(attacking_card, "position", attacking_card.current_slot.position, DEFAULT_CARD_MOVE_SPEED_ATTACK)
			await tween_back.finished
			attacking_card.z_index = 0

			# ✨ Effetto visivo Double Strike (solo se secondo colpo)
			if i == 0 and num_strikes == 2:
				attacking_card.play_talent_icon_pulse("Double Strike")
				await get_tree().create_timer(0.4).timeout


	#await get_tree().create_timer(0.15).timeout
	if attacking_card.card_is_in_slot:
		var tween_back = create_tween()
		tween_back.tween_property(attacking_card, "position", attacking_card.current_slot.position, DEFAULT_CARD_MOVE_SPEED_ATTACK)
		await tween_back.finished
		attacking_card.z_index = 0
	
	if attacking_card.action_border:
		attacking_card.action_border.z_index = -1
		attacking_card.action_border.visible = false
		rpc("hide_action_border_on_card", attacking_card.name)
			
		# 👇 Rimuovi overlay attacco
	remove_attack_overlay(attacking_card)
	rpc("hide_attack_overlay", attacking_card.name, multiplayer.get_unique_id())
	
	# 🔇 Spegnimento visivo bottoni RESOLVE e ENEMY RESOLVE
	$"../ActionButtons".hide_resolve_button()
	$"../ActionButtons".hide_enemy_response_buttons()
	$"../ActionButtons".force_hide_all_green_borders()
	
	already_chained_in_this_go_to_combat = false
	already_chained_in_this_go_to_damage_step = false
	attacking_card.attack_negated = false
	
	if chained_this_battle_step:
		print("🔁 Fine attacco diretto → reset chained_this_battle_step = false")
		chained_this_battle_step = false

	if attacking_card:
		clear_combat_state(attacking_card)
	
	recheck_combat_status()
	
	
	if attacking_card.has_an_attack_target:
		print("SOPRAVVIVE attacking_card.has_an_attack_target = false ")
		attacking_card.has_an_attack_target = false

	var other_player_id = multiplayer.get_peers()[0]
	rpc_id(other_player_id, "sync_chained_flags", false, false)
		
	# 🧩 [ACTION CONSUME] — Passa l'azione solo dal peer attaccante
	if not "Free Strike" in attacking_card.card_data.get_all_talents():
		if multiplayer.get_unique_id() == player_id:
			var phase_manager = get_node_or_null("../PhaseManager")
			if phase_manager:
				var peers = multiplayer.get_peers()
				if peers.size() > 0:
					var other_id = peers[0]
					print("♻️ [Action Switch] Attacco completato → passo azione all’altro peer:", other_id)
					phase_manager.rpc("rpc_give_action", other_id, true)  # 👈 true = from_attack
					phase_manager.rpc_give_action(other_id, true)
	else:
		print("FREE STRIKE NON CONSUMO ACTION")
		attacking_card.play_talent_icon_pulse("Free Strike")
		# ✅ Reset di sicurezza della catena E' PER SICUREZZA
	if chain_locked:
		print("🔓 Reset di sicurezza chain_locked = false dopo direct_attack")
		chain_locked = false
	
	#QUI POI CI DOVRAI METTERE ANCHE GLI EVENTUALI EFFETTI CHE TRIGGERANO ON DAMAGE DI ALTRE CARTE ECC.
	# 📣 [SIGNAL EMIT] direct_damage_fully_resolved (solo se c'è stato danno diretto)
	if direct_damage_done > 0 and is_instance_valid(attacking_card):
		var damage_amount = direct_damage_done
		var damage_type = "direct_damage"
		print("📣 [SIGNAL EMIT] direct_damage_fully_resolved per", attacking_card.card_data.card_name,
			"→", damage_amount, "danni di tipo", damage_type)
		attacking_card.emit_signal("direct_damage_fully_resolved", attacking_card, damage_amount, damage_type)

	$"../ActionButtons".rpc_show_pass_phase_button()

	
@rpc("any_peer")
func attack_here_and_replicate_client_opponent(player_id: int,attacking_card_name: String,defending_card_name: String,defending_owner_id: int,slot_name: String, flying_was_useful: bool = false):
	#var attacking_card_name = attacking_card_data.get("card_name", "")
	#var defending_card_name = defending_card_data.get("card_name", "")
	#var defending_owner_id = defending_card_data.get("owner_id", -1)
	print("📛 Owner della carta difendente:", defending_card_name, "→", defending_owner_id)	
	var attacking_card
	var defending_card
	var y_offset
	var is_attacker = multiplayer.get_unique_id() == player_id
	var attacker_has_deathtouch_kill = false
	var defender_has_deathtouch_kill = false
	var direct_damage_done := 0
	# 🔥 Ricostruisci carte
	if is_attacker:
		attacking_card = $"../CardManager".get_node(NodePath(attacking_card_name))
		defending_card = get_parent().get_parent().get_node(NodePath("EnemyField/CardManager/" + defending_card_name))
		y_offset = BATTLE_ATTACK_OFFSET_Y
	else:
		attacking_card = get_parent().get_parent().get_node(NodePath("EnemyField/CardManager/" + attacking_card_name))
		defending_card = $"../CardManager".get_node(NodePath(defending_card_name))
		y_offset = -BATTLE_ATTACK_OFFSET_Y
	
	print("📦 Attacking card:", attacking_card_name, attacking_card)
	print("📦 Defending card:", defending_card_name, defending_card)

	#if not attacking_card or not defending_card:
		#push_error("❌ Attacking o defending card non trovata.")
		#return

	# 🔥 Accendi ActionBorder attaccante
	if attacking_card.has_node("ActionBorder"):
		attacking_card.get_node("ActionBorder").visible = true
	# ✈️ Mostra l'animazione solo se Flying è presente ed è utile
	var attacker_talents = attacking_card.card_data.get_all_talents()
	if "Flying" in attacker_talents and flying_was_useful:
		attacking_card.play_talent_icon_pulse("Flying")
		await get_tree().create_timer(1.0).timeout  # piccola attesa per far vedere il pulse
		
	attacking_card.z_index = 5

	if not "Ruthless" in attacking_card.card_data.get_all_talents():
		player_creature_that_attacked_this_turn.append(attacking_card)
		attacking_card.attacked_this_turn = true
	# 🌀 Se la carta ha Elusive, disattivalo temporaneamente
	if attacking_card.is_elusive:
		print("🚫", attacking_card.card_data.card_name, " perde temporaneamente Elusive per questo attacco.")
		attacking_card.is_elusive = false
		attacking_card.remove_talent_overlay("Elusive")
		# 🔄 Replica su entrambi i client
		#rpc("rpc_remove_talent_overlay", player_id, attacking_card.name, "Elusive")


	# 🔥 Animazione attacco
	var new_pos = Vector2(defending_card.position.x, defending_card.position.y + y_offset)
	var tween_attack = create_tween()
	tween_attack.tween_property(attacking_card, "position", new_pos, DEFAULT_CARD_MOVE_SPEED_ATTACK)
	await tween_attack.finished
	
	#AUTO-APPROVE
	# 🛑 STOP: Attendi GO TO COMBAT
	if attacking_card == null or not attacking_card.card_is_in_slot or not attacking_card.has_an_attack_target or defending_card == null or not defending_card.card_is_in_slot or attacking_card.attack_negated or attacking_card.position_type == "defense":
		print("⛔ [AUTO] Una delle carte non più valida → salta GO TO COMBAT")
	else:
		cards_waiting_for_go_to_combat.append({
			"card": attacking_card,
			"player_id": player_id
		})
		print("🕒 Aggiunta in attesa GO TO COMBAT:", attacking_card.name, "| Player:", player_id)
		

		
		await wait_for_combat_confirmation(is_attacker, defending_card)
		cards_waiting_for_go_to_combat = cards_waiting_for_go_to_combat.filter(func(e): return e.card != attacking_card)
		print("📉 Rimossa da attesa GO TO COMBAT:", attacking_card.name)

	# 🔥 Determina se il difensore può retaliate  #RIMOSSA CONDIZIONE HAS_AN_ATTACK_TARGET
	var wants_to_retaliate = false
	if attacking_card != null and attacking_card.card_is_in_slot and defending_card != null and defending_card.card_is_in_slot and not attacking_card.attack_negated and not attacking_card.frozen and not attacking_card.position_type == "defense" and not attacking_card.stunned:
		#var defender_can_retaliate = defending_card.position_type == "defense" and defending_card and defending_card.card_data.attack > 0 and defending_card.stunned == false  #tolto player_creatures_that_retaliated_this_turn
		var has_reactivity = "Reactivity" in defending_card.card_data.get_all_talents()
		var defender_can_retaliate = defending_card and defending_card.card_data.attack > 0 and not defending_card.stunned and not defending_card.frozen and (
		defending_card.position_type == "defense" or (defending_card.position_type == "attack" and has_reactivity)
		)
		wants_to_retaliate = await wait_for_retaliate_choice(is_attacker, defender_can_retaliate)
	else:
		print("⛔ [AUTO] skip RETALIATE — stato condizioni:")
		print("  attacking_card != null:", attacking_card != null)
		print("  attacking_card.card_is_in_slot:", attacking_card != null and attacking_card.card_is_in_slot)
		print("  defending_card != null:", defending_card != null)
		print("  defending_card.card_is_in_slot:", defending_card != null and defending_card.card_is_in_slot)
		print("  not attacking_card.attack_negated:", attacking_card != null and not attacking_card.attack_negated)
		print("  not attacking_card.frozen:", attacking_card != null and not attacking_card.frozen)
		print("  attacking_card.position_type != defense:", attacking_card != null and attacking_card.position_type != "defense")
		print("  attacking_card.has_an_attack_target:", attacking_card != null and attacking_card.has_an_attack_target)
		print("  not attacking_card.stunned:", attacking_card != null and not attacking_card.stunned)

	# 🛑 STOP: Attendi TO DAMAGE STEP
	if attacking_card == null or not attacking_card.card_is_in_slot or defending_card == null or not defending_card.card_is_in_slot or attacking_card.attack_negated or attacking_card.position_type == "defense":
		print("⛔ [AUTO] skip TO DAMAGE STEP — stato condizioni:")
		print("  attacking_card == null:", attacking_card == null)
		print("  attacking_card.card_is_in_slot:", attacking_card != null and attacking_card.card_is_in_slot)
		print("  attacking_card.has_an_attack_target:", attacking_card != null and attacking_card.has_an_attack_target)
		print("  defending_card == null:", defending_card == null)
		print("  defending_card.card_is_in_slot:", defending_card != null and defending_card.card_is_in_slot)
		print("  attacking_card.attack_negated:", attacking_card != null and attacking_card.attack_negated)
		print("  attacking_card.position_type == defense:", attacking_card != null and attacking_card.position_type == "defense")

		# ✅ FIX VISUALE: riporta l'attaccante nella sua posizione di slot se ancora valido
		if attacking_card and attacking_card.card_is_in_slot and attacking_card.current_slot:
			var tween_back = create_tween()
			tween_back.tween_property(attacking_card, "position", attacking_card.current_slot.position, DEFAULT_CARD_MOVE_SPEED_ATTACK)
			await tween_back.finished
			attacking_card.z_index = 0
	else:
		cards_waiting_for_to_damage_step.append({
			"card": attacking_card,
			"player_id": player_id
		})
		print("🕒 Aggiunta in attesa TO DAMAGE STEP:", attacking_card.name, "| Player:", player_id)
		await wait_for_to_damage_step(is_attacker)
		
		## 🛑 Aspetta che la chain sia completamente risolta **e** che l'oppo abbia premuto GO TO COMBAT,
		## oppure che l'attaccante abbia forzato il passaggio alla damage step
		if chained_this_battle_step:
			while (chain_locked or not effect_stack.is_empty() or not opponent_pressed_go_to_combat) and not attacker_pressed_to_damage_step:
				await get_tree().process_frame
		
		cards_waiting_for_to_damage_step = cards_waiting_for_to_damage_step.filter(func(e): return e.card != attacking_card)
		print("📉 Rimossa da attesa TO DAMAGE STEP:", attacking_card.name)

		#-------------- ATTACCO DELL'ATTACCANTE CON DANNI ------------
		# 🔥 Calcolo dei danni, con supporto per DOUBLE STRIKE
		var num_strikes = 1
		if "Double Strike" in attacking_card.card_data.get_all_talents():
			num_strikes = 2

		for i in range(num_strikes):
			if not attacking_card.card_is_in_slot or attacking_card.attack_negated:
				print("⛔ Attaccante non valido → interrompo strike", i)
				break
			if attacking_card.card_data.health <= 0:
				print("💀 Attaccante morto → stop strike", i)
				break
			if attacking_card.card_data.active_debuffs.has("Stunned"):
				print("⚡️ Attaccante stunnato → stop strike", i)
				break
			if attacking_card.card_data.active_debuffs.has("Frozen"):
				print("⚡️ Attaccante freezato → stop strike", i)
				break
			if not defending_card.card_is_in_slot:
				print("❌ Difensore non più in campo → stop strike", i)
				break

			#var atk_val = attacking_card.card_data.attack
			var def_hp_before = defending_card.card_data.health  # 💥 Overkill: HP prima del colpo

			# 🔥 Finche' ci sono attacchi multipli da fare, una volta passate le condizioni di validita'.
			if i > 0:
			#if i == 1:
				print("⚔️ DOUBLE STRIKE SECONDO COLPO di", attacking_card.card_data.card_name)
				# 💨 1. Tween di ritorno alla posizione originale (slot) con easing "out"
				if attacking_card.current_slot:
					var tween_back = create_tween()
					tween_back.set_trans(Tween.TRANS_QUAD)  # curva dolce (quadratica)
					tween_back.set_ease(Tween.EASE_OUT)     # rallenta in arrivo
					tween_back.tween_property(attacking_card, "position", attacking_card.current_slot.position, 0.25)
					await tween_back.finished

				# ✨ 2. Pulse dell'icona Double Strike
				await get_tree().create_timer(0.4).timeout
				attacking_card.play_talent_icon_pulse("Double Strike")
				await get_tree().create_timer(0.4).timeout

				# ⚔️ 3. Tween di riavvicinamento al target
				var forward_pos = Vector2(defending_card.position.x, defending_card.position.y + y_offset)
				var tween_forward = create_tween()
				tween_forward.tween_property(attacking_card, "position", new_pos, 0.2)
				await tween_forward.finished

				#var defender_can_retaliate = defending_card.position_type == "defense" and defending_card and defending_card.card_data.attack > 0 and defending_card.stunned == false  #tolto player_creatures_that_retaliated_this_turn
				var has_reactivity = "Reactivity" in defending_card.card_data.get_all_talents()
				var defender_can_retaliate = defending_card and defending_card.card_data.attack > 0 and not defending_card.stunned and not defending_card.frozen and (
				defending_card.position_type == "defense" or (defending_card.position_type == "attack" and has_reactivity)
				)
				wants_to_retaliate = await wait_for_retaliate_choice(is_attacker, defender_can_retaliate)
							

				
			# 💥 Danno base ATTACCO NORMALE 
			if "Phys Immune" in defending_card.card_data.get_all_talents():
				print("🛡️", defending_card.card_data.card_name, "è immune → nessun danno.")
				play_damage_shake(defending_card, 0)
			else:
				var damage_done = max(0, attacking_card.card_data.attack - defending_card.card_data.armour)
				defending_card.card_data.health = max(0, defending_card.card_data.health - damage_done)
				defending_card.get_node("Health").text = str(defending_card.card_data.health)
					# 🔔 Segnale di danno inflitto (da attaccante a creatura)
				if damage_done > 0:
					attacking_card.emit_signal("damage_dealt", attacking_card, attacking_card.card_data.attack, "to_creature")
				defending_card.emit_signal("damage_taken", defending_card, damage_done)
				# 💀 DEATHTOUCH → se l'attaccante ha questo talento e infligge almeno 1 danno, la creatura difendente muore
				if damage_done > 0 and "Deathtouch" in attacking_card.card_data.get_all_talents():
					print("💀 Deathtouch attivo! ", defending_card.card_data.card_name, "verrà distrutta.")
					attacking_card.play_talent_icon_pulse("Deathtouch")
					await get_tree().create_timer(0.3).timeout
					defender_has_deathtouch_kill = true

			# 🧠 Flag per decidere se il difensore può contrattaccare
			var mastery_was_useful = false

			# ⚔️ Se l'attaccante ha Mastery e ha ucciso il difensore → niente contrattacco PER ORA TOLTO MASTERY CHE FUNZIONA PER DEFENDER
			#if "Mastery" in attacking_card.card_data.get_all_talents() and defending_card.card_data.health <= 0 and not "Mastery" in defending_card.card_data.get_all_talents():
			if "Mastery" in attacking_card.card_data.get_all_talents() and defending_card.card_data.health <= 0:
				mastery_was_useful = true
				attacking_card.play_talent_icon_pulse("Mastery")
				print("🎓 Mastery attiva: il difensore", defending_card.card_data.card_name, "non contrattacca perché è stato sconfitto.")
			# 🔥 Rimozione o rinnovo dello Stun se la carta subisce danno ma sopravvive
			if defending_card.card_data.health < defending_card.card_data.max_health:
				# 🔍 Controlla se è stunnato (nuova logica a dizionari)
				var is_stunned := false
				for d in defending_card.card_data.active_debuffs:
					if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Stunned":
						is_stunned = true
						break

				if is_stunned:
					if "Stun" in attacking_card.card_data.get_all_talents():
						if defending_card.card_data.health > 0:
							print("♻️ Stun rinnovato su", defending_card.card_data.card_name)
							defending_card.stunned = true
							defending_card.play_debuff_icon_pulse("Stunned")
							defending_card.stun_timer = 2
						else:
							print("✅ Stun rimosso da", defending_card.card_data.card_name)
							defending_card.stunned = false
							defending_card.card_data.remove_debuff_type("Stunned")
							defending_card.update_debuff_icons()
							defending_card.rpc("rpc_remove_debuff", player_id, defending_card.name, "Stunned")
							defending_card.stun_timer = 0
					else:
						print("✅ Stun rimosso da", defending_card.card_data.card_name)
						defending_card.stunned = false
						defending_card.card_data.remove_debuff_type("Stunned")
						defending_card.update_debuff_icons()
						defending_card.rpc("rpc_remove_debuff", player_id, defending_card.name, "Stunned")
						defending_card.stun_timer = 0

			defending_card.update_card_visuals()

			# 💥 TALENT AGGIUNTO : OVERKILL 
			if "Overkill" in attacking_card.card_data.get_all_talents():
				if attacking_card.card_data.attack > def_hp_before:
					var excess = attacking_card.card_data.attack - def_hp_before
					if excess > 0:
						print("💥 OVERKILL! Danno extra:", excess)
						await get_tree().create_timer(0.3).timeout
						attacking_card.play_talent_icon_pulse("Overkill")
						await get_tree().create_timer(0.3).timeout
						
						# 🔰 Controlla Protection come nel direct attack
						var protected = check_and_consume_protection(is_attacker)
						
						if protected:
							print("🩹 Nessun danno Overkill inflitto: Protection attiva.")
						else:
							if is_attacker:
								enemy_LP = max(0, enemy_LP - excess)
								get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)
								attacking_card.emit_signal("damage_dealt", attacking_card, excess, "direct_damage")
								print("💥 Overkill infligge", excess, "danni diretti al nemico (rimasti:", enemy_LP, ")")
								direct_damage_done = excess  # 👈 memorizza per segnale finale

							else:
								player_LP = max(0, player_LP - excess)
								$"../PlayerLP".text = str(player_LP)
								attacking_card.emit_signal("damage_dealt", attacking_card, excess, "direct_damage")
								print("💥 Overkill subisce", excess, "danni diretti (rimasti:", player_LP, ")")
								direct_damage_done = excess  # 👈 memorizza per segnale finale





			# ⚡️ TALENT AGGIUNTO : STUN (applicato dal colpo)
			
			if "Stun" in attacking_card.card_data.get_all_talents() and attacking_card.card_data.attack > 0:
				if defending_card.card_data.health > 0:
					attacking_card.play_talent_icon_pulse("Stun")

					# 🔍 Controlla se il debuff è già presente
					var already_stunned := false
					for d in defending_card.card_data.active_debuffs:
						if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Stunned":
							already_stunned = true
							break

					if not already_stunned:
						print("🆕 Stun applicato a", defending_card.card_data.card_name)
						defending_card.stunned = true
						defending_card.card_data.add_debuff(attacking_card, "Stunned")
						defending_card.stun_timer = 2
						defending_card.update_debuff_icons()
					else:
						print("♻️ Stun rinnovato su", defending_card.card_data.card_name)
						defending_card.stunned = true
						defending_card.play_debuff_icon_pulse("Stunned")
						defending_card.stun_timer = 2
					#await get_tree().create_timer(0.3).timeout
					
			if "Freeze" in attacking_card.card_data.get_all_talents() and attacking_card.card_data.attack > 0:
				if defending_card.card_data.health > 0:
					attacking_card.play_talent_icon_pulse("Freeze")
					if not defending_card.card_data.active_debuffs.has("Frozen"):
						print("🆕 Freeze applicato a", defending_card.card_data.card_name)
						defending_card.frozen = true
						defending_card.card_data.add_debuff(attacking_card,"Frozen")
						defending_card.freeze_timer = 1
						defending_card.update_debuff_icons()


			
			# CONTRATTACCO DIFENSORE E SCALO DEL SUO ATK E DANNI CONTRATK
			if ((defending_card.position_type == "defense") or 
				(defending_card.position_type == "attack" and "Reactivity" in defending_card.card_data.get_all_talents())) \
				and wants_to_retaliate and not mastery_was_useful:
					
				await get_tree().create_timer(0.5).timeout #se c'e' contrattacco aspetto
				if defending_card.position_type == "attack" and "Reactivity" in defending_card.card_data.get_all_talents():
					defending_card.play_talent_icon_pulse("Reactivity")
					
				
				#if defending_card not in player_creatures_that_retaliated_this_turn:
				# 💥 Calcolo del danno effettivo inflitto all'attaccante
				var damage_to_attacker = min((defending_card.card_data.attack - attacking_card.card_data.armour), attacking_card.card_data.health) 
				# 💔 Applica il danno all'attaccante (ma rispetta Phys Immune)
				if "Phys Immune" in attacking_card.card_data.get_all_talents():
					play_damage_shake(attacking_card, 0)
				else:
					attacking_card.card_data.health = max(0, attacking_card.card_data.health - damage_to_attacker)
					attacking_card.get_node("Health").text = str(attacking_card.card_data.health)
					if damage_to_attacker > 0:
						defending_card.emit_signal("damage_dealt", defending_card, defending_card.card_data.attack, "to_creature")
					attacking_card.emit_signal("damage_taken", attacking_card, damage_to_attacker)
										# 💀 DEATHTOUCH → segna l'attaccante per la distruzione se ha subito danno da un difensore con Deathtouch
					if damage_to_attacker > 0 and "Deathtouch" in defending_card.card_data.get_all_talents():
						print("💀 Deathtouch del difensore! ", attacking_card.card_data.card_name, "sarà distrutta.")
						defending_card.play_talent_icon_pulse("Deathtouch")
						await get_tree().create_timer(0.3).timeout
						attacker_has_deathtouch_kill = true
						
				# ⚔️ Il difensore perde ATK pari al danno inflitto effettivo
				defending_card.card_data.attack = max(0, defending_card.card_data.attack - damage_to_attacker - attacking_card.card_data.armour)
				defending_card.get_node("Attack").text = str(defending_card.card_data.attack)
				print("🩸 Retaliate: il difensore", defending_card.card_data.card_name, 
					  "ha perso", damage_to_attacker + attacking_card.card_data.armour, "ATK (ora:", defending_card.card_data.attack, ")")
					

				# ⚡️ Talento STUN
				if "Stun" in defending_card.card_data.get_all_talents() and damage_to_attacker > 0:
					if attacking_card.card_data.health > 0:
						defending_card.play_talent_icon_pulse("Stun")
						if not attacking_card.card_data.active_debuffs.has("Stunned"):
							print("🆕 Stun applicato da difensore", defending_card.card_data.card_name)
							attacking_card.stunned = true
							attacking_card.card_data.add_debuff(defending_card,"Stunned")
							attacking_card.stun_timer = 2
							attacking_card.update_debuff_icons()
						else:
							print("♻️ Stun rinnovato su attaccante", attacking_card.card_data.card_name)
							attacking_card.stunned = true
							attacking_card.play_debuff_icon_pulse("Stunned")
							attacking_card.stun_timer = 2
							
				# ⚡️ Talento FREEZE
				if "Freeze" in defending_card.card_data.get_all_talents() and damage_to_attacker > 0:
					if attacking_card.card_data.health > 0:
						defending_card.play_talent_icon_pulse("Freeze")
						if not attacking_card.card_data.active_debuffs.has("Frozen"):
							print("🆕 Freeze applicato da difensore", defending_card.card_data.card_name)
							attacking_card.frozen = true
							attacking_card.card_data.add_debuff(defending_card,"Frozen")
							attacking_card.freeze_timer = 1
							attacking_card.update_debuff_icons()
						else:
							print("♻️ Freeze rinnovato su attaccante", attacking_card.card_data.card_name)
							attacking_card.frozen = true
							attacking_card.play_debuff_icon_pulse("Frozen")
							attacking_card.freeze_timer = 1
					#player_creatures_that_retaliated_this_turn.append(defending_card)

					# 🔁 Aggiorna visuali
				attacking_card.update_card_visuals()
				defending_card.update_card_visuals()

				
			await get_tree().create_timer(0.4).timeout

		print("✅ Fine fase danni (Double Strike gestito automaticamente)")


		# 📣 [SIGNAL EMIT] direct_damage_fully_resolved (solo se c'è stato danno diretto tipo Overkill)
		if direct_damage_done > 0 and is_instance_valid(attacking_card):
			var damage_amount = direct_damage_done
			var damage_type = "direct_damage"
			print("📣 [SIGNAL EMIT] direct_damage_fully_resolved per", attacking_card.card_data.card_name,
				"→", damage_amount, "danni di tipo", damage_type)
			attacking_card.emit_signal("direct_damage_fully_resolved", attacking_card, damage_amount, damage_type)

		
		var attacker_destroyed = attacking_card.card_data.health == 0 or attacker_has_deathtouch_kill
		var defender_destroyed = defending_card.card_data.health == 0 or defender_has_deathtouch_kill


		if attacker_destroyed:
			destroy_card(attacking_card, "Player" if is_attacker else "Opponent")
		if defender_destroyed:
			destroy_card(defending_card, "Opponent" if is_attacker else "Player")
			
			
				# 🔁 Riporta indietro l'attaccante se ancora vivo
		if not attacker_destroyed:
			var tween_return = create_tween()
			tween_return.tween_property(attacking_card, "position", attacking_card.current_slot.position, DEFAULT_CARD_MOVE_SPEED_ATTACK)
			await tween_return.finished
			attacking_card.z_index = 0
	
		# 🔔 TRIGGER: When_Equipped_Destroys_by_Combat
		# === ATTACCANTE uccide DIFENSORE ===
		if defender_destroyed and defending_card.is_enemy_card():
			for equip_card in attacking_card.equipped_spells:
				if equip_card.card_data.effect_type_2 == "On_Trigger" \
				and equip_card.card_data.trigger_type_2 == "When_Equipped_Destroys_by_Combat":
					print("🔥 [EQUIP TRIGGER FROM KILL] ATTACCANTE →", equip_card.card_data.card_name)
					await $"../CardManager".trigger_card_effect(equip_card, true, attacking_card, 2)

		# === DIFENSORE uccide ATTACCANTE ===
		if attacker_destroyed and attacking_card.is_enemy_card():
			for equip_card in defending_card.equipped_spells:
				if equip_card.card_data.effect_type_2 == "On_Trigger" and equip_card.card_data.trigger_type_2 == "When_Equipped_Destroys_by_Combat":
					print("🔥 [EQUIP TRIGGER FROM KILL] DIFENSORE →", equip_card)
					await $"../CardManager".trigger_card_effect(equip_card, true, defending_card, 2)




	# 🔥 Pulisci il bordo rosso del difensore
	if defending_card.has_node("RedHighlightBorder"):
		defending_card.get_node("RedHighlightBorder").visible = false
	rpc("hide_red_border_on_card", defending_card.name)


	# 🔥 Spegni ActionBorder dell'attaccante
	if attacking_card.has_node("ActionBorder"):
		attacking_card.get_node("ActionBorder").visible = false
	rpc("hide_action_border_on_card", attacking_card.name)
	
	# 👇 Rimuovi overlay attacco
	remove_attack_overlay(attacking_card)
	rpc("hide_attack_overlay", attacking_card.name, multiplayer.get_unique_id())
	
		## 🔇 Spegnimento visivo bottoni RESOLVE e ENEMY RESOLVE
	$"../ActionButtons".hide_resolve_button()
	$"../ActionButtons".hide_enemy_response_buttons()
	$"../ActionButtons".force_hide_all_green_borders()
	
	already_chained_in_this_go_to_combat = false
	already_chained_in_this_go_to_damage_step = false
	attacking_card.attack_negated = false
	
	if chained_this_battle_step:
		print("🔁 Fine attacco normale → reset chained_this_battle_step = false")
		chained_this_battle_step = false

	if attacking_card:
		clear_combat_state(attacking_card)

	if defending_card:
		clear_combat_state(defending_card)
		
	recheck_combat_status()

	
	var other_player_id = multiplayer.get_peers()[0]
	rpc_id(other_player_id, "sync_chained_flags", false, false)
	
	# Dopo l'attacco
	if attacking_card.has_an_attack_target:
		print("SOPRAVVIVE attacking_card.has_an_attack_target = false ")
		attacking_card.has_an_attack_target = false

	if defending_card.is_being_attacked:
		if attacking_card in defending_card.being_attacked_by_cards:
			defending_card.being_attacked_by_cards.erase(attacking_card)
			print(" LOCAL Rimozione attacco di:", attacking_card.name)
		if defending_card.being_attacked_by_cards.size() == 0:
			print(" SOPRAVVIVE defending_card.is_being_attacked = false")
			defending_card.is_being_attacked = false

	var attacker_id = multiplayer.get_unique_id()
	var defender_id = multiplayer.get_peers()[0] if defending_card.is_enemy_card() else attacker_id
	rpc("sync_attack_flags", attacking_card.name, "", attacker_id, defender_id)  # "" cancella

	# 🧩 [ACTION CONSUME] — Passa l'azione solo dal peer attaccante
	if not "Free Strike" in attacking_card.card_data.get_all_talents():
		if multiplayer.get_unique_id() == player_id:
			var phase_manager = get_node_or_null("../PhaseManager")
			if phase_manager:
				var peers = multiplayer.get_peers()
				if peers.size() > 0:
					var other_id = peers[0]
					print("♻️ [Action Switch] Attacco completato → passo azione all’altro peer:", other_id)
					phase_manager.rpc("rpc_give_action", other_id, true)  # 👈 true = from_attack
					phase_manager.rpc_give_action(other_id, true)
	else:
		print("FREE STRIKE NON CONSUMO ACTION")
		attacking_card.play_talent_icon_pulse("Free Strike")
				
		
	$"../ActionButtons".rpc_show_pass_phase_button()

@rpc("any_peer")
func receive_retaliate_choice(wants_to_retaliate: bool) -> void:
	received_retaliate_choice_value = wants_to_retaliate
	emit_signal("retaliate_choice_received")

@rpc("any_peer")
func receive_resolve_choice():
	print("📨 receive_resolve_choice() su:", multiplayer.get_unique_id())
	emit_signal("resolve_choice_received")
	

	var my_id = multiplayer.get_unique_id()
	var last_card = effect_stack.back() if effect_stack.size() > 0 else null

	#var current_pos = effect_stack.size() - 1
	#var current_card = effect_stack[current_pos]
	#var previous_card = effect_stack[current_pos - 1]

	var action_buttons = $"../ActionButtons"

	# ✅ Skip se è appena stato premuto GO TO COMBAT
	if opponent_pressed_go_to_combat:
		#opponent_pressed_go_to_combat = false
		print("⏩ RESOLVE ignorato (GO TO COMBAT premuto)")
		var other_player_id = multiplayer.get_peers()[0]
		rpc_id(other_player_id, "receive_final_resolve_ack")
		emit_signal("final_resolve_ack_received")
		emit_signal("self_resolve_choice_finished")
		return

	# 🔍 Posso concatenare?
	var has_response := false
	for card in player_creatures_on_field + player_spells_on_field:
		if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
			has_response = true
			break

	if has_response and not chain_locked and last_card and last_card.player_id != my_id:  #last_card impedisce che io posso richainare ancora .
		
		action_buttons.show_resolve_button()
		await action_buttons.resolve_chosen
		action_buttons.hide_resolve_button()

		var other_player_id = multiplayer.get_peers()[0]
		rpc_id(other_player_id, "receive_final_resolve_ack")
		emit_signal("final_resolve_ack_received")
	else:
		#var my_id = multiplayer.get_unique_id()
		#var last_card = effect_stack.back() if effect_stack.size() > 0 else null
	#
		#var current_pos = effect_stack.size() - 1
		#var current_card = effect_stack[current_pos]
		#var previous_card = effect_stack[current_pos - 1]

		#if last_card and last_card.player_id == my_id and has_response and not chain_locked:  #penso che serva che chain non deve essere locked.
			#print("🟢 Ultima carta nella chain è mia e ho risposte → mostro RESOLVE per concatenare")
			#action_buttons.show_resolve_button()
			#await action_buttons.resolve_chosen
			#action_buttons.hide_resolve_button()

		#if chain_locked and current_card.player_id == previous_card.player_id:
			#print("🟢 Stoppo carta consecutiva")
			#action_buttons.show_resolve_button()
			#await action_buttons.resolve_chosen
			#action_buttons.hide_resolve_button()
			#var other_player_id = multiplayer.get_peers()[0]
			#rpc_id(other_player_id, "receive_final_resolve_ack")
			#emit_signal("final_resolve_ack_received")
		
			
		var other_player_id = multiplayer.get_peers()[0]
		rpc_id(other_player_id, "receive_final_resolve_ack")
		emit_signal("final_resolve_ack_received")
		

	emit_signal("self_resolve_choice_finished")
	if action_buttons.hourglass_icon:
		action_buttons.hourglass_icon.visible = false
		action_buttons.stop_hourglass_animation()

@rpc("any_peer")
func receive_final_resolve_ack():
	emit_signal("final_resolve_ack_received")

@rpc("any_peer")
func receive_to_damage_step_chosen():
	emit_signal("to_damage_step_chosen")
	
@rpc("any_peer")
func show_enemy_retaliate_visual():
	$"../ActionButtons".show_enemy_retaliate_button()

@rpc("any_peer")
func show_enemy_ok_visual():
	await get_tree().process_frame
	$"../ActionButtons".show_enemy_ok_button()
	
@rpc("any_peer")
func hide_enemy_response_buttons():
	$"../ActionButtons".hide_enemy_response_buttons()
#@rpc("any_peer")
#func apply_retaliate_damage_to_attacker(attacker_card_name: String, damage_amount: int) -> void:
	#var attacker_card = $"../CardManager".get_node_or_null(attacker_card_name)
	#if attacker_card == null:
		#attacker_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + attacker_card_name)
#
	#if attacker_card:
		#attacker_card.card_data.health = max(0, attacker_card.card_data.health - damage_amount)
		#attacker_card.get_node("Health").text = str(attacker_card.card_data.health)
		#attacker_card.update_card_visuals()
	#else:
		#push_error("❌ apply_retaliate_damage_to_attacker: carta non trovata: " + attacker_card_name)


@rpc("any_peer")
func show_red_border_on_card(card_name: String, owner_id: int):
	var local_id = multiplayer.get_unique_id()
	var card: Node = null

	if local_id == owner_id:
		card = $"../CardManager".get_node_or_null(card_name)
	else:
		card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card and card.card_is_in_slot and card.has_node("RedHighlightBorder"):
		#var red_border = card.get_node("RedHighlightBorder")
		#red_border.visible = true
		card.get_node("RedHighlightBorder").visible = true
		card.animate_red_border_pulse()

	else:
		print("❌ Red Border: carta non trovata o non valida:", card_name, "| Owner ID previsto:", owner_id)


@rpc("any_peer")
func hide_red_border_on_card(card_name: String):
	var card = $"../CardManager".get_node_or_null(card_name)

	if not card:
		card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card and card.has_node("RedHighlightBorder"):
		card.red_highlight_border.visible = false
		#if card.targeted_stack_count <= 1:
			#card.red_highlight_border.visible = false
			#print("🔻 Nascondo red border di", card.name)
		#else:
			#print("⛔ NON nascondo red border su", card.name, "perché target_count =", card.targeted_stack_count)
			#print("✅ card is Card:", card is Card)
			#print("✅ card class:", card.get_class())
			#print("✅ has_method animate_red_border_pulse:", card.has_method("animate_red_border_pulse"))
			#card.animate_red_border_pulse()
func tribute_card(card, card_owner, is_for_tribute_summ: bool = false):
	card.z_index = 0

	# ⛔ Uccidi tween red border se attivo
	if card.red_border_tween and is_instance_valid(card.red_border_tween):
		card.red_border_tween.kill()
		card.red_border_tween = null

	# Nascondi bordi e overlay
	if card.has_node("ActionBorder"):
		card.get_node("ActionBorder").visible = false
	if card.has_node("HighlightBorder"):
		card.get_node("HighlightBorder").visible = false
	if card.has_node("RedHighlightBorder"):
		card.get_node("RedHighlightBorder").visible = false
	if card.has_node("GreenHighlightBorder"):
		card.get_node("GreenHighlightBorder").visible = false
	if card.has_node("NextCardBuffedBorder"):
		card.get_node("NextCardBuffedBorder").visible = false
	remove_chain_overlay(card)

	if card.has_node("AttackOverlay"):
		card.get_node("AttackOverlay").queue_free()
		await get_tree().process_frame

	# Determina posizione GY
	var new_pos: Vector2
	if card_owner == "Player":
		new_pos = $"../PlayerGY".position
		card.get_node("Area2D/CollisionShape2D").disabled = true
		card.card_is_in_playerGY = true
		print("CARD MESSA IN GY A SEGUITO DI TRIBUTO,  card.card_is_in_playerGY =", card.card_is_in_playerGY)
		$"../PlayerGY".add_to_gy(card.card_data.make_runtime_copy())

		# Rimuovi da liste di campo
		if card in player_creatures_on_field:
			player_creatures_on_field.erase(card)
		if card in player_spells_on_field:
			player_spells_on_field.erase(card)
	else:
		new_pos = get_parent().get_parent().get_node("EnemyField/EnemyGY").position
		card.get_node("Area2D/CollisionShape2D").disabled = true
		card.card_is_in_playerGY = true
		print("CARD MESSA IN ENEMY GY A SEGUITO DI TRIBUTO → card.card_is_in_playerGY =", card.card_is_in_playerGY)
		get_parent().get_parent().get_node("EnemyField/EnemyGY").add_to_gy(card.card_data.make_runtime_copy())

		if card in opponent_creatures_on_field:
			opponent_creatures_on_field.erase(card)
		if card in opponent_spells_on_field:
			opponent_spells_on_field.erase(card)

	# 🧩 [BOUNCER CLEANUP] Se la carta era registrata nei trigger upkeep/endphase → rimuovila
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	if combat_manager:
		# --- Rimuovi da trigger_upkeep_cards ---
		for i in range(combat_manager.trigger_upkeep_cards.size() - 1, -1, -1):
			var entry = combat_manager.trigger_upkeep_cards[i]
			if entry.has("card") and entry.card == card:
				print("🧹 [BOUNCER CLEANUP] Rimuovo", card.card_data.card_name, "da trigger_upkeep_cards")
				combat_manager.trigger_upkeep_cards.remove_at(i)

		# --- Rimuovi da trigger_endphase_cards ---
		for i in range(combat_manager.trigger_endphase_cards.size() - 1, -1, -1):
			var entry = combat_manager.trigger_endphase_cards[i]
			if entry.has("card") and entry.card == card:
				print("🧹 [BOUNCER CLEANUP] Rimuovo", card.card_data.card_name, "da trigger_endphase_cards")
				combat_manager.trigger_endphase_cards.remove_at(i)

	# 🔗 Sgancia dallo slot
	if card.current_slot:
		var slot = card.current_slot
		slot.card_in_slot = null
		if slot.has_node("Area2D/CollisionShape2D"):
			slot.get_node("Area2D/CollisionShape2D").disabled = false
	card.current_slot = null
	card.card_is_in_slot = false

	clear_combat_state(card)
	recheck_combat_status()
	if card.has_an_attack_target:
		handle_forced_combat_end(card, "tributata")


	card.z_index = graveyard_z_index
	graveyard_z_index += 1
	
	# 🧩 Distruggi eventuali enchant legate
	if card.enchant_spells.size() > 0:
		for enchant_card in card.enchant_spells.duplicate():
			if is_instance_valid(enchant_card):
				print("💥 [ENCHANT LINK] Distruggo enchant legata:", enchant_card.card_data.card_name)
				var owner_enchant = "Player" if not enchant_card.is_enemy_card() else "Opponent"

				if combat_manager and combat_manager.has_method("remove_enchant_effects"):
					combat_manager.remove_enchant_effects(enchant_card, card)
				card.enchant_spells.erase(enchant_card)
				enchant_card.enchanted_to = null
				destroy_card(enchant_card, owner_enchant)

	# 🧩 Riduci durabilità equip legati
	if card.equipped_spells.size() > 0:
		for equip_card in card.equipped_spells.duplicate():
			if is_instance_valid(equip_card):
				equip_card.card_data.spell_duration -= 1
				equip_card.update_card_visuals()
				equip_card.equipped_to = null
				print("⚙️ [EQUIP LINK] Durability di ", equip_card.card_data.card_name, " ridotta a ", equip_card.card_data.spell_duration)
				if equip_card.card_data.spell_duration <= 0:
					var owner_equip = "Player" if not equip_card.is_enemy_card() else "Opponent"
					destroy_card(equip_card, owner_equip)

	# 🧩 Se la carta tributo era Enchant → rimuovi i suoi effetti
	if card.card_data.temp_effect == "Enchant" and card.enchanted_to and is_instance_valid(card.enchanted_to):
		var target = card.enchanted_to
		print("💥 Enchant", card.card_data.card_name, "tribuata → rimuovo effetti da", target.card_data.card_name)

		if combat_manager and combat_manager.has_method("remove_enchant_effects"):
			combat_manager.remove_enchant_effects(card, target)
		target.enchant_spells.erase(card)
		card.enchanted_to = null

	# 🧩 Se la carta tributo era Equip → rimuovi i suoi effetti
	if card.card_data.effect_type == "Equip" and card.equipped_to and is_instance_valid(card.equipped_to):
		var target = card.equipped_to
		print("💥 Equip", card.card_data.card_name, "tributata → rimuovo effetti da", target.card_data.card_name)

		# ✅ 1️⃣ PRIMA: cleanup While (usa ancora i buff)
		if target.card_data.trigger_type == "When_Equipped" \
		and target.card_data.temp_effect == "While":
			combat_manager.remove_while_effects_from_source(target, card)

		# ✅ 2️⃣ POI: rimozione completa equip (può distruggere tutto)
		if combat_manager and combat_manager.has_method("remove_equip_effects"):
			combat_manager.remove_equip_effects(card, target)

		# 3️⃣ Scollega riferimenti equip
		target.equipped_spells.erase(card)
		card.equipped_to = null

	# 🌀 Effetti generali post-rimozione
	if card.card_data.spell_duration == 1000: #se E' FIELD LA TOGLI
		remove_field_effects()
	handle_spellpower_on_destroy(card, card_owner)
	remove_aura_effects(card)
	if card.card_data.trigger_type.begins_with("While_"):
		print("💀 [WHILE LOST] Carta distrutta:", card.card_data.card_name, "→ emetto lost_while_condition")
		emit_signal("lost_while_condition", self)
	# 🔥 Animazione movimento nel GY
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_pos, DEFAULT_CARD_MOVE_SPEED)

	if card.rotation_degrees != 0:
		tween.parallel().tween_property(card, "rotation_degrees", 0, DEFAULT_CARD_MOVE_SPEED)

	if card.position_type == "facedown":
		var anim = card.get_node_or_null("AnimationPlayer")
		if anim:
			anim.play("card_flip")
		card.set_position_type("faceup")

	tween.parallel().tween_property(card, "modulate", Color(0.6, 0.6, 0.6, 1), DEFAULT_CARD_MOVE_SPEED)
	await tween.finished

	card.set_in_graveyard(true)

	# ♻️ Ripristina valori originali
	card.card_data.attack = card.card_data.original_attack
	card.card_data.health = card.card_data.original_health
	card.card_data.max_attack = card.card_data.original_attack
	card.card_data.max_health = card.card_data.original_health
	card.card_data.effect_magnitude_1 = card.card_data.original_effect_magnitude_1
	card.card_data.effect_magnitude_2 = card.card_data.original_effect_magnitude_2
	card.card_data.effect_magnitude_3 = card.card_data.original_effect_magnitude_3
	card.card_data.effect_magnitude_4 = card.card_data.original_effect_magnitude_4

	print("🔄 [TRIBUTE] Ripristino valori originali per", card.name, ": ATK =", card.card_data.attack, ", HP =", card.card_data.health)
	card.update_card_visuals()
	if not is_for_tribute_summ: # per eventuali effetti di sacrifice mentre ci sono centauri
		await get_tree().create_timer(0.3).timeout
	card.emit_signal("card_left_field", card, "tribute", is_for_tribute_summ)
	#notify_card_left_field_global(card, "tribute")


	
func apply_bouncer_effect(card: Node2D, card_owner: String, is_for_tribute_summ: bool = false) -> void:
	if not is_instance_valid(card):
		push_warning("⚠️ apply_bouncer_effect: target non valido.")
		return
		


	print("💫 [BOUNCER] Rimando in mano:", card.card_data.card_name)
	card.z_index = 0
	var new_pos: Vector2
	var hand_node

	# 🔍 Determina a chi appartiene
	if card_owner == "Player":
		hand_node = $"../PlayerHand"
	else:
		hand_node = get_parent().get_parent().get_node_or_null("EnemyField/EnemyHand")

	if not is_instance_valid(hand_node):
		push_warning("⚠️ apply_bouncer_effect: mano non trovata per " + card_owner)
		return

	# 🧹 Rimuovi eventuali icone di mana speso
	$"../CardManager".hide_spent_mana_icons(card)

	if card.red_border_tween and is_instance_valid(card.red_border_tween):
		card.red_border_tween.kill()
		card.red_border_tween = null
	# 🧹 Disattiva overlay e bordi visivi
	if card.has_node("ActionBorder"):
		card.get_node("ActionBorder").visible = false
	if card.has_node("HighlightBorder"):
		card.get_node("HighlightBorder").visible = false
	if card.has_node("RedHighlightBorder"):
		card.get_node("RedHighlightBorder").visible = false
	if card.has_node("GreenHighlightBorder"):
		card.get_node("GreenHighlightBorder").visible = false
	if card.has_node("NextCardBuffedBorder"):
		card.get_node("NextCardBuffedBorder").visible = false
		
	if effect_stack.size() <= 1:        # FIXA BUG CHE QUANDO ATTACCANTE MUORE NON SCOMPAIONO I REDBORDER
		# 🔁 Rimuovi RedHighlightBorder da tutte le carte sul campo (inline, senza funzione)
		for c in player_creatures_on_field:
			if c.has_node("RedHighlightBorder"):
				c.get_node("RedHighlightBorder").visible = false
		for c in player_spells_on_field:
			if c.has_node("RedHighlightBorder"):
				c.get_node("RedHighlightBorder").visible = false
		for c in opponent_creatures_on_field:
			if c.has_node("RedHighlightBorder"):
				c.get_node("RedHighlightBorder").visible = false
		for c in opponent_spells_on_field:
			if c.has_node("RedHighlightBorder"):
				c.get_node("RedHighlightBorder").visible = false
	
	remove_chain_overlay(card)
	# 👇 Rimuovi eventuale overlay d’attacco
	if card.has_node("AttackOverlay"):
		card.get_node("AttackOverlay").queue_free()
		await get_tree().process_frame
	# 🧩 Libera slot
	if card.current_slot:
		var slot = card.current_slot
		if slot.has_node("Area2D/CollisionShape2D"):
			slot.get_node("Area2D/CollisionShape2D").disabled = false
		slot.card_in_slot = null
		card.current_slot = null

	card.card_is_in_slot = false

	# 🔁 Rimuovi dalle liste di campo
	if card_owner == "Player":
		player_creatures_on_field.erase(card)
		player_spells_on_field.erase(card)
	else:
		opponent_creatures_on_field.erase(card)
		opponent_spells_on_field.erase(card)
	# 🧩 [BOUNCER CLEANUP] Se la carta era registrata nei trigger upkeep/endphase → rimuovila
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	if combat_manager:
		# --- Rimuovi da trigger_upkeep_cards ---
		for i in range(combat_manager.trigger_upkeep_cards.size() - 1, -1, -1):
			var entry = combat_manager.trigger_upkeep_cards[i]
			if entry.has("card") and entry.card == card:
				print("🧹 [BOUNCER CLEANUP] Rimuovo", card.card_data.card_name, "da trigger_upkeep_cards")
				combat_manager.trigger_upkeep_cards.remove_at(i)

		# --- Rimuovi da trigger_endphase_cards ---
		for i in range(combat_manager.trigger_endphase_cards.size() - 1, -1, -1):
			var entry = combat_manager.trigger_endphase_cards[i]
			if entry.has("card") and entry.card == card:
				print("🧹 [BOUNCER CLEANUP] Rimuovo", card.card_data.card_name, "da trigger_endphase_cards")
				combat_manager.trigger_endphase_cards.remove_at(i)

	# ⛔ Disattiva collisione temporaneamente
	if card.has_node("Area2D/CollisionShape2D"):
		card.get_node("Area2D/CollisionShape2D").disabled = true

	# 🧹 Pulisci stati di combat / targeting
	clear_combat_state(card)
	recheck_combat_status()
	if card.has_an_attack_target:
		print("AVEVA ATTACK TARGET")
		handle_forced_combat_end(card, "bouncered")  #NON ERA PRESENTE

	if card.is_being_targeted and card.being_targeted_by_cards.size() > 0:
		for source_card in card.being_targeted_by_cards:
			if source_card:
				source_card.has_a_target = false
		card.being_targeted_by_cards.clear()
		card.is_being_targeted = false

	# 🧩 Se ha enchant collegate → rimuovile e distruggile
	if card.enchant_spells.size() > 0:
		for enchant_card in card.enchant_spells.duplicate():
			if is_instance_valid(enchant_card):
				print("💥 [ENCHANT LINK] Rimuovo enchant legata:", enchant_card.card_data.card_name)
				var owner_enchant = "Player" if not enchant_card.is_enemy_card() else "Opponent"

				if combat_manager and combat_manager.has_method("remove_enchant_effects"):
					combat_manager.remove_enchant_effects(enchant_card, card)
				card.enchant_spells.erase(enchant_card)
				enchant_card.enchanted_to = null
				destroy_card(enchant_card, owner_enchant)


	# 🧩 Se la carta distrutta ha degli equip legati → riduci durabilità di ognuno
	if card.equipped_spells.size() > 0:
		for equip_card in card.equipped_spells.duplicate():
			if is_instance_valid(equip_card):
				equip_card.card_data.spell_duration -= 1
				equip_card.update_card_visuals()
						# 🔗 Scollega riferimenti equip
				equip_card.equipped_to = null
				print("⚙️ [EQUIP LINK] Durability di ", equip_card.card_data.card_name, " ridotta a ", equip_card.card_data.spell_duration)
				if equip_card.card_data.spell_duration <= 0:
					print("💥 Equip", equip_card.card_data.card_name, "si distrugge per durabilità 0")
					var owner_equip = "Player" if not equip_card.is_enemy_card() else "Opponent"
					destroy_card(equip_card, owner_equip)


	# 🧩 Se la carta distrutta è una Enchant → rimuovi completamente i suoi effetti dal target
	if card.card_data.temp_effect == "Enchant" and card.enchanted_to and is_instance_valid(card.enchanted_to):
		var target = card.enchanted_to
		print("💥 Enchant", card.card_data.card_name, "distrutta → rimuovo effetti da", target.card_data.card_name)


		if combat_manager and combat_manager.has_method("remove_enchant_effects"):
			combat_manager.remove_enchant_effects(card, target)

		# 🔗 Scollega riferimenti enchant
		target.enchant_spells.erase(card)
		card.enchanted_to = null

	# 🧩 Se la carta distrutta è una Equip → rimuovi completamente i suoi effetti dal target
	if card.card_data.effect_type == "Equip" and card.equipped_to and is_instance_valid(card.equipped_to):
		var target = card.equipped_to
		print("💥 Equip", card.card_data.card_name, "bouncerata → rimuovo effetti da", target.card_data.card_name)

		# ✅ 1️⃣ PRIMA: cleanup While (usa ancora i buff)
		if target.card_data.trigger_type == "When_Equipped" \
		and target.card_data.temp_effect == "While":
			combat_manager.remove_while_effects_from_source(target, card)

		# ✅ 2️⃣ POI: rimozione completa equip (può distruggere tutto)
		if combat_manager and combat_manager.has_method("remove_equip_effects"):
			combat_manager.remove_equip_effects(card, target)

		# 3️⃣ Scollega riferimenti equip
		target.equipped_spells.erase(card)
		card.equipped_to = null
	
	
	# 🔁 Se questa carta era bersagliata, resetta targeting anche via RPC
	if card.is_being_targeted and card.being_targeted_by_cards.size() > 0:
		for source_card in card.being_targeted_by_cards:
			if source_card:
				source_card.has_a_target = false  # ✅ AGGIUNGI QUI
				var source_owner_id = multiplayer.get_unique_id() if not source_card.is_enemy_card() else multiplayer.get_peers()[0]
				var target_owner_id = multiplayer.get_unique_id() if not card.is_enemy_card() else multiplayer.get_peers()[0]
				rpc("sync_targeting_flags", source_card.name, "", source_owner_id, target_owner_id)

		
		var names = []
		for c in card.being_targeted_by_cards:
			names.append(c.name)
		

		card.being_targeted_by_cards.clear()
		card.is_being_targeted = false

	# ✅ Rimuovi dal pulse stack solo se questa carta era presente (come oggetto, non placeholder)
	if not currently_targeted_cards.is_empty():
		var last = currently_targeted_cards.back()
		if typeof(last) != TYPE_DICTIONARY and last == card:
			var removed_card = currently_targeted_cards.pop_back()
			print("🧹 Rimossa dal pulse stack:", removed_card.name)

			# Mostra la nuova ultima carta, se c’è
			if not currently_targeted_cards.is_empty():
				var last_card = currently_targeted_cards.back()
				print("🔴 PULSE:", last_card.name, "è ORA l'ULTIMA in currently_targeted_cards → pulse!")
				if typeof(last_card) == TYPE_DICTIONARY:
					print("⚠️ Pulse su placeholder:", last_card["name"])
				else:
					last_card.animate_red_border_pulse()

			var remaining_names := []
			for c in currently_targeted_cards:
				remaining_names.append(c.name)
				print("📦 Pulse stack rimanente:", remaining_names)
		else:
			print("ℹ️ Carta distrutta NON era l’ultima nel pulse stack → nessun pop_back eseguito.")

	# Se questa carta stava attaccando altre carte, rimuovi l'attacco
	if card.has_an_attack_target:
		print(" CAZZOOOO card.has_an_attack_target = false")
		card.has_an_attack_target = false
	
	if card.is_being_attacked:
		print(" CAZZZOOOO  card.is_being_attacked = false")
		card.is_being_attacked = false


	# 🧹 Stacca la carta distrutta da tutte le aure attive prima di aggiornare SP o altri effetti
	print("🧹 [AURA DETACH] Controllo se", card.card_data.card_name, "è affetta da aure...")

	var all_auras = player_spells_on_field + opponent_spells_on_field

	for aura in all_auras:
		if not is_instance_valid(aura):
			continue
		if aura.card_data.effect_type != "Aura" or aura.card_data.card_class != "ContinuousSpell":
			continue
		if aura.aura_affected_cards.is_empty():
			continue

		for i in range(aura.aura_affected_cards.size() - 1, -1, -1):
			var entry = aura.aura_affected_cards[i]
			if typeof(entry) != TYPE_DICTIONARY or not entry.has("card"):
				continue

			var affected_card = entry.card
			if not is_instance_valid(affected_card):
				aura.aura_affected_cards.remove_at(i)
				continue

			if affected_card == card:
				print("⚠️ [AURA DETACH] Rimosso", card.card_data.card_name, "da", aura.card_data.card_name)
				aura.aura_affected_cards.remove_at(i)

				# Rimuovi buff/debuff derivanti da questa aura
				card.card_data.remove_debuff_by_source(aura)
				card.card_data.remove_buff_by_source(aura)

		# Se l’aura ha perso un target, aggiorna subito la grafica
		aura.update_card_visuals()
	if card.card_data.spell_duration == 1000: #se E' FIELD LA TOGLI
		remove_field_effects()
	handle_spellpower_on_destroy(card, card_owner)

	remove_aura_effects(card)
	# 🔄 RIPRISTINA VALORI BASE
	card.card_data.attack = card.card_data.original_attack
	card.card_data.health = card.card_data.original_health
	card.card_data.max_attack = card.card_data.original_attack
	card.card_data.max_health = card.card_data.original_health
	
	if card.card_data.trigger_type.begins_with("While_"):
		print("💀 [WHILE LOST] Carta distrutta:", card.card_data.card_name, "→ emetto lost_while_condition")
		emit_signal("lost_while_condition", self)   #NON ERA PRESENTE


	# 💫 Animazione in due fasi: verso il centro schermo, poi ritorno in mano
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 📍 Calcola il centro schermo sull’asse X
	var viewport_center_x = get_viewport().get_visible_rect().size.x / 2

	# 📍 Mantieni l’asse Y coerente con la mano (sopra per Player, sotto per Opponent)
	var intermediate_y = hand_node.position.y + (1000 if card_owner == "Player" else 50)
	var intermediate_pos = Vector2(viewport_center_x, intermediate_y)

	# 🌀 Fase 1: movimento verso il centro
	tween.tween_property(card, "position", intermediate_pos, DEFAULT_CARD_MOVE_SPEED)
	if card.rotation_degrees != 0:
		tween.parallel().tween_property(card, "rotation_degrees", 0, DEFAULT_CARD_MOVE_SPEED)

	# 🃏 Se torna al nemico → flippa facedown e nascondi labels / icone
	if card_owner == "Opponent":
		var anim = card.get_node_or_null("AnimationPlayer")
		if anim:
			anim.play("card_flip_to_facedown")

		# 🔕 Nascondi valori e icone visive
		if card.attack_label:
			card.attack_label.visible = false
		if card.health_label:
			card.health_label.visible = false
		if card.spell_multiplier_label:
			card.spell_multiplier_label.visible = false
		if card.spell_duration_label:
			card.spell_duration_label.visible = false

		# 🔒 Nascondi interamente talent_icons_container e icone al suo interno
		if is_instance_valid(card.talent_icons_container):
			card.talent_icons_container.visible = false
			for child in card.talent_icons_container.get_children():
				child.queue_free()  # 🔥 distrugge le icone invece di nasconderle

		var infinity_icon = card.get_node_or_null("InfinityIcon")
		if is_instance_valid(infinity_icon):
			infinity_icon.visible = false

	# 🔁 Riattiva collisione
	if card.has_node("Area2D/CollisionShape2D"):
		card.get_node("Area2D/CollisionShape2D").disabled = false


	card.emit_signal("card_left_field", card, "bouncer", is_for_tribute_summ)
	tween.parallel().tween_property(card, "scale", Vector2(1, 1), DEFAULT_CARD_MOVE_SPEED)
	await tween.finished
	
	# ⏳ Piccola pausa per rendere fluido il passaggio
	await get_tree().create_timer(0.05).timeout
	

	
	# 🧹 Rimuovi la carta dal parent attuale
	if card.get_parent():
		card.get_parent().remove_child(card)


	print("🧪 [BOUNCER DEBUG]")
	print(" - peer:", multiplayer.get_unique_id())
	print(" - card in tree?:", card.is_inside_tree())
	print(" - CardManager:", $"../CardManager")
	print(" - CardManager valid?:", is_instance_valid($"../CardManager"))
	# ♻️ Reinstanzia la carta nella mano del proprietario partendo dalla posizione centrale
	if card_owner == "Player":
		var card_scene = preload("res://Scene/Card.tscn")
		var new_card = card_scene.instantiate()
		new_card.hover_enabled = false
		$"../CardManager".add_child(new_card)
		new_card.name = "Card"
		new_card.card_unique_id = "%s_%d" % [card.card_data.card_name, randi()]

		# 👇 Partenza visiva: dal centro schermo
		new_card.position = intermediate_pos

		# 👇 Aggiungila alla mano (update_hand_positions la muoverà nel punto finale)
		$"../PlayerHand".add_card_to_hand(new_card, 0.0)
		new_card.set_card_data(card.card_data.make_runtime_copy())
		new_card.is_in_hand()
		print("♻️ [BOUNCER] Carta", card.card_data.card_name, "reinstanziata in mano Player")

	elif card_owner == "Opponent":
		var card_scene = preload("res://Scene/EnemyCard.tscn")
		var new_card = card_scene.instantiate()
		$"../CardManager".add_child(new_card)
		new_card.name = "OpponentCard"
		new_card.card_unique_id = "%s_%d" % [card.card_data.card_name, randi()]

		# 👇 Partenza visiva: dal centro schermo
		new_card.position = intermediate_pos
		

		get_parent().get_parent().get_node_or_null("EnemyField/EnemyHand").add_card_to_hand(new_card, 0.0)
		new_card.set_card_data(card.card_data.make_runtime_copy())
		new_card.is_in_hand()
		print("♻️ [BOUNCER] Carta", card.card_data.card_name, "reinstanziata in mano Opponent")

	# 🧹 Reset stato base
	card.is_in_hand()
	card.z_index = 20
	card.hover_enabled = true
	card.card_is_in_playerGY = false
	card.card_is_in_slot = false

	#card.set_visible_faceup()

	# 🔄 Ripristina valori originali
	card.card_data.attack = card.card_data.original_attack
	card.card_data.health = card.card_data.original_health
	card.card_data.max_attack = card.card_data.original_attack
	card.card_data.max_health = card.card_data.original_health
	card.card_data.effect_magnitude_1 = card.card_data.original_effect_magnitude_1
	card.card_data.effect_magnitude_2 = card.card_data.original_effect_magnitude_2
	card.card_data.effect_magnitude_3 = card.card_data.original_effect_magnitude_3
	card.card_data.effect_magnitude_4 = card.card_data.original_effect_magnitude_4
	card.update_card_visuals()

	print("✅ [BOUNCER] Carta", card.card_data.card_name, "tornata correttamente in mano di", card_owner)



	
	#notify_card_left_field_global(card, "bouncer")
	
func destroy_card(card, card_owner, is_for_tribute_summ: bool = false):
	
	card.z_index = 0
	
	print("🧩 DESTROY su:", card.name)
	print("   ➤ card path:", card.get_path())
	print("   ➤ in tree?:", card.is_inside_tree())
	print("   ➤ node_to_path:", get_node_or_null(card.get_path()))
	print("   ➤ owner:", card_owner)
		# 🧹 Rimuovi eventuali SpentManaIcons (per sicurezza)
	$"../CardManager".hide_spent_mana_icons(card)
	$"../CardManager".rpc("rpc_hide_spent_mana_on_card", card.name, card_owner)
	# ⛔ Uccidi tween red border se attivo
	if card.red_border_tween and is_instance_valid(card.red_border_tween):
		card.red_border_tween.kill()
		card.red_border_tween = null
#
	## ⛔ Nascondi subito il red border (evita blinking residui)
	#if card.has_node("RedHighlightBorder"):
		#card.get_node("RedHighlightBorder").visible = false
	
	var new_pos: Vector2
	
	if card.has_node("ActionBorder"):
		card.get_node("ActionBorder").visible = false
	if card.has_node("HighlightBorder"):
		card.get_node("HighlightBorder").visible = false
	if card.has_node("RedHighlightBorder"):
		card.get_node("RedHighlightBorder").visible = false
	if card.has_node("GreenHighlightBorder"):
		card.get_node("GreenHighlightBorder").visible = false
	if card.has_node("NextCardBuffedBorder"):
		card.get_node("NextCardBuffedBorder").visible = false
		
	if effect_stack.size() <= 1:        # FIXA BUG CHE QUANDO ATTACCANTE MUORE NON SCOMPAIONO I REDBORDER
		# 🔁 Rimuovi RedHighlightBorder da tutte le carte sul campo (inline, senza funzione)
		for c in player_creatures_on_field:
			if c.has_node("RedHighlightBorder"):
				c.get_node("RedHighlightBorder").visible = false
		for c in player_spells_on_field:
			if c.has_node("RedHighlightBorder"):
				c.get_node("RedHighlightBorder").visible = false
		for c in opponent_creatures_on_field:
			if c.has_node("RedHighlightBorder"):
				c.get_node("RedHighlightBorder").visible = false
		for c in opponent_spells_on_field:
			if c.has_node("RedHighlightBorder"):
				c.get_node("RedHighlightBorder").visible = false

		# 🔁 Fai la stessa cosa anche via RPC
		#rpc("rpc_hide_red_borders_on_all_cards")

	# 👇 Rimuovi eventuale overlay della chain
	remove_chain_overlay(card)
	# 👇 Rimuovi eventuale overlay d’attacco
	if card.has_node("AttackOverlay"):
		card.get_node("AttackOverlay").queue_free()
		await get_tree().process_frame
		
	
	if card_owner == "Player":
		new_pos = $"../PlayerGY".position
		card.get_node("Area2D/CollisionShape2D").disabled = true  #RICORDATI CHE SE PER CASO DEVE TORNAE IN MANO O IN CAMPO LO DEVI RIATTIVARE
		card.card_is_in_playerGY = true
		print("CARD MESSA IN GY,  card.card_is_in_playerGY =", card.card_is_in_playerGY)
		$"../PlayerGY".add_to_gy(card.card_data.make_runtime_copy())
		
		# Rimuovi da creature/spell
		if card in player_creatures_on_field:
			player_creatures_on_field.erase(card)
		elif card in player_spells_on_field:
			player_spells_on_field.erase(card)
		
	else: # Opponent
		new_pos = get_parent().get_parent().get_node("EnemyField/EnemyGY").position
		
		if card in opponent_creatures_on_field:
			opponent_creatures_on_field.erase(card)
		elif card in opponent_spells_on_field:
			opponent_spells_on_field.erase(card)
			
		card.get_node("Area2D/CollisionShape2D").disabled = true  #RICORDATI CHE SE PER CASO DEVE TORNAE IN MANO O IN CAMPO LO DEVI RIATTIVARE
		card.card_is_in_playerGY = true
		#card.set_in_graveyard(true)
		print("CARD MESSA IN ENEMY GY → card.card_is_in_playerGY =", card.card_is_in_playerGY)
		get_parent().get_parent().get_node("EnemyField/EnemyGY").add_to_gy(card.card_data.make_runtime_copy())


	# ✅ Salva una copia locale
	var slot = card.current_slot

	# Sgancia dallo slot
	if slot:
		slot.card_in_slot = null

		# ✅ Riattiva il collision shape dello slot
		if slot.has_node("Area2D/CollisionShape2D"):
			slot.get_node("Area2D/CollisionShape2D").disabled = false

	card.current_slot = null
	card.card_is_in_slot = false

	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	if combat_manager:
		# --- Rimuovi da trigger_upkeep_cards ---
		for i in range(combat_manager.trigger_upkeep_cards.size() - 1, -1, -1):
			var entry = combat_manager.trigger_upkeep_cards[i]
			if entry.has("card") and entry.card == card:
				print("🧹 [BOUNCER CLEANUP] Rimuovo", card.card_data.card_name, "da trigger_upkeep_cards")
				combat_manager.trigger_upkeep_cards.remove_at(i)

		# --- Rimuovi da trigger_endphase_cards ---
		for i in range(combat_manager.trigger_endphase_cards.size() - 1, -1, -1):
			var entry = combat_manager.trigger_endphase_cards[i]
			if entry.has("card") and entry.card == card:
				print("🧹 [BOUNCER CLEANUP] Rimuovo", card.card_data.card_name, "da trigger_endphase_cards")
				combat_manager.trigger_endphase_cards.remove_at(i)
	
	clear_combat_state(card)
	recheck_combat_status()
	if card.has_an_attack_target:
		handle_forced_combat_end(card, "destroyed")


	# 🧩 Se la carta distrutta ha delle Enchant legate → distruggile tutte
	if card.enchant_spells.size() > 0:
		for enchant_card in card.enchant_spells.duplicate():
			if is_instance_valid(enchant_card):
				print("💥 [ENCHANT LINK] Distruggo enchant legata:", enchant_card.card_data.card_name)
				var owner_enchant = "Player" if not enchant_card.is_enemy_card() else "Opponent"

				# Rimuovi gli effetti dell’enchant dal target (cioè dalla carta distrutta)
				
				if combat_manager and combat_manager.has_method("remove_enchant_effects"):
					combat_manager.remove_enchant_effects(enchant_card, card)

				# 🔗 Scollega riferimenti reciproci
				card.enchant_spells.erase(enchant_card)
				enchant_card.enchanted_to = null

				# 🔥 Distruggi effettivamente la enchant
				destroy_card(enchant_card, owner_enchant)

	# 🧩 Se la carta distrutta ha degli equip legati → riduci durabilità di ognuno
	if card.equipped_spells.size() > 0:
		for equip_card in card.equipped_spells.duplicate():
			if is_instance_valid(equip_card):
				equip_card.card_data.spell_duration -= 1
				equip_card.update_card_visuals()
						# 🔗 Scollega riferimenti equip
				equip_card.equipped_to = null
				print("⚙️ [EQUIP LINK] Durability di ", equip_card.card_data.card_name, " ridotta a ", equip_card.card_data.spell_duration)
				if equip_card.card_data.spell_duration <= 0:
					print("💥 Equip", equip_card.card_data.card_name, "si distrugge per durabilità 0")
					var owner_equip = "Player" if not equip_card.is_enemy_card() else "Opponent"
					destroy_card(equip_card, owner_equip)
					
	# 🧩 Se la carta distrutta è una Enchant → rimuovi completamente i suoi effetti dal target
	if card.card_data.temp_effect == "Enchant" and card.enchanted_to and is_instance_valid(card.enchanted_to):
		var target = card.enchanted_to
		print("💥 Enchant", card.card_data.card_name, "distrutta → rimuovo effetti da", target.card_data.card_name)

		
		if combat_manager and combat_manager.has_method("remove_enchant_effects"):
			combat_manager.remove_enchant_effects(card, target)

		# 🔗 Scollega riferimenti enchant
		target.enchant_spells.erase(card)
		card.enchanted_to = null

	# 🧩 Se la carta distrutta è una Equip → rimuovi completamente i suoi effetti dal target
	if card.card_data.effect_type == "Equip" and card.equipped_to and is_instance_valid(card.equipped_to):
		var target = card.equipped_to
		print("💥 Equip", card.card_data.card_name, "distrutta → rimuovo effetti da", target.card_data.card_name)

		# ✅ 1️⃣ PRIMA: cleanup While (usa ancora i buff)
		if target.card_data.trigger_type == "When_Equipped" \
		and target.card_data.temp_effect == "While":
			combat_manager.remove_while_effects_from_source(target, card)

		# ✅ 2️⃣ POI: rimozione completa equip (può distruggere tutto)
		if combat_manager and combat_manager.has_method("remove_equip_effects"):
			combat_manager.remove_equip_effects(card, target)

		# 3️⃣ Scollega riferimenti equip
		target.equipped_spells.erase(card)
		card.equipped_to = null

		
		
	# Muovi nel GY corretto
	card.z_index = graveyard_z_index
	graveyard_z_index += 1
	


	# 🔁 Se questa carta era bersagliata, resetta targeting anche via RPC
	if card.is_being_targeted and card.being_targeted_by_cards.size() > 0:
		for source_card in card.being_targeted_by_cards:
			if source_card:
				source_card.has_a_target = false  # ✅ AGGIUNGI QUI
				var source_owner_id = multiplayer.get_unique_id() if not source_card.is_enemy_card() else multiplayer.get_peers()[0]
				var target_owner_id = multiplayer.get_unique_id() if not card.is_enemy_card() else multiplayer.get_peers()[0]
				rpc("sync_targeting_flags", source_card.name, "", source_owner_id, target_owner_id)

		
		var names = []
		for c in card.being_targeted_by_cards:
			names.append(c.name)
		

		card.being_targeted_by_cards.clear()
		card.is_being_targeted = false

	# ✅ Rimuovi dal pulse stack solo se questa carta era presente (come oggetto, non placeholder)
	if not currently_targeted_cards.is_empty():
		var last = currently_targeted_cards.back()
		if typeof(last) != TYPE_DICTIONARY and last == card:
			var removed_card = currently_targeted_cards.pop_back()
			print("🧹 Rimossa dal pulse stack:", removed_card.name)

			# Mostra la nuova ultima carta, se c’è
			if not currently_targeted_cards.is_empty():
				var last_card = currently_targeted_cards.back()
				print("🔴 PULSE:", last_card.name, "è ORA l'ULTIMA in currently_targeted_cards → pulse!")
				if typeof(last_card) == TYPE_DICTIONARY:
					print("⚠️ Pulse su placeholder:", last_card["name"])
				else:
					last_card.animate_red_border_pulse()

			var remaining_names := []
			for c in currently_targeted_cards:
				remaining_names.append(c.name)
				print("📦 Pulse stack rimanente:", remaining_names)
		else:
			print("ℹ️ Carta distrutta NON era l’ultima nel pulse stack → nessun pop_back eseguito.")

	# Se questa carta stava attaccando altre carte, rimuovi l'attacco
	if card.has_an_attack_target:
		print(" CAZZOOOO card.has_an_attack_target = false")
		card.has_an_attack_target = false
	
	if card.is_being_attacked:
		print(" CAZZZOOOO  card.is_being_attacked = false")
		card.is_being_attacked = false


	# 🧹 Stacca la carta distrutta da tutte le aure attive prima di aggiornare SP o altri effetti
	print("🧹 [AURA DETACH] Controllo se", card.card_data.card_name, "è affetta da aure...")

	var all_auras = player_spells_on_field + opponent_spells_on_field

	for aura in all_auras:
		if not is_instance_valid(aura):
			continue
		if aura.card_data.effect_type != "Aura" or aura.card_data.card_class != "ContinuousSpell":
			continue
		if aura.aura_affected_cards.is_empty():
			continue

		for i in range(aura.aura_affected_cards.size() - 1, -1, -1):
			var entry = aura.aura_affected_cards[i]
			if typeof(entry) != TYPE_DICTIONARY or not entry.has("card"):
				continue

			var affected_card = entry.card
			if not is_instance_valid(affected_card):
				aura.aura_affected_cards.remove_at(i)
				continue

			if affected_card == card:
				print("⚠️ [AURA DETACH] Rimosso", card.card_data.card_name, "da", aura.card_data.card_name)
				aura.aura_affected_cards.remove_at(i)

				# Rimuovi buff/debuff derivanti da questa aura
				card.card_data.remove_debuff_by_source(aura)
				card.card_data.remove_buff_by_source(aura)

		# Se l’aura ha perso un target, aggiorna subito la grafica
		aura.update_card_visuals()
	if card.card_data.spell_duration == 1000: #se E' FIELD LA TOGLI
		remove_field_effects()

	handle_spellpower_on_destroy(card, card_owner)

	remove_aura_effects(card)
	if card.card_data.trigger_type.begins_with("While_"):
		print("💀 [WHILE LOST] Carta distrutta:", card.card_data.card_name, "→ emetto lost_while_condition")
		emit_signal("lost_while_condition", self)

	
	# 🔥 Se era in difesa (ruotata 90°), riportala in posizione dritta
	# 🔥 Quando distruggi: movimento + raddrizzamento + scopertura INSIEME
	var tween = get_tree().create_tween()

	# 📦 Mixa tutto nel movimento
	tween.tween_property(card, "position", new_pos, DEFAULT_CARD_MOVE_SPEED)

	if card.rotation_degrees != 0:
		tween.parallel().tween_property(card, "rotation_degrees", 0, DEFAULT_CARD_MOVE_SPEED)

	if card.position_type == "facedown":
		var anim = card.get_node_or_null("AnimationPlayer")
		if anim:
			anim.play("card_flip")
		card.set_position_type("faceup")  # rende visibile il fronte della carta

# ⚫ Scurisci ma mantieni i dettagli visibili
	tween.parallel().tween_property(card, "modulate", Color(0.6, 0.6, 0.6, 1), DEFAULT_CARD_MOVE_SPEED)
			
	await tween.finished
	card.set_in_graveyard(true)
	
	card.card_data.attack = card.card_data.original_attack
	card.card_data.health = card.card_data.original_health
	card.card_data.max_attack = card.card_data.original_attack
	card.card_data.max_health = card.card_data.original_health
	card.card_data.effect_magnitude_1 = card.card_data.original_effect_magnitude_1
	card.card_data.effect_magnitude_2 = card.card_data.original_effect_magnitude_2
	card.card_data.effect_magnitude_3 = card.card_data.original_effect_magnitude_3
	card.card_data.effect_magnitude_4 = card.card_data.original_effect_magnitude_4
	print("🔄 Ripristino valori originali per", card.name, ": ATK =", card.card_data.attack, ", HP =", card.card_data.health)
	card.update_card_visuals()

	await get_tree().create_timer(0.3).timeout
	card.emit_signal("card_left_field", card, "destruction", is_for_tribute_summ)
	#notify_card_left_field_global(card, "destruction")


func _get_spellpower_targets(t_sub: String, card_owner: String) -> Dictionary:
	var apply_to_player = false
	var apply_to_enemy = false

	match t_sub:
		"SelfPlayer":
			if card_owner == "Player":
				apply_to_player = true
			else:
				apply_to_enemy = true
		"EnemyPlayer":
			if card_owner == "Player":
				apply_to_enemy = true
			else:
				apply_to_player = true
		"BothPlayers", "None":
			apply_to_player = true
			apply_to_enemy = true

	return {
		"player": apply_to_player,
		"enemy": apply_to_enemy
	}
	
@rpc("any_peer")
func notify_opponent_pressed_go_to_combat():
	opponent_pressed_go_to_combat = true
	print("🔁 [SYNC] opponent_pressed_go_to_combat ricevuto = true")
	var action_buttons = $"../ActionButtons"
	action_buttons.emit_signal("go_to_combat_chosen")  #AGGIUNTO PER FIXARE BUG ATTACCKI DIRETTI DOPO CHAIN CHE NON ASPETTAVANO SU ATTACKER CLIENT

@rpc("any_peer")
func notify_opponent_pressed_to_damage_step():
	print("📩 RPC ricevuto: opponent ha premuto TO DAMAGE STEP")
	attacker_pressed_to_damage_step = true
	
#func remove_untriggered_spells():
	#var spells_to_remove = []
	#for card in player_spells_on_field:
		#if card.card_data.card_class != "ContinuousSpell" and not card.effect_triggered_this_turn:
			#spells_to_remove.append(card)
#
	#for spell_card in spells_to_remove:
		#player_spells_on_field.erase(spell_card)
		#destroy_card(spell_card, "Player")
@rpc("any_peer")
func destroy_spell_card_on_both_sides(card_name: String, player_id):
	var card

	var is_attacker = multiplayer.get_unique_id() == player_id

	if is_attacker:
		# Noi siamo chi ha distrutto
		card = $"../CardManager".get_node_or_null(card_name)
	else:
		# Noi siamo chi vede il nemico che distrugge
		card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card:
		destroy_card(card, "Player" if is_attacker else "Opponent")
	else:
		push_error("❌ Non trovato spell da distruggere:", card_name)

func remove_untriggered_spells():
	var spells_to_remove = []
	for card in player_spells_on_field:
		# 🚫 NON distruggere se è una ContinuousSpell o equip
		if card.card_data.card_class == "ContinuousSpell":
			continue

		if card.card_data.card_class == "EquipSpell":
			continue
		# 🚫 NON distruggere se è coperta
		if card.position_type == "facedown":
			continue

		# ✅ Distruggiamo solo spell non continue e non coperte, che non hanno triggerato
		if not card.effect_triggered_this_turn:
			spells_to_remove.append(card)

	for spell_card in spells_to_remove:
		player_spells_on_field.erase(spell_card)
		var player_id = multiplayer.get_unique_id()
		rpc("destroy_spell_card_on_both_sides", spell_card.name, player_id)
		destroy_card(spell_card, "Player")

#func apply_effect_to_card(card, effect: String, magnitude: int):
	#match effect:
		#"Damage":
			#card.card_data.health = max(0, card.card_data.health - magnitude)
		#"Destroy":
			#var owner = "Player" if not card.is_enemy_card() else "Opponent"
			#destroy_card(card, owner)
		#"Buff":
			#card.card_data.attack += magnitude
			#card.card_data.health += magnitude
		#"Heal":
			#card.card_data.health += magnitude
		#_:
			#print("⚠️ Effetto non riconosciuto:", effect)
#
	#card.update_card_visuals()
	## 🔥 Subito aggiorna i dati via RPC
	#$"../CombatManager".rpc("update_card_stats", card.name, card.card_data.attack, card.card_data.health)
	
#
#@rpc("any_peer")
#func update_card_stats(card_name: String, new_attack: int, new_health: int):
	#var card = $"../CardManager".get_node_or_null(card_name)
	#if not card:
		#card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)
	#
	#if card:
		#card.card_data.attack = new_attack
		#card.card_data.health = new_health
		#card.update_card_visuals()
#
		## 🔥 Nuovo: se HP arriva a 0, distruggiamo
		#if card.card_data.health == 0:
			#var owner = "Player" if not card.is_enemy_card() else "Opponent"
			#destroy_card(card, owner)


#func apply_effect_to_player(player: String, effect: String, magnitude: int):
	#if effect == "GainLP":
		#if player == "Player":
			#player_LP += magnitude
			#$"../PlayerLP".text = str(player_LP)
		#else:
			#enemy_LP += magnitude
			#get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)
#
	#elif effect == "Damage":
		#if player == "Player":
			#player_LP = max(0, player_LP - magnitude)
			#$"../PlayerLP".text = str(player_LP)
		#else:
			#enemy_LP = max(0, enemy_LP - magnitude)
			#get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)
	#else:
		#print("⚠️ Effetto non valido per il giocatore:", effect)

	
	
func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout



func continue_chain_after_resolve(resolved_card_index: int, simulate_resolve : bool):
	print("🔁 Risoluzione completata per chain_position:", resolved_card_index)

	if not just_targeted_creature.is_empty():
		print("🧹 [Risolta una carta] Pulizia just_targeted_creature (nuova fase)")
		just_targeted_creature.clear()
	# ✅ Trova e salva il player_id + stato "was_enchained" prima di rimuovere
	var resolved_player_id = -1
	var resolved_card_name = ""
	var was_enchained_resolved := false
	var resolved_has_keep_going := false
	for e in effect_stack:
		if e.chain_position == resolved_card_index:
			resolved_player_id = e.player_id
			resolved_card_name = e.card_name
			if e.has("was_enchained"):
				was_enchained_resolved = e.was_enchained
			if e.has("has_keep_going"):
				resolved_has_keep_going = e["has_keep_going"]
			break

	print("🔁 Carta risolta:", resolved_card_name,
	"| was_enchained =", was_enchained_resolved,
	"| keep_going =", resolved_has_keep_going)

	# 🧹 Rimuovi overlay e la carta risolta dallo stack
	for i in effect_stack.size():
		if effect_stack[i].chain_position == resolved_card_index:
			# 🔥 Pulizia overlay prima della rimozione
			var card_node: Node2D = null
			if multiplayer.get_unique_id() == resolved_player_id:
				card_node = $"../CardManager".get_node_or_null(resolved_card_name)
			else:
				card_node = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + resolved_card_name)

			remove_chain_overlay(card_node)
			effect_stack.remove_at(i)

			# ✨ Aggiorna glow dopo la rimozione
			update_chain_glow()
			
			# ♻️ Reset flag was_enchained
			if card_node and is_instance_valid(card_node):
				if card_node.was_enchained:
					card_node.was_enchained = false
					print("♻️ Reset was_enchained = false per carta risolta:", card_node.name)

			break
	

	
	# 👇 Ricalcolo consecutive cards
	#if effect_stack.size() >= 2:
		#var last = effect_stack[effect_stack.size() - 1]
		#var second_last = effect_stack[effect_stack.size() - 2]
		#if last.player_id == second_last.player_id:
			#print("🔁 Consecutive cards ancora presenti dopo rimozione")
			#is_consecutive_cards = true
			#rpc("sync_is_consecutive_cards", true)
		#else:
			#is_consecutive_cards = false
			#rpc("sync_is_consecutive_cards", false)
	#else:
		#is_consecutive_cards = false
		#rpc("sync_is_consecutive_cards", false)
	

	print("📉 Stack aggiornato dopo rimozione:")
	for e in effect_stack:
		print("- Card:", e.card_name, "| Player:", e.player_id, "| Pos:", e.chain_position)

	print("📦 Carte rimanenti nello stack:", effect_stack.size())

	current_chain_position -= 1
	if current_chain_position < -1:
		current_chain_position = -1
	print("🔢 [DECREMENT] current_chain_position ora è:", current_chain_position)

	# 🔍 DEBUG prima della decisione
	print("📣 [CHAIN] Io sono:", multiplayer.get_unique_id(), "| Resolved era di:", resolved_player_id)
#
	# ⚠️ Solo il player che ha appena risolto decide cosa succede dopo
	if multiplayer.get_unique_id() != resolved_player_id:
		print("⛔ Non sono il risolutore della carta appena rimossa → esco.")

		# ✅ Se è l'ultimo chain link (posizione 0), invia comunque l'ACK finale per chiudere la chain
		if current_chain_position == 0: # EVITA LA CHIAMATA RESOLVE A FINE CHAIN.
			print("🟢 Ultimo chain link risolto da altro peer → invio comunque ACK finale.")
			var other_player_id = multiplayer.get_peers()[0]
			rpc_id(other_player_id, "receive_final_resolve_ack")
			emit_signal("final_resolve_ack_received")

		return

	# ✅ Se ci sono ancora carte nella chain, trova il prossimo player
	if effect_stack.size() > 0:
		print("🔍 Prossima posizione nella chain:", current_chain_position)

		var next_card_array = effect_stack.filter(func(e): return e.chain_position == current_chain_position)

		if next_card_array.is_empty():
			print("⚠️ Nessuna carta trovata per chain_position:", current_chain_position)
			return

		var next_card = next_card_array[0]
		var next_player_id = next_card.player_id

		var local_id = multiplayer.get_unique_id()
		

		# Verifica se la prossima carta da risolvere è ancora valida
		var next_card_node = null
		if multiplayer.get_unique_id() == next_player_id:
			next_card_node = $"../CardManager".get_node_or_null(next_card.card_name)
		else:
			next_card_node = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + next_card.card_name)

		simulate_resolve = (
			not next_card_node
			or not next_card_node.card_is_in_slot
			#or next_card_node.effect_negated
			#or (next_card_node.card_data.targeting_type == "Targeted" and not next_card_node.has_a_target)
		)
		


		#if local_id == next_player_id:
			#print("⏳ È la mia carta nella chain → aspetto che l'altro giochi o passi")
			## Mostra solo visivamente al giocatore NON attivo (cioè non next_player_id)
			#var other_player_id = multiplayer.get_peers()[0]
			##$"../ActionButtons".show_resolve_button()
			##rpc_id(other_player_id, "show_enemy_resolve_button")  # 👈 mostra solo visivamente
			#rpc_id(other_player_id, "receive_resolve_choice")  # 👈 fa apparire RESOLVE vero
		#else:
			#print("🟢 È il mio turno → mostro il bottone RESOLVE per posizione", current_chain_position)
			#$"../ActionButtons".show_resolve_button()
		if not simulate_resolve:
			# 🔎 Se siamo sull'ultima carta della chain (posizione 0), salta la richiesta di Resolve
			if local_id == next_player_id:
				if current_chain_position == 0:
					print("⚡ LOCAL [AUTO-RESOLVE] Ultimo nodo della chain → emetto direttamente resolve_chosen senza bottone.")
					var action_buttons = $"../ActionButtons"
					action_buttons.emit_signal("resolve_chosen")
					# Prosegui immediatamente come se l’avessi premuto
					var other_player_id = multiplayer.get_peers()[0]
					rpc_id(other_player_id, "receive_final_resolve_ack")
					emit_signal("final_resolve_ack_received")
				else:
					print("⏳ È la mia carta nella chain → aspetto che l'altro giochi o passi")
					var other_player_id = multiplayer.get_peers()[0]
					rpc_id(other_player_id, "receive_resolve_choice")
			else:
				if current_chain_position == 0:
					print("⚡ ALTRO PLAYER [AUTO-RESOLVE] Ultimo nodo della chain → emetto direttamente resolve_chosen senza bottone.")
					var action_buttons = $"../ActionButtons"
					action_buttons.emit_signal("resolve_chosen")
					# Prosegui immediatamente come se l’avessi premuto
					var other_player_id = multiplayer.get_peers()[0]
					rpc_id(other_player_id, "receive_final_resolve_ack")
					emit_signal("final_resolve_ack_received")
				else:
					print("🟢 È il mio turno → mostro il bottone RESOLVE per posizione", current_chain_position)
					$"../ActionButtons".show_resolve_button()
		else:
			if local_id == next_player_id:
				print("⏳ La mia carta non c'e' piu' aspetto simulazione segnali")
				var other_player_id = multiplayer.get_peers()[0]
				rpc_id(other_player_id, "receive_resolve_choice")
			else:
				print("⛔ Skip RESOLVE: source_card fuori dal campo o negata perche' SIMULO RESOLVE = TRUE")
				simulate_resolve = false
				# 🔁 Simula resolve dopo 1 frame, così chi è in await ha il tempo di partire
				await wait(1.0)
				# Simula direttamente il passo successivo
				var other_player_id = multiplayer.get_peers()[0]
								# 🔔 Sincronizza il decremento su entrambi
				#rpc_id(other_player_id,"rpc_decrement_chain_position")

				rpc_id(other_player_id, "receive_resolve_choice") #IMPORTANTE PER SIMULAZIONE
				rpc_id(other_player_id, "receive_final_resolve_ack")
				emit_signal("final_resolve_ack_received")
				await continue_chain_after_resolve(current_chain_position, simulate_resolve)




	else:
		# ✅ La chain è completamente vuota
		chain_locked = false
		current_chain_index = 0
		current_chain_position = -1
		print("✅ Catena completata, RESET LOCALE chain position: ", current_chain_position)

		# 🌀 Dopo fine chain, se esiste un'azione pending, passala ora
		if pending_action_after_chain and not was_enchained_resolved and not resolved_has_keep_going:
			var phase_manager = get_node_or_null("../PhaseManager")
			if phase_manager and pending_action_owner_id == multiplayer.get_unique_id():
				# 🚫 Se l'ultima action proveniva da un attacco, NON ripassare
				if not phase_manager.last_action_from_attack:
					var peers = multiplayer.get_peers()
					if peers.size() > 0:
						var other_id = peers[0]
						print("✅ [CHAIN END] Passo ora l’azione post-chain all’altro peer:", other_id)
						phase_manager.rpc("rpc_give_action", other_id)
						phase_manager.rpc_give_action(other_id)
				else:
					print("🚫 [CHAIN END] Non passo l’azione perché proveniva già da un attacco.")
					phase_manager.last_action_from_attack = false  # reset flag dopo il check
			pending_action_after_chain = false
			pending_action_owner_id = -1
		elif was_enchained_resolved:
			print("🚫 Skip give_action: la carta risolta era ENCHAINED.")
			pending_action_after_chain = false
			
			
		# 💣 Distruzione post-chain
		if not cards_to_destroy_after_chain.is_empty():
			print("💥 [POST-CHAIN] Carte da distruggere dopo risoluzione della chain:")
			for c in cards_to_destroy_after_chain:
				if is_instance_valid(c):
					var owner = "Player" if not c.is_enemy_card() else "Opponent"
					print("   ➤ Distruggo ora:", c.name, "(owner:", owner, ")")
					destroy_card(c, owner)
				else:
					print("   ⚠️ Carta non più valida:", c)
			cards_to_destroy_after_chain.clear()
		# ✅ Svuota pulse stack RESET DI SICUREZZA 
		if not currently_targeted_cards.is_empty():
			var names := []
			for c in currently_targeted_cards:
				if typeof(c) == TYPE_DICTIONARY:
					names.append(c.get("name", "???"))
				else:
					names.append(c.name)
			print("🧹 Reset pulse stack: rimossi", names.size(), "elementi:", names)
			currently_targeted_cards.clear()
		else:
			print("📭 Pulse stack già vuoto.")

		var other_player_id = multiplayer.get_peers()[0]
		check_and_restore_waiting_buttons()
		rpc_id(other_player_id, "check_and_restore_waiting_buttons")
		rpc_id(other_player_id, "rpc_reset_chain_status")
		await get_tree().process_frame
				## 🧹 PULIZIA STATO COMBATTIMENTO — anche se carte non sono morte
		#for card in player_creatures_on_field + opponent_creatures_on_field:
			#if is_instance_valid(card):
				#clear_combat_state(card)
		

	simulate_resolve = false
	var other_player_id = multiplayer.get_peers()[0]
	rpc_id(other_player_id, "sync_simulate_resolve_flag", false)
	print("Ho mandato i segnali simulati RESOLVE")
	print("Ho reimpostato SIMULATE RESOLVE a FALSE")
	
	print("DEBUG CHECK — effect_stack.size():", effect_stack.size())
	print("DEBUG CHECK — cards_waiting_for_go_to_combat:", cards_waiting_for_go_to_combat)
	print("DEBUG CHECK — cards_waiting_for_to_damage_step:", cards_waiting_for_to_damage_step)

##POTREBBE SERVIRE MA PROVIAMO A TOGLIERLO MAGARI CAUSA IL BUG DI ATTACKER MORTO
	#var any_combat_in_progress := false
	#for card in player_creatures_on_field + opponent_creatures_on_field:
		#if card.has_an_attack_target or card.is_being_attacked:
			#print("⚠️ Combattimento ancora in corso su carta:", card)
			#any_combat_in_progress = true
			#break

	print("DEBUG CHECK — any_combat_in_progress:", any_combat_in_progress)

	#if not any_combat_in_progress and $"../CombatManager".effect_stack.is_empty():
		#print("✅ Nessun combattimento attivo e chain finita → riattivo PASS PHASE")
		#$"../ActionButtons".rpc_show_pass_phase_button()  # Mostra su locale
#
		#
		#rpc_id(other_player_id, "rpc_show_pass_phase_button")  # Mostra su remoto

@rpc("any_peer")
func check_and_restore_waiting_buttons():
	var local_id = multiplayer.get_unique_id()
	var action_buttons = $"../ActionButtons"
	var other_player_id = multiplayer.get_peers()[0]


	if effect_stack.size() == 0 and chain_locked:
		print("✅ RESET: chain_locked = false")
		chain_locked = false

	# --- GO TO COMBAT ---
	for entry in cards_waiting_for_go_to_combat:
		var card = entry.card
		var invalid: bool = (
			card == null
			or not card.card_is_in_slot
			or card.attack_negated
		)

		if entry.player_id == local_id:
			if invalid:
				await wait(1.0)
				print("⛔ [GTC] Carta mia non valida → simulo GO TO COMBAT localmente")
				notify_opponent_pressed_go_to_combat()
				receive_resolve_choice()
				$"../ActionButtons".hide_enemy_response_buttons()
				$"../ActionButtons".force_hide_all_green_borders()
		else:
			if invalid:
				await wait(1.0)
				print("⛔ [GTC] Carta nemico non valida → simulo GO TO COMBAT via RPC")
				rpc_id(entry.player_id, "notify_opponent_pressed_go_to_combat")
				rpc_id(entry.player_id, "receive_resolve_choice")
				$"../ActionButtons".hide_enemy_response_buttons()
				$"../ActionButtons".force_hide_all_green_borders()
			else:
				already_chained_in_this_go_to_combat = true
				print("🟢 [GTC] Mostro bottone GO TO COMBAT per carta nemica valida:", card.name)
				await wait(0.2)
				action_buttons.on_go_to_combat_pressed() #AUTOMATIZZA IL CLICK quando riappare il gtc( NON SERVE NEANCHE MOSTRARE IL BUTTON )
				#action_buttons.show_go_to_combat_button()
				action_buttons.hide_label(action_buttons.enchain_label)
				action_buttons.force_hide_all_green_borders()

				gtc_shown = true
				print("✅ [LOCAL] gtc_shown settato a TRUE su peer ", multiplayer.get_unique_id())
				# 🔥 notifico anche all’altro client
				rpc_id(other_player_id, "sync_gtc_shown_flag", true)
			break

	# --- TO DAMAGE STEP ---
	for entry in cards_waiting_for_to_damage_step:
		var card = entry.card
		var invalid: bool = (
			card == null
			or not card.card_is_in_slot
			or card.attack_negated
		)

		if entry.player_id == local_id:
			if invalid:
				await wait(1.0)
				print("⛔ [TDS] Carta mia non valida → simulo TO DAMAGE STEP localmente")
				emit_signal("to_damage_step_chosen")
				$"../ActionButtons".hide_enemy_response_buttons()
				$"../ActionButtons".force_hide_all_green_borders()
				rpc_id(other_player_id, "receive_to_damage_step_chosen")
				rpc_id(other_player_id, "hide_enemy_response_buttons")
			else:
				already_chained_in_this_go_to_damage_step = true
				if not gtc_shown:                #condizione CHE FORSE FIXA IL PROBLEMA DEGLI ATTACCHI CONSECUTIVI E BUG MORTE ATTACCANTE
					print("🟢 [TDS] Mostro bottone TO DAMAGE STEP per carta nemica valida:", card.name)
					#action_buttons.show_to_damage_step_button()
					await wait(0.2)
					action_buttons.on_to_damage_step_pressed()  #AUTOMATIZZA PRESS TDS dopo che e' stato restorato in una chain di combat.
				else:
					print("GTC SHOWN DIOCANNEEEE ")
				# 🔥 notifico anche all’altro client
					#rpc_id(other_player_id, "sync_gtc_shown_flag", false)
				action_buttons.hide_label(action_buttons.enchain_label)
				action_buttons.force_hide_all_green_borders()
		else:
			if invalid:
				await wait(1.0)
				print("⛔ [TDS] Carta nemico non valida → simulo TO DAMAGE STEP via RPC")
				rpc_id(entry.player_id, "receive_to_damage_step_chosen")
				rpc_id(entry.player_id, "hide_enemy_response_buttons")
				emit_signal("to_damage_step_chosen")
				$"../ActionButtons".hide_enemy_response_buttons()
				$"../ActionButtons".force_hide_all_green_borders()
			break

	# --- Sync flags ---
	rpc_id(other_player_id, "sync_chained_flags", false, false)



# 🔹 nuovo RPC per replicare gtc_shown
@rpc("any_peer")
func sync_gtc_shown_flag(value: bool):
	gtc_shown = value
	print("🔄 [SYNC] gtc_shown aggiornato su peer ", multiplayer.get_unique_id(), " → ", gtc_shown)

	
			
	
@rpc("any_peer")
func sync_chained_flags(go_to_combat: bool, to_damage_step: bool):
	print("🔁 [SYNC] Ricevuti chained flags → GTC:", go_to_combat, " | TDS:", to_damage_step)
	already_chained_in_this_go_to_combat = go_to_combat
	already_chained_in_this_go_to_damage_step = to_damage_step

@rpc("any_peer")
func rpc_reset_chain_status():
	print("🔄 [SYNC] Chain completata → reset anche su questo client")
	chain_locked = false
	current_chain_index = 0
	current_chain_position = -1
	print("🔄 [RESET] current_chain_position: ", current_chain_position )
		# 💣 Distruzione post-chain
	if not cards_to_destroy_after_chain.is_empty():
		print("💥 [POST-CHAIN] Carte da distruggere dopo risoluzione della chain:")
		for c in cards_to_destroy_after_chain:
			if is_instance_valid(c):
				var owner = "Player" if not c.is_enemy_card() else "Opponent"
				print("   ➤ Distruggo ora:", c.name, "(owner:", owner, ")")
				destroy_card(c, owner)
			else:
				print("   ⚠️ Carta non più valida:", c)
		cards_to_destroy_after_chain.clear()
	# ✅ Svuota anche il pulse stack qui
	if not currently_targeted_cards.is_empty():
		var names := []
		for c in currently_targeted_cards:
			if typeof(c) == TYPE_DICTIONARY:
				names.append(c.get("name", "???"))
			else:
				names.append(c.name)
		print("🧹 [SYNC] Reset pulse stack: rimossi", names.size(), "elementi:", names)
		currently_targeted_cards.clear()
	else:
		print("📭 [SYNC] Pulse stack già vuoto.")
		
#func resolved_card_player_id(chain_pos: int) -> int:
	#for e in effect_stack:
		#if e.chain_position == chain_pos:
			#return e.player_id
	#return -1  # fallback: non dovrebbe accadere

#@rpc("any_peer")
#func sync_is_consecutive_cards(value: bool):
	#is_consecutive_cards = value

@rpc("any_peer")
func sync_simulate_resolve_flag(value: bool):
	print("🔁 [SYNC] simulate_resolve impostato a:", value)
	simulate_resolve = value


@rpc("any_peer")
func rpc_decrement_chain_position():
	current_chain_position -= 1
	if current_chain_position < -1:
		current_chain_position = -1
	print("🔁 [SYNC] Decrementato current_chain_position →", current_chain_position)


@rpc("any_peer")
func sync_attacking_flag(source_card_name: String, source_owner_id: int, is_attacking: bool):
	var local_id = multiplayer.get_unique_id()
	var source_card: Node = null

	# 🔍 Recupera la carta corretta (campo mio o dell’avversario)
	if local_id == source_owner_id:
		source_card = $"../CardManager".get_node_or_null(source_card_name)
	else:
		source_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + source_card_name)

	# 🔧 Applica lo stato attacking se la carta esiste
	if source_card and source_card.is_card():
		source_card.attacking = is_attacking
		print("⚔️ [SYNC ATTACKING FLAG] Carta:", source_card.name, " → attacking =", is_attacking)
	else:
		push_warning("⚠️ [SYNC ATTACKING FLAG] Carta non trovata:", source_card_name, " (owner_id:", source_owner_id, ")")
	
@rpc("any_peer")
func sync_attack_flags(source_card_name: String, target_card_name: String, source_owner_id: int, target_owner_id: int):
	var local_id = multiplayer.get_unique_id()

	var source_card: Node = null
	var target_card: Node = null

	if local_id == source_owner_id:
		source_card = $"../CardManager".get_node_or_null(source_card_name)
	else:
		source_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + source_card_name)

	if local_id == target_owner_id:
		target_card = $"../CardManager".get_node_or_null(target_card_name)
	else:
		target_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + target_card_name)

	target_card = target_card as Card

	if source_card and target_card:
		source_card.has_an_attack_target = true
		target_card.is_being_attacked = true
		if source_card not in target_card.being_attacked_by_cards:
			target_card.being_attacked_by_cards.append(source_card)
			print("⚔️ [SYNC ATTACK] Carta attaccata:", target_card.name, "da:", source_card.name)
			
		# 🔍 Debug stato
		print("✅ Stato COMBAT →", 
			source_card.name, "has_an_attack_target =", source_card.has_an_attack_target, 
			"|", target_card.name, "is_being_attacked =", target_card.is_being_attacked)
	#elif source_card and target_card_name == "":
		#print("🧹 [SYNC ATTACK] Rimozione attacco di:", source_card.name)
		#for card in get_tree().get_nodes_in_group("Cards"):
			#if source_card in card.being_attacked_by_cards:
				#card.being_attacked_by_cards.erase(source_card)
				#if card.being_attacked_by_cards.size() == 0:
					#card.is_being_attacked = false
	#
		#source_card.has_an_attack_target = false



func remove_chain_overlay(card: Node2D):
	if card:
		# 🛑 Stop tween di pulse e rotazione se esistono
		if card.has_meta("chain_pulse_tween"):
			var pulse_tween: Tween = card.get_meta("chain_pulse_tween")
			if pulse_tween and pulse_tween.is_valid():
				pulse_tween.kill()
			card.remove_meta("chain_pulse_tween")

		if card.has_meta("chain_rotate_tween"):
			var rotate_tween: Tween = card.get_meta("chain_rotate_tween")
			if rotate_tween and rotate_tween.is_valid():
				rotate_tween.kill()
			card.remove_meta("chain_rotate_tween")

		# 🧹 Rimuovi il numero
		if card.has_node("ChainOverlay"):
			card.get_node("ChainOverlay").queue_free()
			await get_tree().process_frame
			

		# 🧹 Rimuovi il glow
		if card.has_node("ChainGlow"):
			card.get_node("ChainGlow").queue_free()
			await get_tree().process_frame


		# 🧹 Rimuovi anche il border
		if card.has_node("ChainBorder"):
			card.get_node("ChainBorder").queue_free()
			await get_tree().process_frame



func add_chain_overlay(card: Node2D, pos: int):
	if not card or not card.card_is_in_slot:
		return

	# 🔄 Rimuovi overlay esistenti prima di aggiungere i nuovi
	if card.has_node("ChainOverlay"):
		card.get_node("ChainOverlay").queue_free()
	if card.has_node("ChainBorder"):
		card.get_node("ChainBorder").queue_free()

	# ✅ Aggiungi prima il border
	var border := Sprite2D.new()
	border.name = "ChainBorder"
	border.texture = preload("res://Assets/Chains/Chain Border.png")
	border.position = Vector2(0, -10)
	border.z_index = 199   # 👈 appena sotto al numero
	card.add_child(border)

	
	# 🔥 Fissalo dritto
	border.rotation_degrees = -card.rotation_degrees
	
	# ✅ Poi il numero
	if CHAIN_TEXTURES.has(pos):
		var overlay := Sprite2D.new()
		overlay.name = "ChainOverlay"
		overlay.texture = CHAIN_TEXTURES[pos]
		overlay.position = Vector2(0, -10)
		overlay.z_index = 200   # 👈 sopra al border
		card.add_child(overlay)
		
		# 🔥 Fissalo dritto
		overlay.rotation_degrees = -card.rotation_degrees
	# ✨ Aggiorna i glow dopo aver messo border + numero
	update_chain_glow()


func add_chain_glow(card: Node2D) -> void:
	if not card or not card.card_is_in_slot:
		return
	# 🔄 Se già c’è un glow, lo tolgo
	if card.has_node("ChainGlow"):
		card.get_node("ChainGlow").queue_free()
		await get_tree().process_frame
	# ✨ Creo glow nuovo
	var glow := Sprite2D.new()
	glow.name = "ChainGlow"
	glow.texture = preload("res://Assets/Chains/GlowChain.png")
	glow.position = Vector2(0, -10)  # stessa posizione overlay
	glow.z_index = 190               # 👈 sotto al numero (200), sopra la carta
	card.add_child(glow)
	# 🔥 Fissalo dritto
	glow.rotation_degrees = -card.rotation_degrees
	print("✨ Glow acceso su", card.name)

func remove_chain_glow(card: Node2D) -> void:
	if card and card.has_node("ChainGlow"):
		card.get_node("ChainGlow").queue_free()
		await get_tree().process_frame
		print("💡 Glow rimosso da", card.name)


# 👇 fuori da update_chain_glow
func _apply_pulse_scale(value: float, children: Array) -> void:
	for child in children:
		if child:
			child.scale = Vector2(value, value)


func update_chain_glow() -> void:
	# 🔄 Spegne tutti i glow e resetta scale
	for e in effect_stack:
		var node: Node2D = null
		if multiplayer.get_unique_id() == e.player_id:
			node = $"../CardManager".get_node_or_null(e.card_name)
		else:
			node = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + e.card_name)
		if node:
			remove_chain_glow(node)
			# stop pulse tween
			if node.has_meta("chain_pulse_tween"):
				var old_tween: Tween = node.get_meta("chain_pulse_tween")
				if old_tween and old_tween.is_valid():
					old_tween.kill()
				node.remove_meta("chain_pulse_tween")
			# stop rotate tween
			if node.has_meta("chain_rotate_tween"):
				var old_rotate: Tween = node.get_meta("chain_rotate_tween")
				if old_rotate and old_rotate.is_valid():
					old_rotate.kill()
				node.remove_meta("chain_rotate_tween")
				# resetta la rotazione a 0
				if node.has_node("ChainBorder"):
					var border = node.get_node("ChainBorder")
					border.rotation_degrees = 0

			# 👇 Reset scale con tween morbido
			for child_name in ["ChainGlow", "ChainOverlay", "ChainBorder"]:
				if node.has_node(child_name):
					var child = node.get_node(child_name)
					var reset_tween = node.create_tween()
					reset_tween.tween_property(child, "scale", Vector2.ONE, 0.2)\
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# --- il resto invariato ---
	if effect_stack.size() > 0:
		var last_entry = effect_stack.back()
		var last_node: Node2D = null
		if multiplayer.get_unique_id() == last_entry.player_id:
			last_node = $"../CardManager".get_node_or_null(last_entry.card_name)
		else:
			last_node = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + last_entry.card_name)

		if last_node:
			add_chain_glow(last_node)

			# stop vecchi tween
			if last_node.has_meta("chain_pulse_tween"):
				var old_tween: Tween = last_node.get_meta("chain_pulse_tween")
				if old_tween and old_tween.is_valid():
					old_tween.kill()
				last_node.remove_meta("chain_pulse_tween")

			if last_node.has_meta("chain_rotate_tween"):
				var old_rotate: Tween = last_node.get_meta("chain_rotate_tween")
				if old_rotate and old_rotate.is_valid():
					old_rotate.kill()
				last_node.remove_meta("chain_rotate_tween")

			# crea nuovo tween di pulse
			var tween = last_node.create_tween()
			last_node.set_meta("chain_pulse_tween", tween)
			tween.set_loops()
			var children: Array = []
			for child_name in ["ChainGlow", "ChainBorder"]: # 👈 solo questi pulsano
				if last_node.has_node(child_name):
					children.append(last_node.get_node(child_name))
			tween.tween_method(Callable(self, "_apply_pulse_scale").bind(children), 1.0, 1.2, 0.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_method(Callable(self, "_apply_pulse_scale").bind(children), 1.2, 1.0, 0.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			# crea nuovo tween di rotazione SOLO per il ChainBorder
			if last_node.has_node("ChainBorder"):
				var border = last_node.get_node("ChainBorder")
				var rotate_tween = last_node.create_tween()
				last_node.set_meta("chain_rotate_tween", rotate_tween)
				rotate_tween.set_loops()
				rotate_tween.tween_property(border, "rotation_degrees", 360, 3.0)\
					.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
				rotate_tween.tween_property(border, "rotation_degrees", 0, 0.0)


func add_attack_overlay(card: Node2D) -> void:
	if not card or not card.card_is_in_slot:
		return
	if card.attack_negated:
		card.attack_negated = false  #MI SERVE PERCHE DOPO UN EVENTUALE STOP ATTACK , QUANDO SI FARA IL SUCCESIVO ATK DEVO RESETTARLO
		print("ATTACK NEGATED A FALSE")
	# 🔄 Rimuovi overlay precedente se già presente
	if card.has_node("AttackOverlay"):
		card.get_node("AttackOverlay").queue_free()
		await get_tree().process_frame

	var overlay := Sprite2D.new()
	overlay.name = "AttackOverlay"
	overlay.texture = preload("res://Assets/Combat/Overlay Atk.png")
	overlay.position = Vector2(0, -20)   # 👈 stessa posizione chain
	overlay.z_index = 200              # 👈 sopra alla carta ma sotto eventuali label
	card.add_child(overlay)

	# 🔥 Fissalo dritto rispetto alla rotazione della carta
	overlay.rotation_degrees = -card.rotation_degrees

	# 📏 Forza dimensioni fisse
	overlay.scale = Vector2(0.04, 0.04)

	print("⚔️ Overlay ATTACK aggiunto su", card.name, "con scala fissa:", overlay.scale)



func remove_attack_overlay(card: Node2D) -> void:
	if card and card.has_node("AttackOverlay"):
		card.get_node("AttackOverlay").queue_free()
		await get_tree().process_frame
		print("🧹 Overlay ATTACK rimosso da", card.name)
		
@rpc("any_peer")
func show_attack_overlay(card_name: String, owner_id: int):
	var local_id = multiplayer.get_unique_id()
	var card: Node = null

	if local_id == owner_id:
		card = $"../CardManager".get_node_or_null(card_name)
	else:
		card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card:
		# 🧹 Rimuovi overlay di selezione (spada)
		$"../CardManager".remove_attack_overlay(card)
		# ✅ Aggiungi overlay di attacco vero
		add_attack_overlay(card)

	if card.attack_negated:      #MI SERVE PERCHE DOPO UN EVENTUALE STOP ATTACK , QUANDO SI FARA IL SUCCESIVO ATK DEVO RESETTARLO
		card.attack_negated = false
		print("ATTACK NEGATED A FALSE")
		
@rpc("any_peer")
func hide_attack_overlay(card_name: String, owner_id: int):
	var local_id = multiplayer.get_unique_id()
	var card: Node = null

	if local_id == owner_id:
		card = $"../CardManager".get_node_or_null(card_name)
	else:
		card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)

	if card:
		remove_attack_overlay(card)


func clear_combat_state(card: Card) -> void:
	# 🔄 Rimuove la carta dalle liste in attesa
	cards_waiting_for_go_to_combat = cards_waiting_for_go_to_combat.filter(func(e): return e.card != card)
	cards_waiting_for_to_damage_step = cards_waiting_for_to_damage_step.filter(func(e): return e.card != card)
	
		## ✅ Importante: resetta sempre il retaliate
	#defender_can_retaliate = false
	# 🔍 DEBUG: mostra le liste aggiornate
	print("🧹 [CLEAR COMBAT STATE] Dopo pulizia per:", card.name)
	print("   cards_waiting_for_go_to_combat =", cards_waiting_for_go_to_combat)
	print("   cards_waiting_for_to_damage_step =", cards_waiting_for_to_damage_step)
	print("   defender_can_retaliate =", defender_can_retaliate)


	
 #AGGIUNTO ORA NON SO SE SERVE --- SE E' ATTIVO C'E' BUG CHE CONSENTE DI CLICCARE CARTE IN MEZZO ALLA CHAIN

	#already_chained_in_this_go_to_combat = false
	#already_chained_in_this_go_to_damage_step = false 
	#var other_player_id = multiplayer.get_peers()[0]
	#print("MANDO RPC SYNC FLAGS PORCODIOOOOO")
	#rpc_id(other_player_id, "sync_chained_flags", false, false)
	
 #FINE FIX


	# 🔄 Reset flag attacco  QUESTO RESET SE E' ATTIVO PORTA AL BUG ATTACCANTE MORTO, PERCHE' RESETTA I FLAG TROPPO PRESTO.
	#card.has_an_attack_target = false
	#card.is_being_attacked = false

	# 🔄 Rimuove la carta dagli attaccanti
	for c in get_tree().get_nodes_in_group("Cards"):
		if card in c.being_attacked_by_cards:
			c.being_attacked_by_cards.erase(card)
			if c.being_attacked_by_cards.is_empty():
				c.is_being_attacked = false

	
	if card.being_attacked_by_cards:
		card.being_attacked_by_cards.clear()

	print("🧹 Stato di combattimento pulito per:", card.name)
	# 🔍 DEBUG: stampa lo stato delle variabili chiave
	#print("🧹 [CLEANUP DEBUG] (Peer ID =", get_tree().get_multiplayer().get_unique_id(), ")")
	#print("   any_combat_in_progress =", any_combat_in_progress)
	#print("   chain_locked =", chain_locked)
	#print("   chain_resolving_in_progress =", chain_resolving_in_progress)
	#print("   effect_stack.size =", effect_stack.size())
	#print("   already_chained_in_this_go_to_combat =", already_chained_in_this_go_to_combat)
	#print("   already_chained_in_this_go_to_damage_step =", already_chained_in_this_go_to_damage_step)
	#print("   chained_this_battle_step =", $"../CombatManager".chained_this_battle_step)
	## 🔍 DEBUG sugli array di attesa
	#print("   cards_waiting_for_go_to_combat =", $"../CombatManager".cards_waiting_for_go_to_combat)
	#print("   cards_waiting_for_to_damage_step =", $"../CombatManager".cards_waiting_for_to_damage_step)
	#print("   current_chain_position =", $"../CombatManager".current_chain_position)  # 🆕 aggiunto


func recheck_combat_status():
	var combat_in_progress := false
	if $"../PhaseManager".haste_battle_step:
		print("RESETTO HASTE BATTLE STEP")
		$"../PhaseManager".haste_battle_step = false
##LUI FORSE E' IL COLPEVOLE DEL BUG DI ATTACKER MORTO, E PROBABILMENTE BUG ANCHE PER CHAIN 1 2 FACEDOWN (PENSAVO SERVISSE)
	#for card in player_creatures_on_field + opponent_creatures_on_field:
		#if card.has_an_attack_target or card.is_being_attacked:
			#combat_in_progress = true
			#break
			
	if chained_this_battle_step:
		combat_in_progress = true

	any_combat_in_progress = combat_in_progress
	print("🔁 [RECHECK] any_combat_in_progress =", any_combat_in_progress)
	if not just_targeted_creature.is_empty():
		print("🧹 [Fine combat] Pulizia just_targeted_creature (nuovo step)")
		just_targeted_creature.clear()
	# ✅ RESET BATTLE STEP STATUS
	if not any_combat_in_progress and cards_waiting_for_go_to_combat.is_empty() and cards_waiting_for_to_damage_step.is_empty():
		#print("🔄Recheck combat status Fine del battle step → reset opponent_pressed_go_to_combat = false")
		print("🔄Recheck combat status Fine del battle step → reset chained_this_battle_step = false")
		chained_this_battle_step = false # AGGIUNTO POTREBBE CAUSARE BUG
		opponent_pressed_go_to_combat = false
		var other_id = multiplayer.get_peers()[0]
		rpc_id(other_id, "rpc_reset_opponent_pressed_flag")

			
func is_last_effect_in_chain(card) -> bool:
	return effect_stack.size() == 1 and card.effect_stack_index == 0
	
@rpc("any_peer")
func rpc_reset_opponent_pressed_flag():
	print("🔄 [SYNC] opponent_pressed_go_to_combat reset su peer remoto")
	opponent_pressed_go_to_combat = false


# ------------------------------------------------------------------
# ⏳ Attende che un effetto (inclusi selection, resolve e chain) sia completato
# ------------------------------------------------------------------
func await_effect_fully_resolved(card: Node) -> void:
	print("⏳ [WAIT] Inizio attesa per completamento effetto di:", card.card_data.card_name)

	while (
		chain_locked
		or not effect_stack.is_empty()
		or $"../CardManager".selection_mode_active
		or $"../CardManager".opponent_selection_mode_active
		#or not trigger_endphase_cards.is_empty()  # 🆕 aspetta che TUTTI i TriggerEndPhase siano risolti		
	):
		await get_tree().process_frame

	await get_tree().create_timer(0.2).timeout
	print("✅ [WAIT] Effetto di", card.card_data.card_name, "completamente risolto. (Trigger list vuota:", trigger_endphase_cards.is_empty(), ")")


# 🧩 Funzione centralizzata per applicare un effetto a una carta
func apply_simple_effect_to_card(card: Node, effect: String, magnitude: int, source_card: Node, player_id: int, trigger_cause: Card = null) -> bool:
	if not is_instance_valid(card):
		return false

	# ⚖️ DETERMINA EFFECT INDEX (1–4) PER TRHESHOLD
	var effect_index := 1
	if effect == source_card.card_data.effect_2:
		effect_index = 2
	elif effect == source_card.card_data.effect_3:
		effect_index = 3
	elif effect == source_card.card_data.effect_4:
		effect_index = 4
	elif effect == source_card.card_data.effect_5:
		effect_index = 5
	# ⚖️ THRESHOLD CHECK PRIMA DI APPLICARE L’EFFETTO
	if not check_threshold_condition(source_card, card, effect_index):
		print("🚫 Threshold non superato → effetto", effect, "annullato su", card.card_data.card_name)
		return false

	# --- APPLICAZIONE EFFETTI ---
	match effect:
		"Custom":
			var custom_effects = get_parent().get_node_or_null("CustomEffects")
			if custom_effects:
				await custom_effects.run_custom_effect(source_card.card_data.card_name, source_card, card, magnitude, player_id)
			else:
				push_warning("⚠️ Nodo CustomEffects non trovato! Effetto custom non eseguito.")

		"Damage":
			card.card_data.health = max(0, card.card_data.health - magnitude)
			card.get_node("Health").text = str(card.card_data.health)
			card.update_card_visuals()
			source_card.emit_signal("damage_dealt", source_card, magnitude, "to_creature")
			card.emit_signal("damage_taken", card, magnitude)
			# ✅ Rimozione stun se subisce danno
			if card.card_data.health < card.card_data.max_health:
				if card.card_data.active_debuffs.has("Stunned"):
					print("✅ Stun rimosso da", card.card_data.card_name)
					card.stunned = false
					card.card_data.remove_debuff("Stunned")
					card.update_debuff_icons()
					card.rpc("rpc_remove_debuff", player_id, card.name, "Stunned")
					card.stun_timer = 0

		"Destroy":
			if card.has_node("RedHighlightBorder"):
				card.red_highlight_border.visible = true

			var is_in_stack := false
			for e in effect_stack:
				if e.card_name == card.name:
					is_in_stack = true
					break

			if is_in_stack:
				print("⚠️ Carta", card.name, "sta risolvendo un effetto → differisco distruzione (post-chain).")
				if not cards_to_destroy_after_chain.has(card):
					cards_to_destroy_after_chain.append(card)
			else:
				var owner = "Player" if not card.is_enemy_card() else "Opponent"
				destroy_card(card, owner)

		"BuffTalent":
			var talent_to_add = source_card.card_data.talent_from_buff
			if talent_to_add != "None":
				print("✨ [BUFF TALENT] Aggiungo talento", talent_to_add, "a", card.card_data.card_name)

				# 🧠 Controlla se il talento era già presente
				var already_had_talent = talent_to_add in card.card_data.get_all_talents()

				# 📦 Aggiungi SEMPRE il buff logico
				card.card_data.add_buff(source_card, "BuffTalent", 0, 0, 0, trigger_cause)

				# 📎 Inserisci il nome del talento nel dizionario del buff
				for b in card.card_data.active_buffs:
					if b["source_card"] == source_card and b["type"] == "BuffTalent":
						b["talent"] = talent_to_add
						break

				# 🎨 Aggiungi visivamente l’icona o overlay SOLO se non c’era già
				if not already_had_talent:
					if card.TALENT_ICONS.has(talent_to_add):
						card._add_icon(talent_to_add)
						card.play_talent_icon_pulse(talent_to_add)
					elif talent_to_add in card.OVERLAY_TALENTS:
						card._add_talent_overlay(talent_to_add)
					print("💪 Talento", talent_to_add, "applicato come buff a", card.card_data.card_name)
				else:
					print("⚖️", card.card_data.card_name, "aveva già il talento", talent_to_add, "(aggiunto solo buff logico)")

				card.update_card_visuals()
			else:
				print("⚠️ Nessun talent_from_buff definito in", source_card.card_data.card_name)


		"Buff":
			var voided_atk = card.card_data.voided_atk
			var effective_buff = max(0, magnitude - voided_atk)
			card.card_data.attack += effective_buff
			card.card_data.max_attack += effective_buff
			card.card_data.health += magnitude
			card.card_data.max_health += magnitude
			card.card_data.voided_atk = max(0, voided_atk - magnitude)
			card.card_data.add_buff(source_card, "Buff", magnitude, magnitude, 0, trigger_cause)
			card.update_card_visuals()
			print("💪 [BUFF] +", effective_buff, "ATK / +", magnitude, "HP su", card.card_data.card_name)

		"BuffAtk":
			var voided_atk = card.card_data.voided_atk
			var effective_buff = max(0, magnitude - voided_atk)
			card.card_data.attack += effective_buff
			card.card_data.max_attack += effective_buff
			card.card_data.voided_atk = max(0, voided_atk - magnitude)
			card.card_data.add_buff(source_card, "BuffAtk", magnitude, 0, 0, trigger_cause)
			card.update_card_visuals()

		"BuffHp":
			card.card_data.health += magnitude
			card.card_data.max_health += magnitude
			card.card_data.add_buff(source_card, "BuffHp", 0, magnitude,0, trigger_cause)
		"BuffArmour":
			card.card_data.armour += magnitude
			card.card_data.add_buff(source_card, "BuffArmour", 0, 0, magnitude, trigger_cause)
			card.update_card_visuals()
			print("🛡️ [BUFF ARMOUR] +", magnitude, "Armour su", card.card_data.card_name)
		"Debuff":
			var old_atk = card.card_data.attack
			var old_hp = card.card_data.health
			card.card_data.attack = max(old_atk - magnitude, 0)
			card.card_data.health = max(old_hp - magnitude, 0)
			card.card_data.max_attack = max(card.card_data.max_attack - magnitude, 0)
			card.card_data.max_health = max(card.card_data.max_health - magnitude, 0)
			card.card_data.voided_atk += max(0, magnitude - (old_atk - card.card_data.attack))
			card.card_data.add_debuff(source_card, "Debuff", magnitude, magnitude)
			await get_tree().process_frame
			card.update_card_visuals()

		"DebuffAtk":
			var old_atk = card.card_data.attack
			card.card_data.max_attack = max(card.card_data.max_attack - magnitude, 0)
			card.card_data.attack = max(card.card_data.attack - magnitude, 0)
			card.card_data.voided_atk += max(0, magnitude - (old_atk - card.card_data.attack))
			card.card_data.add_debuff(source_card, "DebuffAtk", magnitude, 0)
			await get_tree().process_frame
			card.update_card_visuals()

		"DebuffHp":
			card.card_data.max_health = max(card.card_data.max_health - magnitude, 0)
			card.card_data.health = max(card.card_data.health - magnitude, 0)
			card.card_data.add_debuff(source_card, "DebuffHp", 0, magnitude)
			await get_tree().process_frame
			card.update_card_visuals()

		"Heal":
			var old_health = card.card_data.health
			var max_health = card.card_data.max_health

			# 💚 Aumenta la salute ma non oltre la salute massima
			card.card_data.health = clamp(card.card_data.health + magnitude, 0, max_health)

			# 🔢 Calcola quanto è stato effettivamente curato
			var healed_amount = card.card_data.health - old_health
			if healed_amount > 0:
				print("💚 [Effect] Heal:", card.card_data.card_name, "+", healed_amount, "HP (max:", max_health, ")")
				card.play_heal_animation()  # 🎬 animazione locale

			await get_tree().process_frame
			card.update_card_visuals()


		"Freeze":
			if not card.card_data.active_debuffs.has("Frozen"):
				card.frozen = true
				card.freeze_timer = 1
				card.card_data.add_debuff(source_card,"Frozen")
				card.update_debuff_icons()
			else:
				print("♻️ Freeze rinnovato su carta", card.card_data.card_name)
				card.frozen = true
				card.play_debuff_icon_pulse("Frozen")
				card.freeze_timer = 1
				
			if card.has_an_attack_target:
				print("STOPPO ANCHE ATTACCO")
				stop_attack(card)
		
		"Root":
			if not card.card_data.active_debuffs.has("Rooted"):
				card.rooted = true
				card.root_timer = 1 #QUI POI IN BASE AL TEMP EFFECT POTRAI PURE MODIFICARLO
				card.card_data.add_debuff(source_card,"Rooted")
				card.update_debuff_icons()
			else:
				print("♻️ Root rinnovato su carta", card.card_data.card_name)
				card.rooted = true
				card.play_debuff_icon_pulse("Rooted")
				card.freeze_timer = 1
		"Stun":
			var already_stunned := false
			for d in card.card_data.active_debuffs:
				if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Stunned":
					already_stunned = true
					break

			var force_one_turn := false
			if source_card.card_data.temp_effect == "Endphase":
				force_one_turn = true
				print("💫 [ENDPHASE] Forzo durata Stun = 1 su", card.card_data.card_name)

			if already_stunned:
				print("💫 Stun rinnovato su", card.card_data.card_name)
				card.stunned = true
				card.stun_timer = 1 if force_one_turn else 2
				card.play_debuff_icon_pulse("Stunned")
			else:
				print("💫 Effetto Stun applicato a", card.card_data.card_name)
				card.stunned = true
				card.stun_timer = 1 if force_one_turn else 2
				card.card_data.add_debuff(source_card, "Stunned")
				card.update_debuff_icons()
				
			if card.has_an_attack_target:
				print("STOPPO ANCHE ATTACCO")
				stop_attack(card)
		"Counter":
			var cm = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
			if cm and cm.effect_stack.size() > 1:
				var last_index = cm.effect_stack.size() - 1
				var counter_entry = cm.effect_stack[last_index]
				var target_entry = cm.effect_stack[last_index - 1]
				var target_card: Node = null
				if target_entry.player_id == multiplayer.get_unique_id():
					target_card = cm.get_node("../CardManager").get_node_or_null(target_entry.card_name)
				else:
					target_card = cm.get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + target_entry.card_name)
				if target_card and target_card.is_card():
					target_card.effect_negated = true
					target_card.set_negated_state(true)
					print("❌ Effetto di", target_card.card_data.card_name, "è stato negato da Counter!")
			else:
				print("⚠️ [COUNTER] Stack troppo corto o CombatManager non trovato.")

		"Draw":
			print("🃏 Effetto Draw → pesca", magnitude)
			if multiplayer.get_unique_id() == player_id:
				print("CHIAMATA LOCAL PLAYER")
				var deck = get_tree().get_current_scene().get_node_or_null("PlayerField/Deck")
				if deck:
					for i in range(magnitude):
						deck.draw_card()
						await get_tree().create_timer(0.2).timeout
				else:
					print("DECK NON TROVATO")
			else:
				print("CHIAMATA ALTRO PLAYER")
				var deck = get_tree().get_current_scene().get_node_or_null("EnemyField/EnemyDeck")
				if deck:
					for i in range(magnitude):
						deck.draw_card()
						await get_tree().create_timer(0.2).timeout
		# ⚡️ Spell Power Buffs
		"BuffSpellPower", "BuffFireSpellPower", "BuffWindSpellPower", "BuffEarthSpellPower", "BuffWaterSpellPower":
			print("⚡️ Applico effetto Spell Power:", effect, "da", source_card.card_data.card_name)
			var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
			if card_manager:
				if multiplayer.get_unique_id() == player_id:
					# 🟢 Lato del giocatore che ha lanciato l’effetto → aggiorna il proprio lato
					card_manager.apply_spell_power_effects(source_card, false, false, effect)
				else:
					# 🔴 Lato replica → aggiorna solo i valori enemy, ma sempre per l'effetto specifico
					card_manager.apply_spell_power_effects(source_card, true, false, effect)
			else:
				push_warning("⚠️ CardManager non trovato durante BuffSpellPower")
		#"SpawnToken":
			#spawn_token_from(card)
		"Bouncer":
			print("🌀 [BOUNCER] Effetto rimbalzo su", card.card_data.card_name)
			var owner = "Player" if not card.is_enemy_card() else "Opponent"
			await apply_bouncer_effect(card, owner)
		"FieldFlood", "FieldBurn", "FieldWindy", "FieldArid":
			print("🌍 Applico Field Effect:", effect, "da", source_card.card_data.card_name)

			var combat_manager = $"../CombatManager"
			if combat_manager:
				var is_attacker := multiplayer.get_unique_id() == player_id
				combat_manager.apply_field_effect(effect, is_attacker)
			else:
				push_warning("⚠️ CombatManager non trovato durante FieldEffect")
		"AddRepeats":
			var cm = $"../CombatManager"
			if not cm:
				push_warning("⚠️ CombatManager non trovato per AddRepeats")
				return false

			var repeat_amount := magnitude
			var max_cost = source_card.card_data.effect_1_threshold

			var additional_req = null
			if source_card.card_data.t_subtype_1 == "MyNextNormalSpell":
				additional_req = "normal"

			var bonus := {
				"bonus_type": "next_played",
				"type": "AddRepeats",
				"amount": repeat_amount,
				"max_mana_cost": max_cost,
				"card_type": "Spell",
				"owner_id": player_id,
				"expires": "EndPhase",
				"source_card": source_card,
				"additional_requirement": additional_req
			}

			cm.register_player_bonus(bonus)

			print("🔁 [ADD REPEATS] Prossima", additional_req,
				" Spell ≤", max_cost, "otterrà +", repeat_amount, " repeat")



		_:
			print("⚠️ Effetto non riconosciuto:", effect)

	card.update_card_visuals()

	# 🔁 Ritorna true se la carta è morta
	return card.card_data.health == 0


func register_player_bonus(bonus: Dictionary):
	player_bonuses.append(bonus)

	print("✨ [PLAYER BONUS] Registrato:", bonus)

	# 🎨 preview SOLO sul client che possiede il bonus
	if multiplayer.get_unique_id() != bonus.owner_id:
		return

	var hand = $"../PlayerHand"
	if not hand:
		return

	if bonus.bonus_type == "next_played":
		for card in hand.player_hand:
			# 🔐 owner_id passato esplicitamente
			if card_matches_player_bonus(card, bonus, bonus.owner_id):
				card.show_next_card_buffed_border(true)
				print("✨ [PREVIEW BONUS] Border ON su:", card.card_data.card_name)



func clear_next_card_buffed_borders():
	var hand = $"../PlayerHand"
	if not hand:
		return

	for card in hand.player_hand:
		card.show_next_card_buffed_border(false)

func apply_player_bonuses(card: Node2D, owner_id: int):
	var applied := []
	var consumed := []

	for bonus in player_bonuses:
		# 🔐 owner esplicito
		if bonus.owner_id != owner_id:
			continue

		# 🔁 i next_played vanno SEMPRE consumati
		if bonus.bonus_type == "next_played":
			consumed.append(bonus)

		# ❌ se non matcha la carta, non applico ma verrà comunque consumato
		if not card_matches_player_bonus(card, bonus, owner_id):
			continue

		# ✅ applicazione effetto
		card.show_next_card_buffed_border(true, true)

		match bonus.type:
			"AddRepeats":
				var current := int(card.card_data.repeats)
				card.card_data.repeats = str(current + bonus.amount)

		applied.append(bonus)

	# 🧹 rimuovi TUTTI i next_played (consumati)
	for b in consumed:
		player_bonuses.erase(b)

	# 🎨 pulizia preview SOLO client proprietario
	if not consumed.is_empty():
		if multiplayer.get_unique_id() == owner_id:
			clear_next_card_buffed_borders()

	# 🧪 debug
	if not applied.is_empty():
		print("✨ [PLAYER BONUS] Applicati:", applied.size())
	elif not consumed.is_empty():
		print("⚠️ [PLAYER BONUS] Consumato senza applicazione")



		
func clear_player_bonuses(bonus_type = null, expires_type = null, effect_type = null):
	var removed := false

	for bonus in player_bonuses.duplicate():
		# 🧠 filtro per macro-tipo (es. "next_played", "aura", "static")
		if bonus_type != null and bonus.get("bonus_type") != bonus_type:
			continue

		# 🎯 filtro per tipo effetto (es. "AddRepeats")
		if effect_type != null and bonus.get("type") != effect_type:
			continue

		# ⏳ filtro per scadenza
		if expires_type != null and bonus.get("expires") != expires_type:
			continue

		player_bonuses.erase(bonus)
		removed = true
		print("🧹 [PLAYER BONUS] Rimosso:",
			bonus.get("bonus_type"),
			bonus.get("type"),
			"expires =", bonus.get("expires"))

	if removed:
		clear_next_card_buffed_borders()

		
		
	
func card_matches_player_bonus(card: Node2D, bonus: Dictionary, owner_id) -> bool:
	if bonus.owner_id != owner_id:
		return false

	if bonus.bonus_type != "next_played":
		return false

	if bonus.card_type != card.card_data.card_type:
		return false

	var req = bonus.get("additional_requirement")
	if req != null:
		match req:
			"normal":
				if card.card_data.card_class != "NormalSpell":
					return false

	# 💰 mana cost
	var mana_cost := 0
	for cost in [
		card.card_data.mana_cost_1,
		card.card_data.mana_cost_2,
		card.card_data.mana_cost_3,
		card.card_data.mana_cost_4,
		card.card_data.mana_cost_5,
		card.card_data.mana_cost_6,
		card.card_data.mana_cost_7
	]:
		if cost != "None":
			mana_cost += 1

	if mana_cost > bonus.max_mana_cost:
		return false

	return true


# 💎 Controlla se il Magic Veil blocca l’effetto e gestisce l’animazione
# 💎 Controlla se il Magic Veil blocca l’effetto e gestisce l’animazione
# Ora include il controllo automatico del threshold: se non lo supera, non consuma il Veil
func check_magic_veil(card: Node, source_card: Node) -> bool:
	if not is_instance_valid(card):
		return false
	if source_card.card_data.effect_type == "Aura":
		print("MAGIC VEIL NON SI APPLICA SU EFFETTI AURA")
		return false
	# 💡 Prima di tutto: controlla il threshold
	var effect_index := 1
	var current_effect = source_card.card_data.effect_1
	if source_card.card_data.effect_2 != "None" and source_card.card_data.effect_2 == current_effect:
		effect_index = 2



	# Solo se la carta ha il Magic Veil e la sorgente è una Spell
	if card.has_magic_veil and source_card.card_data.card_type == "Spell" and source_card.is_enemy_card() != card.is_enemy_card():
		print("✨ [MAGIC VEIL] Effetto spell annullato su", card.name)

		var overlay: Sprite2D = card.get_node_or_null("Magic Veil_Overlay")
		if overlay:
			var t: Tween = card.create_tween()
			t.set_parallel(false)
			t.tween_property(overlay, "modulate:a", 2.0, 0.1)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(overlay, "modulate:a", 0.0, 0.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			t.finished.connect(func():
				if is_instance_valid(card):
					card.remove_talent_overlay("Magic Veil")
					card.has_magic_veil = false
					print("🌀 Magic Veil consumato su", card.name)
			)
			
				# 💥 Se la carta sorgente (Spell) è ancora in campo → viene distrutta
		if is_instance_valid(source_card) and source_card.card_is_in_slot:
			print("💥 [MAGIC VEIL] Distruggo la Spell annullata:", source_card.card_data.card_name)
			var owner = "Player" if not source_card.is_enemy_card() else "Opponent"
			destroy_card(source_card, owner)
				
		return true  # ✅ Effetto annullato (e Magic Veil consumato)

	return false  # 🚫 Nessun Magic Veil → continua normalmente

#func spawn_token_from(card: Node):
	#print("🧬 Effetto SpawnToken attivato da:", card.card_data.card_name)
#
	#var owner_id = card.effect_triggering_player_id
	#var is_local_owner = multiplayer.get_unique_id() == owner_id
#
	#var field_path = ""
	#var card_manager = null
	#var zones_node = null
#
	#if is_local_owner:
		#field_path = "PlayerField"
		#card_manager = get_tree().get_current_scene().get_node("PlayerField/CardManager")
		#zones_node = get_tree().get_current_scene().get_node("PlayerField/PlayerZones")
	#else:
		#field_path = "EnemyField"
		#card_manager = get_tree().get_current_scene().get_node("EnemyField/CardManager")
		#zones_node = get_tree().get_current_scene().get_node("EnemyField/EnemyZones")
#
	## 🔍 Trova il primo slot libero
	#var first_free_slot: Node2D = null
	#for i in range(1, 6):
		#var slot = zones_node.get_node_or_null("CreatureSlot" + str(i))
		#if slot and slot.has_node("Area2D/CollisionShape2D") and slot.get_node("Area2D/CollisionShape2D").disabled == false:
			#first_free_slot = slot
			#break
#
	#if first_free_slot == null:
		#print("⚠️ Nessuno slot libero per spawnare il token su:", field_path)
		#return
#
	## 🧩 Crea i dati del token
	#var token_data := CardData.new()
	#token_data.card_name = "Token_Homunculus"
	#token_data.card_type = "Creature"
	#token_data.creature_race = card.card_data.creature_race
	#token_data.attack = card.card_data.attack
	#token_data.health = card.card_data.health
	#token_data.effect_type = "None"
	#token_data.card_field_sprite = preload("res://Assets/CardImagesFIELD/TokensField/TOKEN HOMUNCULUS 150450 2.png")
	#token_data.card_sprite_preview = preload("res://Assets/CardImagesPreview/TokensPreview/TOKEN HOMUNCULUS 150450 1.png")
#
	## 🧱 Istanzia la scena corretta
	#var token_scene: PackedScene
	#if is_local_owner:
		#token_scene = preload("res://Scene/Card.tscn")
		#var token_card = token_scene.instantiate()
		#token_card.set_card_data(token_data)
		#token_card.set_meta("position_type", "attack")
		#token_card.set_meta("owner_id", owner_id)
		#token_card.set_multiplayer_authority(owner_id)
#
		## 🧾 Nome coerente su entrambi i client
		#token_card.card_data.card_name = "Token_" + str(owner_id) + "_" + str(card.get_instance_id())
#
		#token_card.visible = true
		#card_manager.add_child(token_card)
#
		#print("📜 Creazione Token - Dati iniziali:")
		#print("  • Nome previsto:", token_card.name)
		#print("  • Owner ID:", owner_id)
		#print("  • Campo target:", field_path)
		#print("  • Multiplayer Authority:", token_card.get_multiplayer_authority())
		#print("  • Path previsto del CardManager:", $"../CardManager".get_path())
#
		## 👇 Verifica doppioni o nomi simili (utile se fallisce get_node lato opposto)
		#print("🧩 Lista carte nel CardManager (dopo aggiunta):")
		#for c in $"../CardManager".get_children():
			#print("   -", c.name)
		## 👇 Attendi un frame per sicurezza
		#await $"../CardManager".gioca_token(token_card, first_free_slot)
	#else:
		#token_scene = preload("res://Scene/EnemyCard.tscn")
		#var token_card = token_scene.instantiate()
		#token_card.set_card_data(token_data)
		#token_card.set_meta("position_type", "attack")
		#token_card.set_meta("owner_id", owner_id)
		#token_card.set_multiplayer_authority(owner_id)
#
		## 🧾 Nome coerente su entrambi i client
		#token_card.card_data.cad_name = "Token_" + str(owner_id) + "_" + str(card.get_instance_id())
#
		#token_card.visible = true
		#card_manager.add_child(token_card)
#
		#print("📜 Creazione Token - Dati iniziali:")
		#print("  • Nome previsto:", token_card.name)
		#print("  • Owner ID:", owner_id)
		#print("  • Campo target:", field_path)
		#print("  • Multiplayer Authority:", token_card.get_multiplayer_authority())
		#print("  • Path previsto del CardManager:", $"../CardManager".get_path())
#
		## 👇 Verifica doppioni o nomi simili (utile se fallisce get_node lato opposto)
		#print("🧩 Lista carte nel CardManager (dopo aggiunta):")
		#for c in $"../CardManager".get_children():
			#print("   -", c.name)
		## 👇 Attendi un frame per sicurezza
		#await $"../CardManager".gioca_token(token_card, first_free_slot)
#
#
	## 👇 Gioca il token normalmente (usa tutta la logica di posizionamento, aura ecc.)
#
#
	#print("✅ Token spawnato su:", field_path, "| Slot:", first_free_slot.name, "| Owner:", owner_id)


func handle_card_destruction_check(card: Node, cards_to_destroy: Array) -> void:
	if not is_instance_valid(card):
		print("⚠️ handle_card_destruction_check: carta non valida, skip.")
		return

	# 💀 Controlla se la carta è "morta" oppure spell
	if card.card_data.health != 0 or card.card_data.card_type == "Spell":
		return  # Niente da fare se è ancora viva

	# 🔍 Verifica se la carta è attualmente nello stack (sta risolvendo un effetto)
	var is_in_stack := false
	for e in effect_stack:
		if e.card_name == card.name:
			is_in_stack = true
			break

	if is_in_stack:
		# 🕓 Distruzione differita
		print("⚠️ Carta", card.name, "sta risolvendo un effetto → differisco distruzione (post-chain).")
		if not cards_to_destroy_after_chain.has(card):
			cards_to_destroy_after_chain.append(card)
	else:
		# 🧨 Distruzione immediata (dopo 0.5s)
		cards_to_destroy.append(card)
		var owner = "Player" if not card.is_enemy_card() else "Opponent"
		#await wait(0.5) #SE CREA PROBLEMI RIMETTILA
		if is_instance_valid(card):
			print("💥 Distruggo subito carta", card.name, "(owner:", owner, ")")
			destroy_card(card, owner)


func set_last_played_card(card: Node, owner_id: int):
	if not card:
		return
	if not card.was_enchained:
		pending_action_after_chain = false
		print("RESET SICUREZZA PENDING ACTION AFTER CHAIN PER NON FARE DELAYARE AZIONE")
		
	last_played_card = {"card": card, "owner_id": owner_id}
	print("🃏 [CombatManager] Ultima carta giocata:", card.card_data.card_name, "| Owner:", owner_id)

	# 🧹 Pulisci sempre just_summoned_creature e just_played_spell a meno che questa nuova carta sia enchained
	if not just_summoned_creature.is_empty() and not card.was_enchained:
		print("🧹 [CombatManager] Pulizia just_summoned_creature (nuova carta giocata)")
		just_summoned_creature.clear()
	else:
		print("NIENTE DA CLEARARE O QUESTA ULTIMA CARTA WAS ENCHAINED")

	if not just_played_spell.is_empty() and not card.was_enchained:
		print("🧹 [CombatManager] Pulizia just_played_spell (nuova carta giocata)")
		just_played_spell.clear()
	else:
		print("NIENTE DA CLEARARE O QUESTA ULTIMA CARTA WAS ENCHAINED (SPELL)")

	# 🧹 Pulisci anche just_targeted_creature
	if not just_targeted_creature.is_empty() and not card.was_enchained:
		print("🧹 [CombatManager] Pulizia just_targeted_creature (nuova carta giocata)")
		just_targeted_creature.clear()
	else:
		print("NIENTE TARGET DA CLEARARE O QUESTA ULTIMA CARTA WAS ENCHAINED")

	# ➕ Aggiungi SOLO se è una creatura o spell
	if card.card_data.card_type == "Creature":
		var entry = {"card": card, "owner_id": owner_id}
		
		# 🔹 Usato per logiche immediate (chain, trigger)
		just_summoned_creature.append(entry)
		print("🧩 [CombatManager] Aggiunta just_summoned_creature:", card.card_data.card_name, "| Owner:", owner_id)

		# 🔹 Usato per regole di turno (summoning sickness, ecc.)
		if not summoned_this_turn.has(entry):
			summoned_this_turn.append(entry)
			print("🐣 [CombatManager] Creatura aggiunta a summoned_this_turn:", card.card_data.card_name)

	elif card.card_data.card_type == "Spell":
		var entry = {"card": card, "owner_id": owner_id}
		just_played_spell.append(entry)
		print("🧩 [CombatManager] Aggiunta just_played_spell:", card.card_data.card_name, "| Owner:", owner_id)
				# 🧩 Se la spell è settata coperta → aggiungila a setted_this_turn
		if card.position_type == "facedown":
			if not setted_this_turn.has(entry):
				setted_this_turn.append(entry)
				print("📜 [CombatManager] Spell facedown aggiunta a setted_this_turn:", card.card_data.card_name)


	# 🔍 Calcola valid targets solo se la carta è targeted
	var valid_targets: Array = []
	if card.card_data.targeting_type == "Targeted":
		var is_attacker = multiplayer.get_unique_id() == owner_id
		valid_targets = $"../CombatManager".get_valid_targets(card, is_attacker)

	# 🔍 Controlla effetti immediati o facedown
	var no_immediate_effect = (
		card.card_data.effect_type not in ["OnPlay", "Aura", "Equip"]
		or card.position_type == "facedown"
		or (
			card.card_data.effect_type in ["OnPlay", "Aura", "Equip"]
			and card.card_data.targeting_type == "Targeted"
			and valid_targets.is_empty()
		)
	)

	
	# 👇 Mostra i green highlight solo sul client opposto
	if no_immediate_effect and multiplayer.get_unique_id() != owner_id and not $"../ActionButtons".auto_skip_resolve:
		print("🟩 [CombatManager] Attivo green highlight su carte chainabili (giocatore opposto)")
		$"../ActionButtons".highlight_cards_for_enchain(true)
		$"../ActionButtons".show_label($"../PromptLabels/PlayerEnchainLabel")


		
func animate_spell_power_gain(owner: String, amount: int, offset_x: float = 50.0):
	var icon_node: TextureRect
	var label_node: RichTextLabel
	var delay := 0.2
	var root = get_parent().get_parent()

	match owner:
		"Player":
			icon_node = root.get_node("PlayerField/PlayerSPicon")
			label_node = root.get_node("PlayerField/PlayerSP")
		"Enemy":
			icon_node = root.get_node("EnemyField/EnemySPicon")
			label_node = root.get_node("EnemyField/EnemySP")
		"PlayerFire":
			icon_node = root.get_node("PlayerField/PlayerFireSPicon")
			label_node = root.get_node("PlayerField/PlayerFireSP")
		"EnemyFire":
			icon_node = root.get_node("EnemyField/EnemyFireSPicon")
			label_node = root.get_node("EnemyField/EnemyFireSP")
		"PlayerWind":
			icon_node = root.get_node("PlayerField/PlayerWindSPicon")
			label_node = root.get_node("PlayerField/PlayerWindSP")
		"EnemyWind":
			icon_node = root.get_node("EnemyField/EnemyWindSPicon")
			label_node = root.get_node("EnemyField/EnemyWindSP")
		"PlayerEarth":
			icon_node = root.get_node("PlayerField/PlayerEarthSPicon")
			label_node = root.get_node("PlayerField/PlayerEarthSP")
		"EnemyEarth":
			icon_node = root.get_node("EnemyField/EnemyEarthSPicon")
			label_node = root.get_node("EnemyField/EnemyEarthSP")
		"PlayerWater":
			icon_node = root.get_node("PlayerField/PlayerWaterSPicon")
			label_node = root.get_node("PlayerField/PlayerWaterSP")
		"EnemyWater":
			icon_node = root.get_node("EnemyField/EnemyWaterSPicon")
			label_node = root.get_node("EnemyField/EnemyWaterSP")
		_:
			push_warning("⚠️ animate_spell_power_gain: owner sconosciuto: " + owner)
			return

	if not is_instance_valid(icon_node) or not is_instance_valid(label_node):
		push_warning("⚠️ animate_spell_power_gain: nodi non trovati per " + owner)
		return

	# ✨ Determina se è un'icona elementale
	var is_elemental := owner in [
		"PlayerFire", "EnemyFire",
		"PlayerWind", "EnemyWind",
		"PlayerEarth", "EnemyEarth",
		"PlayerWater", "EnemyWater"
	]

	if is_elemental:
		var was_visible := icon_node.visible  # 👈 controlla se era già visibile prima
		icon_node.visible = true
		label_node.visible = true

		# ⚙️ Direzione dello spostamento
		var direction := 1.0
		if owner.begins_with("Enemy"):
			direction = -1.0

		# 📦 Controlla se esiste già un’altra icona elementale visibile
		var player_field = root.get_node("PlayerField")
		var enemy_field = root.get_node("EnemyField")

		var siblings := []
		if owner.begins_with("Player"):
			siblings = [
				player_field.get_node_or_null("PlayerFireSPicon"),
				player_field.get_node_or_null("PlayerWindSPicon"),
				player_field.get_node_or_null("PlayerEarthSPicon"),
				player_field.get_node_or_null("PlayerWaterSPicon")
			]
		else:
			siblings = [
				enemy_field.get_node_or_null("EnemyFireSPicon"),
				enemy_field.get_node_or_null("EnemyWindSPicon"),
				enemy_field.get_node_or_null("EnemyEarthSPicon"),
				enemy_field.get_node_or_null("EnemyWaterSPicon")
			]

		var other_visible := false
		for s in siblings:
			if s != null and s != icon_node and s.visible:
				other_visible = true
				break

		# 🔁 Sposta solo se NON era già visibile
		if not was_visible and other_visible:
			icon_node.position.x += offset_x * direction
			label_node.position.x += offset_x * direction

	# 🔢 Logica animazione
	var current_sp := int(label_node.text)
	var original_icon_modulate := icon_node.self_modulate
	var base_scale := Vector2(0.2, 0.2)
	if is_elemental:
		base_scale = Vector2(0.15, 0.15)

	var steps = abs(amount)
	var flash_color := Color(2.0, 2.0, 2.0, 2.0)

	# 🔼 Porta icona e label in primo piano
	icon_node.z_index = 705
	label_node.z_index = 706

	for i in range(steps):
		if amount > 0:
			current_sp += 1
		elif amount < 0:
			current_sp -= 1

		label_node.text = str(current_sp)

		var tween := get_tree().create_tween()
		tween.set_parallel(true)

		var text_color := Color(1, 1, 1)
		if amount > 0:
			text_color = Color(0.2, 1.0, 0.2)
		elif amount < 0:
			text_color = Color(1.0, 0.4, 0.2)

		tween.tween_property(icon_node, "scale", base_scale * 2.0, 0.1)
		tween.tween_property(icon_node, "self_modulate", flash_color, 0.1)
		tween.tween_property(label_node, "self_modulate", text_color, 0.1)
		tween.chain().tween_property(icon_node, "scale", base_scale, 0.1)
		tween.tween_property(icon_node, "self_modulate", original_icon_modulate, 0.1)

		await get_tree().create_timer(delay).timeout

	# 🔽 Ripristina Z-index originale
	icon_node.z_index = 700
	label_node.z_index = 701





func update_all_aura_bonuses(delta_sp: float, sp_type: String = "Generic", sp_owner_is_enemy: bool = false):
	print("\n🔄 [AURA UPDATE] Aggiornamento aure | Tipo SP:", sp_type, "| ΔSP:", delta_sp, "| SP lato nemico:", sp_owner_is_enemy)

	if delta_sp == 0:
		print("⚠️ Nessuna variazione di SP, skip aggiornamento aure.")
		return

	var all_auras = player_spells_on_field + opponent_spells_on_field
	
	print("📦 [AURA UPDATE] Totale aure sul campo:", all_auras.size())

	for aura in all_auras:
		if not is_instance_valid(aura):
			continue
		if aura.card_data.effect_type != "Aura" or aura.card_data.card_class != "ContinuousSpell":
			continue

		# 🔹 Determina se deve essere aggiornata in base al lato SP
		if sp_owner_is_enemy and not aura.is_enemy_card():
			print("🚫 [AURA UPDATE] Aura", aura.card_data.card_name, "è del player, ma SP modificato è nemico → skip")
			continue
		elif not sp_owner_is_enemy and aura.is_enemy_card():
			print("🚫 [AURA UPDATE] Aura", aura.card_data.card_name, "è nemica, ma SP modificato è del player → skip")
			continue

		# 💠 FILTRO ELEMENTALE
		if sp_type != "Generic" and aura.card_data.card_attribute != sp_type:
			print("🚫 [AURA UPDATE] Aura", aura.card_data.card_name, 
				"ignora ΔSP tipo", sp_type, "(ha attributo", aura.card_data.card_attribute, ")")
			continue

		var owner_is_enemy = aura.is_enemy_card()
		var delta_bonus = aura.card_data.spell_multiplier * delta_sp

		#print("✨ [AURA UPDATE APPLY]",
			#" Nome:", aura.card_data.card_name,
			#" | Owner:", ("Enemy" if owner_is_enemy else "Player"),
			#" | Attributo:", aura.card_data.card_attribute,
			#" | SP tipo:", sp_type,
			#" | ΔSP:", delta_sp,
			#" | Moltiplicatore:", aura.card_data.spell_multiplier,
			#" | ΔBonus:", delta_bonus)
#
		# ⚡ AGGIORNA SEMPRE LA MAGNITUDE DELL’AURA
		var current_magnitude = 0.0
		if aura.has_meta("current_effective_magnitude"):
			current_magnitude = aura.get_meta("current_effective_magnitude")
		else:
			current_magnitude = aura.card_data.effect_magnitude_1

		# 📈 Calcola la nuova magnitude in base alla variazione SP
		var new_magnitude = current_magnitude + (aura.card_data.spell_multiplier * delta_sp)
		aura.set_meta("current_effective_magnitude", new_magnitude)
		print("💫 [AURA MAGNITUDE UPDATE] ", aura.card_data.card_name,
			"| Vecchia:", current_magnitude,
			"| ΔSP:", delta_sp,
			"| Mult:", aura.card_data.spell_multiplier,
			"| Nuova:", new_magnitude)

		# Se l’aura non ha target, esci prima ma la magnitude resta aggiornata
		if aura.aura_affected_cards.is_empty():
			print("📭 [AURA MAGNITUDE ONLY] Nessuna creatura colpita da", aura.card_data.card_name, "→ solo aggiornamento magnitude")
			continue

		for entry in aura.aura_affected_cards:
			print("\n🧩 [DEBUG ENTRY] Raw entry:", entry)

			if typeof(entry) != TYPE_DICTIONARY:
				print("🚫 [AURA ENTRY] entry non è un dizionario →", typeof(entry))
				continue

			if not entry.has("card"):
				print("🚫 [AURA ENTRY] Manca chiave 'card' →", entry)
				continue

			var affected = entry.card

			if not is_instance_valid(affected):
				print("🚫 [AURA ENTRY] Carta non valida o già rimossa →", entry)
				continue

			print("✅ [AURA ENTRY VALIDA]",
				"\n   • Card name:", affected.card_data.card_name,
				"\n   • Owner enemy:", affected.is_enemy_card(),
				"\n   • Current ATK:", affected.card_data.attack,
				"\n   • Current HP:", affected.card_data.health,
				"\n   • Voided ATK:", affected.card_data.voided_atk
			)
 
			entry.magnitude += delta_bonus  #FONDAMENTALE
			print("MAGNITUDE = :",entry.magnitude)
			
			

				
			print("🧾 [AURA ENTRY DEBUG]", aura.card_data.card_name, "| Effect1:", aura.card_data.effect_1,
			"| Total entries:", aura.aura_affected_cards.size(),
			"| Card affected:", affected.card_data.card_name)
			# 🔁 Scorri tutti gli effetti della carta Aura
			for i in range(1, 2):
				var effect_name = aura.card_data.get("effect_%d" % i)
				if effect_name == "None":
					continue
				
				match effect_name:
					# 🟩 BUFF
					"BuffAtk":
						if delta_bonus > 0:
							# 🟩 Aumento dell'attacco (consuma voided_atk)
							var voided_atk = affected.card_data.voided_atk
							var effective_buff = max(0, delta_bonus - voided_atk)
							affected.card_data.attack += effective_buff
							affected.card_data.max_attack += effective_buff
							affected.card_data.voided_atk = max(0, voided_atk - delta_bonus)
							print("🟩 [AURA BUFF ATK] +", effective_buff, "ATK | voided ↓:", affected.card_data.voided_atk)

						elif delta_bonus < 0:
							# 💀 Il buff si riduce → comportati come un debuff
							var magnitude = abs(delta_bonus)
							var old_atk = affected.card_data.attack
							var old_max_atk = affected.card_data.max_attack

							affected.card_data.max_attack = max(0, affected.card_data.max_attack - magnitude)
							affected.card_data.attack = max(0, affected.card_data.attack - magnitude)

							var atk_loss = old_atk - affected.card_data.attack
							var voided_increase = max(0, magnitude - atk_loss)

							affected.card_data.voided_atk += voided_increase
							affected.card_data.voided_atk = max(0, affected.card_data.voided_atk)

							print("💀 [AURA BUFF→DEBUFF ATK] -", atk_loss, "ATK | voided +", voided_increase,
								"→", affected.card_data.voided_atk)

					"Buff":
						if delta_bonus > 0:
							var voided_atk = affected.card_data.voided_atk
							var effective_buff = max(0, delta_bonus - voided_atk)
							affected.card_data.attack += effective_buff
							affected.card_data.max_attack += effective_buff
							affected.card_data.health += delta_bonus
							affected.card_data.max_health += delta_bonus
							affected.card_data.voided_atk = max(0, voided_atk - delta_bonus)
							print("🟩 [AURA BUFF] +", effective_buff, "ATK / +", delta_bonus, "HP | voided ↓:", affected.card_data.voided_atk)

						elif delta_bonus < 0:
							var magnitude = abs(delta_bonus)
							var old_atk = affected.card_data.attack
							var new_atk = max(0, old_atk - magnitude)
							var atk_loss = old_atk - new_atk
							var voided_increase = max(0, magnitude - atk_loss)

							affected.card_data.attack = new_atk
							affected.card_data.max_attack = max(0, affected.card_data.max_attack - magnitude)
							affected.card_data.health = max(0, affected.card_data.health - magnitude)
							affected.card_data.max_health = max(0, affected.card_data.max_health - magnitude)
							affected.card_data.voided_atk += voided_increase

							print("💀 [AURA BUFF→DEBUFF] -", atk_loss, "ATK /", magnitude, "HP | voided +", voided_increase,
								"→", affected.card_data.voided_atk)

					
					"BuffHp":
						affected.card_data.health += delta_bonus
						affected.card_data.max_health += delta_bonus
					
					"BuffArmour":
						affected.card_data.armour += delta_bonus

					# 💀 DEBUFF — solo il peer owner della carta
					"DebuffAtk":
						if delta_bonus > 0:
							 #💀 SP aumenta → debuff si intensifica
							var magnitude = delta_bonus
							var old_atk = affected.card_data.attack
							var old_max = affected.card_data.max_attack

							affected.card_data.max_attack = max(0, old_max - magnitude)
							affected.card_data.attack = max(0, old_atk - magnitude)

							var atk_loss = old_atk - affected.card_data.attack
							var voided_increase = max(0, magnitude - atk_loss)

							affected.card_data.voided_atk += voided_increase
							affected.card_data.voided_atk = max(0, affected.card_data.voided_atk)

							print("💀 [AURA ΔDEBUFF ATK+] -", atk_loss, "ATK | voided +", voided_increase,
								"→", affected.card_data.voided_atk)


						elif delta_bonus < 0:
						# 💫 SP diminuisce → debuff si indebolisce (recupero)
							var magnitude = abs(delta_bonus)
							var old_atk = affected.card_data.attack
							var old_max = affected.card_data.max_attack
							var voided_atk = affected.card_data.voided_atk

							print("🧩 [AURA ΔDEBUFF ATK-RECOVER START]",
								"\n   • Carta:", affected.card_data.card_name,
								"\n   • ΔBonus:", delta_bonus,
								"\n   • Magnitude:", magnitude,
								"\n   • ATK prima:", old_atk,
								"\n   • Max ATK prima:", old_max,
								"\n   • Voided prima:", voided_atk
							)

							# Calcolo recupero effettivo
							var effective_recovery = max(0, magnitude - voided_atk)
							print("   → Calcolo recovery: max(0, ", magnitude, " - ", voided_atk, ") = ", effective_recovery)

							# Ripristina ATK e riduce voided
							affected.card_data.attack += effective_recovery
							affected.card_data.max_attack += effective_recovery
							affected.card_data.voided_atk = max(0, voided_atk - magnitude)

							print("🧩 [AURA ΔDEBUFF ATK-RECOVER RESULT]",
								"\n   • Recupero effettivo:", effective_recovery,
								"\n   • ATK dopo:", affected.card_data.attack,
								"\n   • Max ATK dopo:", affected.card_data.max_attack,
								"\n   • Voided dopo:", affected.card_data.voided_atk
							)




					"DebuffHp":
						var old_hp = affected.card_data.health
						affected.card_data.max_health = max(0, affected.card_data.max_health - delta_bonus)
						var hp_loss = old_hp - affected.card_data.health
						print("💀 [AURA ΔDebuffHp OWNER]", affected.card_data.card_name, "HP -", hp_loss, "(Δ", delta_bonus, ")")


					"Debuff":
						if delta_bonus > 0:
							# 💀 SP aumenta → debuff più forte
							var magnitude = delta_bonus
							var old_atk = affected.card_data.attack
							var old_hp = affected.card_data.health
							var old_max_atk = affected.card_data.max_attack
							var old_max_hp = affected.card_data.max_health

							affected.card_data.max_attack = max(0, old_max_atk - magnitude)
							affected.card_data.max_health = max(0, old_max_hp - magnitude)
							affected.card_data.attack = max(0, old_atk - magnitude)
							affected.card_data.health = max(0, old_hp - magnitude)

							var atk_loss = old_atk - affected.card_data.attack
							var hp_loss = old_hp - affected.card_data.health

							var voided_increase = max(0, magnitude - atk_loss)
							affected.card_data.voided_atk += voided_increase
							affected.card_data.voided_atk = max(0, affected.card_data.voided_atk)

							print("💀 [AURA ΔDEBUFF+] -", atk_loss, "ATK / -", hp_loss, "HP | voided +", voided_increase,
								"→", affected.card_data.voided_atk)

						elif delta_bonus < 0:
							# 💫 SP diminuisce → debuff si indebolisce (recupero)
							var magnitude = abs(delta_bonus)
							var voided_atk = affected.card_data.voided_atk
							var effective_recovery = max(0, magnitude - voided_atk)

							affected.card_data.attack += effective_recovery
							affected.card_data.max_attack += effective_recovery
							affected.card_data.health += magnitude
							affected.card_data.max_health += magnitude
							affected.card_data.voided_atk = max(0, voided_atk - magnitude)

							print("🧩 [AURA ΔDEBUFF-RECOVER] +", effective_recovery, "ATK / +", magnitude, "HP | voided ↓:", affected.card_data.voided_atk)




			# 🔄 Aggiorna i buff/debuff attivi registrati
			for buff_entry in affected.card_data.active_buffs:
				if typeof(buff_entry) == TYPE_DICTIONARY and buff_entry.has("source_card") and is_instance_valid(buff_entry.source_card):
					if buff_entry.source_card == aura:
						match aura.card_data.effect_1:
							"BuffAtk":
								buff_entry.magnitude_atk += delta_bonus
							"BuffHp":
								buff_entry.magnitude_hp += delta_bonus
							"BuffArmour":
								buff_entry.magnitude_armour += delta_bonus
							"Buff":
								buff_entry.magnitude_atk += delta_bonus
								buff_entry.magnitude_hp += delta_bonus


			for debuff_entry in affected.card_data.active_debuffs:
				if typeof(debuff_entry) == TYPE_DICTIONARY and debuff_entry.has("source_card") and is_instance_valid(debuff_entry.source_card):
					if debuff_entry.source_card == aura:
						match aura.card_data.effect_1:
							"DebuffAtk":
								debuff_entry.magnitude_atk += delta_bonus
								
							"DebuffHp":
								debuff_entry.magnitude_hp += delta_bonus

							"Debuff":
								debuff_entry.magnitude_atk += delta_bonus
								debuff_entry.magnitude_hp += delta_bonus


			# 🧩 Clamp finale di sicurezza
			if affected.card_data.attack < 0:
				affected.card_data.attack = 0
			if affected.card_data.health < 0:
				affected.card_data.health = 0
			if affected.card_data.armour < 0:
				affected.card_data.armour = 0  # 👈 aggiunta per evitare valori negativi di armour


			affected.update_card_visuals()





func check_threshold_condition(source_card: Node, target_card: Node, effect_index: int) -> bool:
	if not is_instance_valid(source_card) or not is_instance_valid(target_card):
		return true  # sicurezza

	var card_data = source_card.card_data
	if card_data == null:
		return true

	var threshold_type = ""
	var threshold_value = 0

	# 📦 Seleziona threshold corretto
	match effect_index:
		1:
			threshold_type = card_data.effect_1_threshold_type
			threshold_value = card_data.effect_1_threshold
		2:
			threshold_type = card_data.effect_2_threshold_type
			threshold_value = card_data.effect_2_threshold
		3:
			threshold_type = card_data.effect_3_threshold_type
			threshold_value = card_data.effect_3_threshold
		4:
			threshold_type = card_data.effect_4_threshold_type
			threshold_value = card_data.effect_4_threshold
		_:
			return true

	# 🚫 Nessun tipo definito → effetto sempre valido
	if threshold_type == "None" or threshold_type == "":
		return true

	var atk = target_card.card_data.attack
	var hp = target_card.card_data.health
	var attribute = target_card.card_data.card_attribute

	# ⚡️ ThresholdSpellPower scaling
	if card_data.scaling_1 == "ThresholdSpellPower" or card_data.scaling_2 == "ThresholdSpellPower":
		var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
		if combat_manager == null:
			push_warning("⚠️ CombatManager non trovato per ThresholdSpellPower scaling.")
			return true

		var is_attacker = multiplayer.get_unique_id() == source_card.card_data.owner_id if source_card.card_data.has_method("owner_id") else true

		var spell_power_total = 0
		if is_attacker:
			spell_power_total = combat_manager.player_SP
			match card_data.card_attribute:
				"Fire": spell_power_total += combat_manager.player_FireSP
				"Water": spell_power_total += combat_manager.player_WaterSP
				"Earth": spell_power_total += combat_manager.player_EarthSP
				"Wind": spell_power_total += combat_manager.player_WindSP
		else:
			spell_power_total = combat_manager.enemy_SP
			match card_data.card_attribute:
				"Fire": spell_power_total += combat_manager.enemy_FireSP
				"Water": spell_power_total += combat_manager.enemy_WaterSP
				"Earth": spell_power_total += combat_manager.enemy_EarthSP
				"Wind": spell_power_total += combat_manager.enemy_WindSP

		# aggiungi spell power base della carta
		spell_power_total += card_data.base_spell_power

		# Calcola bonus finale da spell power
		var bonus = spell_power_total * card_data.spell_multiplier
		var threshold_final = threshold_value + bonus

		print("🔮 [ThresholdSpellPower] Base:", threshold_value,
			" | SP Totale:", spell_power_total,
			" | Mult:", card_data.spell_multiplier,
			" | Threshold finale:", threshold_final)

		threshold_value = threshold_final

	# --- Verifica effettiva ---
	match threshold_type:
		"ApplyThresholdOverATK":
			if atk >= threshold_value:
				return true
			else:
				print("❌ Threshold non superato (ATK <", threshold_value, "):", atk)
				return false

		"ApplyThresholdUnderATK":
			if atk <= threshold_value:
				return true
			else:
				print("❌ Threshold non soddisfatto (ATK >", threshold_value, "):", atk)
				return false

		"ApplyThresholdOverHP":
			if hp >= threshold_value:
				return true
			else:
				print("❌ Threshold non superato (HP <", threshold_value, "):", hp)
				return false

		"ApplyThresholdUnderHP":
			if hp <= threshold_value:
				return true
			else:
				print("❌ Threshold non soddisfatto (HP >", threshold_value, "):", hp)
				return false

		"ApplyToFire":
			return attribute == "Fire"
		"ApplyToEarth":
			return attribute == "Earth"
		"ApplyToWater":
			return attribute == "Water"
		"ApplyToWind":
			return attribute == "Wind"

		"ApplyToFrozen":
			for d in target_card.card_data.active_debuffs:
				if typeof(d) == TYPE_DICTIONARY and d.get("type", "") == "Frozen":
					print("❄️ Threshold ApplyToFrozen soddisfatto per:", target_card.card_data.card_name)
					return true
			print("🚫 Threshold ApplyToFrozen fallito: target non è Frozen →", target_card.card_data.card_name)
			return false

		_:
			return true




func register_continuous_aura_targets(source_card, magnitude: int, is_attacker: bool, t_subtype: String) -> void:
	if source_card.card_data.effect_type != "Aura" or source_card.card_data.card_class != "ContinuousSpell":
		return  # ❌ Non è un’aura continua, esci

	print("✨ [AURA] Applicazione Aura:", source_card.card_data.card_name, "| Subtype:", t_subtype)

	var combat_manager = $"../CombatManager"
	if combat_manager == null:
		push_warning("⚠️ CombatManager non trovato per registrazione aura")
		return

	var aura_targets: Array = []

	# 🎯 Seleziona le carte in base al t_subtype
	match t_subtype:
		"AllEnemyCreatures":
			if is_attacker:
				aura_targets = combat_manager.opponent_creatures_on_field.duplicate()
			else:
				aura_targets = combat_manager.player_creatures_on_field.duplicate()

		"AllEnemyATKCreatures":
			if is_attacker:
				for card in combat_manager.opponent_creatures_on_field:
					if card.position_type == "attack":
						aura_targets.append(card)
			else:
				for card in combat_manager.player_creatures_on_field:
					if card.position_type == "attack":
						aura_targets.append(card)

		"AllEnemyDEFCreatures":
			if is_attacker:
				for card in combat_manager.opponent_creatures_on_field:
					if card.position_type == "defense":
						aura_targets.append(card)
			else:
				for card in combat_manager.player_creatures_on_field:
					if card.position_type == "defense":
						aura_targets.append(card)

		"AllAllyCreatures":
			if is_attacker:
				aura_targets = combat_manager.player_creatures_on_field.duplicate()
			else:
				aura_targets = combat_manager.opponent_creatures_on_field.duplicate()

		"AllCreatures":
			for card in combat_manager.player_creatures_on_field:
				aura_targets.append(card)
			for card in combat_manager.opponent_creatures_on_field:
				aura_targets.append(card)

		"AllAllyDEFCreatures":
			if is_attacker:
				for card in combat_manager.player_creatures_on_field:
					if card.position_type == "defense":
						aura_targets.append(card)
			else:
				for card in combat_manager.opponent_creatures_on_field:
					if card.position_type == "defense":
						aura_targets.append(card)
		# 🌋 NUOVI SUBTYPE PER ELEMENTI ----------------------------------------------------
		"AllFireCreatures":
			for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
				if card.card_data.card_attribute == "Fire":
					aura_targets.append(card)

		"AllEarthCreatures":
			for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
				if card.card_data.card_attribute == "Earth":
					aura_targets.append(card)

		"AllWaterCreatures":
			for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
				if card.card_data.card_attribute == "Water":
					aura_targets.append(card)

		"AllWindCreatures":
			for card in combat_manager.player_creatures_on_field + combat_manager.opponent_creatures_on_field:
				if card.card_data.card_attribute == "Wind":
					aura_targets.append(card)

		# (facoltativo) Se vuoi anche quelli solo nemici:
		"AllEnemyFireCreatures":
			if is_attacker:
				for card in combat_manager.opponent_creatures_on_field:
					if card.card_data.card_attribute == "Fire":
						aura_targets.append(card)
			else:
				for card in combat_manager.player_creatures_on_field:
					if card.card_data.card_attribute == "Fire":
						aura_targets.append(card)

		"AllEnemyEarthCreatures":
			if is_attacker:
				for card in combat_manager.opponent_creatures_on_field:
					if card.card_data.card_attribute == "Earth":
						aura_targets.append(card)
			else:
				for card in combat_manager.player_creatures_on_field:
					if card.card_data.card_attribute == "Earth":
						aura_targets.append(card)

		"AllEnemyWaterCreatures":
			if is_attacker:
				for card in combat_manager.opponent_creatures_on_field:
					if card.card_data.card_attribute == "Water":
						aura_targets.append(card)
			else:
				for card in combat_manager.player_creatures_on_field:
					if card.card_data.card_attribute == "Water":
						aura_targets.append(card)

		"AllEnemyWindCreatures":
			if is_attacker:
				for card in combat_manager.opponent_creatures_on_field:
					if card.card_data.card_attribute == "Wind":
						aura_targets.append(card)
			else:
				for card in combat_manager.player_creatures_on_field:
					if card.card_data.card_attribute == "Wind":
						aura_targets.append(card)

		_:
			print("⚠️ [AURA] Subtype non gestito per l’aura:", t_subtype)
			return
	# ---------------------------------------------------------------------------

	# 🧹 Pulisci vecchie associazioni e registra nuove carte affette
	for c in aura_targets:
		if not is_instance_valid(c):
			continue
		if c.card_data.health <= 0:
			continue

		if not source_card.aura_affected_cards.any(func(entry):
			return typeof(entry) == TYPE_DICTIONARY and entry.card == c):
			var new_entry = {
				"card": c,
				"magnitude": magnitude
			}
			source_card.aura_affected_cards.append(new_entry)

			print("🔗 [AURA LINK] Aggiunta", c.card_data.card_name,
				"tra le carte influenzate da", source_card.card_data.card_name,
				"(mag:", magnitude, ")")

	# 💫 Se nessuna carta è valida, salva comunque la magnitude
	if source_card.aura_affected_cards.is_empty():
		source_card.set_meta("current_effective_magnitude", magnitude)
		print("💫 [AURA INIT] Nessuna carta valida al momento — magnitude salvata:", magnitude)

	print("📜 [AURA] Carte influenzate da", source_card.card_data.card_name, ":",
		source_card.aura_affected_cards.map(func(x):
			return "%s (mag:%s)" % [x.card.card_data.card_name, str(x.magnitude)]))



func cleanup_voided_atk_and_tooltips(target_card: Node) -> void:
	if not is_instance_valid(target_card):
		return

	var cd = target_card.card_data
	var max_atk = cd.max_attack  # 🧩 già aggiornato dinamicamente nel tuo sistema
	# 🧹 Pulizia opzionale voided_atk (solo se vuoi mantenerla)
	if target_card.has_meta("voided_atk") and cd.attack > 0:
		print("🧹 [AURA CLEANUP] voided_atk rimosso da", cd.card_name)
		target_card.remove_meta("voided_atk")

		for entry in cd.get_debuffs_array():
			if typeof(entry) == TYPE_DICTIONARY and entry.has("voided_atk"):
				entry.erase("voided_atk")
	# 🔄 Riallinea eventuali debuff da Aura
	for debuff_dict in cd.get_debuffs_array():
		if typeof(debuff_dict) == TYPE_DICTIONARY \
		and debuff_dict.has("source_card") \
		and is_instance_valid(debuff_dict["source_card"]) \
		and debuff_dict["source_card"].card_data.effect_type == "Aura" \
		and debuff_dict["type"] in ["Debuff", "DebuffAtk", "DebuffHp"]:

			var aura_card = debuff_dict["source_card"]
			var old_value = debuff_dict.get("magnitude_atk", 0)
			var new_value = old_value

			if aura_card.has_meta("current_effective_magnitude"):
				var eff_mag = aura_card.get_meta("current_effective_magnitude")

				# 💡 Se la carta ha ancora ATK > 0 → mostra l'effetto completo
				# Altrimenti cappalo al max_attack (evita -600 su carta da 400)
				if cd.attack > 0:
					new_value = eff_mag
				else:
					new_value = min(eff_mag, max_atk)

				print("⚖️ [AURA SYNC] Debuff su", cd.card_name,
					"→ eff_mag:", eff_mag,
					"| atk:", cd.attack,
					"| max_atk:", max_atk,
					"| mostrato:", new_value)
			else:
				print("⚠️ [AURA SYNC] Aura", aura_card.card_data.card_name,
					"non ha meta 'current_effective_magnitude' — magnitude invariata.")
				new_value = old_value

			debuff_dict["magnitude_atk"] = new_value





func remove_aura_effects(card: Node, specific_target: Node = null) -> void:
	if not card or not card.card_data:
		return

	if card.card_data.effect_type != "Aura" or card.card_data.card_class != "ContinuousSpell":
		print("RITORNO DA REMOVE")
		return

	print("💨 [AURA HELPER] Rimozione Aura:", card.card_data.card_name)

	for entry in card.aura_affected_cards:
		var affected: Node = null
		var applied_magnitude: float = 0.0
		var voided_atk: float = 0.0

		# 🧩 Compatibilità con nuovo e vecchio formato
		if typeof(entry) == TYPE_DICTIONARY:
			if entry.has("card"):
				affected = entry.card
			if entry.has("magnitude"):
				applied_magnitude = entry.magnitude
			if entry.has("voided_atk"):
				voided_atk = entry.voided_atk
		else:
			affected = entry
			applied_magnitude = card.card_data.effect_magnitude_1

		# 🔍 Se specific_target è fornito, salta tutte le altre carte
		if specific_target != null and affected != specific_target:
			continue

		if not is_instance_valid(affected):
			continue

		print("⛔ [AURA][RPC] Rimuovo effetto da:", affected.card_data.card_name,
			"(mag:", applied_magnitude, ", voided_atk:", voided_atk, ")")

		# 💡 Reset voided_atk se serve
		if affected.card_data.attack > 0:
			print("🧹 [AURA CLEANUP] voided_atk azzerato su", affected.card_data.card_name,
				"(prima:", affected.card_data.voided_atk, ")")
			affected.card_data.voided_atk = 0.0
			if typeof(entry) == TYPE_DICTIONARY and entry.has("voided_atk"):
				entry.erase("voided_atk")

		# 🔄 Ciclo su tutti e 4 gli effetti della carta Aura
		for i in range(1, 6):
			var effect_name = card.card_data.get("effect_%d" % i)
			if effect_name == "None":
				continue


			# 🎯 Verifica subtype prima di applicare la rimozione
			var t_sub = card.card_data.get("t_subtype_%d" % i)
			if specific_target == null and not card._aura_target_matches_subtype(affected, t_sub):
				print("🚫 [AURA REMOVE] Target non combacia col subtype:", t_sub, "→ salto rimozione per", affected.card_data.card_name)
				continue


			# 📏 Magnitude effettiva
			var magnitude := 0.0
			if typeof(entry) == TYPE_DICTIONARY:
				if entry.has("magnitude"):
					magnitude = entry.magnitude
				elif entry.has("magnitudes") and typeof(entry.magnitudes) == TYPE_ARRAY and entry.magnitudes.size() >= i:
					magnitude = entry.magnitudes[i - 1]
			else:
				magnitude = card.card_data.get("effect_magnitude_%d" % i)

			print("📏 [AURA REMOVE RPC] Effetto:", effect_name, "| Magnitude effettiva:", magnitude)

			match effect_name:
				"Buff":
					var old_atk = affected.card_data.attack
					var old_hp = affected.card_data.health
					var old_max_hp = affected.card_data.max_health

					affected.card_data.attack = max(affected.card_data.attack - applied_magnitude, 0)
					affected.card_data.max_attack = max(affected.card_data.max_attack - applied_magnitude, 0)
					affected.card_data.max_health = max(0, affected.card_data.max_health - applied_magnitude)
					if affected.card_data.health > affected.card_data.max_health:
						affected.card_data.health = affected.card_data.max_health

					var atk_loss = old_atk - affected.card_data.attack
					var hp_loss = old_max_hp - affected.card_data.max_health
					var voided_increase = max(0, applied_magnitude - atk_loss)
					affected.card_data.voided_atk += voided_increase

					print("💀 [BUFF REMOVE]", affected.card_data.card_name, "(-", atk_loss, "ATK / -", hp_loss, "Max HP)")

				"BuffAtk":
					var old_atk = affected.card_data.attack
					affected.card_data.max_attack = max(affected.card_data.max_attack - applied_magnitude, 0)
					affected.card_data.attack = max(affected.card_data.attack - applied_magnitude, 0)
					var atk_loss = old_atk - affected.card_data.attack
					var voided_increase = max(0, applied_magnitude - atk_loss)
					affected.card_data.voided_atk += voided_increase
					print("💀 [BUFFATK REMOVE]", affected.card_data.card_name, "(-", atk_loss, "ATK)")

				"BuffHp":
					var old_max_hp = affected.card_data.max_health
					affected.card_data.max_health = max(0, affected.card_data.max_health - magnitude)
					if affected.card_data.health > affected.card_data.max_health:
						affected.card_data.health = affected.card_data.max_health
					print("💔 [AURA BUFFHP REMOVE] Max Health -", magnitude, "(da", old_max_hp, "a", affected.card_data.max_health, ") su", affected.card_data.card_name)

				"BuffArmour":
					var old_armour = affected.card_data.armour
					affected.card_data.armour = max(0, affected.card_data.armour - magnitude)
					print("💔 [AURA BUFFARMOUR REMOVE] Armour -", magnitude, "(da", old_armour, "a", affected.card_data.armour, ") su", affected.card_data.card_name)

				"DebuffAtk":
					var effective_recover = max(magnitude - affected.card_data.voided_atk, 0)
					affected.card_data.max_attack += effective_recover
					affected.card_data.attack += effective_recover
					affected.card_data.voided_atk = max(0, affected.card_data.voided_atk - magnitude)

				"DebuffHp":
					affected.card_data.max_health += magnitude
					affected.card_data.health += magnitude

				"Debuff":
					var effective_recover2 = max(magnitude - affected.card_data.voided_atk, 0)
					affected.card_data.max_attack += effective_recover2
					affected.card_data.attack += effective_recover2
					affected.card_data.max_health += magnitude
					affected.card_data.health += magnitude
					affected.card_data.voided_atk = max(0, affected.card_data.voided_atk - magnitude)

		# 🔒 Clamp e aggiornamento
		if affected.card_data.attack < 0:
			affected.card_data.attack = 0
		if affected.card_data.health < 0:
			affected.card_data.health = 0

		affected.card_data.remove_buff_by_source(card)
		affected.card_data.remove_debuff_by_source(card)
		affected.update_card_visuals()

		# 🌐 Sincronizza rete
		var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
		if combat_manager:
			combat_manager.rpc("update_card_stats", affected.name, affected.card_data.attack, affected.card_data.health)

	# Se era mirata a una sola carta, rimuovi solo quella entry
	if specific_target != null:
		var to_remove = []
		for entry in card.aura_affected_cards:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("card") and entry.card == specific_target:
				to_remove.append(entry)
		for e in to_remove:
			card.aura_affected_cards.erase(e)
	else:
		card.aura_affected_cards.clear()





func remove_enchant_effects(enchant_card: Node, target: Node, condition_source: Node = null) -> void:
	if not is_instance_valid(enchant_card) or not is_instance_valid(target):
		return
	if not enchant_card.card_data or not target.card_data:
		return

	print("🛠️ [REMOVE ENCHANT EFFECTS] Rimozione effetti di", enchant_card.card_data.card_name, "da", target.card_data.card_name)

	# --- 🔹 Identifica eventuale BuffTalent associato a questa enchant
	var has_talent_buff := false
	var talent_buff_name := ""
	for buff in target.card_data.get_buffs_array():
		if typeof(buff) == TYPE_DICTIONARY and buff.get("type", "") == "BuffTalent" and buff.get("source_card") == enchant_card:
			has_talent_buff = true
			talent_buff_name = target.card_data.talent_from_buff
			break

	# --- 🧩 LOGICA DI RIMOZIONE BUFF/DEBUFF
	var mods = target.card_data.all_stat_modifiers
	var index_to_remove := -1
	var mod_type := ""

	for i in range(mods.size()):
		var mod = mods[i]
		if typeof(mod) == TYPE_DICTIONARY and mod.get("source_card") == enchant_card:
			mod_type = mod.get("type", "")
			index_to_remove = i
			break

	if index_to_remove != -1:
		var removed_mod = mods[index_to_remove]
		var magnitude = removed_mod.get("magnitude_atk", 0)
		var magnitude_hp = removed_mod.get("magnitude_hp", 0)
		var magnitude_armour = removed_mod.get("magnitude_armour", 0)
		
		# --- 🔸 BUFF / BUFFATK → logica avanzata (compensazione + voided_atk)
		if mod_type in ["Buff", "BuffAtk"]:
			print("🧩 [REMOVE LOGIC] Rimozione", mod_type, "ATK:", magnitude)

			# Calcola buff/debuff residui
			var total_buffs := 0
			var total_debuffs := 0
			for j in range(mods.size() - 1, -1, -1):  # 🔁 SCORRE A RITROSO
				if j == index_to_remove:
					continue
				var m = mods[j]
				if typeof(m) != TYPE_DICTIONARY:
					continue
				if m.get("type") == "Buff":
					total_buffs += m.get("magnitude_atk", 0)
				elif m.get("type") == "Debuff":
					total_debuffs += abs(m.get("magnitude_atk", 0))

			var net = total_buffs - total_debuffs
			print("📊 Somma buff residui:", total_buffs, " | Somma debuff residui:", total_debuffs, " | Netto:", net)

			# --- 🔸 Attacco
			var atk_before = target.card_data.attack
			var atk_after = max(0, atk_before - magnitude)
			var lost_amount = atk_before - atk_after
			var leftover_magnitude = magnitude - lost_amount
			target.card_data.attack = atk_after
			target.card_data.max_attack = max(0, target.card_data.max_attack - lost_amount)

			# --- 🔸 Punti Vita (HP)
			if mod_type == "Buff":
				# 🔹 Rimuove solo la max_health (non la health attuale)
				var old_max_hp = target.card_data.max_health
				target.card_data.max_health = max(0, target.card_data.max_health - magnitude)
				if target.card_data.health > target.card_data.max_health:
					target.card_data.health = target.card_data.max_health
				print("💔 [REMOVE LOGIC] Buff HP rimossa: max_health -", magnitude, "(da", old_max_hp, "a", target.card_data.max_health, ") su", target.card_data.card_name)
			else:
				# BuffAtk → nessuna modifica alla vita
				pass

			print("💔 Rimosso ATK:", lost_amount, " | Rimanente magnitude:", leftover_magnitude)

			# --- Compensazione su debuff se prevalgono
			if net < 0 and leftover_magnitude > 0:
				print("⚖️ Prevalenza di debuff → inizio compensazione su debuff")
				for j in range(mods.size()):
					if j == index_to_remove:
						continue
					var m = mods[j]
					if typeof(m) != TYPE_DICTIONARY or m.get("type") != "Debuff":
						continue
					var debuff_val = abs(m.get("magnitude_atk", 0))
					if debuff_val <= 0:
						continue

					var reduction = min(leftover_magnitude, debuff_val)
					m["magnitude_atk"] = debuff_val - reduction
					mods[j] = m
					leftover_magnitude -= reduction
					print("➡️ Debuff ridotto di", reduction, "→ nuovo valore:", m["magnitude_atk"])
					if leftover_magnitude <= 0:
						break

			# --- Sincronizza debuff attivi
			for d_group in [
				target.card_data.active_debuffs,
				target.card_data.active_debuffs_until_endphase,
				target.card_data.active_debuffs_until_battlephase,
				target.card_data.active_debuffs_until_battlestep,
				target.card_data.active_debuffs_from_while_effects,
			]:
				for d in d_group:
					if typeof(d) != TYPE_DICTIONARY:
						continue
					var src_card = d.get("source_card")
					for m in mods:
						if typeof(m) == TYPE_DICTIONARY and m.get("type") == "Debuff" and m.get("source_card") == src_card:
							var updated_val = abs(m.get("magnitude_atk", d.get("magnitude_atk", 0)))
							if d["magnitude_atk"] != updated_val:
								print("🔁 [SYNC] Aggiornato debuff attivo da", src_card.card_data.card_name, "→", updated_val)
								d["magnitude_atk"] = updated_val
							break

			# --- Leftover → voided_atk
			if leftover_magnitude > 0:
				target.card_data.voided_atk += leftover_magnitude
				print("🌀 Residuo non compensato:", leftover_magnitude, "→ aggiunto a voided_atk (tot:", target.card_data.voided_atk, ")")

			mods.remove_at(index_to_remove)
			target.card_data.all_stat_modifiers = mods
			target.card_data.debug_print_all_modifiers()
			print("✅", mod_type, "rimosso con logica avanzata da", enchant_card.card_data.card_name)


		# --- 🔸 DEBUFF / DEBUFFATK → logica semplice (restituzione netta ATK)
		elif mod_type == "DebuffAtk":
			var voided = target.card_data.voided_atk
			var restore_val = max(0, magnitude - voided)

			target.card_data.attack += restore_val
			target.card_data.max_attack += restore_val
			target.card_data.voided_atk = max(0, voided - magnitude)
			
		elif mod_type == "Debuff":
			var voided = target.card_data.voided_atk
			var restore_val = max(0, magnitude - voided)
			target.card_data.attack += restore_val
			target.card_data.max_attack += restore_val
			target.card_data.voided_atk = max(0, voided - magnitude)
			print("💫 [REMOVE LOGIC]", mod_type, "rimosso → restituiti", restore_val, "(magn:", magnitude, ", voided:", voided, ") su", target.card_data.card_name)
			
			## --- 🔸 Punti Vita (HP)
			if mod_type == "Debuff":
				target.card_data.health += magnitude
				target.card_data.max_health += magnitude
			else:
				# DeBuffAtk → nessuna modifica alla vita
				pass
			
			mods.remove_at(index_to_remove)
			target.card_data.all_stat_modifiers = mods

		# --- 🔸 BUFFHP → logica semplice
		elif mod_type == "BuffHp":
			# 🔹 Rimuove solo la max_health (non la health attuale)
			var old_max_hp = target.card_data.max_health
			target.card_data.max_health = max(0, target.card_data.max_health - magnitude_hp)
			
			# Clamp se health > max_health
			if target.card_data.health > target.card_data.max_health:
				target.card_data.health = target.card_data.max_health
			
			print("💔 [REMOVE LOGIC] BuffHp rimossa: max_health -", magnitude_hp, "(da", old_max_hp, "a", target.card_data.max_health, ") su", target.card_data.card_name)
			mods.remove_at(index_to_remove)
			target.card_data.all_stat_modifiers = mods
			
		# --- 🔸 BUFFARMOUR → rimuove solo armour attuale
		elif mod_type == "BuffArmour":
			var old_armour = target.card_data.armour
			target.card_data.armour = max(0, target.card_data.armour - magnitude_armour)
			print("💔 [REMOVE LOGIC] BuffArmour rimossa: armour -", magnitude_armour, "(da", old_armour, "a", target.card_data.armour, ") su", target.card_data.card_name)
			mods.remove_at(index_to_remove)
			target.card_data.all_stat_modifiers = mods

		# --- 🔸 DEBUFFHP → logica semplice
		elif mod_type == "DebuffHp":
			target.card_data.health += magnitude_hp
			target.card_data.max_health += magnitude_hp
			print("💫 [REMOVE LOGIC] DebuffHp +", magnitude_hp, "su", target.card_data.card_name)
			mods.remove_at(index_to_remove)
			target.card_data.all_stat_modifiers = mods

	else:
		print("ℹ️ Nessun Buff/Debuff ATK trovato per", enchant_card.card_data.card_name, "→ procedura standard di pulizia")



	# --- Pulizia logica generale prima di vedere i talent da aggiornare
	target.card_data.remove_buff_by_source(enchant_card)
	target.card_data.remove_debuff_by_source(enchant_card)
	target.card_data.active_buffs_until_endphase = target.card_data.active_buffs_until_endphase.filter(func(b): return b.get("source_card") != enchant_card)
	target.card_data.active_debuffs_until_endphase = target.card_data.active_debuffs_until_endphase.filter(func(d): return d.get("source_card") != enchant_card)
	# --- 💨 Rimozione eventuali talenti conferiti da questa enchant (stessa logica di remove_equip_effects)
	var original_talents = target.card_data.get_talents_array()
	var current_talents = target.card_data.get_all_talents()
	var all_buffs = target.card_data.get_buffs_array()

	for t in current_talents:
		if not (t in original_talents):
			var granted_by_this_enchant := false
			for b in all_buffs:
				if typeof(b) == TYPE_DICTIONARY and b.get("type", "") == "BuffTalent" \
				and b.get("source_card") == enchant_card and b.get("talent", "") == t:
					granted_by_this_enchant = true
					break
			if granted_by_this_enchant:
				print("🚫 [ENCHANT REMOVE] Rimuovo talento conferito da enchant rimossa:", t)
				if t in target.TALENT_ICONS:
					target._remove_icon(t)
				elif t in target.OVERLAY_TALENTS:
					target.remove_talent_overlay(t)
				if target.card_data.talent_from_buff == t:
					target.card_data.talent_from_buff = "None"

	target.update_talent_icons()

	## --- Pulizia logica generale
	#target.card_data.remove_buff_by_source(enchant_card)
	#target.card_data.remove_debuff_by_source(enchant_card)
	#target.card_data.active_buffs_until_endphase = target.card_data.active_buffs_until_endphase.filter(func(b): return b.get("source_card") != enchant_card)
	#target.card_data.active_debuffs_until_endphase = target.card_data.active_debuffs_until_endphase.filter(func(d): return d.get("source_card") != enchant_card)

	## --- UI refresh
	#if target.has_node("Attack"):
		#target.get_node("Attack").text = str(target.card_data.attack)
	#if target.has_node("Health"):
		#target.get_node("Health").text = str(target.card_data.health)
	target.update_card_visuals()

	print("✅ [ENCHANT REMOVE] Effetti rimossi completamente da", target.card_data.card_name)





func remove_equip_effects(equip_card: Node, target: Node) -> void:
	if not is_instance_valid(equip_card) or not is_instance_valid(target):
		return
	if not equip_card.card_data or not target.card_data:
		return

	print("🛠️ [REMOVE EQUIP EFFECTS] Rimozione effetti di", equip_card.card_data.card_name, "da", target.card_data.card_name)

	# --- 🔹 Identifica eventuale BuffTalent associato a questa equip
	var has_talent_buff := false
	var talent_buff_name := ""
	for buff in target.card_data.get_buffs_array():
		if typeof(buff) == TYPE_DICTIONARY and buff.get("type", "") == "BuffTalent" and buff.get("source_card") == equip_card:
			has_talent_buff = true
			talent_buff_name = target.card_data.talent_from_buff
			break

	# --- 🧩 LOGICA DI RIMOZIONE BUFF/DEBUFF (identica a ENCHANT)
	var mods = target.card_data.all_stat_modifiers
	var index_to_remove := -1
	var mod_type := ""

	for i in range(mods.size()):
		var mod = mods[i]
		if typeof(mod) == TYPE_DICTIONARY and mod.get("source_card") == equip_card:
			mod_type = mod.get("type", "")
			index_to_remove = i
			break

	if index_to_remove != -1:
		var removed_mod = mods[index_to_remove]
		var magnitude = removed_mod.get("magnitude_atk", 0)
		var magnitude_hp = removed_mod.get("magnitude_hp", 0)
		var magnitude_armour = removed_mod.get("magnitude_armour", 0)
		
		if mod_type in ["Buff", "BuffAtk"]:
			print("🧩 [REMOVE LOGIC] Rimozione", mod_type, "ATK:", magnitude)

			var total_buffs := 0
			var total_debuffs := 0
			for j in range(mods.size() - 1, -1, -1):
				if j == index_to_remove:
					continue
				var m = mods[j]
				if typeof(m) != TYPE_DICTIONARY:
					continue
				if m.get("type") == "Buff":
					total_buffs += m.get("magnitude_atk", 0)
				elif m.get("type") == "Debuff":
					total_debuffs += abs(m.get("magnitude_atk", 0))

			var net = total_buffs - total_debuffs
			print("📊 Somma buff residui:", total_buffs, " | Somma debuff residui:", total_debuffs, " | Netto:", net)

			# --- 🔸 Attacco
			var atk_before = target.card_data.attack
			var atk_after = max(0, atk_before - magnitude)
			var lost_amount = atk_before - atk_after
			var leftover_magnitude = magnitude - lost_amount
			target.card_data.attack = atk_after
			target.card_data.max_attack = max(0, target.card_data.max_attack - lost_amount)

			# --- 🔸 Punti Vita (HP)
			if mod_type == "Buff":
				# 🔹 Riduce solo la max_health, non la health attuale
				var old_max_hp = target.card_data.max_health
				target.card_data.max_health = max(0, target.card_data.max_health - magnitude)
				if target.card_data.health > target.card_data.max_health:
					target.card_data.health = target.card_data.max_health
				print("💔 [REMOVE LOGIC] Buff HP rimossa: max_health -", magnitude, "(da", old_max_hp, "a", target.card_data.max_health, ") su", target.card_data.card_name)
			else:
				# BuffAtk → nessuna modifica alla vita
				pass

			print("💔 Rimosso ATK:", lost_amount, " | Rimanente magnitude:", leftover_magnitude)

			# --- 🔁 Compensazione debuff se net < 0
			if net < 0 and leftover_magnitude > 0:
				print("⚖️ Prevalenza di debuff → compensazione su debuff")
				for j in range(mods.size()):
					if j == index_to_remove:
						continue
					var m = mods[j]
					if typeof(m) != TYPE_DICTIONARY or m.get("type") != "Debuff":
						continue
					var debuff_val = abs(m.get("magnitude_atk", 0))
					if debuff_val <= 0:
						continue
					var reduction = min(leftover_magnitude, debuff_val)
					m["magnitude_atk"] = debuff_val - reduction
					mods[j] = m
					leftover_magnitude -= reduction
					print("➡️ Debuff ridotto di", reduction, "→ nuovo valore:", m["magnitude_atk"])
					if leftover_magnitude <= 0:
						break

			# --- 🔁 Sincronizza debuff attivi
			for d_group in [
				target.card_data.active_debuffs,
				target.card_data.active_debuffs_until_endphase,
				target.card_data.active_debuffs_until_battlephase,
				target.card_data.active_debuffs_until_battlestep,
				target.card_data.active_debuffs_from_while_effects,
			]:
				for d in d_group:
					if typeof(d) != TYPE_DICTIONARY:
						continue
					var src_card = d.get("source_card")
					for m in mods:
						if typeof(m) == TYPE_DICTIONARY and m.get("type") == "Debuff" and m.get("source_card") == src_card:
							var updated_val = abs(m.get("magnitude_atk", d.get("magnitude_atk", 0)))
							if d["magnitude_atk"] != updated_val:
								print("🔁 [SYNC] Aggiornato debuff attivo da", src_card.card_data.card_name, "→", updated_val)
								d["magnitude_atk"] = updated_val
							break

			if leftover_magnitude > 0:
				target.card_data.voided_atk += leftover_magnitude
				print("🌀 Residuo non compensato:", leftover_magnitude, "→ aggiunto a voided_atk (tot:", target.card_data.voided_atk, ")")

			mods.remove_at(index_to_remove)
			target.card_data.all_stat_modifiers = mods
			target.card_data.debug_print_all_modifiers()
			print("✅", mod_type, "rimosso con logica avanzata da", equip_card.card_data.card_name)


		elif mod_type in ["Debuff", "DebuffAtk"]:
			var voided = target.card_data.voided_atk
			var restore_val = max(0, magnitude - voided)
			target.card_data.attack += restore_val
			target.card_data.max_attack += restore_val
			target.card_data.voided_atk = max(0, voided - magnitude)
			
			target.card_data.health += restore_val
			target.card_data.max_health += restore_val
			print("💫 [REMOVE LOGIC]", mod_type, "rimosso → restituiti", restore_val, "(magn:", magnitude, ", voided:", voided, ") su", target.card_data.card_name)
			mods.remove_at(index_to_remove)
			target.card_data.all_stat_modifiers = mods
				# --- 🔸 Ripristina anche HP


		elif mod_type == "BuffHp":
			# 🔹 Rimuove solo la max_health (non la health attuale)
			var old_max_hp = target.card_data.max_health
			target.card_data.max_health = max(0, target.card_data.max_health - magnitude_hp)
			
			# Clamp se health > max_health
			if target.card_data.health > target.card_data.max_health:
				target.card_data.health = target.card_data.max_health
			
			print("💔 [REMOVE LOGIC] BuffHp rimossa: max_health -", magnitude_hp, "(da", old_max_hp, "a", target.card_data.max_health, ") su", target.card_data.card_name)

		# --- 🔸 BUFFARMOUR → rimuove solo armour attuale
		elif mod_type == "BuffArmour":
			var old_armour = target.card_data.armour
			target.card_data.armour = max(0, target.card_data.armour - magnitude_armour)
			print("💔 [REMOVE LOGIC] BuffArmour rimossa: armour -", magnitude_armour, "(da", old_armour, "a", target.card_data.armour, ") su", target.card_data.card_name)
		
		elif mod_type == "DebuffHp":
			target.card_data.health += magnitude_hp
			target.card_data.max_health += magnitude_hp
			print("💫 [REMOVE LOGIC] DebuffHp +", magnitude_hp, "su", target.card_data.card_name)

	else:
		print("ℹ️ Nessun Buff/Debuff ATK trovato per", equip_card.card_data.card_name, "→ procedura standard di pulizia")


	# --- Pulizia logica generale
	target.card_data.remove_buff_by_source(equip_card)
	target.card_data.remove_debuff_by_source(equip_card)
	target.card_data.active_buffs_until_endphase = target.card_data.active_buffs_until_endphase.filter(func(b): return b.get("source_card") != equip_card)
	target.card_data.active_debuffs_until_endphase = target.card_data.active_debuffs_until_endphase.filter(func(d): return d.get("source_card") != equip_card)

	# --- 💨 Rimozione eventuali talenti conferiti da questa equip
	var original_talents = target.card_data.get_talents_array()
	var current_talents = target.card_data.get_all_talents()
	var all_buffs = target.card_data.get_buffs_array()

	for t in current_talents:
		if not (t in original_talents):
			var granted_by_this_equip := false
			for b in all_buffs:
				if typeof(b) == TYPE_DICTIONARY and b.get("type", "") == "BuffTalent" \
				and b.get("source_card") == equip_card and b.get("talent", "") == t:
					granted_by_this_equip = true
					break
			if granted_by_this_equip:
				print("🚫 [EQUIP REMOVE] Rimuovo talento conferito da equip rimossa:", t)
				if t in target.TALENT_ICONS:
					target._remove_icon(t)
				elif t in target.OVERLAY_TALENTS:
					target.remove_talent_overlay(t)
				if target.card_data.talent_from_buff == t:
					target.card_data.talent_from_buff = "None"

	target.update_talent_icons()
	target.update_card_visuals()

	print("✅ [EQUIP REMOVE] Effetti rimossi completamente da", target.card_data.card_name)







func handle_spellpower_on_destroy(card: Node, card_owner: String) -> void:
	var combat_manager = $"../CombatManager"
	var root = get_parent().get_parent()
	var is_enemy_owner = (card_owner == "Opponent")

	# 🔁 Scansiona tutti e 4 gli effetti della carta
	for i in range(1, 6):
		var eff_name = card.card_data.get("effect_%d" % i)
		var t_sub = card.card_data.get("t_subtype_%d" % i)
		var magnitude = card.card_data.get("effect_magnitude_%d" % i)

		if not (eff_name in [
			"BuffSpellPower", "BuffFireSpellPower", "BuffWindSpellPower",
			"BuffEarthSpellPower", "BuffWaterSpellPower"
		]):
			continue

		if card.card_data.temp_effect != "None":
			print("🌀 [", eff_name, "] Effetto temporaneo → nessuna riduzione SP.")
			continue

		print("💀 Analizzo distruzione effetto %d: %s → Target: %s (magnitudine: %d)" % [i, eff_name, t_sub, magnitude])

		# 🔹 Determina lato su cui rimuovere lo Spell Power
		var remove_from_player = false
		var remove_from_enemy = false

		match t_sub:
			"SelfPlayer":
				if not is_enemy_owner:
					remove_from_player = true
				else:
					remove_from_enemy = true
			"EnemyPlayer":
				if not is_enemy_owner:
					remove_from_enemy = true
				else:
					remove_from_player = true
			"BothPlayers", "None":
				remove_from_player = true
				remove_from_enemy = true

		# ✨ Applica la riduzione sul lato corretto
		if remove_from_player:
			_apply_single_spellpower_removal(combat_manager, eff_name, magnitude, false)
			_reset_spellpower_icon_position(root, "Player", eff_name)
		if remove_from_enemy:
			_apply_single_spellpower_removal(combat_manager, eff_name, magnitude, true)
			_reset_spellpower_icon_position(root, "Enemy", eff_name)

func _reset_spellpower_icon_position(root: Node, owner: String, eff_name: String) -> void:
	# Determina quali nodi resettare in base al tipo di effetto
	var icon_node: TextureRect
	var label_node: RichTextLabel

	match [owner, eff_name]:
		["Player", "BuffFireSpellPower"]:
			icon_node = root.get_node("PlayerField/PlayerFireSPicon")
			label_node = root.get_node("PlayerField/PlayerFireSP")
		["Player", "BuffWindSpellPower"]:
			icon_node = root.get_node("PlayerField/PlayerWindSPicon")
			label_node = root.get_node("PlayerField/PlayerWindSP")
		["Player", "BuffEarthSpellPower"]:
			icon_node = root.get_node("PlayerField/PlayerEarthSPicon")
			label_node = root.get_node("PlayerField/PlayerEarthSP")
		["Player", "BuffWaterSpellPower"]:
			icon_node = root.get_node("PlayerField/PlayerWaterSPicon")
			label_node = root.get_node("PlayerField/PlayerWaterSP")

		["Enemy", "BuffFireSpellPower"]:
			icon_node = root.get_node("EnemyField/EnemyFireSPicon")
			label_node = root.get_node("EnemyField/EnemyFireSP")
		["Enemy", "BuffWindSpellPower"]:
			icon_node = root.get_node("EnemyField/EnemyWindSPicon")
			label_node = root.get_node("EnemyField/EnemyWindSP")
		["Enemy", "BuffEarthSpellPower"]:
			icon_node = root.get_node("EnemyField/EnemyEarthSPicon")
			label_node = root.get_node("EnemyField/EnemyEarthSP")
		["Enemy", "BuffWaterSpellPower"]:
			icon_node = root.get_node("EnemyField/EnemyWaterSPicon")
			label_node = root.get_node("EnemyField/EnemyWaterSP")
		_:
			return  # SP generale non ha posizione dinamica

	# Se i nodi esistono e il valore SP è 0 → resetta e nascondi
	if is_instance_valid(icon_node) and is_instance_valid(label_node):
		var current_value := 0
		if label_node.text.is_valid_int():
			current_value = int(label_node.text)

		if current_value == 0:
			if owner == "Player":
				icon_node.position = Vector2(120, 935)
				label_node.position = Vector2(122, 938)
			elif owner == "Enemy":
				icon_node.position = Vector2(1564, 81)
				label_node.position = Vector2(1743, 86)

			icon_node.visible = false
			label_node.visible = false




func _apply_single_spellpower_removal(combat_manager: Node, eff_name: String, magnitude: int, is_enemy: bool):
	var side_prefix = "Enemy" if is_enemy else "Player"
	var display_side = "Enemy" if is_enemy else "Player"
	var field: Node = get_parent().get_parent().get_node("EnemyField") if is_enemy else get_parent()
	
	print("⚙️RIMOZIONE CHIAMO update_all_aura_bonuses(ΔSP:", magnitude, ") per", eff_name)
	
	match eff_name:
		"BuffSpellPower":
			print("⚡ [%s FIELD] Generic Spell Power -%d" % [display_side, magnitude])
			if is_enemy:
				combat_manager.enemy_SP -= magnitude
				field.get_node("EnemySP").text = str(combat_manager.enemy_SP)
				if combat_manager.enemy_SP == 0:
					field.get_node("EnemySP").self_modulate = Color(1, 1, 1)
				combat_manager.update_all_aura_bonuses(-magnitude, "Generic", true)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Generic", true)
			else:
				combat_manager.player_SP -= magnitude
				$"../PlayerSP".text = str(combat_manager.player_SP)
				if combat_manager.player_SP == 0:
					$"../PlayerSP".self_modulate = Color(1, 1, 1)
				combat_manager.update_all_aura_bonuses(-magnitude, "Generic", false)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Generic", false)

		"BuffFireSpellPower":
			print("🔥 [%s FIELD] Fire Spell Power -%d" % [display_side, magnitude])
			if is_enemy:
				combat_manager.enemy_FireSP -= magnitude
				field.get_node("EnemyFireSP").text = str(combat_manager.enemy_FireSP)
				if combat_manager.enemy_FireSP == 0:
					field.get_node("EnemyFireSP").visible = false
					field.get_node("EnemyFireSPicon").visible = false
				combat_manager.update_all_aura_bonuses(-magnitude, "Fire", true)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Fire", true)
			else:
				combat_manager.player_FireSP -= magnitude
				$"../PlayerFireSP".text = str(combat_manager.player_FireSP)
				if combat_manager.player_FireSP == 0:
					$"../PlayerFireSP".visible = false
					$"../PlayerFireSPicon".visible = false
				combat_manager.update_all_aura_bonuses(-magnitude, "Fire", false)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Fire", false)

		"BuffWindSpellPower":
			print("💨 [%s FIELD] Wind Spell Power -%d" % [display_side, magnitude])
			if is_enemy:
				combat_manager.enemy_WindSP -= magnitude
				field.get_node("EnemyWindSP").text = str(combat_manager.enemy_WindSP)
				if combat_manager.enemy_WindSP == 0:
					field.get_node("EnemyWindSP").visible = false
					field.get_node("EnemyWindSPicon").visible = true
				combat_manager.update_all_aura_bonuses(-magnitude, "Wind", true)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Wind", true)
			else:
				combat_manager.player_WindSP -= magnitude
				$"../PlayerWindSP".text = str(combat_manager.player_WindSP)
				if combat_manager.player_WindSP == 0:
					$"../PlayerWindSP".visible = false
					$"../PlayerWindSPicon".visible = false
				combat_manager.update_all_aura_bonuses(-magnitude, "Wind", false)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Wind", false)

		"BuffEarthSpellPower":
			print("🌱 [%s FIELD] Earth Spell Power -%d" % [display_side, magnitude])
			if is_enemy:
				combat_manager.enemy_EarthSP -= magnitude
				field.get_node("EnemyEarthSP").text = str(combat_manager.enemy_EarthSP)
				if combat_manager.enemy_EarthSP == 0:
					field.get_node("EnemyEarthSP").visible = false
					field.get_node("EnemyEarthSPicon").visible = false
				combat_manager.update_all_aura_bonuses(-magnitude, "Earth", true)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Earth", true)
			else:
				combat_manager.player_EarthSP -= magnitude
				$"../PlayerEarthSP".text = str(combat_manager.player_EarthSP)
				if combat_manager.player_EarthSP == 0:
					$"../PlayerEarthSP".visible = false
					$"../PlayerEarthSPicon".visible = false
				combat_manager.update_all_aura_bonuses(-magnitude, "Earth", false)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Earth", false)

		"BuffWaterSpellPower":
			print("💧 [%s FIELD] Water Spell Power -%d" % [display_side, magnitude])
			if is_enemy:
				combat_manager.enemy_WaterSP -= magnitude
				field.get_node("EnemyWaterSP").text = str(combat_manager.enemy_WaterSP)
				if combat_manager.enemy_WaterSP == 0:
					field.get_node("EnemyWaterSP").visible = false
					field.get_node("EnemyWaterSPicon").visible = false
				combat_manager.update_all_aura_bonuses(-magnitude, "Water", true)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Water", true)
			else:
				combat_manager.player_WaterSP -= magnitude
				$"../PlayerWaterSP".text = str(combat_manager.player_WaterSP)
				if combat_manager.player_WaterSP == 0:
					$"../PlayerWaterSP".visible = false
					$"../PlayerWaterSPicon".visible = false
				combat_manager.update_all_aura_bonuses(-magnitude, "Water", false)
				combat_manager.update_all_enchant_bonuses(-magnitude, "Water", false)


func update_all_enchant_bonuses(delta_sp: float, sp_type: String = "Generic", sp_owner_is_enemy: bool = false) -> void:
	print("\n🔮 [ENCHANT UPDATE] Aggiornamento Enchant legati alle creature | Tipo SP:", sp_type, "| ΔSP:", delta_sp, "| Lato nemico:", sp_owner_is_enemy)

	if delta_sp == 0:
		print("⚠️ Nessuna variazione di SP, skip aggiornamento enchant.")
		return

	var all_enchants: Array = []
	for card in player_spells_on_field + opponent_spells_on_field:
		if not is_instance_valid(card):
			continue
		if card.card_data.temp_effect == "Enchant":
			all_enchants.append(card)

	print("📦 [ENCHANT UPDATE] Totale enchant trovati:", all_enchants.size())

	for enchant in all_enchants:
		if not is_instance_valid(enchant):
			continue
		if not is_instance_valid(enchant.enchanted_to):
			print("🚫 [ENCHANT] Target non valido per", enchant.card_data.card_name)
			continue

		var target = enchant.enchanted_to

		if sp_owner_is_enemy and not enchant.is_enemy_card():
			continue
		elif not sp_owner_is_enemy and enchant.is_enemy_card():
			continue

		if sp_type != "Generic" and enchant.card_data.card_attribute != sp_type:
			continue

		var delta_bonus = enchant.card_data.spell_multiplier * delta_sp
		print("🎯 [ENCHANT APPLY]", enchant.card_data.card_name, "→ ΔBonus:", delta_bonus)

		var effective_debuff_atk := 0.0
		var effective_debuff_hp := 0.0
		var prev_applied_atk := 0.0   # 🧠 necessario per usarlo dopo
		
		for i in range(1, 6):
			var effect_name = enchant.card_data.get("effect_%d" % i)
			if effect_name == "None" or effect_name == "":
				continue
			
			

			match effect_name:
				# 🟩 BUFF ATK — usa logica voided_atk come le AURE
				"BuffAtk":
					if delta_bonus > 0:
						var voided_atk = target.card_data.voided_atk
						var effective_buff = max(0, delta_bonus - voided_atk)
						target.card_data.attack += effective_buff
						target.card_data.max_attack += effective_buff
						target.card_data.voided_atk = max(0, voided_atk - delta_bonus)
						print("🟩 [ENCHANT BUFF ATK] +", effective_buff, "ATK | voided ↓:", target.card_data.voided_atk)

					elif delta_bonus < 0:
						var magnitude = abs(delta_bonus)
						var old_atk = target.card_data.attack
						var old_max_atk = target.card_data.max_attack

						target.card_data.max_attack = max(0, target.card_data.max_attack - magnitude)
						target.card_data.attack = max(0, target.card_data.attack - magnitude)

						var atk_loss = old_atk - target.card_data.attack
						var voided_increase = max(0, magnitude - atk_loss)

						target.card_data.voided_atk += voided_increase
						target.card_data.voided_atk = max(0, target.card_data.voided_atk)

						print("💀 [ENCHANT BUFF→DEBUFF ATK] -", atk_loss, "ATK | voided +", voided_increase, "→", target.card_data.voided_atk)

				# 🟩 BUFF (ATK + HP) — logica voided_atk identica alle AURE
				"Buff":
					if delta_bonus > 0:
						var voided_atk = target.card_data.voided_atk
						var effective_buff = max(0, delta_bonus - voided_atk)
						target.card_data.attack += effective_buff
						target.card_data.max_attack += effective_buff
						target.card_data.health += delta_bonus
						target.card_data.max_health += delta_bonus
						target.card_data.voided_atk = max(0, voided_atk - delta_bonus)
						print("🟩 [ENCHANT BUFF] +", effective_buff, "ATK / +", delta_bonus, "HP | voided ↓:", target.card_data.voided_atk)

					elif delta_bonus < 0:
						var magnitude = abs(delta_bonus)
						var old_atk = target.card_data.attack
						var new_atk = max(0, old_atk - magnitude)
						var atk_loss = old_atk - new_atk
						var voided_increase = max(0, magnitude - atk_loss)

						target.card_data.attack = new_atk
						target.card_data.max_attack = max(0, target.card_data.max_attack - magnitude)
						target.card_data.health = max(0, target.card_data.health - magnitude)
						target.card_data.max_health = max(0, target.card_data.max_health - magnitude)
						target.card_data.voided_atk += voided_increase

						print("💀 [ENCHANT BUFF→DEBUFF] -", atk_loss, "ATK /", magnitude, "HP | voided +", voided_increase, "→", target.card_data.voided_atk)

				# 💚 BUFF HP — semplice
				"BuffHp":
					target.card_data.health += delta_bonus
					target.card_data.max_health += delta_bonus
					print("💚 [ENCHANT BUFF HP] Δ", delta_bonus, "HP su", target.card_data.card_name)
				# 🛡️ BUFF ARMOUR — semplice
				"BuffArmour":
					target.card_data.armour += delta_bonus
					print("🛡️ [ENCHANT BUFF ARMOUR] Δ", delta_bonus, "Armour su", target.card_data.card_name)

				"DebuffAtk":
					if delta_bonus > 0:
						var atk_room = max(0, target.card_data.attack)
						effective_debuff_atk = min(delta_bonus, atk_room)
						target.card_data.attack = max(0, target.card_data.attack - effective_debuff_atk)
						target.card_data.max_attack = max(0, target.card_data.max_attack - effective_debuff_atk)
						print("💀 [ENCHANT DEBUFF ATK] -", effective_debuff_atk, "ATK (limitato a 0)")

						# 🧠 Se il debuff esiste già, aggiornalo aggiungendo il campo applied_atk
						for d in target.card_data.active_debuffs:
							if d.get("source_card") == enchant and d.get("type") == "DebuffAtk":
								if not d.has("applied_atk"):
									d["applied_atk"] = 0.0
								d["applied_atk"] = effective_debuff_atk
								break

					else:
						# 🟩 attenuazione del debuff → recupero di ATK
						var reduction = abs(delta_bonus)
						for d in target.card_data.active_debuffs:
							if d.get("source_card") == enchant and d.get("type") == "DebuffAtk":
								prev_applied_atk = d.get("applied_atk") if d.has("applied_atk") else 0.0
								var restore = min(reduction, prev_applied_atk)
								d["applied_atk"] = max(0, prev_applied_atk - restore)
								target.card_data.attack += restore
								target.card_data.max_attack += restore
								print("🟩 [ENCHANT DEBUFF ATK attenuato] +", restore, "ATK (limitato al debuff effettivo)")



				# 💀 DEBUFF HP — semplice
				"DebuffHp":
					target.card_data.health = max(0, target.card_data.health - delta_bonus)
					target.card_data.max_health = max(0, target.card_data.max_health - delta_bonus)
					print("💀 [ENCHANT DEBUFF HP] Δ", delta_bonus, "HP su", target.card_data.card_name)

				"Debuff":
					if delta_bonus > 0:
						var atk_room = max(0, target.card_data.attack)
						var hp_room = max(0, target.card_data.health)
						effective_debuff_atk = min(delta_bonus, atk_room)
						effective_debuff_hp = min(delta_bonus, hp_room)

						target.card_data.attack -= effective_debuff_atk
						target.card_data.health -= effective_debuff_hp
						target.card_data.max_attack -= effective_debuff_atk
						target.card_data.max_health -= effective_debuff_hp

						print("💀 [ENCHANT DEBUFF] -", effective_debuff_atk, "ATK / -", effective_debuff_hp, "HP (limitati a 0)")

						for d in target.card_data.active_debuffs:
							if d.get("source_card") == enchant and d.get("type") == "Debuff":
								if not d.has("applied_atk"):
									d["applied_atk"] = 0.0
								if not d.has("applied_hp"):
									d["applied_hp"] = 0.0
								d["applied_atk"] = effective_debuff_atk
								d["applied_hp"] = effective_debuff_hp
								break

					else:
						# 🟩 riduzione del debuff (recupero limitato)
						var reduction = abs(delta_bonus)
						for d in target.card_data.active_debuffs:
							if d.get("source_card") == enchant and d.get("type") == "Debuff":
								prev_applied_atk = d.get("applied_atk") if d.has("applied_atk") else 0.0
								var restore = min(reduction, prev_applied_atk)
								d["applied_atk"] = max(0, prev_applied_atk - restore)
								target.card_data.attack += restore
								target.card_data.max_attack += restore
								print("🟩 [ENCHANT DEBUFF attenuato] +", restore, "ATK (limitato al debuff effettivo)")


				_:
					print("⚠️ [ENCHANT IGNORATO] Effetto non scalabile con SP:", effect_name)

		# 🔄 Aggiorna i buff/debuff registrati nel card_data
		for b in target.card_data.active_buffs:
			if typeof(b) == TYPE_DICTIONARY and b.has("source_card") and b["source_card"] == enchant:
				match b["type"]:
					"Buff":
						b["magnitude_atk"] += delta_bonus
						b["magnitude_hp"] += delta_bonus
					"BuffAtk":
						b["magnitude_atk"] += delta_bonus
					"BuffHp":
						b["magnitude_hp"] += delta_bonus
					"BuffArmour":
						b["magnitude_armour"] += delta_bonus

		# 🔄 Aggiorna i debuff attivi
		for d in target.card_data.active_debuffs:
			if typeof(d) == TYPE_DICTIONARY and d.has("source_card") and d["source_card"] == enchant:
				match d["type"]:
					"Debuff":
						if delta_bonus > 0:
							d["magnitude_atk"] += effective_debuff_atk
							d["magnitude_hp"] += delta_bonus
							d["applied_atk"] = effective_debuff_atk
						else:
							d["magnitude_atk"] -= prev_applied_atk
							d["magnitude_hp"] += delta_bonus

					"DebuffAtk":
						if delta_bonus > 0:
							d["magnitude_atk"] += effective_debuff_atk
							d["applied_atk"] = effective_debuff_atk
						else:
							d["magnitude_atk"] -= prev_applied_atk
							print("PREV APPLIED =", prev_applied_atk)


					"DebuffHp":
						d["magnitude_hp"] += delta_bonus

		# 🧩 Aggiorna anche all_stat_modifiers
		for m in target.card_data.all_stat_modifiers:
			if typeof(m) != TYPE_DICTIONARY:
				continue
			if not m.has("source_card") or m["source_card"] != enchant:
				continue

			match m["type"]:
				"Buff":
					m["magnitude_atk"] += delta_bonus
					m["magnitude_hp"] += delta_bonus
				"BuffAtk":
					m["magnitude_atk"] += delta_bonus
				"BuffHp":
					m["magnitude_hp"] += delta_bonus
				"BuffArmour":
					m["magnitude_armour"] += delta_bonus
				"Debuff":
					if delta_bonus > 0:
						m["magnitude_atk"] += effective_debuff_atk
						m["magnitude_hp"] += delta_bonus
						m["applied_atk"] = effective_debuff_atk
					else:
						m["magnitude_atk"] -= prev_applied_atk
						m["magnitude_hp"] += delta_bonus
				"DebuffAtk":
					if delta_bonus > 0:
						m["magnitude_atk"] += effective_debuff_atk
						m["applied_atk"] = effective_debuff_atk
					else:
						m["magnitude_atk"] -= prev_applied_atk
						print("PREV APPLIED =", prev_applied_atk)
				"DebuffHp":
					m["magnitude_hp"] += delta_bonus


		if target.card_data.attack < 0:
			target.card_data.attack = 0
		if target.card_data.health < 0:
			target.card_data.health = 0
		if target.card_data.armour < 0:
			target.card_data.armour = 0
			
		target.update_card_visuals()
		print("✅ [ENCHANT UPDATE COMPLETO]", enchant.card_data.card_name, "→", target.card_data.card_name)




func find_card_by_name_in_enemy_field(card_name: String) -> Node:
	if card_name == "":
		return null
	for c in opponent_creatures_on_field:
		if c.name == card_name:
			return c
	for s in opponent_spells_on_field:
		if s.name == card_name:
			return s
	return null



func stop_attack(card: Node) -> void:
	if not is_instance_valid(card):
		return

	print("🔄 [STOP ATTACK] Verifica stato di", card.card_data.card_name, "→ posizione:", card.position_type)


	# 🧹 Rimuovi overlay, borders, chain, highlights
	if card.has_node("ActionBorder"):
		card.get_node("ActionBorder").visible = false
	if card.has_node("HighlightBorder"):
		card.get_node("HighlightBorder").visible = false
	if card.has_node("RedHighlightBorder"):
		card.get_node("RedHighlightBorder").visible = false
	if card.has_node("GreenHighlightBorder"):
		card.get_node("GreenHighlightBorder").visible = false
	if card.has_node("AttackOverlay"):
		card.get_node("AttackOverlay").queue_free()
	if card.has_node("NextCardBuffedBorder"):
		card.get_node("NextCardBuffedBorder").visible = false
	# 🔄 Rimuovi overlay chain
	remove_chain_overlay(card)

	if card.has_an_attack_target or card.is_being_attacked: #or card.is_being_targeted:  #PER ORA BUG ATK MORTO FIXATO SOLO SE C'E IS BEING TARGETED
	#if card.is_being_targeted:
		print("⚠️ Carta", card.name, "CHANGE POS/STOP ATK durante un combat → combat terminato, imposto anche i flag attak_target e being attacked a FALSE")
		any_combat_in_progress = false
		chained_this_battle_step = false
		already_chained_in_this_go_to_combat = false
		already_chained_in_this_go_to_damage_step = false
		card.is_being_attacked = false
		print("IMPOSTA ANCHE FLAG ATTACK NEGATED")
		card.attack_negated = true
	# 🧠 Reset combat state
	clear_combat_state(card)
	recheck_combat_status()
	#FORSE QUI IL FORCED COMBAAT END NON SERVE VEDI IN FUTURO EVNETUALI BUG
	handle_forced_combat_end(card, "atk_stopped")

	 ###🌀 Passa azione all’altro giocatore, come in direct_attack
	#if pending_action_owner_id != multiplayer.get_unique_id():
		#var phase_manager = get_node_or_null("../PhaseManager")
		#if phase_manager:
			#await get_tree().create_timer(0.2).timeout
			#var peers = multiplayer.get_peers()
			#if peers.size() > 0:
				#var other_id = peers[0]
				#print("♻️ [Action Switch] Attacco interrotto → passo azione all’altro peer:", other_id)
				#phase_manager.rpc("rpc_give_action", other_id,true)
				#phase_manager.rpc_give_action(other_id,true)
	##else:
		##print("⚠️ PhaseManager non trovato — impossibile passare l’azione!")
#
#
	## 🔁 Se la carta è ancora in campo → riportala nella posizione del suo slot
	#if card.card_is_in_slot and card.current_slot and is_instance_valid(card.current_slot):
		#var tween_return = create_tween()
		#tween_return.set_trans(Tween.TRANS_QUAD)
		#tween_return.set_ease(Tween.EASE_OUT)
		#tween_return.tween_property(card, "position", card.current_slot.position, 0.3)
		#await tween_return.finished
		#print("↩️ [STOP ATTACK] Carta", card.card_data.card_name, "riportata al suo slot.")
	#else:
		#print("⚠️ [STOP ATTACK] Nessuno slot valido trovato per", card.card_data.card_name, "→ skip movimento.")


	card.z_index = 0

	print("✅ [STOP ATTACK] Attacco annullato per carta facedown:", card.card_data.card_name)


func remove_temporary_spellpower_effects():
	print("🧹 [END PHASE] Rimozione Spell Power temporanei (temp_effect == 'EndPhase')...")

	# Cicla su tutte le fonti di spellpower registrate
	for sp_type in spell_power_sources.keys():
		var sources = spell_power_sources[sp_type]
		for source_dict in sources.duplicate():
			if source_dict.has("temporary") and source_dict.temporary:
				print("💀 Rimuovo effetto temporaneo:", source_dict.source, "(", sp_type, ",", source_dict.value, ")")
				var is_enemy = source_dict.enemy
				var magnitude = source_dict.value
				var eff_name = ""

				# Ricostruisce il nome effetto corretto
				match sp_type:
					"Generic": eff_name = "BuffSpellPower"
					"Fire": eff_name = "BuffFireSpellPower"
					"Water": eff_name = "BuffWaterSpellPower"
					"Earth": eff_name = "BuffEarthSpellPower"
					"Wind": eff_name = "BuffWindSpellPower"
					_: eff_name = "BuffSpellPower"

				# Applica la rimozione (come se la carta fosse distrutta)
				get_parent().get_node("CombatManager")._apply_single_spellpower_removal(self, eff_name, magnitude, is_enemy)

				# Rimuovi la fonte dalla lista
				sources.erase(source_dict)

		# Aggiorna la lista nel dizionario principale
		spell_power_sources[sp_type] = sources


func remove_while_effects_from_source(source_card: Card, condition_source: Card) -> void:
	#if not is_instance_valid(source_card) or not is_instance_valid(condition_source):
		#print("RITRNOOOSOSO")
		#return
	print("🧹 [CLEANUP] Rimozione effetti While da",source_card.card_data.card_name)
	if is_instance_valid(condition_source):
		print("🧹 [CLEANUP] Rimozione effetti While da",
			source_card.card_data.card_name,
			"causati da",
			condition_source.card_data.card_name)

	var all_cards = player_creatures_on_field + opponent_creatures_on_field \
		+ player_spells_on_field + opponent_spells_on_field

	for target in all_cards:
		if not is_instance_valid(target) or not target.card_data:
			continue

		var buffs = target.card_data.get_buffs_array()
		var debuffs = target.card_data.get_debuffs_array()

		var affected := false

		for b in buffs:
			if typeof(b) == TYPE_DICTIONARY \
			and b.get("source_card") == source_card \
			and b.get("condition_source", null) == condition_source:
				affected = true
				break

		if not affected:
			for d in debuffs:
				if typeof(d) == TYPE_DICTIONARY \
				and d.get("source_card") == source_card \
				and d.get("condition_source", null) == condition_source:
					affected = true
					break

		if affected:
			var equip_name := "GLOBAL"
			if is_instance_valid(condition_source):
				equip_name = condition_source.card_data.card_name

			print("🧩 [WHILE CLEANUP] Rimuovo While da",
				target.card_data.card_name,
				"(equip:", equip_name, ")")

			remove_enchant_effects(source_card, target, condition_source)

	print("✅ [CLEANUP] While rimossi solo per equip distrutto")


#
		## 🔄 Aggiorna grafica e icone dopo la rimozione del While
		#card.update_card_visuals()
		#card.update_debuff_icons()
		#card.update_talent_icons()  # 👈 AGGIUNGI QUESTA RIGA

func process_triggered_effects_this_chain_link() -> void:
	var card_manager = $"../CardManager"
	if triggered_effects_this_chain_link.is_empty():
		print("✅ Nessun effetto accodato durante la chain.")
		return
		
	triggered_effects_processing = true
	# 🧩 DEBUG: lista iniziale
	var debug_effects := []
	for e in triggered_effects_this_chain_link:
		if e.has("card") and is_instance_valid(e["card"]):
			debug_effects.append(e["card"].card_data.card_name + " (owner:" + str(e["owner_id"]) + ")")
		else:
			debug_effects.append("❌ Carta non valida (probabilmente distrutta)")
	print("⚡ Trovati", triggered_effects_this_chain_link.size(), "effetti accodati da risolvere post-chain:")
	print("📋 Lista iniziale effetti accodati:", debug_effects)

	var resolved_cards_this_cycle: Array = []
	var safety_counter := 0  # 🔒 protezione anti-loop

	while not triggered_effects_this_chain_link.is_empty():
		safety_counter += 1
		if safety_counter > 100:
			print("🚨 [ERRORE] Loop infinito rilevato in process_triggered_effects_this_chain_link! Interruzione forzata.")
			break

		var entry = triggered_effects_this_chain_link.back()
		var card = entry["card"]
		var owner_id = entry["owner_id"]

		if not is_instance_valid(card):
			print("⚠️ Carta accodata non più valida, la rimuovo.")
			triggered_effects_this_chain_link.pop_back()
			continue

		print("🕓 Risolvo effetto accodato di", card.card_data.card_name, "| Owner:", owner_id)

		if owner_id == multiplayer.get_unique_id():
			if card.card_data.targeting_type == "Targeted":
				if card.card_data.t_subtype_1 == "AllCreatures":
					if player_creatures_on_field.size() > 0 or opponent_creatures_on_field.size() > 0:
						await card_manager.enter_selection_mode(card, "effect")
				elif card.card_data.t_subtype_1 == "AllEnemyCreatures":
					if opponent_creatures_on_field.size() > 0:
						await card_manager.enter_selection_mode(card, "effect")
			else:
				await card_manager.trigger_card_effect(card, true)
			
		else:
			print("⏳ Attendo che il peer", owner_id, "risolva l’effetto accodato di", card.card_data.card_name)

		#await get_tree().create_timer(0.5).timeout
		print("ASPETTO FULL RESOLVE")
		#await await_effect_fully_resolved(card)

		triggered_effects_this_chain_link.pop_back()
		print("🗑️ Rimossa carta accodata risolta:", card.card_data.card_name)

		await get_tree().process_frame
	
	triggered_effects_processing = false
	print("✅ Tutti gli effetti accodati sono stati risolti completamente.")
	
@rpc("any_peer")
func apply_untargeted_TRIGGER_effect_here_and_replicate_client_opponent(player_id, source_card_name: String, effect: String, magnitude: int, t_subtype: String = "", is_triggered: bool = true, trigger_cause_name: String = "",forced_effect_index: int = 0):
	var is_attacker = multiplayer.get_unique_id() == player_id
	var source_card
	if is_attacker:
		source_card = $"../CardManager".get_node_or_null(source_card_name)
	else:
		source_card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + source_card_name)
		
	var trigger_cause: Card = null

	if trigger_cause_name != "":
		if is_attacker:
			trigger_cause = $"../CardManager".get_node_or_null(trigger_cause_name)
		else:
			trigger_cause = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + trigger_cause_name)
	#if not source_card:
		#push_error("❌ Source card non trovata per untargeted effect:", source_card_name)
		#return
	# 🔥 Rimuovi subito il selection overlay se c'era
	if $"../CardManager".selection_purpose == "effect":
		$"../CardManager".remove_selection_overlay(source_card)
		
	if not is_instance_valid(source_card): #IMPORTANTE SERVE PER EVITARE BUG DOVE SOURCE CARD NEMICA E' NULL PERCHE' NON RICONOSCE IL NOME, TANTO SIAMO DENTRO RPC.
		push_warning("❌ Source card non valida per effect: " + source_card_name)
		return
	if source_card.has_node("ActionBorder"):
		source_card.get_node("ActionBorder").visible = true
	# ✅ Imposta effect_triggered_this_turn SOLO se non è un effetto On_Trigger
	if source_card.card_data.effect_type != "On_Trigger":
		source_card.effect_triggered_this_turn = true
		#print("✅ Effetto impostato come già triggerato:", source_card.card_data.card_name)
	else:
		print("⛔ Effetto On_Trigger → non impostato come triggerato:", source_card.card_data.card_name)
	
	if source_card.card_data.effect_type == "ActivableAttack":
		if not player_creature_that_attacked_this_turn.has(source_card):
			player_creature_that_attacked_this_turn.append(source_card)
			source_card.attacked_this_turn = true
			print("📝 Aggiunta a player_creature_that_attacked_this_turn:", source_card.name)
		# 🔮 Controllo scaling Spell Power anche per effetti untargeted

	var combat_manager = $"../CombatManager"
	

	
	# ✅ Mostra chain overlay solo se:
	# - NON è un On_Trigger, oppure
	# - È un On_Trigger MA con trigger_type = On_UpKeepPhase o On_EndPhase
	if source_card.card_data.effect_type != "On_Trigger" \
	or (source_card.card_data.effect_type == "On_Trigger"
		and source_card.card_data.trigger_type in ["On_UpKeepPhase", "On_EndPhase"]):
		add_chain_overlay(source_card, effect_stack.size())
	else:
		print("⛔ [SKIP OVERLAY] On_Trigger non di fase → niente chain overlay per", source_card.card_data.card_name)
		# ✅ Se è la prima carta della chain ed esistono carte in attesa gia' in battle → segna chaining attivo

	
	var effect_indices := []

	if forced_effect_index > 0:
		# 🔥 Trigger On Kill → applica SOLO quell’effetto
		effect_indices = [forced_effect_index]
	else:
		# ✨ Effetto normale → ciclo completo
		effect_indices = range(1, 6)
	

	for i in effect_indices:
		var effect_name = source_card.card_data.get("effect_%d" % i)
		magnitude = source_card.card_data.get("effect_magnitude_%d" % i)
		t_subtype = source_card.card_data.get("t_subtype_%d" % i)
		var scaling_type = source_card.card_data.get("scaling_%d" % i)

		if effect_name == "None" or effect_name == "":
			continue  # ⏭️ nessun effetto valido in questo slot

		# 🧮 SCALING SPELL POWER

		var spell_power_total = 0

		# 1️⃣ Spell Power base
		if is_attacker:
			spell_power_total = combat_manager.player_SP
		else:
			spell_power_total = combat_manager.enemy_SP

		# 2️⃣ Spell Power per attributo
		var attr = source_card.card_data.card_attribute
		if attr != "" and attr != "None":
			match attr:
				"Fire":
					if is_attacker:
						spell_power_total += combat_manager.player_FireSP
					else:
						spell_power_total += combat_manager.enemy_FireSP
				"Water":
					if is_attacker:
						spell_power_total += combat_manager.player_WaterSP
					else:
						spell_power_total += combat_manager.enemy_WaterSP
				"Earth":
					if is_attacker:
						spell_power_total += combat_manager.player_EarthSP
					else:
						spell_power_total += combat_manager.enemy_EarthSP
				"Wind":
					if is_attacker:
						spell_power_total += combat_manager.player_WindSP
					else:
						spell_power_total += combat_manager.enemy_WindSP

		# 3️⃣ Aggiungi spell power base della carta
		spell_power_total += source_card.card_data.base_spell_power

		print("✨ [SPELL POWER TOTAL]", source_card.card_data.card_name,
			"| Attributo:", attr,
			"| SP Totale:", spell_power_total)


		# 4️⃣ Applica scaling se richiesto
		match scaling_type:
			"None":
				pass

			"MagnitudeSpellPower":
				var bonus = source_card.card_data.spell_multiplier * spell_power_total
				magnitude += bonus
				print("🔮 [SCALING SpellPower #", i, "]",
					" Carta:", source_card.card_data.card_name,
					" | SP Totale:", spell_power_total,
					" | Mult:", source_card.card_data.spell_multiplier,
					" | Bonus:", bonus,
					" | Magnitude finale:", magnitude)

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
				var scale_amount = source_card.card_data.get("scaling_amount_%d" % i)
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
				var scale_amount = source_card.card_data.get("scaling_amount_%d" % i)
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

				var scale_amount = source_card.card_data.get("scaling_amount_%d" % i)
				var bonus = hand_size * scale_amount
				magnitude += bonus
				print("✋ [SCALING HandSize #", i, "]",
					" | Carte in mano:", hand_size,
					" | Scaling Amount:", scale_amount,
					" | Bonus:", bonus,
					" | Magnitude finale:", magnitude)

			_:
				print("⚠️ [SCALING] Tipo di scaling non riconosciuto:", scaling_type)


		var cards_to_destroy = []
		var temp_effect_type = ""
		temp_effect_type = source_card.card_data.temp_effect
		
		if source_card.card_is_in_slot and not source_card.effect_negated and (forced_effect_index != 0 or source_card.card_data.targeting_type != "Targeted"):
			# 🔮 Se non è uno dei subtype logici o Self, usa helper
			if not t_subtype in ["Self", "SelfPlayer", "EnemyPlayer", "BothPlayers", "MyNextNormalSpell","None"]:
				var valid_targets = $"../CombatManager".get_valid_targets(source_card, is_attacker, t_subtype)
				

				if valid_targets.is_empty():
					print("⚠️ Nessun target valido trovato per effetto untargeted di:", source_card.card_data.card_name, "| subtype:", t_subtype)
				else:
					print("🎯 Target validi trovati per", source_card.card_data.card_name)

				for card in valid_targets:
					if not is_instance_valid(card):
						continue
					if check_magic_veil(card, source_card):
						continue
					if card.card_data.health <= 0 and not card.card_data_card_type == "Spell":
						continue

					apply_simple_effect_to_card(card, effect_name, magnitude, source_card, player_id, trigger_cause)
					await handle_card_destruction_check(card, cards_to_destroy)
					card.update_card_visuals()
					rpc("update_card_stats", card.name, card.card_data.attack, card.card_data.health)

				register_continuous_aura_targets(source_card, magnitude, is_attacker, t_subtype)

				# 💥 Distruzione immediata (senza delay)
				for card in cards_to_destroy:
					if not is_instance_valid(card):
						continue
					var owner = "Player"
					if card.is_enemy_card():
						owner = "Opponent"
					destroy_card(card, owner)

			# 🎯 Gestione manuale per Self e Player logic effects
			else:
				match t_subtype:
					"Self":
						print("🪞 [UNTARGETED SELF] Applico effetto", effect_name, "su", source_card.card_data.card_name)
						if is_instance_valid(source_card) and not source_card.effect_negated:
							apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id, trigger_cause)
							source_card.update_card_visuals()
							await handle_card_destruction_check(source_card, [])
						else:
							print("❌ [UNTARGETED SELF] Carta non valida o negata, effetto saltato.")

					"SelfPlayer":
						if is_attacker:
							if effect_name == "GainLP":
								player_LP += magnitude
								$"../PlayerLP".text = str(player_LP)

							elif effect_name == "Damage":
								# ➤ Danno al player locale (SelfPlayer)
								var protected = check_and_consume_protection(false)  # false = colpisce il player
								if protected:
									print("🩹 Nessun danno SelfPlayer inflitto (Protection attiva).")
								else:
									player_LP = max(0, player_LP - magnitude)
									$"../PlayerLP".text = str(player_LP)
									source_card.emit_signal("damage_dealt", source_card, magnitude, "direct_damage")
									print("💥 SelfPlayer infligge", magnitude, "danni al player (rimasti:", player_LP, ")")

							elif effect_name == "PreventDamage":  # 🛡️ nuovo effetto
								var is_next_damage = magnitude == 1
								show_player_status_icon("Protection", true, false, temp_effect_type, is_next_damage)
								print("🛡️ [PreventDamage] Protezione attiva sul player (attaccante)")

							elif effect_name in ["AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWaterMana", "AddWindMana"]:
								var mana_manager_path = "../ManaSlots"
								var mana_manager = get_node_or_null(mana_manager_path)
								if mana_manager == null:
									push_error("❌ ManaSlotManager non trovato in " + mana_manager_path)
									return

								var mana_type = ""
								match effect_name:
									"AddColorlessMana": mana_type = "Colorless"
									"AddFireMana": mana_type = "Fire"
									"AddEarthMana": mana_type = "Earth"
									"AddWaterMana": mana_type = "Water"
									"AddWindMana": mana_type = "Wind"

								for j in range(magnitude):
									var single_slot: Array[String] = [mana_type]
									mana_manager.add_extra_mana_slots(single_slot, source_card.card_data.temp_effect)
									await get_tree().create_timer(0.05).timeout

							elif effect_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWaterSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower"]:
								apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id, trigger_cause)

						else:
							if effect_name == "GainLP":
								enemy_LP += magnitude
								get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)

							elif effect_name == "Damage":
								# ➤ Danno al nemico (SelfPlayer per il difensore)
								var protected = check_and_consume_protection(true)  # true = colpisce enemy
								if protected:
									print("🩹 Nessun danno SelfPlayer inflitto al nemico (Protection attiva).")
								else:
									enemy_LP = max(0, enemy_LP - magnitude)
									get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)
									source_card.emit_signal("damage_dealt", source_card, magnitude, "direct_damage")
									print("💥 SelfPlayer infligge", magnitude, "danni al nemico (rimasti:", enemy_LP, ")")

							elif effect_name == "PreventDamage":  # 🛡️ nuovo effetto
								var is_next_damage = magnitude == 1
								show_player_status_icon("Protection", true, true, temp_effect_type, is_next_damage)
								print("🛡️ [PreventDamage] Protezione attiva sull’enemy player")

							elif effect_name in ["AddColorlessMana", "AddFireMana", "AddEarthMana", "AddWaterMana", "AddWindMana"]:
								var enemy_mana_manager_path = "EnemyField/ManaSlots"
								var enemy_mana_manager = get_parent().get_parent().get_node_or_null(enemy_mana_manager_path)
								if enemy_mana_manager == null:
									push_error("❌ Enemy ManaSlotManager non trovato in " + enemy_mana_manager_path)
									return

								var mana_type = ""
								match effect_name:
									"AddColorlessMana": mana_type = "Colorless"
									"AddFireMana": mana_type = "Fire"
									"AddEarthMana": mana_type = "Earth"
									"AddWaterMana": mana_type = "Water"
									"AddWindMana": mana_type = "Wind"

								for j in range(magnitude):
									var single_slot: Array[String] = [mana_type]
									enemy_mana_manager.add_extra_mana_slots(single_slot, source_card.card_data.temp_effect)
									await get_tree().create_timer(0.05).timeout

							elif effect_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWaterSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower"]:
								apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id, trigger_cause)


					"EnemyPlayer":
						if is_attacker:
							if effect_name == "GainLP":
								enemy_LP += magnitude
								get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)

							elif effect_name == "Damage":
								# ➤ Danno al nemico (target = enemy)
								var protected = check_and_consume_protection(true)
								if protected:
									print("🩹 Nessun danno EnemyPlayer inflitto (Protection attiva).")
								else:
									enemy_LP = max(0, enemy_LP - magnitude)
									get_parent().get_parent().get_node("EnemyField/EnemyLP").text = str(enemy_LP)
									print("💥 EnemyPlayer infligge", magnitude, "danni al nemico (rimasti:", enemy_LP, ")")

							elif effect_name == "PreventDamage":  # 🛡️ nuovo effetto
								var is_next_damage = magnitude == 1
								show_player_status_icon("Protection", true, true, temp_effect_type, is_next_damage)
								print("🛡️ [PreventDamage] Protezione attiva sull’enemy player (attaccante)")

							elif effect_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWaterSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower"]:
								apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id, trigger_cause)

						else:
							if effect_name == "GainLP":
								player_LP += magnitude
								$"../PlayerLP".text = str(player_LP)

							elif effect_name == "Damage":
								# ➤ Danno al player locale (target = player)
								var protected = check_and_consume_protection(false)
								if protected:
									print("🩹 Nessun danno EnemyPlayer subìto (Protection attiva).")
								else:
									player_LP = max(0, player_LP - magnitude)
									$"../PlayerLP".text = str(player_LP)
									source_card.emit_signal("damage_dealt", source_card, magnitude, "direct_damage")
									print("💥 EnemyPlayer subisce", magnitude, "danni (rimasti:", player_LP, ")")

							elif effect_name == "PreventDamage":  # 🛡️ nuovo effetto
								var is_next_damage = magnitude == 1
								show_player_status_icon("Protection", true, false, temp_effect_type, is_next_damage)
								print("🛡️ [PreventDamage] Protezione attiva sul player (difensore)")

							elif effect_name in ["BuffSpellPower", "BuffFireSpellPower", "BuffWaterSpellPower", "BuffEarthSpellPower", "BuffWindSpellPower"]:
								apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id, trigger_cause)
					"MyNextNormalSpell":
						print("MY NEXT NORMAL SPELL AGGIUNGO CONDITION NORMAL AL BUFF NEXT SPELL")
						apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id, trigger_cause)
					"None", _:
						print("APPLICO EFFETTO NONE")
						apply_simple_effect_to_card(source_card, effect_name, magnitude, source_card, player_id, trigger_cause)
		else:
			print("❌ Effetto annullato: carta non più in campo o negata →", source_card.name)
			if is_instance_valid(source_card) and source_card.card_is_in_slot:
				var owner = "Player" if not source_card.is_enemy_card() else "Opponent"
				print("💥 [AUTO-DESTROY] Distruggo", source_card.card_data.card_name, "poiché il suo effetto è stato annullato.")
				destroy_card(source_card, owner)


	await wait(0.25)

	#if source_card.card_is_in_slot and not source_card.effect_negated:
	if source_card.card_is_in_slot:
		if source_card.has_node("ActionBorder"):
			source_card.get_node("ActionBorder").visible = false
		if source_card.has_node("NextCardBuffedBorder"):
			source_card.get_node("NextCardBuffedBorder").visible = false
		rpc("hide_action_border_on_card", source_card.name)

		if source_card.card_data.card_type == "Spell" and source_card.card_data.card_class != "ContinuousSpell" and source_card.card_data.card_class != "EquipSpell" and not source_card in cards_to_destroy_after_chain:
			if source_card.effect_negated:
				source_card.effect_negated = false
				source_card.set_negated_state(false)
				print("Reset effect negated prima di andare a GY")
			var owner = "Player" if is_attacker else "Opponent"
			destroy_card(source_card, owner)
		# ⚡ NOVITÀ: ContinuousSpell o EquipSpell negate → vengono distrutte
		elif source_card.card_data.card_type == "Spell" and source_card.effect_negated and (source_card.card_data.card_class == "ContinuousSpell" or source_card.card_data.card_class == "EquipSpell"):
			source_card.effect_negated = false
			source_card.set_negated_state(false)
			print("💥 Continuous/Equip Spell negata → distrutta:", source_card.card_data.card_name)
			var owner = "Player" if is_attacker else "Opponent"
			destroy_card(source_card, owner)
		# 🔥 Muovi la carta indietro con un tween animato
		else:
			var tween = get_tree().create_tween()
			if is_attacker:
				tween.tween_property(source_card, "position:y", source_card.position.y + 10, 0.2) # Se io sono chi ha triggerato → torna giù
			else:
				tween.tween_property(source_card, "position:y", source_card.position.y - 10, 0.2) # Se io sono il client → sale su!
				

		source_card.z_index = 0
		
		await get_tree().process_frame
		if source_card.has_node("ActionBorder"):

			source_card.get_node("ActionBorder").z_index = -1
			source_card.get_node("ActionBorder").visible = false
			var ab = source_card.get_node("ActionBorder")
		if source_card.has_node("NextCardBuffedBorder"):
			source_card.get_node("NextCardBuffedBorder").visible = false
		var owner = "Player" if is_attacker else "Opponent"
		rpc("hide_action_border_on_card", source_card.name, owner)
		# 🔇 Spegnimento visivo bottoni RESOLVE e ENEMY RESOLVE

	
		# 👇 Rimuovi overlay di questa carta
	remove_chain_overlay(source_card)


func play_damage_shake(card: Node2D, damage_amount: int = 0) -> void:
	if not is_instance_valid(card):
		return
	
	var original_pos := card.position
	var t := card.create_tween()
	t.set_parallel(false)

	# 🌀 Passo indietro (arretramento dolce, invertito per enemy)
	var direction := 1
	if card.is_enemy_card():
		direction = -1

	if damage_amount != 0:
		# 💥 Arretramento verticale 
		t.tween_property(card, "position:y", original_pos.y + (30 * direction), 0.08)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 💫 Se danno == 0 (es. Phys Immune) → aggiungi leggero shake orizzontale
	if damage_amount == 0:
		t.parallel().tween_property(card, "position:x", original_pos.x + 6, 0.06)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(card, "position:x", original_pos.x - 5, 0.06)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(card, "position:x", original_pos.x + 3, 0.05)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(card, "position:x", original_pos.x, 0.05)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 🔁 Ritorno fluido alla posizione originale
	t.tween_property(card, "position:y", original_pos.y, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func play_damage_dealt_screen_shake(damage_amount: int) -> void:
	var camera := get_parent().get_node_or_null("Camera2D")
	if not is_instance_valid(camera):
		print("⚠️ Nessuna Camera2D trovata per lo screen shake.")
		return

	var original_pos = camera.position

	# 🧮 Intensità proporzionale ai multipli di 500 danni
	var intensity := int(floor(float(damage_amount) / 500.0))
	intensity = clamp(intensity, 1, 8)

	print("🎯 Intensità:", intensity, "(danno:", damage_amount, ")")

	# 💫 Parametri del movimento (perfettamente calibrati su intensity = 1)
	# A intensity 1 -> base_strength = 0.3, punch_strength = 1.0, punch_duration = 0.02, return_duration = 0.1
	# Crescita esponenziale più rapida sopra intensity 1
	var base_strength := 0.3 * pow(1.8, float(intensity - 1))
	var punch_strength := (base_strength + (0.7 * intensity)) * pow(1.3, float(intensity - 1))

	var base_punch_duration := 0.02
	var base_return_duration := 0.1
	var punch_duration := base_punch_duration * pow(1.15, float(intensity - 1))
	var return_duration := base_return_duration * pow(1.1, float(intensity - 1))

	# 🔁 Ferma eventuale movimento precedente
	if camera.has_meta("shake_tween") and is_instance_valid(camera.get_meta("shake_tween")):
		camera.get_meta("shake_tween").kill()
		camera.position = original_pos

	var tween := create_tween()
	camera.set_meta("shake_tween", tween)

	# 💥 Direzione casuale (prevalentemente orizzontale)
	var direction := Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()
	var offset = original_pos + (direction * punch_strength)

	# 🔸 Spinta → ritorno fluido
	tween.tween_property(camera, "position", offset, punch_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", original_pos, return_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	print("💥 Camera shake | forza:", punch_strength, "durata:", punch_duration, "/", return_duration)





func play_summon_camera_impact(strength := 1.0, is_bouncer: bool = false) -> void:
	var camera := get_parent().get_node_or_null("Camera2D")
	if not is_instance_valid(camera):
		return

	if is_bouncer:
		print("IMPACT [BOUNCER]")
	else:
		print("IMPACT [SUMMON]")

	var original_zoom: Vector2 = camera.zoom
	strength = clamp(strength, 0.5, 3.0)

	var amount := 0.06 * strength

	# Zoom OUT (summon) = valore più piccolo
	var zoom_out := original_zoom - Vector2(amount, amount)
	# Zoom IN (bouncer) = valore più grande
	var zoom_in := original_zoom + Vector2(amount, amount)

	var first_duration := 0.12
	var return_duration := 0.18

	# 🛑 Kill tween precedente
	if camera.has_meta("summon_zoom_tween") and is_instance_valid(camera.get_meta("summon_zoom_tween")):
		camera.get_meta("summon_zoom_tween").kill()
		camera.zoom = original_zoom

	var tween := create_tween()
	camera.set_meta("summon_zoom_tween", tween)

	if is_bouncer:
		# 🔁 BOUNCER → prima zoom IN
		tween.tween_property(camera, "zoom", zoom_in, first_duration)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
	else:
		# 🔽 SUMMON → prima zoom OUT
		tween.tween_property(camera, "zoom", zoom_out, first_duration)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)

	# 🔙 Ritorno al valore base (sempre)
	tween.tween_property(camera, "zoom", original_zoom, return_duration)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
















func notify_summon_global(summoned_card: Card) -> void:
	if not is_instance_valid(summoned_card):
		return

	print("📢 [HELPER] notify_summon_global → notifica evocazione di:", summoned_card.card_data.card_name)

	# Determina il lato del campo
	var ally_creatures: Array = []
	if summoned_card.is_enemy_card():
		ally_creatures = opponent_creatures_on_field
	else:
		ally_creatures = player_creatures_on_field

	# 🔍 Avvisa tutte le carte alleate con trigger_type == "While_NoOtherAlly"
	for c in ally_creatures:
		if not is_instance_valid(c):
			continue
		if c == summoned_card:
			continue
		if c.card_data and c.card_data.trigger_type == "While_NoOtherAlly" or c.card_data.trigger_type == "IF_NoOtherAlly":
			print("📣 [SIGNAL] Invio on_ally_summoned →", c.card_data.card_name)
			c._on_ally_summoned(summoned_card)


func notify_card_left_field_global(left_card: Card, reason: String, is_for_tribute_summ: bool = false) -> void:
	if not is_instance_valid(left_card):
		return
	
	print("📢 [GLOBAL] notify_card_left_field_global →", left_card.card_data.card_name, 
		"ha lasciato il campo (motivo:", reason, ") | is_for_tribute_summ:", is_for_tribute_summ)

	# 🛑 Esegui il check solo se la carta uscita è una creatura
	if left_card.card_data.card_type != "Creature":
		print("🚫 [WHILE CHECK SKIPPED] La carta uscita non è una creatura:", left_card.card_data.card_name)
		return

	# ⚠️ Evita attivazioni While_NoOtherAlly se la rimozione è parte di un'evocazione per tributo
	if is_for_tribute_summ:
		print("🕊️ [WHILE IGNORED] Ignoro check While_NoOtherAlly perché rimozione dovuta a tributo d'evocazione.")
		return

	var ally_creatures: Array = []
	if left_card.is_enemy_card():
		ally_creatures = opponent_creatures_on_field
	else:
		ally_creatures = player_creatures_on_field

	# 🧩 Controlla tutte le creature alleate rimaste
	for c in ally_creatures:
		if not is_instance_valid(c):
			continue
		if c.card_data.trigger_type != "While_NoOtherAlly":
			continue

		var valid_allies: Array = []
		for other in ally_creatures:
			if is_instance_valid(other) and other != c:
				valid_allies.append(other)

		if valid_allies.is_empty():
			print("✨ [WHILE REGAINED] While_NoOtherAlly riattivato su", c.card_data.card_name, "dopo che", left_card.card_data.card_name, "è uscita dal campo")

			if chain_locked:
				print("⏸️ [QUEUE] Chain attiva → accodo effetto in triggered_effects_this_chain_link")
				triggered_effects_this_chain_link.append({
					"card": c,
					"owner_id": multiplayer.get_unique_id()
				})
			else:
				var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
				if card_manager and card_manager.has_method("trigger_card_effect"):
					card_manager.trigger_card_effect(c,true)


@rpc("any_peer")
func rpc_sync_just_targeted_creature(card_name: String, owner_id: int):
	var local_id = multiplayer.get_unique_id()
	var card: Node = null

	if local_id == owner_id:
		print("LOCAL CARD")
		card = get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + card_name)

	else:
		print("REMOTE CARD")
		card = $"../CardManager".get_node_or_null(card_name)
	if card:
		just_targeted_creature.clear()
		just_targeted_creature.append({"card": card, "owner_id": owner_id})
		print("📨 [RPC_RECEIVED] rpc_sync_just_targeted_creature ricevuto su peer:", local_id, "| carta:", card_name)
	else:
		push_warning("⚠️ [SYNC] Carta non trovata: " + card_name)


func check_opponent_has_response(is_attacker: bool) -> bool:
	var cm = $"../CombatManager"
	var opponent_has_response := false

	if is_attacker:
		for card in cm.opponent_creatures_on_field:
			if not card or not card.is_card():
				continue
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break

		if not opponent_has_response:
			for card in cm.opponent_spells_on_field:
				if not card or not card.is_card():
					continue
				if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
					opponent_has_response = true
					break
	else:
		for card in cm.player_creatures_on_field:
			if not card or not card.is_card():
				continue
			if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
				opponent_has_response = true
				break

		if not opponent_has_response:
			for card in cm.player_spells_on_field:
				if not card or not card.is_card():
					continue
				if card.position_type == "facedown" or (card.card_data.effect_speed == "Quick" and not card.effect_triggered_this_turn):
					opponent_has_response = true
					break

	return opponent_has_response

func get_valid_targets(source_card: Card, is_attacker: bool = true, forced_subtype: String = "") -> Array:
	var targets: Array = []
	
	if not is_instance_valid(source_card):
		return targets

	var card_data = source_card.card_data
	if not card_data:
		return targets

	var subtype := ""

	if forced_subtype != "":
		subtype = forced_subtype
	else:
		subtype = card_data.t_subtype_1
	
	if subtype == "" or subtype == "None":
		# Se non c’è subtype → ritorna la carta stessa come target implicito
		if is_instance_valid(source_card):
			targets.append(source_card)
		return targets

	print("🧩 [DEBUG BOUNCER] t_subtype_1 di", source_card.card_data.card_name, "=", subtype)
	# 📊 Riferimenti ai campi attivi
	var player_creatures = player_creatures_on_field
	var enemy_creatures = opponent_creatures_on_field
	var player_spells = player_spells_on_field
	var enemy_spells = opponent_spells_on_field

	# 🔎 Se è un effetto Targeted, escludi la carta sorgente
	if card_data.targeting_type == "Targeted":
		if card_data.card_type == "Creature":
			player_creatures = player_creatures.filter(func(c):
				return is_instance_valid(c) and c != source_card
			)
			enemy_creatures = enemy_creatures.filter(func(c):
				return is_instance_valid(c) and c != source_card
			)
		elif card_data.card_type == "Spell":
			player_spells = player_spells.filter(func(c):
				return is_instance_valid(c) and c != source_card
			)
			enemy_spells = enemy_spells.filter(func(c):
				return is_instance_valid(c) and c != source_card
			)

	# 🧭 Logica per subtype
	match subtype:
		# 🌍 GENERALI
		"AllCards":
			targets.append_array(player_creatures)
			targets.append_array(enemy_creatures)
			targets.append_array(player_spells)
			targets.append_array(enemy_spells)

		"AllCreatures":
			targets.append_array(player_creatures)
			targets.append_array(enemy_creatures)

		"AllSpells":
			targets.append_array(player_spells)
			targets.append_array(enemy_spells)

		# 🧩 ALLEATI
		"AllAllyCreatures":
			if is_attacker:
				targets.append_array(player_creatures)
			else:
				targets.append_array(enemy_creatures)

		"AllAllyDEFCreatures":
			var source := []
			if is_attacker:
				source = player_creatures
			else:
				source = enemy_creatures
			for c in source:
				if is_instance_valid(c) and c.position_type == "defense":
					targets.append(c)

		"AllAllyATKCreatures":
			var source := []
			if is_attacker:
				source = player_creatures
			else:
				source = enemy_creatures
			for c in source:
				if is_instance_valid(c) and c.position_type == "attack":
					targets.append(c)

		"AllAllySpells":
			if is_attacker:
				targets.append_array(player_spells)
			else:
				targets.append_array(enemy_spells)

		# 🧩 NEMICI
		"AllEnemyCreatures":
			if is_attacker:
				targets.append_array(enemy_creatures)
			else:
				targets.append_array(player_creatures)

		"AllEnemyDEFCreatures":
			var source := []
			if is_attacker:
				source = enemy_creatures
			else:
				source = player_creatures
			for c in source:
				if is_instance_valid(c) and c.position_type == "defense":
					targets.append(c)

		"AllEnemyATKCreatures":
			var source := []
			if is_attacker:
				source = enemy_creatures
			else:
				source = player_creatures
			for c in source:
				if is_instance_valid(c) and c.position_type == "attack":
					targets.append(c)

		"AllEnemySpells":
			if is_attacker:
				targets.append_array(enemy_spells)
			else:
				targets.append_array(player_spells)

		# ⚔️ POSIZIONALI GLOBALI
		"AllDEFCreatures":
			for c in player_creatures + enemy_creatures:
				if is_instance_valid(c) and c.position_type == "defense":
					targets.append(c)

		"AllATKCreatures":
			for c in player_creatures + enemy_creatures:
				if is_instance_valid(c) and c.position_type == "attack":
					targets.append(c)

		# 🌈 ELEMENTALI
		"AllFireCreatures", "AllEarthCreatures", "AllWaterCreatures", "AllWindCreatures":
			var attr := ""
			if subtype == "AllFireCreatures":
				attr = "Fire"
			elif subtype == "AllEarthCreatures":
				attr = "Earth"
			elif subtype == "AllWaterCreatures":
				attr = "Water"
			elif subtype == "AllWindCreatures":
				attr = "Wind"

			for c in player_creatures + enemy_creatures:
				if is_instance_valid(c) and c.card_data.card_attribute == attr:
					targets.append(c)
					
		"All_NON_WaterNON_Flying_Creatures":
			for c in player_creatures + enemy_creatures:
				if not is_instance_valid(c):
					continue

				# ❌ Escludi Water
				if c.card_data.card_attribute == "Water":
					continue

				# ❌ Escludi Flying
				var talents = c.card_data.get_all_talents()
				if "Flying" in talents:
					continue

				targets.append(c)

		# 👤 SELF & PLAYERS (gestiti altrove)
		"Self", "SelfPlayer", "EnemyPlayer", "BothPlayers":
			pass

		# 🧩 CASI SPECIALI
		"LastPlayedCreature":
			var last_list = $"../CombatManager".just_summoned_creature
			if last_list.size() > 0:
				for entry in last_list:
					if entry.has("card") and is_instance_valid(entry.card):
						targets.append(entry.card)

		"JustTargetedCreature":
			var jt_list = $"../CombatManager".just_targeted_creature
			if jt_list.size() > 0:
				for entry in jt_list:
					if entry.has("card") and is_instance_valid(entry.card):
						targets.append(entry.card)

		"AttackingCreature":
			for c in player_creatures + enemy_creatures:
				if is_instance_valid(c) and c.has_an_attack_target:
					targets.append(c)

		"None",_:
			pass

	# 🚫 Escludi sempre la source_card dai target (anche per AoE)
	targets = targets.filter(func(c):
		return is_instance_valid(c) and c != source_card
	)
	return targets


func handle_forced_combat_end(card: Node2D, reason: String = "removed") -> void:
	# 🔹 Pulisci stato di combattimento
	clear_combat_state(card)
	recheck_combat_status()

	# 🧹 Rimuovi la carta da eventuali code in attesa
	cards_waiting_for_go_to_combat = cards_waiting_for_go_to_combat.filter(func(e): return e.card != card)
	cards_waiting_for_to_damage_step = cards_waiting_for_to_damage_step.filter(func(e): return e.card != card)

	# 🛑 Se una chain è in corso e un combat è attivo → termina forzatamente
	#if chain_locked and any_combat_in_progress: #potrebbe servire
	any_combat_in_progress = false
	chained_this_battle_step = false
	already_chained_in_this_go_to_combat = false
	already_chained_in_this_go_to_damage_step = false

	print("⚠️ [FORCED COMBAT END] Carta", card.name, reason, "durante chain → combat terminato e flag resettati.")

	var action_buttons = $"../ActionButtons"
	action_buttons.on_go_to_combat_pressed()
	action_buttons.on_resolve_pressed()
	action_buttons.on_retaliate_pressed()
	action_buttons.on_to_damage_step_pressed()
	# 🔔 Risveglia eventuali coroutine in attesa di scelte o conferme
	emit_signal("go_to_combat_chosen")
	emit_signal("resolve_choice_received")
	emit_signal("retaliate_choice_received")
	emit_signal("to_damage_step_chosen")

	# 🥊 Se la carta era coinvolta in un combattimento attivo (attaccante o difensore)
	if card.has_an_attack_target or card.is_being_attacked:
		print("⚠️ Carta", card.name, reason, "durante un combat → imposto i flag di attacco/difesa a FALSE.")
		
		any_combat_in_progress = false
		chained_this_battle_step = false
		already_chained_in_this_go_to_combat = false
		already_chained_in_this_go_to_damage_step = false

		card.has_an_attack_target = false
		card.is_being_attacked = false

		# ✅ Riabilita input (es. dopo bouncer o distruzione)
		var input_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/InputManager")
		if input_manager:
			input_manager.inputs_disabled = false
			print("🟢 [INPUT RESET] Input riabilitati dopo", reason, "su", card.card_data.card_name)


func show_player_status_icon(status_name: String, show: bool, is_enemy: bool = false, temp_effect_type: String = "", is_next_damage: bool = false):
	print("🧩 show_player_status_icon CALLED | status:", status_name, "| show:", show, "| is_enemy:", is_enemy, "| temp_effect_type:", temp_effect_type)

	var main_node = get_parent().get_parent()  # CombatManager → PlayerField → Main
	var container_path: String

	if is_enemy:
		container_path = "EnemyField/EnemyStatusContainer"
	else:
		container_path = "PlayerField/PlayerStatusContainer"

	print("🔍 Cerco container:", container_path)
	var container = main_node.get_node_or_null(container_path)
	if container == null:
		push_error("❌ Status container non trovato in " + container_path)
		return

	if not STATUS_ICONS.has(status_name):
		push_warning("⚠️ Nessuna icona definita per status: " + status_name)
		return

	var icon_path = STATUS_ICONS[status_name]
	var owner_dict
	var status_array

	if is_enemy:
		owner_dict = status_icons["enemy"]
		status_array = enemy_statuses
	else:
		owner_dict = status_icons["player"]
		status_array = player_statuses

	# ==========================================================
	# MOSTRA ICONA
	# ==========================================================
	if show:
		var status_data = {
			"name": status_name,
			"temporary": temp_effect_type == "This_Step",
			"temp_effect_type": temp_effect_type,
			"is_next_damage": is_next_damage
		}

		# Aggiungi solo se non esiste già
		var already_present = false
		for s in status_array:
			if s["name"] == status_name:
				already_present = true
				break

		if not already_present:
			status_array.append(status_data)
			if status_data["temporary"]:
				if is_enemy:
					print("⏳ [TEMP STATUS] Aggiunto status temporaneo:", status_name, "→ Enemy")
				else:
					print("⏳ [TEMP STATUS] Aggiunto status temporaneo:", status_name, "→ Player")
			else:
				if is_enemy:
					print("🟢 [STATUS] Aggiunto status permanente:", status_name, "→ Enemy")
				else:
					print("🟢 [STATUS] Aggiunto status permanente:", status_name, "→ Player")

		# Mostra o crea l’icona
		if owner_dict.has(status_name) and is_instance_valid(owner_dict[status_name]):
			owner_dict[status_name].visible = true
		else:
			var icon = TextureRect.new()
			icon.texture = load(icon_path)
			icon.name = status_name.capitalize() + "Icon"
			icon.custom_minimum_size = Vector2(48, 48)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.tooltip_text = status_name.capitalize()

			# ✅ Allineamento diverso per player/enemy
			if is_enemy:
				icon.anchor_left = 1
				icon.anchor_right = 1
				icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # cresce verso sinistra
				icon.pivot_offset = Vector2(icon.size.x, 0)  # sposta il pivot a destra
			else:
				icon.anchor_left = 0
				icon.anchor_right = 0
				icon.grow_horizontal = Control.GROW_DIRECTION_END  # cresce verso destra
				icon.pivot_offset = Vector2(0, 0)  # pivot normale


			container.add_child(icon)
			owner_dict[status_name] = icon
			print("🪄 [STATUS ICON] Aggiunta icona:", status_name, "→", container_path)
			# ✨ Avvia il tween di pulsazione appena appare o si riattiva
			player_status_icon_pulse(icon)


		if temp_effect_type == "This_Step":
			print("💫 [NOTIFY] Lo status", status_name, "è temporaneo e verrà rimosso a fine step.")

		# ==========================================================
		# RIMUOVI ICONA
		# ==========================================================
	else:
		var to_remove: Array[int] = []
		for i in range(status_array.size()):
			if status_array[i]["name"] == status_name:
				to_remove.append(i)

		for i in range(to_remove.size() - 1, -1, -1):
			var idx = to_remove[i]
			status_array.remove_at(idx)
			if is_enemy:
				print("🧹 [STATUS] Rimosso:", status_name, "→ Enemy")
			else:
				print("🧹 [STATUS] Rimosso:", status_name, "→ Player")

		if owner_dict.has(status_name) and is_instance_valid(owner_dict[status_name]):
			owner_dict[status_name].visible = false


func player_status_icon_pulse(icon: TextureRect) -> void:
	if not is_instance_valid(icon):
		return

	# Kill eventuali tween precedenti
	if icon.has_meta("pulse_tween"):
		var old_tween: Tween = icon.get_meta("pulse_tween")
		if is_instance_valid(old_tween):
			old_tween.kill()

	var tween = create_tween()
	icon.set_meta("pulse_tween", tween)

	# Reset stato base
	icon.scale = Vector2(1, 1)
	icon.modulate = Color(1, 1, 1, 1)

	# ✅ Effetto pulsazione: ingrandimento + "glow"
	tween.parallel().tween_property(icon, "scale", Vector2(3, 3), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "modulate", Color(2, 2, 2, 1), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# ✅ Ritorno graduale allo stato normale
	tween.tween_property(icon, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func clear_temporary_statuses():
	for status in player_statuses.duplicate():
		if status["temporary"]:
			show_player_status_icon(status["name"], false, false)
	for status in enemy_statuses.duplicate():
		if status["temporary"]:
			show_player_status_icon(status["name"], false, true)


func _protection_icon_shake(icon: TextureRect, consumed: bool, is_enemy: bool = false):
	# ==============================================================
	# 🔍 Recupera o verifica l'icona dal container corretto
	# ==============================================================
	if icon == null or not is_instance_valid(icon):
		print("❌ _protection_icon_shake: icona nulla o non valida, tento di recuperarla dal container.")

		var main_node = get_parent().get_parent()
		var container_path := ""

		if is_enemy:
			container_path = "EnemyField/EnemyStatusContainer"
		else:
			container_path = "PlayerField/PlayerStatusContainer"

		var container = main_node.get_node_or_null(container_path)
		if container == null:
			push_error("❌ _protection_icon_shake: container non trovato → " + container_path)
			return

		icon = container.get_node_or_null("ProtectionIcon")
		if icon == null or not is_instance_valid(icon):
			push_error("❌ _protection_icon_shake: impossibile recuperare icona Protection in " + container_path)
			return

	# ==============================================================
	# ⚡️ Animazione Shake + Flash colore
	# ==============================================================
	print("💫 _protection_icon_shake avviato | consumed:", consumed)

	var shake_strength := 0.15
	var flash_color := Color(1, 1, 1)
	var offset_px := 5.0  # movimento orizzontale

	if consumed:
		shake_strength = 0.25
		flash_color = Color(1, 0.3, 0.3)
		offset_px = 8.0

	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var tween := create_tween()
	tween.set_parallel(true)

	# ⚡️ Micro movimento orizzontale (funziona anche nei container)
	var original_offset := icon.offset_left
	tween.tween_property(icon, "offset_left", original_offset + offset_px, 0.04)
	tween.tween_property(icon, "offset_left", original_offset - offset_px, 0.04)
	tween.tween_property(icon, "offset_left", original_offset, 0.06)

	# ✨ Flash colore
	tween.tween_property(icon, "modulate", flash_color, 0.1)
	tween.tween_property(icon, "modulate", Color(1, 1, 1), 0.2)

	if consumed:
		await tween.finished
		icon.visible = false


func check_and_consume_protection(is_target_enemy: bool) -> bool:
	# Restituisce true se il bersaglio è protetto dal danno.
	var statuses = enemy_statuses if is_target_enemy else player_statuses
	var icons = status_icons["enemy"] if is_target_enemy else status_icons["player"]
	var protected := false

	for status in statuses:
		if status["name"] == "Protection":
			protected = true
			print("🛡️ [PROTECTION].")

			var icon = null
			if icons.has("Protection"):
				icon = icons["Protection"]

			if status.get("is_next_damage", false):
				print("🧹 [PROTECTION] Effetto Protection (Next Damage) consumato → rimosso.")
				if icon != null and is_instance_valid(icon):
					_protection_icon_shake(icon, true, is_target_enemy)
				show_player_status_icon("Protection", false, is_target_enemy)
			else:
				if icon != null and is_instance_valid(icon):
					_protection_icon_shake(icon, false, is_target_enemy)
			break

	return protected


func resolve_field_spell_conflict(new_card: Node):
	# Deve essere faceup
	if new_card.position_type == "facedown":
		return

	if not is_global_field_spell(new_card):
		return

	var cards_to_destroy: Array = []

	# 🔎 Spell duration 1000 già presenti — MIO CAMPO
	for c in player_spells_on_field:
		if c != new_card and is_global_field_spell(c):
			cards_to_destroy.append(c)

	# 🔎 Spell duration 1000 già presenti — CAMPO AVVERSARIO
	for c in opponent_spells_on_field:
		if c != new_card and is_global_field_spell(c):
			cards_to_destroy.append(c)

	# ❌ Nessun conflitto → esci
	if cards_to_destroy.is_empty():
		return

	print("🌍 [GLOBAL SPELL] Conflitto spell_duration=1000 → distruzione globale")

	# ➕ Distruggi anche la nuova
	cards_to_destroy.append(new_card)
	await get_tree().create_timer(0.25).timeout
	# 💥 Distruzione sincronizzata
	for card in cards_to_destroy:
		if card.is_enemy_card():
			destroy_card(card, "Opponent")
		else:
			destroy_card(card, "Player") 


func is_global_field_spell(card: Node) -> bool:
	if not card or not card.card_data:
		return false

	return (
		card.card_data.card_type == "Spell"
		and card.card_data.spell_duration == 1000
	)

const FIELD_BORDER_COLORS := {
	# 🌊 Acqua – blu pulito, luminoso ma non notturno
	"FieldFlood": Color(0.3, 0.70, 0.95, 1.0),

	# 🔥 Fuoco – rosso caldo deciso (questo va bene)
	"FieldBurn":  Color(1.0, 0.45, 0.25, 1.0),

	# 🌬️ Vento – verde naturale, quasi salvia
	"FieldWindy": Color(0.35, 0.85, 0.50, 1.0),

	# 🏜️ Arido – ocra caldo, rilassante
	"FieldArid": Color(0.75, 0.60, 0.30, 1.0)
}


func apply_field_effect(effect: String, _is_attacker: bool) -> void:
	print("🌍 [FIELD EFFECT] Applico:", effect)

	if not FIELD_BORDER_COLORS.has(effect):
		push_warning("⚠️ Field effect non riconosciuto: " + effect)
		return

	var scene := get_tree().get_current_scene()
	var all_slots := []

	var player_zones = scene.get_node_or_null("PlayerField/PlayerZones")
	if player_zones:
		all_slots += player_zones.get_children()

	var enemy_zones = scene.get_node_or_null("EnemyField/EnemyZones")
	if enemy_zones:
		all_slots += enemy_zones.get_children()

	var target_color: Color = FIELD_BORDER_COLORS[effect]

	for slot in all_slots:
		# 🔁 reset logico
		slot.flooded = false
		slot.burning = false
		slot.windy   = false
		slot.arid    = false

		# ✅ attiva flag corretto
		match effect:
			"FieldFlood": slot.flooded = true
			"FieldBurn":  slot.burning = true
			"FieldWindy": slot.windy   = true
			"FieldArid":  slot.arid    = true

		# 🎨 CROSS-FADE DEL BORDO
		if slot.has_node("SlotBorder"):
			var border = slot.get_node("SlotBorder")

			

			# se è la prima volta → parte da trasparente
			if border.modulate.a == 0.0:
				border.modulate = Color(
					target_color.r,
					target_color.g,
					target_color.b,
					0.0
				)
			
			border.visible = true
			var tween := get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)

			# fade diretto dal colore attuale → nuovo colore
			tween.tween_property(
				border,
				"modulate",
				target_color,
				0.35
			)
			
	await get_tree().create_timer(1.0).timeout
	# ⚠️ SOLO IL PROPRIETARIO DELLA FIELD NOTIFICA I WHILE
	#if not _is_attacker:
		#return
	# 🌊 Notifica alle creature se il campo è diventato Flooded
	if effect == "FieldFlood":
		print("🌊 [FIELD EFFECT] Notifico creature While_FieldFlooded")

		var card_manager = scene.get_node_or_null("PlayerField/CardManager")
		if card_manager == null:
			return

		# 🔍 Prende tutte le creature sul terreno (array già esistenti)
		var all_creatures := []
		all_creatures += $"../CombatManager".player_creatures_on_field
		#all_creatures += $"../CombatManager".opponent_creatures_on_field  #non serve vedere quelle di oppo perche' la chiamata e' gia' replicata su anche il suo client, le guarda da se'

		for c in all_creatures:
			if not is_instance_valid(c):
				continue
			if not c.card_data:
				continue
			if c.card_data.trigger_type != "While_FieldFlooded":
				continue

			print("✨ [TRIGGER] While_FieldFlooded attivato per", c.card_data.card_name)

			# stesso pattern delle altre While
			#if chain_locked:
				#print("CHAIN LOCKED FLOODED")
				#triggered_effects_this_chain_link.append({
					#"card": c,
					#"owner_id": c.multiplayer.get_unique_id()
				#})
			#else:
			if card_manager.has_method("trigger_card_effect"):
				print("TRIGGERO EFFETTO DA FLOODED")
				card_manager.trigger_card_effect(c,true)





func remove_field_effects() -> void:
	print("🧹 [FIELD EFFECT] Rimozione field effect")

	var scene := get_tree().get_current_scene()
	var all_slots := []

	var player_zones = scene.get_node_or_null("PlayerField/PlayerZones")
	if player_zones:
		all_slots += player_zones.get_children()

	var enemy_zones = scene.get_node_or_null("EnemyField/EnemyZones")
	if enemy_zones:
		all_slots += enemy_zones.get_children()

	for slot in all_slots:
		# reset logico
		slot.flooded = false
		slot.burning = false
		slot.windy   = false
		slot.arid    = false

		# 🎨 fade-out SlotBorder
		if slot.has_node("SlotBorder"):
			var border = slot.get_node("SlotBorder")

			var tween := get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)

			tween.tween_property(
				border,
				"modulate",
				Color(1, 1, 1, 0.0),
				0.35
			)

			# nascondi alla fine
			tween.finished.connect(func():
				border.visible = false
			)


	var all_creatures = player_creatures_on_field + opponent_creatures_on_field

	for c in all_creatures:
		if is_instance_valid(c) \
		and c.card_data \
		and c.card_data.trigger_type == "While_FieldFlooded":
			print("❌ [WHILE LOST] While_FieldFlooded perso da", c.card_data.card_name)
			c.emit_signal("lost_while_condition", c)

func _trigger_when_equipped_effect(target_card: Card, equip_card: Card) -> void:
	if not is_instance_valid(target_card):
		return
	if not target_card.card_data:
		return
	if target_card.card_data.trigger_type != "When_Equipped":
		return

	print("✨ [WHEN_EQUIPPED] Trigger su", target_card.card_data.card_name)

	if chain_locked:
		print("⏸️ [QUEUE] Chain attiva → accodo When_Equipped")
		triggered_effects_this_chain_link.append({
			"card": target_card,
			"owner_id": multiplayer.get_unique_id()
		})
	else:
		var card_manager = get_tree().get_current_scene() \
			.get_node_or_null("PlayerField/CardManager")

		if card_manager and card_manager.has_method("trigger_card_effect"):
			card_manager.trigger_card_effect(target_card, true, equip_card)


@rpc("any_peer")
func rpc_clear_just_happened_arrays():
	print("🧹 [RPC] Pulizia just_* su peer:", multiplayer.get_unique_id())

	just_summoned_creature.clear()
	just_played_spell.clear()
	just_targeted_creature.clear()

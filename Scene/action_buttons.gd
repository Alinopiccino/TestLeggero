extends Node2D

signal retaliate_chosen
signal direct_attack_chosen
signal resolve_chosen
signal go_to_combat_chosen
signal to_damage_step_chosen

var player_wants_to_retaliate: bool = false
var current_visible_label: RichTextLabel = null
var auto_skip_resolve: bool = false
var enemy_auto_skip_resolve: bool = false

@onready var retaliate_button = $PlayerRetaliateButton
@onready var ok_button = $PlayerOkButton
@onready var resolve_button = $PlayerResolveButton
@onready var direct_attack_button = $PlayerDirectAttackButton
@onready var go_to_combat_button = $PlayerGoToCombatButton
@onready var to_damage_step_button = $PlayerToDamageStepButton

@onready var auto_skip_resolve_checkbox: CheckBox = $"../PlayerAutoSkipResolve"
@onready var enchain_label = $"../PromptLabels/PlayerEnchainLabel"
@onready var player_selection_label = $"../PromptLabels/PlayerSelectionLabel"
@onready var enemy_resolve_button = $EnemyResolveButton  # già definito in hide_all_buttons
@onready var proceed_step_label = $"../PromptLabels/ProceedStepLabel"
@onready var hourglass_icon = $"../HourglassIcon"
var hourglass_tween: Tween


func _ready():
	retaliate_button.pressed.connect(on_retaliate_pressed)
	ok_button.pressed.connect(on_ok_pressed)
	resolve_button.pressed.connect(on_resolve_pressed)
	direct_attack_button.pressed.connect(on_direct_attack_pressed)
	go_to_combat_button.pressed.connect(on_go_to_combat_pressed)
	to_damage_step_button.pressed.connect(on_to_damage_step_pressed)
	auto_skip_resolve_checkbox.toggled.connect(_on_auto_skip_resolve_toggled)
	
		# Assicurati che parta invisibile
	if hourglass_icon:
		hourglass_icon.pivot_offset = hourglass_icon.size / 2
		hourglass_icon.visible = false
		hourglass_icon.rotation_degrees = 0
		
	if enchain_label:
		enchain_label.visible = false
	
		# 👇 Nasconde il bottone visivo lato nemico
	if enemy_resolve_button:
		enemy_resolve_button.visible = false
		enemy_resolve_button.disabled = true
	
	## 👇 forza la clessidra visibile all’avvio
	#if hourglass_icon:
		#hourglass_icon.visible = true
	
	update_buttons_visibility()  # Mostra solo pass phase all'inizio
	update_pass_phase_button_state()  # 👈 MOSTRA il pass phase se appropriato
	
@rpc("any_peer")
func rpc_show_resolve_button_for_next_player():
	print("📬 [RPC] Mostra bottone RESOLVE → ricevente:", multiplayer.get_unique_id())
	show_resolve_button()
# 📌 Funzione centrale: mostra solo un tipo di bottoni alla volta secondo priorità
func update_buttons_visibility(show_resolve := false, show_retaliate := false, show_direct_attack := false, show_go_to_combat := false, show_to_damage_step := false):
	hide_all_buttons(show_to_damage_step)  # 👈 passa l’informazione corretta


		# 👇 ogni volta che appaiono bottoni interattivi → nascondo la clessidra
	if show_resolve or show_retaliate or show_direct_attack or show_go_to_combat or show_to_damage_step:
		if hourglass_icon:
			hourglass_icon.visible = false
			stop_hourglass_animation()

	
	if show_resolve:
		visible = true
		resolve_button.visible = true
		resolve_button.disabled = false
		return  # 🔙 Blocca tutto il resto

	if show_retaliate:
		visible = true
		retaliate_button.visible = true
		retaliate_button.disabled = false
		ok_button.visible = true
		ok_button.disabled = false
		return

	if show_direct_attack:
		visible = true
		direct_attack_button.visible = true
		direct_attack_button.disabled = false
		return

	if show_go_to_combat:
		visible = true
		go_to_combat_button.visible = true
		go_to_combat_button.disabled = false
		return
	
	if show_to_damage_step:
		visible = true
		to_damage_step_button.visible = true
		to_damage_step_button.disabled = false
		return

	## Se nessuno degli altri è attivo, mostra Pass Phase
	#var phase_manager = get_parent().get_node_or_null("PhaseManager")
	#if phase_manager:
		#var combat_manager = get_parent().get_node_or_null("CombatManager")
		#if combat_manager and combat_manager.chain_locked:
			#phase_manager.player_pass_button.visible = false
			#phase_manager.player_pass_button.disabled = true
		#else:
			#phase_manager.player_pass_button.visible = true
			#phase_manager.player_pass_button.disabled = phase_manager.has_passed_this_phase
#
	## 🔁 Sincronizza Pass Phase sui due client
	#var other_peer_id = multiplayer.get_peers()[0] if multiplayer.get_peers().size() > 0 else null
	#if other_peer_id != null:
		#if are_action_buttons_visible():
			#rpc_id(other_peer_id, "rpc_disable_pass_phase")
		#else:
			#rpc_id(other_peer_id, "rpc_enable_pass_phase")


func update_pass_phase_button_state():
	var phase_manager = get_parent().get_node_or_null("PhaseManager")
	var combat_manager = get_parent().get_node_or_null("CombatManager")

	if not phase_manager:
		return

	# 🔒 Se la chain è locked, disattiva e nascondi il bottone
	#if combat_manager and combat_manager.chain_locked:
		#phase_manager.player_pass_button.visible = false
		#phase_manager.player_pass_button.disabled = true
		#return
	
	print("📊 update_pass_phase_button_state()")
	print(" - resolve_button.visible:", resolve_button.visible)
	print(" - go_to_combat_button.visible:", go_to_combat_button.visible)
	print(" - to_damage_step_button.visible:", to_damage_step_button.visible)

	if not are_action_buttons_visible():
		print("✅ Nessun altro bottone visibile → mostro Pass Phase")
		if phase_manager.player_action_count != 0:
			phase_manager.player_pass_button.visible = true
			phase_manager.player_pass_button.disabled = phase_manager.has_passed_this_phase
		if hourglass_icon:
			hourglass_icon.visible = false
			stop_hourglass_animation()

	else:
		print("⛔ Altri bottoni visibili → NON mostro Pass Phase")

# 🔘 Bottoni individuali (wrapper per chiarezza e compatibilità)
func show_resolve_button():
	update_buttons_visibility(true)
	show_label($"../PromptLabels/PlayerEnchainLabel")

	var other_peer_id = get_other_peer_id()
	if other_peer_id != -1:
		rpc_id(other_peer_id, "rpc_hide_pass_phase_button")

func hide_resolve_button(force := false):
	var combat_manager = get_parent().get_node_or_null("CombatManager")
	var phase_manager = get_parent().get_node_or_null("PhaseManager")
	var my_id = multiplayer.get_unique_id()

	# 🔥 Nascondi sempre il bottone quando viene premuto
	resolve_button.visible = false
	resolve_button.disabled = true
	visible = false
	hide_label($"../PromptLabels/PlayerEnchainLabel")

	update_buttons_visibility()
	hide_label($"../PromptLabels/PlayerEnchainLabel")

	# 👇 Dopo un frame, mostra Pass Phase solo se chi ha l'azione è questo giocatore
	await get_tree().process_frame

	#if not are_action_buttons_visible() and phase_manager:
		## ✅ Solo chi ha l'azione deve vedere il Pass Phase
		#if phase_manager.player_action_count == 1:
			#print("🟢 Questo client ha l'azione → mostra Pass Phase")
			#rpc_show_pass_phase_button()
		#else:
			#print("🔴 Non è il turno di questo client → NON mostrare Pass Phase")


func show_buttons():  # Retaliate/OK
	update_buttons_visibility(false, true)
	
	var other_peer_id = get_other_peer_id()
	if other_peer_id != -1:
		rpc_id(other_peer_id, "rpc_hide_pass_phase_button")

func hide_buttons():
	update_buttons_visibility()
	
	#if not are_action_buttons_visible():
		#var other_peer_id = get_other_peer_id()
		#if other_peer_id != -1:
			#rpc_id(other_peer_id, "rpc_show_pass_phase_button")

func show_direct_attack_button():
	update_buttons_visibility(false, false, true)

func hide_direct_attack_button():
	update_buttons_visibility()

func show_go_to_combat_button():
	update_buttons_visibility(false, false, false, true)
	show_label($"../PromptLabels/PlayerEnchainLabel")
	
	var other_peer_id = get_other_peer_id()
	if other_peer_id != -1:
		rpc_id(other_peer_id, "rpc_hide_pass_phase_button")
	
func hide_go_to_combat_button():
	update_buttons_visibility()
	hide_label($"../PromptLabels/PlayerEnchainLabel")
	
	#if not are_action_buttons_visible():
		#var other_peer_id = get_other_peer_id()
		#if other_peer_id != -1:
			#rpc_id(other_peer_id, "rpc_show_pass_phase_button")
		
func show_to_damage_step_button():
	update_buttons_visibility(false, false, false, false, true)
	show_label($"../PromptLabels/PlayerEnchainLabel")
	
	var other_peer_id = get_other_peer_id()
	if other_peer_id != -1:
		rpc_id(other_peer_id, "rpc_hide_pass_phase_button")

func hide_to_damage_step_button():
	update_buttons_visibility()
	hide_label($"../PromptLabels/PlayerEnchainLabel")
	
	#if not are_action_buttons_visible():
		#var other_peer_id = get_other_peer_id()
		#if other_peer_id != -1:
			#rpc_id(other_peer_id, "rpc_show_pass_phase_button")

# 🔄 Nasconde tutti i bottoni (interno)
func hide_all_buttons(damage_step_active := false):
	visible = false

	
	retaliate_button.visible = false
	retaliate_button.disabled = true

	ok_button.visible = false
	ok_button.disabled = true

	resolve_button.visible = false
	resolve_button.disabled = true

	direct_attack_button.visible = false
	direct_attack_button.disabled = true

	go_to_combat_button.visible = false
	go_to_combat_button.disabled = true

	to_damage_step_button.visible = false
	to_damage_step_button.disabled = true

	var enemy_retaliate_button = $EnemyRetaliateButton
	var enemy_ok_button = $EnemyOkButton
	#var enemy_resolve_button = $EnemyResolveButton
	
## ⚠️ Nascondi solo se non deve restare visivo
	#if enemy_resolve_button and not damage_step_active:
		#enemy_resolve_button.visible = false
		#enemy_resolve_button.disabled = true

	if not damage_step_active:
		if enemy_retaliate_button:
			enemy_retaliate_button.visible = false
			enemy_retaliate_button.disabled = true

		if enemy_ok_button:
			enemy_ok_button.visible = false
			enemy_ok_button.disabled = true

	var phase_manager = get_parent().get_node_or_null("PhaseManager")
	if phase_manager:
		phase_manager.player_pass_button.visible = false
		phase_manager.player_pass_button.disabled = true

	if hourglass_icon: #POTREBBE CAUSARE BUG DI NON MOSTRAGGIO CLESSIDRA, MA L'HO MESSO PERHCE DOPO COMBAT CHAIN APPARE CLESSIDRA SENZA MOIVO
		hourglass_icon.visible = false
		stop_hourglass_animation()
# 👆 Eventi pulsanti
func on_direct_attack_pressed():

	
	if $"../CardManager".selection_mode_active and not direct_attack_button.visible: #LASCIA NOT VISIBLE PERCHE' SENNO NON PUOI MAI PREMERE DIRECT ATK
		direct_attack_button.focus_mode = Control.FOCUS_NONE
		direct_attack_button.release_focus()
		print("⛔ Ignorato: sei in selection mode.")
		return
	direct_attack_button.focus_mode = Control.FOCUS_ALL
	emit_signal("direct_attack_chosen")
	hide_direct_attack_button()

func on_resolve_pressed():
	

		
	if $"../CardManager".selection_mode_active:
		resolve_button.focus_mode = Control.FOCUS_NONE
		resolve_button.release_focus()
		print("⛔ Ignorato: sei in selection mode.")
		return

	resolve_button.focus_mode = Control.FOCUS_ALL
	emit_signal("resolve_chosen")
	hide_resolve_button()

func on_retaliate_pressed():

	if $"../CardManager".selection_mode_active:
		retaliate_button.focus_mode = Control.FOCUS_NONE
		retaliate_button.release_focus()
		print("⛔ Ignorato: sei in selection mode.")
		return
	retaliate_button.focus_mode = Control.FOCUS_ALL
	player_wants_to_retaliate = true
	emit_signal("retaliate_chosen")

func on_ok_pressed():

	if $"../CardManager".selection_mode_active:
		ok_button.focus_mode = Control.FOCUS_NONE
		ok_button.release_focus()
		print("⛔ Ignorato: sei in selection mode.")
		return
	ok_button.focus_mode = Control.FOCUS_ALL
	player_wants_to_retaliate = false
	emit_signal("retaliate_chosen")

func on_go_to_combat_pressed():

	if $"../CardManager".selection_mode_active:
		go_to_combat_button.focus_mode = Control.FOCUS_NONE
		go_to_combat_button.release_focus()
		print("⛔ Ignorato: sei in selection mode.")
		return
	go_to_combat_button.focus_mode = Control.FOCUS_ALL
	emit_signal("go_to_combat_chosen")
	hide_go_to_combat_button()
	# ✅ Imposta su entrambi i client la variabile
	var combat_manager = $"../CombatManager"
	combat_manager.opponent_pressed_go_to_combat = true
	var other_player_id = multiplayer.get_peers()[0]
	if other_player_id:
		combat_manager.rpc_id(other_player_id, "notify_opponent_pressed_go_to_combat")

func on_to_damage_step_pressed():

	if $"../CardManager".selection_mode_active:
		to_damage_step_button.focus_mode = Control.FOCUS_NONE
		to_damage_step_button.release_focus()
		print("⛔ Ignorato: sei in selection mode.")
		return

	to_damage_step_button.focus_mode = Control.FOCUS_ALL
	# ✅ Setta il flag in locale
	var combat_manager = $"../CombatManager"
	combat_manager.attacker_pressed_to_damage_step = true
	emit_signal("to_damage_step_chosen")
	hide_to_damage_step_button()
	# ✅ Notifica anche l'altro client
	var other_player_id = multiplayer.get_peers()[0]
	if other_player_id:
		combat_manager.rpc_id(other_player_id, "notify_opponent_pressed_to_damage_step")

	
func show_enemy_retaliate_button():
	var enemy_retaliate_button = $EnemyRetaliateButton
	if enemy_retaliate_button:
		enemy_retaliate_button.visible = true
		enemy_retaliate_button.disabled = true  # È solo visivo

func show_enemy_ok_button():
	var enemy_ok_button = $EnemyOkButton
	if enemy_ok_button:
		enemy_ok_button.visible = true
		enemy_ok_button.disabled = true  # È solo visivo
		
func show_enemy_resolve_button():
	var enemy_resolve_button = $EnemyResolveButton
	if enemy_resolve_button:
		enemy_resolve_button.visible = true
		enemy_resolve_button.disabled = true  # Solo estetico

func hide_enemy_response_buttons():
	var damage_step_active = to_damage_step_button.visible

	if damage_step_active:
		return  # ❗ NON nascondere se siamo ancora nel damage step

	var enemy_retaliate_button = $EnemyRetaliateButton
	if enemy_retaliate_button:
		enemy_retaliate_button.visible = false
		enemy_retaliate_button.disabled = true

	var enemy_ok_button = $EnemyOkButton
	if enemy_ok_button:
		enemy_ok_button.visible = false
		enemy_ok_button.disabled = true
		
	var enemy_resolve_button = $EnemyResolveButton
	if enemy_resolve_button:
		enemy_resolve_button.visible = false
		enemy_resolve_button.disabled = true


func show_label(label_to_show: RichTextLabel):
	var my_id = multiplayer.get_unique_id()
	var cm = $"../CombatManager"

	# 🔒 BLOCCO: non mostrare nulla se la catena è in risoluzione o se l'ultima carta inserita è tua
	if cm.chain_locked:
		print("⛔ Label bloccata (chain_locked attivo)")
		return

	if (
		(cm.already_chained_in_this_go_to_combat and not $"../ActionButtons".to_damage_step_button.visible and not $"../ActionButtons".resolve_button.visible)
		or
		(cm.already_chained_in_this_go_to_damage_step and not $"../ActionButtons".go_to_combat_button.visible and not $"../ActionButtons".resolve_button.visible)
	):
		print("⛔ Label bloccata (già chained in questa fase) → mostro ProceedStepLabel")
		return

	if cm.effect_stack.size() > 0:
		var last_card = cm.effect_stack.back()
		if last_card.player_id == my_id:
			print("⛔ Label bloccata (ultima carta è mia)")
			return

	if not label_to_show:
		return

	# 🔍 Se è la enchain_label, controlla se ci sono davvero carte attivabili
	if label_to_show == enchain_label:
		var should_show_label := false

		for card in cm.player_creatures_on_field + cm.player_spells_on_field:
			if can_card_be_enchained(card, cm):
				should_show_label = true
				break

		if not should_show_label:
			print("🔕 Nessuna carta valida per enchain → label non mostrata")
			return

	# ✅ Mostra l’etichetta e i green border coerenti
	highlight_cards_for_enchain(true)

	var label_container = label_to_show.get_parent()
	for child in label_container.get_children():
		if child is RichTextLabel:
			child.visible = (child == label_to_show)



func hide_label(label_to_hide: RichTextLabel):
	if not label_to_hide:
		return
	label_to_hide.visible = false

	if label_to_hide == enchain_label:
		highlight_cards_for_enchain(false)

	var fallback_label: RichTextLabel = null
	if resolve_button.visible or retaliate_button.visible or go_to_combat_button.visible or to_damage_step_button.visible:
		fallback_label = enchain_label
	elif selection_mode_should_be_visible():
		fallback_label = player_selection_label
	
	if proceed_step_label:
		proceed_step_label.visible = false

	if fallback_label:
		show_label(fallback_label)


func selection_mode_should_be_visible() -> bool:
	var card_manager = get_parent().get_node_or_null("CardManager")
	if card_manager:
		return card_manager.selection_mode_active
	return false
	
func highlight_cards_for_enchain(should_show: bool):
	var cm = $"../CombatManager"
	var my_id = multiplayer.get_unique_id()

	# 🔒 Blocca la visualizzazione se la catena è locked
	if cm.chain_locked:
		print("⛔ Green border bloccato (chain_locked)")
		return

	# 🔒 Blocca se già chained nello stesso step
	if (
		(cm.already_chained_in_this_go_to_combat and not $"../ActionButtons".to_damage_step_button.visible and not $"../ActionButtons".resolve_button.visible)
		or
		(cm.already_chained_in_this_go_to_damage_step and not $"../ActionButtons".go_to_combat_button.visible and not $"../ActionButtons".resolve_button.visible)
	):
		print("⛔ Green border bloccato (già chained in questo step)")
		return

	# 🔒 Blocca se l'ultima carta nello stack è tua
	if cm.effect_stack.size() > 0:
		var last_card = cm.effect_stack.back()
		if last_card.player_id == my_id:
			print("⛔ Green border bloccato (ultima carta nello stack è mia)")
			return

	# 🟩 Controlla tutte le carte del giocatore
	for card in cm.player_creatures_on_field + cm.player_spells_on_field:
		if not card or not card.card_is_in_slot:
			continue

		# Usa la helper centralizzata
		var can_enchain = can_card_be_enchained(card, cm)

		if card.has_node("GreenHighlightBorder"):
			card.get_node("GreenHighlightBorder").visible = (should_show and can_enchain)

			if should_show and can_enchain:
				print("🟩 [Enchain] Carta attivabile:", card.card_data.card_name)
			elif should_show:
				print("🔕 [Enchain] Carta non valida per enchain:", card.card_data.card_name)




				
func force_hide_all_green_borders():
	for card in $"../CombatManager".player_creatures_on_field + $"../CombatManager".player_spells_on_field:
		if card and card.has_node("GreenHighlightBorder"):
			card.get_node("GreenHighlightBorder").visible = false


@rpc("any_peer")
func rpc_hide_pass_phase_button():
	var local_id = multiplayer.get_unique_id()
	print("📥 [RPC] HIDE Pass Phase → eseguito su peer:", local_id)

	var phase_manager = get_parent().get_node_or_null("PhaseManager")
	if phase_manager:
		#phase_manager.player_pass_button.visible = false
		phase_manager.player_pass_button.disabled = true
		print("⛔ Pass Phase nascosto (peer:", local_id, ")")

	# ⏳ Mostra la clessidra
	if hourglass_icon:
		hourglass_icon.visible = true
		print("⏳ HourglassIcon VISIBILE (peer:", local_id, ")")
		start_hourglass_animation()


@rpc("any_peer")
func rpc_show_pass_phase_button():
	var local_id = multiplayer.get_unique_id()
	print("📥 [RPC] SHOW Pass Phase → eseguito su peer:", local_id)

	# Aspetta un frame così eventuali bottoni si chiudono
	await get_tree().process_frame

	# Prima di ri-mostrarlo → nascondi la clessidra
	if hourglass_icon:
		
		hourglass_icon.visible = false
		stop_hourglass_animation()
		print("✅ HourglassIcon NASCOSTO (peer:", local_id, ")")

	# Ricalcola lo stato dei bottoni dopo la UI cleanup
	update_pass_phase_button_state()
	var phase_manager = get_parent().get_node_or_null("PhaseManager")
	if phase_manager and phase_manager.player_pass_button.visible:
		print("✅ Pass Phase mostrato (peer:", local_id, ")")
	else:
		print("⚠️ Pass Phase NON mostrato (peer:", local_id, ")")


			
func are_action_buttons_visible() -> bool:
	return (
		resolve_button.visible
		or retaliate_button.visible
		or ok_button.visible
		or go_to_combat_button.visible
		or to_damage_step_button.visible
	)

func get_other_peer_id() -> int:
	for peer_id in multiplayer.get_peers():
		if peer_id != multiplayer.get_unique_id():
			return peer_id
	return -1  # Nessun altro peer


# Avvia animazione clessidra
func start_hourglass_animation():
	if not hourglass_icon:
		return
	# interrompi eventuale animazione precedente
	if hourglass_tween:
		hourglass_tween.kill()
		hourglass_tween = null
	
	# resetta sempre la rotazione a 0° quando (ri)appare
	hourglass_icon.rotation_degrees = 0
	
	# crea nuovo tween
	hourglass_tween = create_tween()
	hourglass_tween.tween_property(
		hourglass_icon, "rotation_degrees", 360, 1.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# loop con pausa
	hourglass_tween.finished.connect(func():
		hourglass_icon.rotation_degrees = 0
		await get_tree().create_timer(1.0).timeout
		start_hourglass_animation()
	)


func stop_hourglass_animation():
	if hourglass_tween:
		hourglass_tween.kill()
		hourglass_tween = null
	if hourglass_icon:
		# reset anche quando la nascondi
		hourglass_icon.rotation_degrees = 0


# =========================================================
# 🧩 HELPER: verifica se una carta può essere enchained
# =========================================================
func can_card_be_enchained(card: Node, cm: Node) -> bool:
	if not card or not is_instance_valid(card):
		return false
	if not cm or not is_instance_valid(cm):
		return false
	if not card.card_is_in_slot:
		return false

	var data = card.card_data
	if not data:
		return false

	# ⚙️ Classificazione base
	var is_instant_spell = data.card_class == "InstantSpell"
	var is_quick_effect = data.effect_type == "Activable" and data.effect_speed == "Quick"
	var is_counter_spell = data.effect_1 == "Counter" and data.trigger_type == "On_Cast"

	# 💥 Deve essere almeno uno di questi tipi
	if not (is_instant_spell or is_quick_effect or is_counter_spell):
		return false

	# 🔒 ❌ Blocca se la carta è appena stata giocata (è in just_played_spell)
	for entry in cm.just_played_spell:
		if entry.has("card") and is_instance_valid(entry.card) and entry.card == card:
			print("⛔ [Enchain] Carta appena giocata, non può essere enchainata:", card.card_data.card_name)
			return false
			
	# 🔒 Blocca se già usata in questo turno
	if card.effect_triggered_this_turn:
		return false

	# 🔧 Riferimenti campo
	var player_creatures = cm.player_creatures_on_field
	var enemy_creatures = cm.opponent_creatures_on_field
	var player_spells = cm.player_spells_on_field
	var enemy_spells = cm.opponent_spells_on_field

	var targeting_type = data.targeting_type
	var t_subtype = data.t_subtype_1
	var activation_cost = data.activation_cost
	var effect_type = data.effect_type

	# 🩸 Controllo costo "sacrificeAllyCreature"
	if activation_cost == "sacrificeAllyCreature":
		if player_creatures.size() == 0:
			return false

		# se anche targeted, controlla condizioni specifiche
		if targeting_type == "Targeted":
			match t_subtype:
				"AllAllyCreatures":
					if player_creatures.size() < 2:
						return false
				"AllEnemyCreatures":
					if player_creatures.size() < 1 or enemy_creatures.size() < 1:
						return false
				"AllCreatures":
					if player_creatures.size() < 1 or (player_creatures.size() + enemy_creatures.size()) < 2:
						return false
							
	## 🎯 Controllo targeting generico centralizzato
	if targeting_type == "Targeted":
		var valid_targets = cm.get_valid_targets(card, true)
		if valid_targets.is_empty():
			print("NESSUN TARGET VALIDO PER EFFETTO TARGETENCHAINABLE")
			return false
	### 🎯 Controllo targeting generico
	#if targeting_type == "Targeted":
		#match t_subtype:
			#"AllCreatures":
				#if player_creatures.size() == 0 and enemy_creatures.size() == 0:
					#return false
			#"AllAllyCreatures":
				#if player_creatures.size() == 0:
					#return false
			#"AllEnemyCreatures":
				#if enemy_creatures.size() == 0:
					#return false
			#"AllSpells":
				#if player_spells.size() <= 1 and enemy_spells.size() == 0:
					#return false
			#"AllEnemySpells":
				#if enemy_spells.size() == 0:
					#return false
			## 🆕 Nuovi casi di targeting specifici
			#"AllEnemyDEFCreatures":
				#var has_def = false
				#for c in enemy_creatures:
					#if is_instance_valid(c) and c.position_type == "defense":
						#has_def = true
						#break
				#if not has_def:
					#return false
#
			#"AllEnemyATKCreatures":
				#var has_atk = false
				#for c in enemy_creatures:
					#if is_instance_valid(c) and c.position_type == "attack":
						#has_atk = true
						#break
				#if not has_atk:
					#return false
#
			#"AllAllyDEFCreatures":
				#var has_def = false
				#for c in player_creatures:
					#if is_instance_valid(c) and c.position_type == "defense":
						#has_def = true
						#break
				#if not has_def:
					#return false
#
			#"AllAllyATKCreatures":
				#var has_atk = false
				#for c in player_creatures:
					#if is_instance_valid(c) and c.position_type == "attack":
						#has_atk = true
						#break
				#if not has_atk:
					#return false
	# 🧩 Caso Counter (On_Cast)
	if is_counter_spell:
		if cm.effect_stack.size() == 0:
			return false

		# 📦 Ottieni la carta precedente nella chain
		var last_index = cm.effect_stack.size() - 1
		var target_entry = cm.effect_stack[last_index]
		var target_card: Node = null
		if target_entry.player_id == multiplayer.get_unique_id():
			target_card = cm.get_node("../CardManager").get_node_or_null(target_entry.card_name)
		else:
			target_card = cm.get_parent().get_parent().get_node_or_null("EnemyField/CardManager/" + target_entry.card_name)

		if not is_instance_valid(target_card):
			return false

		# 🚫 NUOVO BLOCCO: il counter funziona SOLO su SPELL
		if not target_card.card_data:
			return false

		var target_class = target_card.card_data.card_class
		if target_class != "Spell" and target_class != "InstantSpell":
			print("🚫 [COUNTER] Target non è una spell:", target_card.card_data.card_name)
			return false

		# 💰 Threshold ApplyToUnderXmanaCost
		if data.effect_1_threshold_type == "ApplyToUnderXmanaCost":
			var threshold_value = data.effect_1_threshold
			var mana_cost = target_card.card_data.get_mana_cost()

			if mana_cost <= threshold_value:
				print("✅ [COUNTER] Enchain consentito su spell:", target_card.card_data.card_name)
				return true
			else:
				print("🚫 [COUNTER] Mana troppo alto per counter:", target_card.card_data.card_name)
				return false

		# ✅ Counter valido su spell
		return true


	# ⚔️ Caso On_Attack
	if data.trigger_type == "On_Attack":
		var any_attacking = false
		for c in player_creatures + enemy_creatures:
			if not c or not c.has_an_attack_target:
				continue
			any_attacking = true
			break
		if not any_attacking:
			return false

	# 🟩 Caso speciale "LastPlayedCreature"
	if t_subtype == "LastPlayedCreature":
		var has_recent = false
		for entry in cm.just_summoned_creature:
			if entry.has("card") and is_instance_valid(entry.card):
				has_recent = true
				break
		if not has_recent:
			return false

			
	# 🟧 Nuovo caso speciale "JustTargetedCreature"
	if t_subtype == "JustTargetedCreature":
		var has_targeted = false
		for entry in cm.just_targeted_creature:
			if entry.has("card") and is_instance_valid(entry.card):
				has_targeted = true
				break
		if not has_targeted:
			return false

	# ✅ SE ARRIVI QUI, TUTTI I CONTROLLI SONO PASSATI
	return true

func _input(event):
	if event.is_action_pressed("ui_confirm"):  #in project settings , input map, c'e' una barra azioni che ho chiamato ui confirm
		print("PENE")
		# Resolve ha la massima priorità
		if resolve_button.visible and not resolve_button.disabled:
			on_resolve_pressed()
			get_viewport().set_input_as_handled()
			return

		if go_to_combat_button.visible and not go_to_combat_button.disabled:
			on_go_to_combat_pressed()
			get_viewport().set_input_as_handled()
			return

		if to_damage_step_button.visible and not to_damage_step_button.disabled:
			on_to_damage_step_pressed()
			get_viewport().set_input_as_handled()
			return


func _on_auto_skip_resolve_toggled(pressed: bool) -> void:

	auto_skip_resolve = pressed
	print("☑️ [ActionButtons] Auto-skip resolve:", auto_skip_resolve)
	# 🔥 RIMUOVE IL FOCUS
	auto_skip_resolve_checkbox.release_focus()
	auto_skip_resolve_checkbox.focus_mode = Control.FOCUS_NONE
	# Sync al peer (stato, non UI)
	rpc("rpc_set_enemy_auto_skip_resolve", auto_skip_resolve)


@rpc("any_peer")
func rpc_set_enemy_auto_skip_resolve(value: bool) -> void:
	enemy_auto_skip_resolve = value
	print("📡 [ActionButtons] Enemy auto-skip resolve:", enemy_auto_skip_resolve)

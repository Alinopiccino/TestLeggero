extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_ENEMY_CARD = 16 #devi guardare il value che c'e' in quel layer e riportare quel valore
const COLLISION_MASK_DECK = 4
const COLLISION_MASK_GY = 128


var card_manager_reference
var deck_reference
var inputs_disabled = false #se vuoi impedire un input basta che metti if input_disabled : return su quella specifica funzione

func _ready() -> void:
	card_manager_reference = $"../CardManager"
	deck_reference = $"../Deck"


func _input(event):
	#if inputs_disabled:
		#return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				emit_signal("left_mouse_button_clicked")
				raycast_at_cursor()
			else:
				emit_signal("left_mouse_button_released")
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			emit_signal("right_mouse_button_clicked")
			raycast_at_cursor_right_click()

#func _input(event):
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		#if event.pressed:
			#emit_signal("left_mouse_button_clicked")
			#raycast_at_cursor()
		#else:
			#emit_signal("left_mouse_button_released")
	#elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			#emit_signal("right_mouse_button_clicked")
			#raycast_at_cursor_right_click()
			
func raycast_at_cursor():
	if inputs_disabled:
		print("🔒 Input disabilitati, ignorato click sinistro.")
		return
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD | COLLISION_MASK_DECK | COLLISION_MASK_GY | COLLISION_MASK_ENEMY_CARD 
	
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		var collider = result[0].collider
		var card = get_click_target_with_highest_z_index(result)

		if $"../CardManager".selection_mode_active and not $"../CardManager".selection_purpose == "tribute_selection":
			var own_card = $"../CardManager".raycast_check_for_own_card()
			if own_card:
				print("🎯 Selezionata carta propria:", own_card.name)
				$"../CombatManager".enemy_card_selected(own_card)
				return
		
		if card:
			print("✅ Carta identificata:", card.name)
			print("CLICKO 🎨 ATK:", card.card_data.attack, " / ORIG:", card.card_data.original_attack, " / MAX:", card.card_data.max_attack)
			print("CLICKO 🎨 HP:", card.card_data.health, " / ORIG:", card.card_data.original_health, " / MAX:", card.card_data.max_health)

			# 🕳️ Stampa del voided_atk se presente
			var voided_atk = card.card_data.voided_atk
			print("🕳️ CLICKO Voided ATK:", voided_atk)
			
			if card.stunned and card.position_type == "attack":
				print("🚫 LA CARTA È IN ATK STUNNATA:", card.name, "| ⏳ stun_timer =", card.stun_timer)

			if card.is_elusive:
				print("🚫 LA CARTA È ELUSIVE: ", card.name)
						## 🔍 DEBUG STATO DELLA CARTA
						
			if card.has_magic_veil:
				print("LA CARTA HA MAGIC VEIL: ", card.name)
				
			var is_enemy = card.has_method("is_enemy_card") and card.is_enemy_card()
			var is_in_slot = card.has_method("card_is_in_slot") and card.card_is_in_slot
			var is_in_gy = card.has_method("card_is_in_playerGY") and card.card_is_in_playerGY

			#print("   ➤ Nemica?:", is_enemy)
			#print("   ➤ In Slot?:", is_in_slot)
			#print("   ➤ Nel Cimitero?:", is_in_gy)

			if card.has_method("is_enemy_card") and card.is_enemy_card():
				var cm = $"../CombatManager"
				var card_manager = $"../CardManager"
				
				if card_manager.selected_card and card_manager.selection_mode_active and card_manager.selection_purpose == "attack":
					# 🛡️ Controllo Taunt: verifica se ci sono carte nemiche con talento "Taunt"
					var enemy_cards = cm.opponent_creatures_on_field
					var taunt_cards = enemy_cards.filter(func(c):
						return "Taunt" in c.card_data.get_all_talents()
					)
					
										# 🚫 Controllo Elusive: non puoi attaccare carte con questo talento
					if card.is_elusive:
						print("🚫 Bersaglio non valido:", card.name, "è ELUSIVE! L'attacco viene ignorato.")
						return  # 🔒 blocca il click	
					
					if taunt_cards.size() > 0:
						# Se esiste almeno una carta con Taunt, puoi cliccare solo su quelle
						if not ("Taunt" in card.card_data.get_all_talents()):
							print("🚫 Hai cliccato", card.name, "ma ci sono nemici con TAUNT! Devi attaccare prima una carta con Taunt.")
							
							# 🔴 Effetto visivo sulla carta cliccata (errore)
							if card.has_method("play_invalid_target_flash"):
								card.play_invalid_target_flash()
							
							# 🟩 Evidenzia le carte con TAUNT che possono essere attaccate
							for taunt_card in taunt_cards:
								if is_instance_valid(taunt_card):
									print("💡 Evidenzio carta con TAUNT:", taunt_card.name)
									taunt_card.play_talent_icon_pulse("Taunt")
									
							return  # 🔒 blocca il click
						
				if card_manager.selected_card and card_manager.selected_card.card_data.card_type == "Spell":
					var enemy_cards = cm.opponent_creatures_on_field
					var magical_taunt_cards = enemy_cards.filter(func(c):
						return "Magical Taunt" in c.card_data.get_all_talents()
					)

					if magical_taunt_cards.size() > 0:
						# Se ci sono carte con Magical Taunt, puoi cliccare solo su di esse
						if not ("Magical Taunt" in card.card_data.get_all_talents()):
							print("🚫 Hai cliccato", card.name, "ma ci sono nemici con MAGICAL TAUNT! Devi selezionare prima una carta con Magical Taunt.")

							# 🔴 Effetto visivo sulla carta cliccata (errore)
							if card.has_method("play_invalid_target_flash"):
								card.play_invalid_target_flash()

							# 🟪 Evidenzia le carte con Magical Taunt
							for taunt_card in magical_taunt_cards:
								if is_instance_valid(taunt_card):
									print("💫 Evidenzio carta con MAGICAL TAUNT:", taunt_card.name)
									taunt_card.play_talent_icon_pulse("Magical Taunt")

							return  # 🔒 blocca il click
						
					print("🔫 Attacco carta nemica:", card.name)
					cm.enemy_card_selected(card)
					return
					
				elif card_manager.selected_card:
					# Target generico (non attacco)
					print("✨ Effetto su carta nemica:", card.name)
					cm.enemy_card_selected(card)
					return
					
				else:
					print("👀 Hai cliccato una carta nemica ma nessuna carta è selezionata.")
					#print("   ➤ Nemica?:", card.is_enemy_card())
					#print("   ➤ In Slot?:", card.card_is_in_slot)
					#print("   ➤ Nel Cimitero?:", card.card_is_in_playerGY)
			else:
				print("🟦 Carta giocatore cliccata:", card.name)
				var card_manager = $"../CardManager"


				# 🪙 --- SELEZIONE TRIBUTI ATTIVA ---
				if card_manager.tribute_selection_active:
					var cm = $"../CombatManager"

					var summoned_this_turn = cm.summoned_this_turn.any(func(entry):
						return entry.card == card
					)

					if card.card_data.card_type == "Creature" and card.card_is_in_slot and not summoned_this_turn:
						# Evita duplicati
						if not card_manager.tribute_selected_cards.has(card):
							card_manager.tribute_selected_cards.append(card)
							card.red_highlight_border.visible = true
							print("⚔️ Selezionata come tributo:", card.card_data.card_name)

						# Se abbiamo selezionato tutti i tributi richiesti
						if card_manager.tribute_selected_cards.size() >= card_manager.tribute_selection_required:
							print("✅ Tutti i tributi selezionati, sacrifico ora.")
							card_manager.finish_tribute_selection()
							card_manager.exit_selection_mode(true)

					else:
						print("🚫 Non puoi selezionare questa carta come tributo (evocata questo turno o non valida).")
						if card.has_method("play_invalid_target_flash"):
							card.play_invalid_target_flash()

					return
				# --- Fine selezione tributi ---

				card_manager_reference.card_clicked(card)
		elif collider.collision_mask == COLLISION_MASK_DECK:
			print("📦 Hai cliccato sul mazzo")
			deck_reference.deck_clicked()
			
		elif collider.collision_mask == COLLISION_MASK_GY:
			print("🪦 [InputManager] Click rilevato sul cimitero (GY)")
			
			var gy_node = collider.get_parent()
			if gy_node:
				print("🔗 [InputManager] Nodo GY trovato:", gy_node.name, " | Script:", gy_node.get_script())
			else:
				print("❌ [InputManager] gy_node == null")
				return
			
			# Accesso diretto a gy_cards (lo script PlayerGY.gd ce l'ha sempre)
			if gy_node.has_meta("_script"):
				print("ℹ️ [InputManager] Script attaccato al nodo GY:", gy_node.get_script())
			
			if "gy_cards" in gy_node:
				var gy_cards = gy_node.gy_cards
				print("📜 [InputManager] gy_cards trovate. Count =", gy_cards.size())
				
				var popup = $"../GYPopup"
				if popup:
					print("📦 [InputManager] GYPopup trovato, mostro le carte...")
					popup.show_cards(gy_cards)
				else:
					print("❌ [InputManager] GYPopup non trovato!")
			else:
				print("⚠️ [InputManager] Il nodo GY non espone 'gy_cards'")


	else:
		print("❌ Nessun oggetto cliccabile sotto il cursore.")
	
#func raycast_at_cursor():
	#var space_state = get_world_2d().direct_space_state
	#var parameters = PhysicsPointQueryParameters2D.new()
	#parameters.position = get_global_mouse_position()
	#parameters.collide_with_areas = true
	#parameters.collision_mask = COLLISION_MASK_CARD | COLLISION_MASK_DECK | COLLISION_MASK_GY | COLLISION_MASK_ENEMY_CARD 
	#
	#var result = space_state.intersect_point(parameters)
	#if result.size() > 0:
		#var result_collision_mask = result[0].collider.collision_mask
		#if result_collision_mask == COLLISION_MASK_CARD:
			#var card_found = result[0].collider.get_parent()
			#if card_found:
				#card_manager_reference.card_clicked(card_found)
		#elif result_collision_mask == COLLISION_MASK_DECK:
			#deck_reference.draw_card()
			#
		#elif result_collision_mask == COLLISION_MASK_ENEMY_CARD:
			#
			#$"../TurnManager".enemy_card_selected(result[0].collider.get_parent())
			#
		#elif result_collision_mask == COLLISION_MASK_GY:
			#card_manager_reference.on_player_gy_clicked()

#func raycast_at_cursor():
	#var space_state = get_world_2d().direct_space_state
	#var parameters = PhysicsPointQueryParameters2D.new()
	#parameters.position = get_global_mouse_position()
	#parameters.collide_with_areas = true
	#parameters.collision_mask = 0xFFFF  # per test, poi restringi
#
	#var result = space_state.intersect_point(parameters)
	#if result.size() > 0:
		#var obj = result[0].collider.get_parent()
		#
		#if obj and obj.has_method("is_enemy_card") and obj.is_enemy_card():
			#print("Hai cliccato una carta nemica!")
			#$"../TurnManager".enemy_card_selected(obj)
		#
		#elif obj and obj.has_method("is_card") and obj.is_card():
			#card_manager_reference.card_clicked(obj)
#
		#elif obj.name == "Deck":
			#deck_reference.draw_card()
		#
		#elif obj.name == "GY":
			#card_manager_reference.on_player_gy_clicked()
func get_click_target_with_highest_z_index(results):
	var highest_card = null
	var highest_z = -1

	for entry in results:
		var card = entry.collider.get_parent()
		if card.has_method("is_card") and card.is_card():
			if card.z_index > highest_z:
				highest_z = card.z_index
				highest_card = card
	return highest_card



		
func raycast_at_cursor_right_click():
	if inputs_disabled:
		print("🔒 Input disabilitati, ignorato click destro.")
		return

	var selected_card = card_manager_reference.selected_card
	if selected_card:
		var action_border_visible = selected_card.has_node("ActionBorder") and selected_card.get_node("ActionBorder").visible
		var should_block_right_click = (not card_manager_reference.selection_mode_active and action_border_visible)

		if should_block_right_click:
			print("⏳ Right-click ignorato: la carta è fuori dalla selection mode ma attende ancora resolve:", selected_card.name)
			return

	# Se invece siamo in selection mode normale (es. prima di cliccare un target), allora si può annullare
	if card_manager_reference.selection_mode_active and not card_manager_reference.selection_purpose == "tribute_selection" and not selected_card.card_data.effect_type == "OnPlay":
		card_manager_reference.exit_selection_mode()
		return

	# Altrimenti: raycast come prima
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD

	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		var card_found = result[0].collider.get_parent()
		if card_found:
			card_manager_reference.card_right_clicked(card_found)

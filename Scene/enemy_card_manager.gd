#extends Node2D
#
#@export var card_field_path: NodePath
#@onready var card_field = get_node(card_field_path)
#
#const COLLISION_MASK_CARD = 1
#const COLLISION_MASK_CARD_SLOT = 2
#const COLLISION_MASK_ENEMY_HOVER = 64  # Layer 7
#const DEFAULT_CARD_MOVE_SPEED = 0.1
#const CARD_SMALLER_SCALE = 0.15 #dimensione carta nella zone
#const CARD_SLOT_HOVER_SCALE = 0.155 #hovering quando e' nella zone
#const Z_INDEX_SLOT = 0       # Quando è piazzata sul campo
#const Z_INDEX_HAND = 20       # Quando è nella mano
#const Z_INDEX_HOVER = 2      # Quando ci passi sopra col mouse o stai trascinando
#const Z_INDEX_HIGHLIGHT_BORDER = 5
#const Z_INDEX_DRAG = 20
#
#var screen_size
#var card_being_dragged
#var is_hovering_on_card
#var player_hand_reference
#var selected_card
#var last_hovered_enemy = null
#var offset = Vector2()
#
#
#func _ready() -> void:
	#screen_size = get_viewport_rect().size
	#
	#
	#var player_zones = get_parent().get_node_or_null("PlayerZones")
	#if player_zones:
		#for slot in player_zones.get_children():
			#print("🎯 Slot:", slot.name)
			#var area = slot.get_node_or_null("Area2D")
			#var shape = area and area.get_node_or_null("CollisionShape2D")
			#if not area or not shape:
				#print("⚠️ Slot incompleto:", slot.name)
	##player_hand_reference = $"../PlayerHand"
	##$"../InputManager".connect("left_mouse_button_released", on_left_click_released)
	##$"../PlayerGY".connect("gy_clicked", on_player_gy_clicked) #chatGPT
#
##func _process(delta: float) -> void:
	##if card_being_dragged:
		##var mouse_pos= get_global_mouse_position()
		##card_being_dragged.position = mouse_pos - offset
		### Annulla drag con tasto destro solo mentre si trascina
		##if Input.is_action_just_pressed("right_click"):
			##cancel_drag()
		###card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x), clamp(mouse_pos.y, 0, screen_size.y))
		### Hover per le carte nemiche
	##handle_enemy_hover()
	##
##func cancel_drag():
	##if card_being_dragged:
		##player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
		##card_being_dragged.z_index = Z_INDEX_HAND
##
		### Forza il re-hover se il mouse è ancora sopra
		##var hovered_card = raycast_check_for_card()
		##if hovered_card == card_being_dragged:
			##highlight_card(card_being_dragged, true)
#
		##card_being_dragged = null
##
##func on_player_gy_clicked(): #chatGPT
	##print("Hai cliccato sul cimitero!")
##
##func on_left_click_released():
	###print("card managare released")
	##if card_being_dragged:
		##finish_drag()
		#
#
#
##func card_clicked(card):  #del TUTORIAL, nessuna delle due funziona per far partire l'atk
	##
	##if card.card_is_in_playerGY == true: #chatgpt, serve per impedire click di carte nel cimitero.
		##return
	##if card.card_is_in_slot:
		##if $"../TurnManager".is_opponent_turn == false:
			##if card.card_data.card_type != "Creature":   #chatgpt, serve per impedire di triggerare l'atk alle spell
				##return
			##if card not in $"../TurnManager".player_creature_that_attacked_this_turn:
				##if $"../TurnManager".opponent_cards_on_field.size() == 0:
					##$"../TurnManager".direct_attack(card, "Player")
					##return
				##else:
					##select_card_for_battle(card)
	##else:
		###card in hand
		##start_drag(card)
#
##func card_right_clicked(card):
	##
	##if card.card_is_in_playerGY == true:
		##return
	##if not card.card_is_in_slot:
		##return
	##if $"../TurnManager".is_opponent_turn:
		##return
	##if card.card_data.effect_type != "Activable":
		##return
##
	### Se targeting = Targeted, seleziona la carta
	##if card.card_data.targeting_type == "Targeted":
		##card.z_index = Z_INDEX_HIGHLIGHT_BORDER
		##select_card_for_effect(card)
	##else:
		### Altri tipi (es. AoE)
		##$"../TurnManager".apply_aoe_effect(card, "Auto")
		#
##func select_card_for_battle(card):
	###check se e' gia' selected
	##if selected_card:
		##if selected_card == card:
			##card.position.y += 20
			##card.z_index = Z_INDEX_HIGHLIGHT_BORDER
			##selected_card = null
			##
		##else:
			##selected_card.position.y += 20
			##selected_card = card
			##card.position.y -= 20
	##else:
		##selected_card = card
		##card.position.y -= 20
#
#
##func select_card_for_effect(card):
	##if selected_card:
		##if selected_card == card:
			##
			##card.position.y += 20
			##
			##selected_card = null
		##else:
			##selected_card.position.y += 20
			##selected_card = card
			##card.position.y -= 20
	##else:
		##selected_card = card
		##card.position.y -= 20
		#
##func unselect_selected_card():
	##if selected_card:
		##selected_card.position.y += 20
		##selected_card = null
		##selected_card.z_index = Z_INDEX_SLOT
##
##func start_drag(card):
	##card_being_dragged = card
	##card.scale = Vector2(0.2, 0.2)
	##card.z_index = Z_INDEX_DRAG
#
#
	#
	## Calcola l'offset tra il centro della carta e il mouse al momento del click
	##var mouse_pos = get_global_mouse_position()
	##var card_center = card.position
	##offset = mouse_pos - card_center
#
	##card.position = get_global_mouse_position()
	#
##func finish_drag():
	##card_being_dragged.scale = Vector2(0.21,0.21)
	##var card_slot_found = raycast_check_for_card_slot()
	##
	##if card_slot_found and not card_slot_found.card_in_slot:
		##if card_being_dragged.card_data.card_type == card_slot_found.card_slot_type:
			##
			##
			##card_being_dragged.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
			##card_being_dragged.card_is_in_slot = card_slot_found
			##card_being_dragged.z_index = Z_INDEX_SLOT
			##is_hovering_on_card = false
			##player_hand_reference.remove_card_from_hand(card_being_dragged)
			##card_being_dragged.position = card_slot_found.position
			##card_slot_found.get_node("Area2D/CollisionShape2D").disabled = true
			##card_slot_found.card_in_slot = true
			##
			### ✅ RIMUOVI LA CARTA DAL MAZZO ORIGINALE
			##if $"../Deck".has_method("remove_card_from_deck"):
				##$"../Deck".remove_card_from_deck(card_being_dragged.card_data)
			##elif $"../EnemyDeck".has_method("remove_card_from_deck"):
				##$"../EnemyDeck".remove_card_from_deck(card_being_dragged.card_data)
			###---chatgpt--- metodo per far apparire border bianco fin da subito  se hai ancora il cursore sopra card droppata
			##var parameters = PhysicsPointQueryParameters2D.new()
			##parameters.position = get_global_mouse_position()
			##parameters.collide_with_areas = true
			##parameters.collision_mask = COLLISION_MASK_CARD
			##var result = get_world_2d().direct_space_state.intersect_point(parameters)
			##if result.size() > 0:
				##var hovered_card = get_click_target_with_highest_z_index(result)
				##if hovered_card == card_being_dragged:
					##card_being_dragged.highlight_border.visible = true
			###---chatgpt--- metodo per far apparire border bianco fin da subito  se hai ancora il cursore sopra card droppata
			##if card_being_dragged.card_data.card_type == "Creature":
				##$"../TurnManager".player_creatures_on_field.append(card_being_dragged)
			##elif card_being_dragged.card_data.card_type == "Spell":
				##$"../TurnManager".player_spells_on_field.append(card_being_dragged)  
				###chatgpt, viene considerata creatura on field solo se ha type creatura
			##
			##var player_id = multiplayer.get_unique_id()
			##var card_data_dict = card_being_dragged.card_data.to_dict()
			##rpc("play_card_here_and_for_clients_opponent", player_id, card_data_dict)
			##play_card_here_and_for_clients_opponent(player_id, card_data_dict)
			##
		##else:
			##player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
			##card_being_dragged.z_index = Z_INDEX_HAND
			##
##
##
	##else:
		##player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
		##card_being_dragged.z_index = Z_INDEX_HAND
##
	##
	##card_being_dragged = null
	#
	#
#
#@rpc("any_peer")
#func play_opponent_card(card_data_dict: Dictionary, slot_name: String, from_hand_position: Vector2):
	#print("📥 [EnemyCardManager] Replica carta:", card_data_dict["card_name"], "in slot:", slot_name)
	#print("🖐️ Replica: carta giocata dalla posizione:", from_hand_position)
#
	#var card = CardSpawner.spawn_enemy_card(card_data_dict)
	#card_field.add_child(card)
#
	#card.scale = Vector2(0.15, 0.15)
	#card.z_index = Z_INDEX_SLOT
	#card.card_is_in_slot = true
#
	## 🔁 Mappa slot dell'avversario nei corrispettivi EnemySlot
	#var mapped_slot_name := ""
	#if slot_name.begins_with("CreatureSlot"):
		#mapped_slot_name = slot_name.replace("CreatureSlot", "EnemyCreatureSlot")
	#elif slot_name.begins_with("SpellSlot"):
		#mapped_slot_name = slot_name.replace("SpellSlot", "EnemySpellSlot")
	#else:
		#mapped_slot_name = slot_name  # fallback
#
	## 🔍 Cerca PlayerZones (il contenitore degli EnemySlot)
	#var zones_container = get_parent().find_child("PlayerZones", true, false)
	#if zones_container:
		#var slot = zones_container.find_child(mapped_slot_name, true, false)
		#if slot:
			#from_hand_position.y = get_viewport().get_visible_rect().size.y - from_hand_position.y
			#card.position = from_hand_position  # 👈 posizione iniziale visiva (da mano avversaria)
			#var tween = get_tree().create_tween()
			#tween.tween_property(card, "position", slot.position, 0.2)
			#slot.card_in_slot = true
			#var area = slot.get_node_or_null("Area2D")
			##slot.get_node("Area2D/CollisionShape2D").disabled = true
			#
			#if area:
				#var shape = area.get_node_or_null("CollisionShape2D")
				#if shape:
					#shape.disabled = true
				#else:
					#print("❌ CollisionShape2D non trovato dentro Area2D nello slot:", slot.name)
			#else:
				#print("❌ Area2D non trovato nello slot:", slot.name)
#
			#var tween2 = get_tree().create_tween()
			#tween2.tween_property(card, "scale", Vector2(0.16, 0.16), 0.2)
			#print("✅ Carta posizionata in:", mapped_slot_name)
		#else:
			#print("❌ Slot non trovato:", mapped_slot_name)
	#else:
		#print("❌ PlayerZones non trovato nel campo (campo avversario)")
#
	## 🧹 Rimuove dalla mano avversaria
	#var enemy_hand = get_parent().get_node_or_null("EnemyHand")
	#if enemy_hand:
		#enemy_hand.remove_card_by_name(card_data_dict["card_name"])
#
#
#
#
#func connect_card_signals(card):
	#card.connect("hovered", on_hovered_over_card)
	#card.connect("hovered_off", on_hovered_off_card)
#
#func on_hovered_over_card(card): 
	#if card.card_is_in_slot:
		#return
	#if card.card_is_in_playerGY: #chatgpt
		#return
	#if card_being_dragged:
		#return
	#
#
	#if !is_hovering_on_card:
		#is_hovering_on_card = true
		#highlight_card(card, true)
#
#func on_hovered_off_card(card):
	#if card.card_is_in_playerGY:
		#return
	#if card_being_dragged:
		#return
	#if not card.card_is_in_slot:
		#highlight_card(card, false)
		#is_hovering_on_card = false
#
		#var new_card_hovered = raycast_check_for_card()
		#if new_card_hovered:
			#highlight_card(new_card_hovered, true)
			#is_hovering_on_card = true
#
#
#func handle_enemy_hover():
	#var space_state = get_world_2d().direct_space_state
	#var parameters = PhysicsPointQueryParameters2D.new()
	#parameters.position = get_global_mouse_position()
	#parameters.collide_with_areas = true
	#parameters.collision_mask = COLLISION_MASK_ENEMY_HOVER
#
	#var result = space_state.intersect_point(parameters)
#
	#if result.size() > 0:
		#var enemy_card = result[0].collider.get_parent()
		#
		#if enemy_card and enemy_card.is_in_hand():
			#return
		## Se stiamo hovering su una carta diversa da prima
		#if enemy_card != last_hovered_enemy:
			## Rimuovi highlight dalla precedente
			#if last_hovered_enemy:
				#last_hovered_enemy.set_highlight(false)
			#
			## Applica highlight alla nuova
			#if enemy_card:
				#enemy_card.set_highlight(true)
			#
			#last_hovered_enemy = enemy_card
	#else:
		## Niente sotto il mouse → spegni il bordo della precedente
		#if last_hovered_enemy:
			#last_hovered_enemy.set_highlight(false)
			#last_hovered_enemy = null
#
#
#func highlight_card(card, hovered):
	#if card.card_data.card_type == "Spell" and card.card_is_in_slot:
		#return
	#if hovered:
		#card.z_index = Z_INDEX_HOVER
		#if card.card_is_in_slot:
			#card.scale = Vector2(CARD_SLOT_HOVER_SCALE, CARD_SLOT_HOVER_SCALE)
			#
		#else:
			#card.scale = Vector2(0.25, 0.25)
			#
			#if not card.has_meta("original_position"):
				#card.set_meta("original_position", card.position)
#
			## Alza la carta
			#card.position.y -= 40  # o quanto vuoi farla uscire
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
			#card.scale = Vector2(0.2, 0.2)
			#card.z_index = Z_INDEX_HAND
			#
			## Ripristina la posizione originale se salvata
			#if card.has_meta("original_position"):
				#card.position = card.get_meta("original_position")
				#card.remove_meta("original_position")
		#
	#
		#
#func raycast_check_for_card_slot():
	#var space_state = get_world_2d().direct_space_state
	#var parameters = PhysicsPointQueryParameters2D.new()
	#parameters.position = get_global_mouse_position()
	#parameters.collide_with_areas = true
	#parameters.collision_mask = COLLISION_MASK_CARD_SLOT
	#var result = space_state.intersect_point(parameters)
	#if result.size() > 0:
		#return result[0].collider.get_parent()
		#
	#return null	
#
#func raycast_check_for_card():
	#var space_state = get_world_2d().direct_space_state
	#var parameters = PhysicsPointQueryParameters2D.new()
	#parameters.position = get_global_mouse_position()
	#parameters.collide_with_areas = true
	#parameters.collision_mask = COLLISION_MASK_CARD
	#var result = space_state.intersect_point(parameters)
	#if result.size() > 0:
		##return result[0].collider.get_parent()
		#return get_card_with_highest_z_index(result)
	#return null
	#
#func raycast_check_for_enemy_card():
	#var space_state = get_world_2d().direct_space_state
	#var parameters = PhysicsPointQueryParameters2D.new()
	#parameters.position = get_global_mouse_position()
	#parameters.collide_with_areas = true
	#parameters.collision_mask = COLLISION_MASK_ENEMY_HOVER  # o un altro dedicato
	#var result = space_state.intersect_point(parameters)
	#if result.size() > 0:
		#return result[0].collider.get_parent()
	#return null
	#
#func get_card_with_highest_z_index(cards):
	#var highest_z_card = cards[0].collider.get_parent()
	#var highest_z_index = highest_z_card.z_index
	#
	#for i in range(1, cards.size()):
		#var current_card = cards[1].collider.get_parent()
		#if current_card.z_index > highest_z_index:
			#highest_z_card =  current_card
			#highest_z_index = current_card.z_index
	#return highest_z_card
	#
	#
#func get_click_target_with_highest_z_index(results):
	#var highest_card = null
	#var highest_z = -1
#
	#for entry in results:
		#var card = entry.collider.get_parent()
		#if card.has_method("is_card") and card.is_card():
			#if card.z_index > highest_z:
				#highest_z = card.z_index
				#highest_card = card
	#return highest_card

extends "res://Scripts/card.gd"

#@export var card_data: CardData
#@onready var attack_label = $Attack
#@onready var health_label = $Health
#@onready var card_sprite = $CardImage
#@onready var highlight_border = $HighlightBorder
#@onready var action_border = $ActionBorder



func set_highlight(value: bool):
	if is_in_hand():
		highlight_border.visible = false
	else:
		highlight_border.visible = value

func set_card_data(data: CardData) -> void:
	card_data = data
	card_data.init_original_stats()  # ✅ inizializza i valori originali
	update_card_visuals()

	#play_flip_animation()

#func play_flip_animation() -> void:
	#var anim = get_node_or_null("AnimationPlayer")
	#if anim:
		#anim.play("card_flip")
		#finche' tieni questo nascosto le carte oppo che vengono pescate rimangono coperte
#
#signal hovered
#signal hovered_off
#
#var position_in_hand
#var card_is_in_slot

func _process(_delta):
	if not hover_enabled or card_is_in_playerGY:
		return

	# Se la carta è attualmente hoverata
	if highlight_border.visible:
		var modifier_pressed = Input.is_key_pressed(KEY_CTRL)
		highlight_linked_target(modifier_pressed)


func _ready() -> void:
	#scale = Vector2(0.2, 0.2)
	#print("🧪 EnemyCard ready")
	#print("🔍 attack_label:", attack_label)
	#print("🔍 health_label:", health_label)
	var current = get_parent()
	while current and not current.has_method("connect_card_signals"):
		current = current.get_parent()

	if current:
		current.connect_card_signals(self)

	if card_data:
		update_card_visuals()
		
	#if not is_connected("summoned_on_field", Callable(self, "_on_self_summoned_on_field")): PER ORA NON SERVE  CONNETTERE IN ENEMY CARD
		#connect("summoned_on_field", Callable(self, "_on_self_summoned_on_field"))
	if not is_connected("summoned_on_field", Callable(self, "_on_self_summoned_on_field")):
		connect("summoned_on_field", Callable(self, "_on_self_summoned_on_field"))
	if not is_connected("changed_position", Callable(self, "_on_self_changed_position")):
		connect("changed_position", Callable(self, "_on_self_changed_position"))
	if not is_connected("lost_while_condition", Callable(self, "_on_self_lost_while_condition")):
		connect("lost_while_condition", Callable(self, "_on_self_lost_while_condition"))
	if not is_connected("damage_dealt", Callable(self, "_on_self_damage_dealt")):
		connect("damage_dealt", Callable(self, "_on_self_damage_dealt"))
	if not is_connected("damage_taken", Callable(self, "_on_self_damage_taken")):
		connect("damage_taken", Callable(self, "_on_self_damage_taken"))
		
	hover_timer = Timer.new()
	hover_timer.wait_time = 0.5
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)
	
func set_in_graveyard(state: bool) -> void:
	card_is_in_playerGY = state
	$CardImage.visible = not state
	$CardBack.visible = not state
	$Attack.visible = not state
	$Health.visible = not state
	$HighlightBorder.visible = not state
	$RedHighlightBorder.visible = not state
	$ActionBorder.visible = not state
	if state:
		if is_instance_valid(talent_icons_container):
			var duration_icon = talent_icons_container.get_node_or_null("DurationIcon")
			if duration_icon:
				duration_icon.queue_free()

			var durability_icon = talent_icons_container.get_node_or_null("DurabilityIcon")
			if durability_icon:
				durability_icon.queue_free()
				
			# 🔹 Rimuovi eventuali icone di debuff
	if is_instance_valid(debuff_icons_container):
		for child in debuff_icons_container.get_children():
			if child is TextureRect:
				child.queue_free()

		# 🔹 Svuota anche l’array dei debuff attivi nella card_data (opzionale ma consigliato)
		card_data.active_debuffs.clear()
		stunned = false
		frozen = false
		stun_timer = 0
		freeze_timer = 0
		
func set_position_type(pos_type: String) -> void:
	var previous_position_type = position_type
	position_type = pos_type

	# 🌀 Tween per animare la rotazione o il flip
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	if position_type == "defense":
		if previous_position_type == "attack":
			tween.tween_property(self, "rotation_degrees", 90, 0.25)
			emit_signal("changed_position", self, "defense")
	elif position_type == "attack":
		if previous_position_type == "defense":
			tween.tween_property(self, "rotation_degrees", 0, 0.25)
			emit_signal("changed_position", self, "attack")
	elif position_type == "faceup":
		$CardBack.visible = false
		$CardImage.visible = true
	elif position_type == "facedown":
		$CardBack.visible = true
		$CardImage.visible = false

	
func update_card_visuals():
	if not attack_label or not health_label:
		print("❌ Etichette non trovate in EnemyCard.gd")
		return
		# 🔥 Controllo se la carta ha lo stun e ha perso vita
	#if card_data.active_debuffs.has("Stunned"):
		#if card_data.health < card_data.max_health:
			#card_data.remove_debuff("Stunned")
			#update_debuff_icons()
			#print("✅ Stun rimosso da", card_data.card_name, " perché ha subito danno")
			#print("📛 Debuff rimanenti su ", card_data.card_name, ":", card_data.active_debuffs)
			
			# 👉 Notifica agli altri peer passando anche player_id
			#var player_id = multiplayer.get_unique_id()
			#rpc("rpc_remove_debuff", player_id, self.name, "Stunned")
	# 🚫 Se la carta è in mano (coperta), non mostrare nulla
	is_elusive = "Elusive" in card_data.get_all_talents() and position_type == "attack"
	has_magic_veil = "Magic Veil" in card_data.get_all_talents()
	
	if is_in_hand():
		attack_label.text = ""
		health_label.text = ""
		attack_label.modulate = Color(0, 0, 0)
		health_label.modulate = Color(0, 0, 0)
		return
#
	#if healed:
		#play_heal_animation()  #POTREBBE ESSER BUG DOPPIA CHIMATA DI ANIMATION CON REGEN
		#healed = false
	# ✅ Altrimenti aggiorna normalmente (carta sul campo)
	attack_label.text = str(card_data.attack)
	health_label.text = str(card_data.health)
	
	if card_data.card_type == "Creature":
		# Colore ATTACK

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

	else:
		attack_label.text = ""
		health_label.text = ""
		
		# Colore SPELL MULTI
		


	
		# 🧙‍♂️ Spell Multiplier e Duratio

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
			#attack_label.scale = Vector2(6.7, 6.7)
			#health_label.scale = Vector2(6.7, 6.7)
			#
			#attack_label.position = Vector2(-290, 140)
			#health_label.position = Vector2(40, 140)
			
		elif card_data.card_sprite:
			# 👇 Altrimenti sprite normale
			card_sprite.texture = card_data.card_sprite

	print("🎨 ATK:", card_data.attack, " / ORIG:", card_data.original_attack, " / MAX:", card_data.max_attack)
	print("🎨 HP:", card_data.health, " / ORIG:", card_data.original_health, " / MAX:", card_data.max_health)

func _on_area_2d_mouse_entered() -> void:
	if hover_enabled and not card_is_in_playerGY:
		is_hovered = true
		emit_signal("hovered", self)
		if not is_in_hand():
			highlight_border.visible = true
		hover_timer.start()

func _on_area_2d_mouse_exited() -> void:
	if hover_enabled and not card_is_in_playerGY:
		is_hovered = false
		emit_signal("hovered_off", self)
	highlight_border.visible = false
	highlight_linked_target(false)
	hover_timer.stop()

	var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
	if preview_manager:
		preview_manager.hide_preview()

func is_in_hand() -> bool:
	return position_in_hand != null and not card_is_in_slot and not card_is_in_playerGY
	
func is_enemy_card():
	return true

func is_card():
	return true

func _on_hover_timer_timeout():
	if is_in_hand():
		return  # ❌ Non mostrare la preview se la carta è in mano
		
	var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
	if preview_manager:
		preview_manager.show_preview(self)


func _on_self_changed_position(card: Card, new_position: String) -> void:
	if card != self:
		return
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	# ⚠️ Rileva perdita della condizione While
	if card.card_data.trigger_type == "While_DEFpos" and new_position != "defense":
		print("🧹 [ENEMY WHILE LOST] Carta", card.card_data.card_name, "ha perso While_DEFpos → emetto segnale")
		emit_signal("lost_while_condition", self)
	elif card.card_data.trigger_type == "While_ATKpos" and new_position != "attack":
		print("🧹 [ENEMY WHILE LOST] Carta", card.card_data.card_name, "ha perso While_ATKpos → emetto segnale")
		emit_signal("lost_while_condition", self)
	# 🌬️ --- NUOVO BLOCCO: perdita validità per AURA "AllAllyDEFCreatures" ---
	if new_position == "attack" and combat_manager:
		# 🔍 Controlla SOLO le aure del nemico (cioè del lato avversario)
		var enemy_aura_sources: Array = []
		enemy_aura_sources.append_array(combat_manager.opponent_creatures_on_field)
		enemy_aura_sources.append_array(combat_manager.opponent_spells_on_field)

		for possible_aura in enemy_aura_sources:
			if not is_instance_valid(possible_aura):
				continue
			if possible_aura.card_data.effect_type != "Aura":
				continue

			# ✅ Aura che influenza le creature alleate in DEFENSE
			if possible_aura.card_data.t_subtype_1 == "AllAllyDEFCreatures":
				for entry in possible_aura.aura_affected_cards:
					if entry.has("card") and entry.card == self:
						print("🧹 [ENEMY AURA REMOVE] ", self.card_data.card_name, "ha perso condizione DEF → rimuovo SOLO i suoi effetti di", possible_aura.card_data.card_name)
						combat_manager.remove_aura_effects(possible_aura, self)
						break
	elif new_position == "defense":
		var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
		if card_manager and card_manager.has_method("apply_existing_aura_effect"):
			print("🌱 [AURA APPLY] ", card_data.card_name, "ora in DEF → controllo aure attive...")
			card_manager.apply_existing_aura_effect(self)

func _on_self_lost_while_condition(card: Card) -> void:
	if card != self:
		return

	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	if combat_manager and combat_manager.has_method("remove_while_effects_from_source"):
		print("🧹 [ENEMY CLEANUP] Rimuovo effetti While da", card.card_data.card_name, "sul client remoto")
		combat_manager.remove_while_effects_from_source(self)


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
		print("❌ [WHILE LOST] While_NoOtherAlly perso da", card_data.card_name, "perché è entrata", summoned_card.card_data.card_name)
		emit_signal("lost_while_condition", self)
		
func _on_self_summoned_on_field(card: Card, position: String) -> void: 
	if card != self:
		return
	var combat_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CombatManager")
	var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
		# ✅ solo costo >= 4
	if card_data.get_mana_cost() >= 4 or card_data.tributes > 0:
		combat_manager.play_summon_camera_impact(1.0)
		
	#match position:
		#"defense":
			#if card_data.trigger_type == "While_DEFpos":
				#await get_tree().create_timer(0.3).timeout
				#print("🛡️ [AUTO] While_DEFpos attivato su summon per", card_data.card_name)
				#var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
				#if card_manager and card_manager.has_method("trigger_card_effect"):
					#card_manager.trigger_card_effect(self)
#
		#"attack":
			#if card_data.trigger_type == "While_ATKpos":
				#await get_tree().create_timer(0.3).timeout
				#print("⚔️ [AUTO] While_ATKpos attivato su summon per", card_data.card_name)
				#var card_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardManager")
				#if card_manager and card_manager.has_method("trigger_card_effect"):
					#card_manager.trigger_card_effect(self)

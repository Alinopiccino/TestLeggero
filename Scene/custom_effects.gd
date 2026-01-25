extends Node2D



func run_custom_effect(card_name: String, source_card: Node, target_card: Node = null, magnitude: int = 0, player_id: int = -1) -> void:
	print("✨ [CUSTOM EFFECT] Eseguo effetto personalizzato per:", card_name)

	if not is_instance_valid(source_card) or not source_card.card_data:
		print("⚠️ [CUSTOM EFFECT] source_card o card_data non validi")
		return

	var custom_name = source_card.card_data.custom_effect_name

	if custom_name == "" or custom_name == "None":
		print("⚠️ Nessun effetto custom definito per:", source_card.card_data.card_name)
		return

	print("🔍 [CUSTOM EFFECT] Identificato effetto personalizzato:", custom_name)

	match custom_name:
		"Desert":
			await desert_effect(source_card, player_id)
		_:
			print("⚠️ Nessun effetto custom definito per:", custom_name)
			
			
func desert_effect(source_card: Node, player_id: int) -> void:
	print("🏜️ [Desert Aura] Attivazione iniziale")

	var cm = get_parent().get_node_or_null("CombatManager")
	if cm == null:
		push_warning("❌ CombatManager non trovato per Desert")
		return

	# 🌍 Colleziona tutte le creature sul campo
	var all_creatures = cm.player_creatures_on_field + cm.opponent_creatures_on_field
	source_card.aura_affected_cards.clear()

	# 🧩 Buff/Debuff applicati tramite apply_simple_effect_to_card (così mantieni voided_atk e coerenza)
	for card in all_creatures:
		if not is_instance_valid(card) or card.card_data.health <= 0:
			continue

		# 🎯 Buff a Earth
		if card.card_data.card_attribute == "Earth":
			source_card.aura_affected_cards.append({
				"card": card,
				"magnitude": 200,
				"type": "Buff"
			})
			await cm.apply_simple_effect_to_card(card, "Buff", 200, source_card, player_id)
			print("🪨 [Desert Aura] +200 ATK/HP a", card.card_data.card_name)

		# 💧 Debuff a Water
		elif card.card_data.card_attribute == "Water":
			source_card.aura_affected_cards.append({
				"card": card,
				"magnitude": -200,
				"type": "Debuff"
			})
			await cm.apply_simple_effect_to_card(card, "Debuff", 200, source_card, player_id)
			print("💧 [Desert Aura] -200 ATK/HP a", card.card_data.card_name)

		await get_tree().process_frame

	# 🪄 Magnitude di riferimento per aggiornamenti futuri
	source_card.set_meta("current_effective_magnitude", 200)

	# 🌎 SPELL POWER (può andare anche negativo)
	var earth_gain = 2
	var water_loss = 2

	print("🌍 [Desert] Modifica Spell Power: +%d EarthSP / -%d WaterSP" % [earth_gain, water_loss])

	# 🔸 Aggiornamento lato player
	cm.player_EarthSP += earth_gain
	cm.player_WaterSP -= water_loss

	# 🔸 Aggiornamento lato enemy
	cm.enemy_EarthSP += earth_gain
	cm.enemy_WaterSP -= water_loss

	# 🔥 Aggiorna i label UI (se esistono)
	var scene_root = get_tree().get_current_scene()
	if scene_root.has_node("PlayerField/PlayerEarthSP"):
		scene_root.get_node("PlayerField/PlayerEarthSP").text = str(cm.player_EarthSP)
	if scene_root.has_node("PlayerField/PlayerWaterSP"):
		scene_root.get_node("PlayerField/PlayerWaterSP").text = str(cm.player_WaterSP)
	if scene_root.has_node("EnemyField/EnemyEarthSP"):
		scene_root.get_node("EnemyField/EnemyEarthSP").text = str(cm.enemy_EarthSP)
	if scene_root.has_node("EnemyField/EnemyWaterSP"):
		scene_root.get_node("EnemyField/EnemyWaterSP").text = str(cm.enemy_WaterSP)

	# ✨ Animazione visiva del cambiamento Spell Power (se disponibile)
	if cm.has_method("animate_spell_power_gain"):
		await cm.animate_spell_power_gain("PlayerEarth", earth_gain)
		await cm.animate_spell_power_gain("EnemyEarth", earth_gain)
		await cm.animate_spell_power_gain("PlayerWater", -water_loss)
		await cm.animate_spell_power_gain("EnemyWater", -water_loss)

	# 🌀 Ricalcola tutte le aure in base ai nuovi SP
	cm.update_all_aura_bonuses(+earth_gain, "Earth", false)
	cm.update_all_aura_bonuses(+earth_gain, "Earth", true)
	cm.update_all_aura_bonuses(-water_loss, "Water", false)
	cm.update_all_aura_bonuses(-water_loss, "Water", true)

	# 📜 Registra l’aura per aggiornamenti dinamici
	cm.register_continuous_aura_targets(source_card, 200, multiplayer.get_unique_id() == player_id, "AllCreatures")
	print("🏜️ [Desert Aura] Registrata come aura continua ✅")

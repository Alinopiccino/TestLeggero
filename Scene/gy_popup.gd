extends PopupPanel

@onready var scroll = $ScrollContainer
@onready var container = scroll.get_node("MarginContainer/GridContainer")

const PREVIEW_SCALE := Vector2(0.47, 0.467)
const ORIGINAL_CARD_SIZE := Vector2(300, 450)  # Adatta alla tua texture reale
const CARD_MARGIN := Vector2(100, 100)

const MAX_COLUMNS := 5
const MAX_VISIBLE_ROWS := 3
const FIXED_WIDTH := 700  # ✅ larghezza fissa
const HIGHLIGHT_MANUAL_OFFSET := Vector2(110, 110)  

# 👇 Costanti offset per attack / health
const ATK_OFFSET := Vector2(18, -77)   # relativo all'angolo in basso a sinistra
const HP_OFFSET := Vector2(-50, -77)    # relativo all'angolo in basso a destra
const SPELL_MULTI_OFFSET := Vector2(103, -69)   # relativo all'angolo in basso a sinistra
const SPELL_DUR_OFFSET := Vector2(-22, -29)    # relativo all'angolo in basso a destra

func show_cards(cards: Array):
	print("MOSTRO GY con", cards.size(), "carte")

	# Pulisce contenuto precedente
	for child in container.get_children():
		child.queue_free()

	var count := cards.size()
	container.columns = min(count, MAX_COLUMNS)
	container.add_theme_constant_override("h_separation", 15)
	container.add_theme_constant_override("v_separation", 15)
	# Calcolo dimensione scalata
	var scaled_size = ORIGINAL_CARD_SIZE * PREVIEW_SCALE

	# Crea le carte nel GY
	for card_data in cards:
		if card_data and card_data.card_sprite:
			# Wrapper
			var wrapper = Control.new()
			wrapper.custom_minimum_size = scaled_size
			wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
			wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			# Highlight
			var highlight = TextureRect.new()
			highlight.texture = preload("res://Assets/FieldHighlightBorderBianco.png")
			highlight.stretch_mode = TextureRect.STRETCH_SCALE
			highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			highlight.custom_minimum_size = Vector2(320, 470) * PREVIEW_SCALE
			highlight.position = (scaled_size - highlight.custom_minimum_size) / 2
			highlight.z_index = 0
			highlight.visible = false
			wrapper.add_child(highlight)

			# Sprite della carta
			var tex_rect = TextureRect.new()
			tex_rect.texture = card_data.card_sprite
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.custom_minimum_size = scaled_size
			tex_rect.size_flags_horizontal = Control.SIZE_FILL
			tex_rect.size_flags_vertical = Control.SIZE_FILL
			tex_rect.z_index = 1
			wrapper.add_child(tex_rect)

			# Se è creatura -> aggiungi attacco e health come label separate
			if card_data.card_type == "Creature":
				# Attacco
				var atk_label = Label.new()
				atk_label.text = str(card_data.original_attack)
				atk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # 👈 CENTRATO
				atk_label.add_theme_color_override("font_color", Color.BLACK)
				atk_label.add_theme_font_size_override("font_size", 15)
				atk_label.z_index = 10
				atk_label.position = Vector2(0, scaled_size.y) + ATK_OFFSET
				wrapper.add_child(atk_label)

				# Health
				var hp_label = Label.new()
				hp_label.text = str(card_data.original_health)
				hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # 👈 CENTRATO
				hp_label.add_theme_color_override("font_color", Color.BLACK)
				hp_label.add_theme_font_size_override("font_size", 15)
				hp_label.z_index = 10
				hp_label.position = Vector2(scaled_size.x, scaled_size.y) + HP_OFFSET
				wrapper.add_child(hp_label)
			
			if card_data.card_type == "Spell":
				# Attacco
				var spell_multi_label = Label.new()
				spell_multi_label.text = str(card_data.original_spell_multiplier)
				spell_multi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # 👈 CENTRATO
				spell_multi_label.add_theme_color_override("font_color", Color.BLACK)
				spell_multi_label.add_theme_font_size_override("font_size", 11)
				spell_multi_label.z_index = 10
				spell_multi_label.position = Vector2(0, scaled_size.y) + SPELL_MULTI_OFFSET
				wrapper.add_child(spell_multi_label)
				if card_data.original_spell_multiplier <= 0:
					spell_multi_label.visible = false

				# Health
				var spell_dur_label = Label.new()
				spell_dur_label.text = str(card_data.original_spell_duration)
				spell_dur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # 👈 CENTRATO
				spell_dur_label.add_theme_color_override("font_color", Color.BLACK)
				spell_dur_label.add_theme_font_size_override("font_size", 11)
				spell_dur_label.z_index = 10
				spell_dur_label.position = Vector2(scaled_size.x, scaled_size.y) + SPELL_DUR_OFFSET
				wrapper.add_child(spell_dur_label)
				if card_data.original_spell_duration <= 0 or card_data.original_spell_duration >= 100:
					spell_dur_label.visible = false

			# 🔹 Timer per hover (preview e tooltip)
			var hover_timer := Timer.new()
			hover_timer.wait_time = 0.5
			hover_timer.one_shot = true
			wrapper.add_child(hover_timer)

			# Gestione hover
			wrapper.mouse_entered.connect(func():
				highlight.visible = true
				wrapper.z_index = 100
				hover_timer.start()
			)

			wrapper.mouse_exited.connect(func():
				highlight.visible = false
				wrapper.z_index = 0
				hover_timer.stop()
				# Nascondi subito la preview se era attiva
				var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
				if preview_manager:
					preview_manager.hide_preview()
			)

			hover_timer.timeout.connect(func():
				var preview_manager = get_tree().get_current_scene().get_node_or_null("PlayerField/CardPreviewManager")
				if preview_manager:
					preview_manager.show_preview(card_data, true)  # 👈 mostra valori originali perche' e' nel GY
			)

			container.add_child(wrapper)

	# Aspetta layout prima del calcolo dimensioni
	await get_tree().process_frame

	var num_rows = int(ceil(float(count) / container.columns))
	var visible_rows = min(num_rows, MAX_VISIBLE_ROWS)
	var desired_height = scaled_size.y * visible_rows + CARD_MARGIN.y * (visible_rows + 1)

	# ✅ Applica larghezza fissa e altezza dinamica
	scroll.custom_minimum_size = Vector2(FIXED_WIDTH, desired_height)

	# Centra il popup
	popup_centered()

extends Node2D

var gy_cards: Array = []   # tutte le CardData nel GY
@onready var label = $RichTextLabel
@onready var highlight_border = $HighlightBorder
@onready var top_card_sprite = $TopCardSprite
@onready var atk_label = $AttackGYLabel
@onready var hp_label = $HealthGYLabel
@onready var spell_multi_label = $SpellMultiGYLabel
@onready var spell_dur_label = $SpellDurGYLabel

func _ready():
	label.text = str(gy_cards.size())
	highlight_border.visible = false
	# Assicurati che Area2D sia connessa
	var area = $Area2D
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	#area.input_event.connect(_on_input_event)  # ⬅️ aggiunto
	
func _on_mouse_entered():
	highlight_border.visible = true

func _on_mouse_exited():
	highlight_border.visible = false

#func _on_input_event(viewport, event, shape_idx):
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#print("🖱️ Cliccato sul GY")
		#var popup = get_parent().get_node("GYPopup")  # 👈 prende il fratello GYPopup
		#if popup:
			#popup.show_cards(gy_cards)
		#else:
			#print("❌ Popup non trovato")

func add_to_gy(card_data: CardData) -> void:
	if card_data == null:
		print("⚠️ Carta null non può andare al GY")
		return

	gy_cards.insert(0, card_data)
	print("💀 Carta inviata al GY:", card_data.card_name)
	label.text = str(gy_cards.size())

	await get_tree().create_timer(0.3).timeout  # ⏳ attende 0.3 secondi

	# ✅ Aggiorna la sprite dell'ultima carta
	_update_top_card_sprite()

	# 🔎 Stampa elenco aggiornato
	_print_gy_contents()

func _update_top_card_sprite():
	if top_card_sprite == null:
		print("❌ TopCardSprite non trovato nel GY")
		return

	if gy_cards.size() > 0 and gy_cards[0] != null:
		var top_card = gy_cards[0]
		
		# ✅ Usa la field sprite come priorità
		if top_card.card_sprite:
			top_card_sprite.texture = top_card.card_sprite
		
		# ✅ Mostra ATK e HP originali se è una creatura
		if top_card.card_type == "Creature":
			atk_label.visible = true
			hp_label.visible = true
			spell_multi_label.visible = false
			spell_dur_label.visible = false
			atk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			atk_label.text = str(top_card.original_attack)
			hp_label.text = str(top_card.original_health)
			atk_label.add_theme_color_override("font_color", Color.BLACK)
			hp_label.add_theme_color_override("font_color", Color.BLACK)
		else: #E' UNA SPELL
			atk_label.visible = false
			hp_label.visible = false
			spell_multi_label.visible = true
			spell_dur_label.visible = true
			spell_multi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			spell_dur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if top_card.original_spell_multiplier > 0:
				spell_multi_label.text = str(top_card.original_spell_multiplier)
			if top_card.original_spell_duration > 0 and top_card.original_spell_duration < 100:
				spell_dur_label.text = str(top_card.original_spell_duration)
			spell_multi_label.add_theme_color_override("font_color", Color.BLACK)
			spell_dur_label.add_theme_color_override("font_color", Color.BLACK)

		top_card_sprite.modulate = Color(0.6, 0.6, 0.6, 1)  # 👈 grigiastro scuro
	else:
		top_card_sprite.texture = null
		atk_label.text = ""
		hp_label.text = ""

		
func remove_from_gy(card_data: CardData):
	if card_data in gy_cards:
		gy_cards.erase(card_data)
		print("♻️ Carta rimossa dal GY:", card_data.card_name)
		label.text = str(gy_cards.size())

		# 🔎 Stampa elenco aggiornato
		_print_gy_contents()

# 🔧 Funzione di utilità
func _print_gy_contents():
	var names: Array = []
	for c in gy_cards:
		if c != null:
			names.append(c.card_name)
		else:
			names.append("❌ NULL")
	print("📜 GY attuale →", names)

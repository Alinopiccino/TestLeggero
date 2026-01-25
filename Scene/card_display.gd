extends Node2D
class_name CardDisplay

@export var card_data: CardData
@onready var preview_manager: Node = get_node("/root/Collection/CardPreviewManager")
@onready var card_sprite = $CardImage
@onready var attack_label = $Attack
@onready var health_label = $Health
@onready var spell_multiplier_label = $SpellMultiplier
@onready var spell_duration_label = $SpellDuration
@onready var highlight_border: Sprite2D = $HighlightBorder  # 🔹 è un ColorRect
@onready var shadow_sprite: Sprite2D = $CardShadow  # 👈 nuovo nodo
@onready var deck_copy_label: RichTextLabel = $DeckCopyLabel
@onready var invalid_banner: Node2D = $InvalidBanner
@onready var card_rank_icon: Sprite2D = $CardRankIcon
@onready var card_rank_label: RichTextLabel = $CardRankLabel

var is_hovered := false
var hover_timer: Timer


func _popup_open() -> bool:
	var collection = get_tree().root.get_node_or_null("Collection")
	if not collection:
		return false

	return (
		(collection.deck_creation_popup and collection.deck_creation_popup.visible)
		or (collection.save_confirm_popup and collection.save_confirm_popup.visible)
		or (collection.delete_popup and collection.delete_popup.visible)
	)

func _ready():
	hover_timer = Timer.new()
	hover_timer.wait_time = 0.3
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)
	if card_data:
		update_display()

	# ✅ Connette i segnali di hover dall'Area2D
	if has_node("Area2D"):
		$Area2D.mouse_entered.connect(_on_mouse_entered)
		$Area2D.mouse_exited.connect(_on_mouse_exited)
		$Area2D.input_event.connect(_on_area_input_event) # 👈 nuovo segnale


	# Nascondi highlight all'avvio
	if highlight_border:
		highlight_border.visible = false
		
	# Inizializza ombra (sempre visibile)
	if shadow_sprite:
		shadow_sprite.visible = true

func update_display():
	if not card_data:
		return

	# 🖼️ Immagine principale
	card_sprite.texture = card_data.card_sprite if card_data.card_sprite else null

	# 💥 Attack / Health (solo per Creature)
	if card_data.card_type == "Creature":
		attack_label.text = str(card_data.attack)
		health_label.text = str(card_data.health)
		attack_label.visible = true
		health_label.visible = true
		spell_multiplier_label.visible = false
		spell_duration_label.visible = false
	elif card_data.card_type == "Spell":
		# Spell Multiplier / Duration
		attack_label.visible = false
		health_label.visible = false

		if card_data.spell_multiplier > 0:
			spell_multiplier_label.text = str(card_data.spell_multiplier)
			spell_multiplier_label.visible = true
		else:
			spell_multiplier_label.visible = false

		if card_data.spell_duration > 0 and card_data.spell_duration < 100:
			spell_duration_label.text = str(card_data.spell_duration)
			spell_duration_label.visible = true
		else:
			spell_duration_label.visible = false
	else:
		# Nessun tipo riconosciuto
		attack_label.visible = false
		health_label.visible = false
		spell_multiplier_label.visible = false
		spell_duration_label.visible = false

	# ---------------------------------------------------
	# ⭐️ Mostra il Rank della carta
	# ---------------------------------------------------
	if card_rank_icon:
		card_rank_icon.visible = true  # puoi anche legarlo a card_type se vuoi
	if card_rank_label:
		card_rank_label.visible = true
		card_rank_label.text = "[b]" + str(card_data.card_rank) + "[/b]"

func update_deck_copy_count(count: int):
	if count > 0:
		# Usa il BBCode che hai già impostato come stile da inspector
		deck_copy_label.text = "[b][font_size=24]x[/font_size][font_size=36]" + str(count) + "[/font_size][/b]"
		deck_copy_label.visible = true
	else:
		deck_copy_label.visible = false


# ----------------------------------------------------------
# 🎨 Hover semplice
# ----------------------------------------------------------
func _on_mouse_entered() -> void:
	if _popup_open():
		return
	is_hovered = true
	if highlight_border:
		highlight_border.visible = true
	hover_timer.start()

func _on_mouse_exited() -> void:
	if _popup_open():
		return
	is_hovered = false
	if highlight_border:
		highlight_border.visible = false
	hover_timer.stop()
	if preview_manager:
		preview_manager.hide_preview()


func _on_hover_timer_timeout():
	if preview_manager and card_data:
		print("SHOW")
		preview_manager.show_preview(card_data)


func _on_area_input_event(viewport, event, shape_idx):
	if _popup_open():
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				print("🖱️ Click sinistro su:", card_data.card_name)
				_on_left_click()
			MOUSE_BUTTON_RIGHT:
				print("🖱️ Click destro su:", card_data.card_name)
				_on_right_click()

func _on_left_click():
	var collection = get_tree().root.get_node_or_null("Collection")
	if not collection:
		return

	if collection.is_in_deck_edit_mode and collection.current_deck_data:
		# 🔎 Conta quante copie della carta sono già nel deck
		var copies := 0
		for c in collection.current_deck_data.cards:
			if c == card_data:
				copies += 1

		# 🚫 Se hai già 3 copie → mostra solo feedback visivo e niente animazione
		if copies >= 3:
			print("⛔ Hai già 3 copie di:", card_data.card_name)
			if has_method("_show_max_copies_feedback"):
				_show_max_copies_feedback()
			return

		# ✅ Altrimenti aggiungi e anima normalmente
		collection.add_card_to_current_deck(card_data)
		if collection.has_method("animate_card_transfer"):
			collection.animate_card_transfer(self, card_data)
	else:
		print("ℹ️ Click sinistro in modalità normale, nessuna azione.")


func _on_right_click():
	var collection = get_tree().root.get_node_or_null("Collection")
	if not collection:
		return

	if collection.is_in_deck_edit_mode and collection.current_deck_data:
		collection.remove_card_from_current_deck(card_data)
	else:
		print("ℹ️ Click destro in modalità normale, nessuna azione.")


func show_stat_labels(visible: bool):
	attack_label.visible = visible
	health_label.visible = visible
	spell_duration_label.visible = visible
	spell_multiplier_label.visible = visible


func _pulse_copy_label():
	if not deck_copy_label:
		return

	if deck_copy_label.has_meta("pulse_tween"):
		var old_tween: Tween = deck_copy_label.get_meta("pulse_tween")
		if old_tween and old_tween.is_running():
			old_tween.kill()


	deck_copy_label.scale = Vector2(1, 1)
	

	var tween := create_tween()
	deck_copy_label.set_meta("pulse_tween", tween)

	# 🔹 Transizione lineare, nessuna ease
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT) # puoi anche lasciare il default, non influisce con LINEAR

	# 🔸 Animazione dolce ma costante
	tween.tween_property(deck_copy_label, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(deck_copy_label, "scale", Vector2(1.0, 1.0), 0.1)
	


func _show_max_copies_feedback():
	if not deck_copy_label:
		return

	# 🔹 Se già un tween è in corso, uccidilo
	if deck_copy_label.has_meta("error_tween"):
		var old_tween: Tween = deck_copy_label.get_meta("error_tween")
		if old_tween and old_tween.is_running():
			old_tween.kill()

	# Colore iniziale (bianco)
	var base_color = Color(1, 1, 1, 1)
	deck_copy_label.modulate = base_color
	deck_copy_label.scale = Vector2(1, 1)

	var tween := create_tween()
	deck_copy_label.set_meta("error_tween", tween)

	# 🔸 Transizione lineare, nessun easing
	tween.set_trans(Tween.TRANS_LINEAR)

	# 🔴 Lampeggia in rosso + piccolo "pulse" costante
	tween.parallel().tween_property(deck_copy_label, "modulate", Color(1, 0.1, 0.1), 0.1)
	tween.parallel().tween_property(deck_copy_label, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(deck_copy_label, "modulate", base_color, 0.3)
	tween.tween_property(deck_copy_label, "scale", Vector2(1.0, 1.0), 0.2)
	
func mark_as_invalid_in_expand(is_invalid: bool):
	if invalid_banner:
		invalid_banner.visible = is_invalid

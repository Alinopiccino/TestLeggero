extends Node2D
class_name DeckCardDisplay

@export var card_data: CardData
@onready var sprite: Sprite2D = $CardSprite
@onready var highlight_border: Sprite2D = $HighlightBorder
@onready var area: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var preview_manager: Node = get_node_or_null("/root/Collection/CardPreviewManager")
@onready var invalid_banner: Sprite2D = $InvalidBanner

var is_hovered := false
var hover_timer: Timer

# 🆕 Sistema copie multiple
var copy_count: int = 1
var count_label: Label
var rank_icon: Sprite2D
var rank_label: Label

# ----------------------------------------------------------
# 🔍 Utility: popup aperto?
# ----------------------------------------------------------
func _popup_open() -> bool:
	var collection = get_tree().root.get_node_or_null("Collection")
	if not collection:
		return false

	return (
		(collection.deck_creation_popup and collection.deck_creation_popup.visible)
		or (collection.save_confirm_popup and collection.save_confirm_popup.visible)
		or (collection.delete_popup and collection.delete_popup.visible)
	)

# ----------------------------------------------------------
# 🧩 Ready
# ----------------------------------------------------------
func _ready():
	# 🆕 Crea subito la label del contatore
	count_label = Label.new()
	count_label.visible = false
	count_label.add_theme_font_size_override("font_size", 22)
	count_label.modulate = Color(1, 0.8, 0.09, 1) # giallo tenue
	count_label.text = ""
	count_label.position = Vector2(140, -17)
	add_child(count_label)



	# 🆕 Icona rank (sempre visibile)
	rank_icon = Sprite2D.new()
	rank_icon.texture = preload("res://Assets Collezione/STAR ICON BOH.png")
	rank_icon.scale = Vector2(30.0 / rank_icon.texture.get_width(), 30.0 / rank_icon.texture.get_height())
	rank_icon.position = Vector2(215, -1)
	add_child(rank_icon)

	# 🏷️ Label Rank (solo numero)
	rank_label = Label.new()
	rank_label.add_theme_font_size_override("font_size", 20)
	rank_label.modulate = Color(1.0, 0.894, 0.875, 1)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.size = Vector2(24, 24)
	rank_label.position = Vector2(204, -16) # vicino al count_label
	rank_label.text = str(card_data.card_rank)
	add_child(rank_label)

	
	# ⏱️ Timer per preview
	hover_timer = Timer.new()
	hover_timer.wait_time = 0.3
	hover_timer.one_shot = true
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)

	if card_data:
		update_display()


	# 🖱️ Connessioni per hover e click
	if area:
		area.mouse_entered.connect(_on_mouse_entered)
		area.mouse_exited.connect(_on_mouse_exited)
		area.input_event.connect(_on_area_input_event)

	# Bordo nascosto all'inizio
	if highlight_border:
		highlight_border.visible = false



# ----------------------------------------------------------
# 🎴 Display aggiornato
# ----------------------------------------------------------
func update_display():
	if not card_data:
		return
	if not sprite:
		push_error("❌ Nodo CardSprite non trovato in DeckCardDisplay!")
		return
		
	# 🧱 Usa la texture del deck editor dal CardData
	sprite.texture = card_data.card_deck_sprite if card_data.card_deck_sprite else null
	_update_count_label()

func _update_count_label():
	if copy_count > 1:
		count_label.text = "×" + str(copy_count)
		count_label.visible = true
	else:
		count_label.visible = false

# ----------------------------------------------------------
# 🆕 Gestione copie duplicate
# ----------------------------------------------------------
func increment_copy_count():
	copy_count += 1
	_update_count_label()
	pulse_highlight()

func decrement_copy_count():
	copy_count = max(1, copy_count - 1)
	_update_count_label()

func pulse_highlight():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)

# ----------------------------------------------------------
# 🎨 Hover + Preview
# ----------------------------------------------------------
func _on_mouse_entered():
	if _popup_open():
		return
	is_hovered = true
	if highlight_border:
		highlight_border.visible = true
	hover_timer.start()

func _on_mouse_exited():
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
		preview_manager.show_preview(card_data)

# ----------------------------------------------------------
# 🖱️ Clicks
# ----------------------------------------------------------
func _on_area_input_event(viewport, event, shape_idx):
	if _popup_open():
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				print("🖱️ Click sinistro su carta del deck:", card_data.card_name)
				_on_left_click()
			MOUSE_BUTTON_RIGHT:
				print("🖱️ Click destro su carta del deck:", card_data.card_name)
				_on_right_click()

func _on_left_click():
	var collection = get_tree().root.get_node_or_null("Collection")
	if not collection:
		print("⚠️ Collection non trovata nel tree.")
		return

	if collection.is_in_deck_edit_mode and collection.current_deck_data:
		if collection.has_method("remove_card_from_current_deck"):
			collection.remove_card_from_current_deck(card_data)
			print("➖ Rimossa dal deck:", card_data.card_name)
	else:
		print("ℹ️ Click sinistro in modalità normale, nessuna azione.")

func _on_right_click():
	var collection = get_tree().root.get_node_or_null("Collection")
	if not collection:
		print("⚠️ Collection non trovata nel tree.")
		return

	if collection.is_in_deck_edit_mode and collection.current_deck_data:
		if collection.has_method("remove_card_from_current_deck"):
			collection.remove_card_from_current_deck(card_data)
			print("➖ Rimossa dal deck:", card_data.card_name)
	else:
		print("ℹ️ Click destro in modalità normale, nessuna azione.")

func decrement_copy_count_and_update() -> bool:
	if copy_count > 1:
		# 🎬 ANIMAZIONE: rimozione di una singola copia (ma la carta resta visiva)
		_spawn_removal_animation(false)
		copy_count -= 1
		_update_count_label()
		print("🔻 Decrementata copia per:", card_data.card_name, "→", copy_count)
		return true
	else:
		# 🎬 ANIMAZIONE: ultima copia → rimuovi la carta visiva alla fine
		_spawn_removal_animation(true)
		return false


func _spawn_removal_animation(remove_self: bool = false):
	if not sprite or not sprite.texture:
		return

	# 🔹 Crea un duplicato temporaneo della carta
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.position = sprite.position
	ghost.scale = sprite.scale
	ghost.modulate = Color(1, 1, 1, 1)
	add_child(ghost)

	# 🔹 Crea il tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "position:x", ghost.position.x - 120, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)

	if remove_self:
		# 👋 Anche la carta principale vola via e sparisce
		var tween_self = create_tween()
		tween_self.set_parallel(true)
		tween_self.tween_property(self, "position:x", position.x - 120, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_self.tween_property(self, "modulate:a", 0.0, 0.2)
		tween_self.finished.connect(func():
			if is_instance_valid(self):
				queue_free())

	# 🔹 Rimuovi il ghost quando l’animazione termina
	tween.finished.connect(func():
		if is_instance_valid(ghost):
			ghost.queue_free())


func mark_as_invalid(is_invalid: bool):
	if not invalid_banner:
		return
	invalid_banner.visible = is_invalid

extends TextureRect

@export var mana_type: String = ""
@export var drag_preview_size: Vector2 = Vector2(100, 100)
@export var drag_preview_offset: Vector2 = Vector2(-50, -100) 
# ↑ offset rispetto al cursore (negativo Y = più in alto, positivo = più in basso)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("🖱 Click su mana option:", mana_type)
		_insert_into_first_free_slot()
#
#func _get_drag_data(_pos):
	#print("🔥 _get_drag_data chiamato per", mana_type)
#
	## 🔹 Contenitore per gestire offset
	#var preview_container := Control.new()
	#preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
#
	## 🔹 Texture effettiva
	#var preview := TextureRect.new()
	#preview.texture = texture
	#preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	#preview.ignore_texture_size = true
	#preview.size = drag_preview_size
	#preview.modulate = Color(1, 1, 1, 1)
#
	## Aggiungi la texture nel contenitore
	#preview_container.add_child(preview)
#
	## Posiziona la texture al centro del contenitore
	#preview.position = -preview.size / 2.0
#
	## 🔹 Imposta offset finale del contenitore
	#preview_container.position = drag_preview_offset
#
	## Imposta come anteprima del drag
	#set_drag_preview(preview_container)
#
	## Dati del drag
	#var data = {
		#"type": "mana",
		#"mana_type": mana_type,
		#"texture": texture
	#}
	#print("📦 Drag data =", data)
	#return data

# 🧩 Nuova funzione — inserisce automaticamente il mana nel primo slot libero
func _insert_into_first_free_slot():
	var root = get_tree().root
	var slot_container = root.find_child("ManaSlotContainer", true, false)

	if not slot_container:
		print("⚠️ Nessun 'ManaSlotContainer' trovato nella scena.")
		return

	for slot in slot_container.get_children():
		if not slot.filled:
			print("✅ Inserisco", mana_type, "nel primo slot libero:", slot.name)
			slot.mana_icon.texture = texture
			slot.current_mana_type = mana_type
			slot.filled = true
			slot.mana_icon.visible = true
			slot.modulate = Color(1, 1, 1)
			_play_mana_glow(slot)
			return


	print("⚠️ Nessuno slot libero disponibile per", mana_type)


# 💫 Effetto glow semplice (fade-in + hold + fade-out)
func _play_mana_glow(slot: Node):
	if not slot or not slot.current_mana_type:
		return

	var glow_paths = {
		"Fire": preload("res://Assets/Mana/FuocoUsing.png"),
		"Wind": preload("res://Assets/Mana/VentoUsing.png"),
		"Water": preload("res://Assets/Mana/AcquaUsing.png"),
		"Earth": preload("res://Assets/Mana/TerraUsing.png")
	}

	var mana_type = slot.current_mana_type
	if not glow_paths.has(mana_type):
		return

	var base_icon: TextureRect = slot.mana_icon
	if not base_icon:
		return

	# 🔹 Overlay temporaneo sopra la texture base
	var glow_icon := TextureRect.new()
	glow_icon.texture = glow_paths[mana_type]
	glow_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow_icon.ignore_texture_size = true
	glow_icon.custom_minimum_size = base_icon.custom_minimum_size
	glow_icon.anchor_left = 0
	glow_icon.anchor_top = 0
	glow_icon.anchor_right = 1
	glow_icon.anchor_bottom = 1
	glow_icon.offset_left = 0
	glow_icon.offset_top = 0
	glow_icon.offset_right = 0
	glow_icon.offset_bottom = 0
	glow_icon.modulate = Color(1, 1, 1, 0) # parte trasparente
	slot.add_child(glow_icon)
	slot.move_child(glow_icon, slot.get_child_count() - 1) # porta sopra

	# 🔹 Tween: fade-in → mantieni → fade-out
	var tween := slot.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# fade-in
	tween.tween_property(glow_icon, "modulate:a", 1.0, 0.2)

	# fade-out
	tween.tween_property(glow_icon, "modulate:a", 0.0, 0.2)

	# rimuovi overlay
	tween.tween_callback(Callable(func():
		if is_instance_valid(glow_icon):
			glow_icon.queue_free()
	))

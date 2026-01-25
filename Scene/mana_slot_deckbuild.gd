extends Control

var filled := false
var current_mana_type := ""
var is_dragging := false

@onready var slot: TextureRect = $Slot
@onready var mana_icon: TextureRect = $ManaChoice

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	if slot:
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		print("⚠️ _ready: slot nodo non trovato in ", name)
	if mana_icon:
		mana_icon.visible = false
		mana_icon.ignore_texture_size = true
		mana_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mana_icon.custom_minimum_size = Vector2(48, 48)
	else:
		print("⚠️ _ready: mana_icon nodo non trovato in ", name)
		
	# ➕ Connetti segnali per rilevare entrata/uscita del cursore
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	print("🟢 Slot ready:", name, "filled=", filled)


func _can_drop_data(_pos, data) -> bool:
	is_dragging = true  # ora sappiamo che un drag è in corso
	if data.has("type") and data["type"] == "mana" and not filled:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)  # 👆 mano = "puoi droppare"
		modulate = Color(2, 2, 2, 1)  # più chiaro = effetto "illuminato"
		return true
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)  # ↗ normale
		modulate = Color(1, 1, 1)      # reset se non droppabile
		return false


func _drop_data(_pos, data):
	print("🎯 _drop_data chiamato su", name, "data=", data)
	if not _can_drop_data(_pos, data):
		print("   ✖ Drop ignorato su", name)
		modulate = Color(1, 1, 1)
		return

	mana_icon.texture = data["texture"]
	current_mana_type = data["mana_type"]
	filled = true
	mana_icon.visible = true
	modulate = Color(1, 1, 1)
	print("   ✅ Slot riempito con:", current_mana_type)


# ✅ Quando termina un drag ovunque
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)  # resetta alla fine del drag
		is_dragging = false
		if not filled:
			modulate = Color(1, 1, 1)


# ✅ Quando il mouse entra nello slot (mentre dragga)
func _on_mouse_entered():
	# non serve fare nulla — viene già gestito da _can_drop_data
	pass


# ✅ Quando il mouse esce dallo slot mentre trascini
func _on_mouse_exited():
	if is_dragging and not filled:
		modulate = Color(1, 1, 1)
		print("🚪 Mouse exited", name, "→ modulate reset")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		print("🖱 Right-click on", name, "filled=", filled)
		if filled:
			clear_slot()


func clear_slot():
	print("🔄 clear_slot on", name, "was current_mana_type=", current_mana_type)
	mana_icon.visible = false
	mana_icon.texture = null
	current_mana_type = ""
	filled = false
	modulate = Color(1, 1, 1)
	print("   ❎ Slot cleared:", name, "filled=", filled)

extends Control

@onready var world = $World

@onready var play_button = $World/VBoxContainer/PlayButton
@onready var collection_button = $World/VBoxContainer/CollectionButton
@onready var quit_button = $World/VBoxContainer/QuitButton

@onready var username_edit = $World/UsernameEdit
@onready var username_label = $World/UsernameLabel

@onready var luce_accesa = $World/LuceAccesa
@onready var luce_spenta = $World/LuceSpenta

@onready var background = $World/Background
@onready var flicker_timer = $FlickerTimer


var is_flickering := false
var flicker_count := 0
var flicker_max := 0

var current_username := "Player"


func _ready():

	if not MenuState.main_menu_intro_played:
		MenuState.main_menu_intro_played = true
		await _play_camera_settle()
	else:
		world.position.y = 0  # niente animazione

	# --- resto del tuo codice ---
	play_button.pressed.connect(_on_play_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	username_label.text = current_username
	username_edit.text = current_username
	username_edit.visible = false

	username_edit.focus_entered.connect(_on_username_focus_entered)
	username_edit.focus_exited.connect(_on_username_focus_exited)
	username_edit.text_submitted.connect(_on_username_submitted)
	username_label.gui_input.connect(_on_label_clicked)

	randomize()
	flicker_timer.timeout.connect(_on_flicker_timeout)
	_start_stable_phase()


# =====================================================
# 🎥 CAMERA SETTLE (ARRIVO DALLO SPLASH)
# =====================================================

func _play_camera_settle():
	await get_tree().process_frame

	world.position.y = 1920

	var tween := create_tween()
	tween.tween_property(world, "position:y", 0, 0.9) \
		.set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)

	await tween.finished


# =====================================================
# 💡 FLICKER LUCE
# =====================================================

func _start_stable_phase():
	is_flickering = false
	luce_accesa.visible = true
	flicker_timer.wait_time = randf_range(0.4, 0.5)
	flicker_timer.start()


func _start_flicker_phase():
	is_flickering = true
	flicker_count = 0
	flicker_max = randi_range(3, 4)
	flicker_timer.wait_time = randf_range(0.04, 0.08)
	flicker_timer.start()


func _on_flicker_timeout():
	if is_flickering:
		luce_accesa.visible = !luce_accesa.visible
		flicker_count += 1

		if flicker_count >= flicker_max:
			_start_stable_phase()
		else:
			flicker_timer.wait_time = randf_range(0.04, 0.08)
			flicker_timer.start()
	else:
		if randf() < 0.10:
			_start_flicker_phase()
		else:
			_start_stable_phase()


# =====================================================
# ✏️ USERNAME
# =====================================================

func _on_label_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		username_label.visible = false
		username_edit.visible = true
		username_edit.grab_focus()
		username_edit.select_all()


func _on_username_focus_entered() -> void:
	pass


func _on_username_focus_exited() -> void:
	username_edit.text = current_username
	username_edit.visible = false
	username_label.visible = true


func _on_username_submitted(new_text: String) -> void:
	current_username = new_text.strip_edges()
	username_label.text = current_username
	username_label.visible = true
	username_edit.visible = false
	username_edit.release_focus()


# =====================================================
# 🎮 BOTTONI
# =====================================================

func _on_play_pressed():
	flicker_timer.stop()

	var next_scene = load("res://Scene/Main.tscn").instantiate()
	var tree := get_tree()

	tree.root.add_child(next_scene)
	tree.current_scene = next_scene

	queue_free()  # rimuove il MainMenu


func _on_collection_pressed():
	flicker_timer.stop()

	var next_scene = load("res://Scene/Collection.tscn").instantiate()
	var tree := get_tree()

	tree.root.add_child(next_scene)
	tree.current_scene = next_scene

	queue_free()


func _on_quit_pressed():
	get_tree().quit()

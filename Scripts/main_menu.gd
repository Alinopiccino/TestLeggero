extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var collection_button = $VBoxContainer/CollectionButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var username_edit = $UsernameEdit
@onready var username_label = $UsernameLabel
@onready var luce_accesa = $LuceAccesa
@onready var flicker_timer = $FlickerTimer

var is_flickering := false
var flicker_count := 0
var flicker_max := 0

var current_username := "Player"

func _ready():
	# Bottoni menu
	play_button.pressed.connect(_on_play_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Username edit/label
	username_label.text = current_username

	username_edit.text = current_username
	username_edit.visible = false

	# Connetti segnali del LineEdit
	username_edit.focus_entered.connect(_on_username_focus_entered)
	username_edit.focus_exited.connect(_on_username_focus_exited)
	username_edit.text_submitted.connect(_on_username_submitted)

	username_label.gui_input.connect(_on_label_clicked)
	randomize()

	flicker_timer.timeout.connect(_on_flicker_timeout)
	_start_stable_phase()

func _start_stable_phase():
	is_flickering = false
	luce_accesa.visible = true
	
	# Rimane stabile per un tempo casuale
	flicker_timer.wait_time = randf_range(0.4, 0.5)
	flicker_timer.start()


func _start_flicker_phase():
	is_flickering = true
	flicker_count = 0
	
	# Numero casuale di lampeggi veloci
	flicker_max = randi_range(3, 4)
	
	# Prima oscillazione veloce
	flicker_timer.wait_time = randf_range(0.04, 0.08)
	flicker_timer.start()


func _on_flicker_timeout():
	if is_flickering:
		# Toggle veloce
		luce_accesa.visible = !luce_accesa.visible
		flicker_count += 1
		
		if flicker_count >= flicker_max:
			# Torna stabile
			_start_stable_phase()
		else:
			# Continua flicker veloce
			flicker_timer.wait_time = randf_range(0.04, 0.08)
			flicker_timer.start()
	
	else:
		# Decide casualmente se iniziare flicker
		if randf() < 0.10:  # 15% probabilità
			_start_flicker_phase()
		else:
			_start_stable_phase()




# --- GESTIONE USERNAME ---
func _on_label_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		username_label.visible = false
		username_edit.visible = true
		username_edit.grab_focus()
		username_edit.select_all()


func _on_username_focus_entered() -> void:
	# (facoltativo: potresti aggiungere effetti visivi qui)
	pass


func _on_username_focus_exited() -> void:
	# Se perde il focus senza aver premuto Invio → annulla modifica
	username_edit.text = current_username
	username_edit.visible = false
	username_label.visible = true


func _on_username_submitted(new_text: String) -> void:
	# Aggiorna l'username solo quando si preme Invio
	current_username = new_text.strip_edges()
	username_label.text = current_username
	username_label.visible = true
	username_edit.visible = false
	# Rimuovi il focus per evitare riattivazioni indesiderate
	username_edit.release_focus()


# --- GESTIONE BOTTONI ---
func _on_play_pressed():
	print("🎮 Vai alla scena multiplayer...")
	get_tree().change_scene_to_file("res://Scene/Main.tscn")
	
	flicker_timer.stop()   # ← Ferma il flicker

func _on_collection_pressed():
	print("📚 Vai alla collezione...")
	get_tree().change_scene_to_file("res://Scene/Collection.tscn")
	
	flicker_timer.stop()   # ← Ferma il flicker

func _on_quit_pressed():
	print("👋 Esco dal gioco")
	get_tree().quit()

extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var collection_button = $VBoxContainer/CollectionButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var username_edit = $UsernameEdit
@onready var username_label = $UsernameLabel

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

func _on_collection_pressed():
	print("📚 Vai alla collezione...")
	get_tree().change_scene_to_file("res://Scene/Collection.tscn")

func _on_quit_pressed():
	print("👋 Esco dal gioco")
	get_tree().quit()

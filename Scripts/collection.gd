extends Node2D

@onready var deck_background: Sprite2D = $DeckBackground
@onready var expand_deck_button: TextureButton = $ExpandDeckButton
@onready var shrink_deck_button: TextureButton = $ShrinkDeckButton
var showing_deck_view := false
var refreshing_expand_view := false  # 👈 nuovo flag temporaneo
@onready var card_area: Node2D = $CardArea
@onready var background: Sprite2D = $Background
@onready var next_page_button: TextureButton = $NextPageButton
@onready var prev_page_button: TextureButton = $PrevPageButton
@onready var page_label: RichTextLabel = $PageLabel
@export var card_scene: PackedScene = preload("res://Scene/CardDisplay.tscn")
@export var deck_card_scene: PackedScene = preload("res://Scene/DeckCardDisplay.tscn")
@onready var fire_button: TextureButton = $AttributeButtons/FireButton
@onready var wind_button: TextureButton = $AttributeButtons/WindButton
@onready var water_button: TextureButton = $AttributeButtons/WaterButton
@onready var earth_button: TextureButton = $AttributeButtons/EarthButton
@onready var search_bar: LineEdit = $SearchBar
@onready var back_button: Button = $BackButton
@onready var save_deck_button: Button = $SaveDeckButton
@onready var deck_cards_area: Node2D = $DeckListPanel/DeckCardsArea
@export var deck_card_spacing := 40.0
@onready var save_confirm_popup: ConfirmationDialog = $SaveConfirmPopup
@onready var delete_popup: ConfirmationDialog = $DeleteDeckPopup

var attribute_buttons := {} # dizionario per accesso rapido
var original_deck_snapshot: DeckData = null
var current_deck_data: DeckData = null
var is_in_deck_edit_mode := false
var deck_modified := false
var _deck_edit_connected: bool = false
var deck_is_invalid: bool = false
var deck_is_invalid_due_to_rank: bool = false
var deck_is_invalid_due_to_cards: bool = false
var deck_is_invalid_due_to_count: bool = false
const DECK_PANEL_START_POS := Vector2(140, 160)
#var delete_popup: ConfirmationDialog = null  # 👈 aggiungila in cima al file tra le variabili
# Layout delle carte
@export var columns := 6
@export var max_rows := 3
@export var spacing_x := 200
@export var spacing_y := 270
@export var card_scale := 1
@export var start_offset := Vector2(300, 200) # start della griglia

# Layout del deck espanso
@export var deck_columns := 5
@export var deck_max_rows := 8
@export var deck_spacing_x := 200
@export var deck_spacing_y := 270
@export var deck_card_scale := 0.75
@export var deck_start_offset := Vector2(200, 200)

# In Collection.gd, in cima
var scroll_enabled := true
var scroll_offset := 0.0
var scroll_speed := 100.0
var scroll_min := -9999.0
var scroll_max := 0.0
# ----------------------------------------------------------
# 🧱 SEZIONE DECKS
# ----------------------------------------------------------
@onready var deck_list_panel: Panel = $DeckListPanel
@onready var deck_buttons_container: VBoxContainer = $DeckListPanel/VBoxContainer/DeckButtonsContainer
@onready var create_deck_button: Button = $DeckListPanel/VBoxContainer/CreateDeckButton
@onready var deck_creation_popup: AcceptDialog = $DeckCreationPopup
@onready var deck_name_input: LineEdit = $DeckCreationPopup/MarginContainer/VBoxContainer/DeckNameInput

@onready var mana_ordering_button: TextureButton = $DeckListPanel/ManaOrderingButton
@onready var rank_ordering_button: TextureButton = $DeckListPanel/RankOrderingButton
@onready var mana_ordering_icon: Sprite2D = $DeckListPanel/ManaOrderingIcon
@onready var rank_ordering_icon: Sprite2D = $DeckListPanel/RankOrderingIcon
@onready var rank_sprite_for_label: Sprite2D = $DeckListPanel/RankSpriteForLabel
@onready var deck_size_sprite_for_label: Sprite2D = $DeckListPanel/DeckSizeSpriteForLabel

var mana_order_state := "none"  # valori: "none", "asc", "desc"
var rank_order_state := "none"  # valori: "none", "asc", "desc"

const ICON_NONE = preload("res://Assets Collezione/NO FILTER ICON.png")
const ICON_ASC = preload("res://Assets Collezione/INCR FILTER ICON.png")
const ICON_DESC = preload("res://Assets Collezione/DECR FILTER ICON.png")

# Paginazione
var all_card_paths: Array[String] = []
var pages_data: Array = [] # contiene array di percorsi, uno per ogni pagina
var cards_per_page := 18  # 6x3
var current_page := 0
var total_pages := 0
# ----------------------------------------------------------
# 🔍 Filtro corrente
# ----------------------------------------------------------
var current_filter_mode := "Attribute" # default al caricamento
var filtered_card_paths: Array[String] = []
var card_cache: Dictionary = {} # path -> CardData
var card_instances_by_attr: Dictionary = {} # attr -> [CardDisplay]
# ----------------------------------------------------------
# 🔹 Ready
# ----------------------------------------------------------
func _ready():
	attribute_buttons = {
	"Fire": fire_button,
	"Wind": wind_button,
	"Water": water_button,
	"Earth": earth_button
	}


	# Collega i click
	fire_button.pressed.connect(func(): _on_attribute_button_pressed("Fire"))
	wind_button.pressed.connect(func(): _on_attribute_button_pressed("Wind"))
	water_button.pressed.connect(func(): _on_attribute_button_pressed("Water"))
	earth_button.pressed.connect(func(): _on_attribute_button_pressed("Earth"))
	
	
	next_page_button.pressed.connect(_on_page_button_pressed.bind(next_page_button))
	prev_page_button.pressed.connect(_on_page_button_pressed.bind(prev_page_button))

	
	# Salva la posizione originale di ciascun bottone
	for attr in attribute_buttons.keys():
		var btn = attribute_buttons[attr]
		btn.set_meta("base_position", btn.position)
		
	deck_creation_popup.about_to_popup.connect(func():
		# 🔹 Appena il popup si apre, seleziona subito la LineEdit
		await get_tree().process_frame  # aspetta un frame per sicurezza
		deck_name_input.grab_focus()
	)
		# 🔹 Colleghiamo i segnali della search bar
	search_bar.text_submitted.connect(_on_search_bar_submitted)
	search_bar.text_changed.connect(_on_search_bar_text_changed) #SE MI DA FASTIDIO POSSO ANCHE TOGLIERLO COSI'
	create_deck_button.pressed.connect(_on_create_deck_pressed)
	
	if mana_ordering_button:
		print("✅ Mana button trovato:", mana_ordering_button.name)
		mana_ordering_button.pressed.connect(_on_mana_ordering_button_pressed)
	else:
		push_error("❌ MANA ORDERING BUTTON NON TROVATO")

	if rank_ordering_button:
		print("✅ Rank button trovato:", rank_ordering_button.name)
		rank_ordering_button.pressed.connect(_on_rank_ordering_button_pressed)
	else:
		push_error("❌ RANK ORDERING BUTTON NON TROVATO")
	
	deck_creation_popup.confirmed.connect(_on_deck_creation_confirmed)
	deck_name_input.text_submitted.connect(func(_text):
		deck_name_input.release_focus()
		
		# 🔹 Dai focus al bottone OK del popup (così Invio lo preme)
		var ok_button = deck_creation_popup.get_ok_button()
		if ok_button:
			ok_button.grab_focus()
	)
	
	expand_deck_button.pressed.connect(_on_expand_deck_pressed)
	shrink_deck_button.pressed.connect(_on_shrink_deck_pressed)

	
	deck_background.visible = false
	shrink_deck_button.visible = false
	_load_existing_decks()


	
	print("📚 Caricamento collezione carte...")
	load_all_card_paths("res://CardResources")
	_preload_all_cards() # 👈 nuova funzione
	
	
	total_pages = int(ceil(float(all_card_paths.size()) / float(cards_per_page)))
	_apply_default_filter()
	_show_page(0)
	_update_page_buttons()
	_update_page_label()
	_highlight_current_attribute()


	if save_confirm_popup:
		# 🔹 Crea i bottoni solo una volta
		save_confirm_popup.get_ok_button().visible = false
		save_confirm_popup.get_cancel_button().visible = false
		var save_btn = save_confirm_popup.add_button("💾 Save Changes", true, "save")
		var discard_btn = save_confirm_popup.add_button("❌ Do Not Save", false, "discard")
		var cancel_btn = save_confirm_popup.add_cancel_button("↩️ Cancel")

		# Collega una sola volta il segnale custom_action
		save_confirm_popup.custom_action.connect(_on_save_confirm_popup_choice)


var scroll_tween: Tween

func _unhandled_input(event: InputEvent) -> void:
	# ------------------------------------------------------
	# 🧩 Gestione popup creazione deck
	# ------------------------------------------------------
	if deck_creation_popup.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			var focused = get_viewport().gui_get_focus_owner()
			if focused != deck_name_input:
				deck_creation_popup._ok_pressed()
		return

	# ------------------------------------------------------
	# 🧱 Scroll fluido del deck
	# ------------------------------------------------------
	if scroll_enabled:
		var target_offset := scroll_offset  # posizione attuale

		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				target_offset = clamp(scroll_offset + scroll_speed, scroll_min, scroll_max)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				target_offset = clamp(scroll_offset - scroll_speed, scroll_min, scroll_max)

		elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			target_offset = clamp(scroll_offset + event.relative.y, scroll_min, scroll_max)

		if target_offset != scroll_offset:
			scroll_offset = target_offset

			# 🔹 Stop tween precedente se ancora in corso
			if scroll_tween and scroll_tween.is_running():
				scroll_tween.kill()


			# 🔹 Crea tween fluido con rallentamento
			scroll_tween = create_tween()
			scroll_tween.tween_property(deck_cards_area, "position:y", scroll_offset, 0.15)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_OUT)





# ----------------------------------------------------------
# 📦 Caricamento carte
# ----------------------------------------------------------
func load_all_card_paths(path: String):
	var dir = DirAccess.open(path)
	if not dir:
		push_error("❌ Impossibile aprire la cartella: " + path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			load_all_card_paths(path + "/" + file_name)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			all_card_paths.append(path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

# ----------------------------------------------------------
# 🧩 Crea tutte le carte una sola volta
# ----------------------------------------------------------
func _create_all_cards():
	for i in range(all_card_paths.size()):
		var card_data: CardData = load(all_card_paths[i])
		if not card_data:
			continue

		var card_instance = card_scene.instantiate()
		card_instance.card_data = card_data
		card_instance.scale = Vector2(card_scale, card_scale)
		card_area.add_child(card_instance)

		var index = i
		var col = index % columns
		var row = index / columns % max_rows  # si resetta ogni 3 righe
		var page = index / cards_per_page     # calcola la pagina
		var page_offset_y = page * (max_rows * spacing_y + 200)  # distanza tra le pagine

		# Posiziona la carta
		card_instance.position = start_offset + Vector2(col * spacing_x, row * spacing_y)

		# 🔹 Nascondi carte non della prima pagina
		card_instance.visible = (page == 0)

# ----------------------------------------------------------
# 📑 Mostra la pagina desiderata
# ----------------------------------------------------------
func _show_page(page: int):
	current_page = clamp(page, 0, total_pages - 1)

	# 🔹 Nascondi tutte le carte prima
	for child in card_area.get_children():
		child.visible = false

	if pages_data.is_empty():
		return

	var page_info = pages_data[current_page]
	var cards = page_info["cards"]
	var attr = page_info.get("group_id", "Unknown")

	print("📄 Mostrando pagina", current_page + 1, "→ Attributo:", attr)

	# ------------------------------------------------------
	# 🕒 Mostra le carte con animazione pop (come nell’expand)
	# ------------------------------------------------------
	for i in range(cards.size()):
		var path = cards[i]
		if not card_cache.has(path):
			continue

		var card_instance = _find_instance_by_path(path)
		if not card_instance:
			continue

		var col = i % columns
		var row = i / columns
		card_instance.position = start_offset + Vector2(col * spacing_x, row * spacing_y)
		card_instance.visible = true

		# 🔸 Applica animazione "pop"
		card_instance.scale = Vector2(0.0, 0.0)
		var pop_tween = create_tween()
		card_instance.set_meta("pop_tween", pop_tween)
		pop_tween.set_trans(Tween.TRANS_BACK)
		pop_tween.set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(
			card_instance,
			"scale",
			Vector2(card_scale, card_scale),
			0.3
		).set_delay(i * 0.02)
		pop_tween.finished.connect(func():
			card_instance.set_meta("pop_tween", null)
		)


		pop_tween.finished.connect(func():
			card_instance.set_meta("pop_tween", null)
		)

	_update_page_buttons()
	_update_page_label()
	_highlight_current_attribute()


func _find_instance_by_path(path: String) -> Node2D:
	for attr in card_instances_by_attr.keys():
		var valid_cards: Array = []
		for c in card_instances_by_attr[attr]:
			if not is_instance_valid(c):
				continue  # 👈 evita l'accesso a oggetti freed
			if c.card_data and c.card_data.resource_path == path:
				return c
			valid_cards.append(c)
		# 👇 rimpiazza con solo i validi, così ripulisce progressivamente
		card_instances_by_attr[attr] = valid_cards
	return null

# ----------------------------------------------------------
# 🔘 Bottoni pagina
# ----------------------------------------------------------
func _on_next_page_button_pressed() -> void:
	if current_page < total_pages - 1:
		_show_page(current_page + 1)

func _on_prev_page_button_pressed() -> void:
	if current_page > 0:
		_show_page(current_page - 1)

func _update_page_buttons():
	prev_page_button.visible = current_page > 0
	next_page_button.visible = current_page < total_pages - 1

# ----------------------------------------------------------
# 🔙 Torna al menu principale
# ----------------------------------------------------------
func _on_back_button_pressed():
	back_button.release_focus()  # ✅ Rimuove focus subito

	# 🧹 Se siamo in modalità deck editor ed è aperta la vista espansa → chiudila prima
	if showing_deck_view:
		print("📕 Chiusura automatica vista espansa prima del ritorno indietro")
		_on_shrink_deck_pressed()

	_clear_search_bar()  # 👈 svuota sempre la barra di ricerca

	# 🔹 Se siamo in modalità deck edit e ci sono modifiche non salvate
	if is_in_deck_edit_mode and deck_modified:
		_show_unsaved_changes_popup()
		return
	
	# 🔙 Altrimenti esegui il comportamento standard
	_exit_deck_edit_mode_or_leave()



func _show_unsaved_changes_popup():
	save_confirm_popup.dialog_text = "You still have unsaved deck changes"
	save_confirm_popup.popup_centered()

func _on_save_confirm_popup_choice(action: String):
	# 🔹 Chiudi manualmente il popup
	if save_confirm_popup and save_confirm_popup.visible:
		save_confirm_popup.hide()

	match action:
		"save":
			print("💾 Salva e esci")
			if current_deck_data:
				_on_save_deck_pressed(current_deck_data)
			deck_modified = false
			_update_save_button_visibility()
			_exit_deck_edit_mode_or_leave()
			

		"discard":
			print("❌ Non salvare e esci")
			if original_deck_snapshot and current_deck_data:
				# 🔁 Ripristina i dati originali
				_restore_original_deck_state()
			deck_modified = false
			_update_save_button_visibility()
			_exit_deck_edit_mode_or_leave()

		_:
			print("↩️ Annulla — rimani nel deck editor")

func _restore_original_deck_state():
	if not original_deck_snapshot or not current_deck_data:
		return

	# 🔁 Ripristina tutti i campi
	current_deck_data.deck_name = original_deck_snapshot.deck_name
	current_deck_data.mana_slot_1 = original_deck_snapshot.mana_slot_1
	current_deck_data.mana_slot_2 = original_deck_snapshot.mana_slot_2
	current_deck_data.mana_slot_3 = original_deck_snapshot.mana_slot_3
	current_deck_data.mana_slot_4 = original_deck_snapshot.mana_slot_4
	current_deck_data.mana_slot_5 = original_deck_snapshot.mana_slot_5

	current_deck_data.cards = original_deck_snapshot.cards.duplicate(true)
	# ✅ Ripristina anche lo stato di validità
	current_deck_data.is_valid = original_deck_snapshot.is_valid
	deck_is_invalid_due_to_cards = not original_deck_snapshot.is_valid and deck_is_invalid_due_to_cards
	deck_is_invalid_due_to_rank = not original_deck_snapshot.is_valid and deck_is_invalid_due_to_rank
	deck_is_invalid = not current_deck_data.is_valid
	
	print("🔄 Deck ripristinato allo stato originale:", current_deck_data.deck_name)


func _exit_deck_edit_mode_or_leave():
	current_deck_data = null
	original_deck_snapshot = null
	deck_modified = false
	_update_save_button_visibility()

	# 🔹 Pulisci l'area deck visiva
	if deck_cards_area:
		for child in deck_cards_area.get_children():
			child.queue_free()

	if is_in_deck_edit_mode:
		is_in_deck_edit_mode = false
		
		mana_ordering_button.visible = false
		rank_ordering_button.visible = false
		mana_ordering_icon.visible = false
		rank_ordering_icon.visible = false
		rank_sprite_for_label.visible = false
		deck_size_sprite_for_label.visible = false
		
		save_deck_button.visible = false
		expand_deck_button.visible = false
		create_deck_button.visible = true
		back_button.text = "LEAVE"

		# 🔹 Nascondi tutte le label delle copie nella collezione
		_hide_all_collection_copy_labels()

		var vbox = $DeckListPanel/VBoxContainer
		if vbox.has_node("CurrentDeckHeader"):
			vbox.get_node("CurrentDeckHeader").queue_free()

		_load_existing_decks()
		print("🔙 Uscita da modalità deck editing.")
	else:
		is_in_deck_edit_mode = false
		back_button.text = "LEAVE"
		_hide_all_collection_copy_labels()  # 👈 anche qui, nel caso venga chiamata direttamente
		print("🔙 Torno al menu principale...")
		get_tree().change_scene_to_file("res://Scene/main_menu.tscn")

	_apply_default_filter()  # 👈 ripristina vista collezione standard
# ----------------------------------------------------------
# 🔥 Filtro iniziale: ordina per attributo
# ----------------------------------------------------------
func _apply_default_filter():
	current_filter_mode = "Attribute"
	pages_data.clear()
	filtered_card_paths.clear()

	var attribute_order = ["Fire", "Wind", "Water", "Earth"]

	# 🔸 Raggruppa le carte per attributo
	var grouped_by_attr: Dictionary = {}
	for attr in attribute_order:
		grouped_by_attr[attr] = []

	for path in all_card_paths:
		var card_data: CardData = load(path)
		if card_data and grouped_by_attr.has(card_data.card_attribute):
			grouped_by_attr[card_data.card_attribute].append(card_data)

	# 🔹 Ordina ogni gruppo per costo (totale e colorato)
	for attr in attribute_order:
		if not grouped_by_attr.has(attr):
			continue

		var cards_for_attr: Array = grouped_by_attr[attr]
		if cards_for_attr.is_empty():
			continue

		cards_for_attr.sort_custom(func(a: CardData, b: CardData) -> bool:
			var total_a = a.get_mana_cost()
			var total_b = b.get_mana_cost()

			if total_a != total_b:
				return total_a < total_b  # Ordine per costo totale

			# 🔍 Se costo totale uguale → conta mana colorato
			var color_count_a = 0
			var color_count_b = 0
			for m in a.get_mana_cost_array():
				if m != "Colorless":
					color_count_a += 1
			for m in b.get_mana_cost_array():
				if m != "Colorless":
					color_count_b += 1
			# Prima chi ha meno mana colorato
			return color_count_a < color_count_b
		)

		## 🧩 DEBUG — mostra l’ordine finale per l’attributo
		#print("\n=== 🔥 Carte ordinate per attributo:", attr, " ===")
		#for card in cards_for_attr:
			#var mana_array = card.get_mana_cost_array()
			#var total_cost = mana_array.size()
			#var color_cost = mana_array.filter(func(x): return x != "Colorless").size()
			#print(card.card_name, "→ totale:", total_cost, " colorati:", color_cost)
		#print("───────────────────────────────\n")

		# 🔹 Ora dividiamo il gruppo ordinato in pagine da 18 carte
		for i in range(0, cards_for_attr.size(), cards_per_page):
			var page_cards = []
			for j in range(i, min(i + cards_per_page, cards_for_attr.size())):
				page_cards.append(cards_for_attr[j].resource_path)

			pages_data.append({
				"group_id": attr, # ✅ identifica il gruppo/filtro
				"cards": page_cards
			})

	# 🔸 Calcola numero totale di pagine e mostra la prima
	total_pages = pages_data.size()
	current_page = 0
	_show_page(0)
	_update_page_buttons()
	_update_page_label()
	_highlight_current_attribute()
	



	
# ----------------------------------------------------------
# 🔄 Aggiorna la griglia in base alle carte filtrate
# ----------------------------------------------------------
func _refresh_cards_display():
	for child in card_area.get_children():
		child.queue_free()

	for i in range(filtered_card_paths.size()):
		var card_data: CardData = load(filtered_card_paths[i])
		if not card_data:
			continue

		var card_instance = card_scene.instantiate()
		card_instance.card_data = card_data
		card_instance.scale = Vector2(card_scale, card_scale)
		card_area.add_child(card_instance)

		# 🧮 Calcolo colonna, riga e pagina
		var index = i
		var col = index % columns
		var row = (index / columns) % max_rows
		var page = index / cards_per_page

		# Ogni gruppo di 18 crea una nuova "pagina visiva"
		var page_offset_y = page * (max_rows * spacing_y + 200)
		card_instance.position = start_offset + Vector2(col * spacing_x, row * spacing_y)

		card_instance.visible = (page == 0)

	total_pages = int(ceil(float(filtered_card_paths.size()) / float(cards_per_page)))
	current_page = 0
	_update_page_buttons()
	_update_page_label()
	_highlight_current_attribute()


func _update_page_label():
	if pages_data.is_empty():
		page_label.clear()
		page_label.append_text("0/0")
		return

	var current_group = pages_data[current_page].get("group_id", "Unknown")

	# Filtra tutte le pagine appartenenti a questo gruppo
	var group_pages = pages_data.filter(func(p): return p.get("group_id", "") == current_group)

	# Trova l'indice della pagina corrente dentro al gruppo
	var group_page_index := 0
	for i in range(group_pages.size()):
		if group_pages[i] == pages_data[current_page]:
			group_page_index = i
			break

	# Aggiorna la label nel formato 1/2 ecc.
	page_label.clear()
	page_label.append_text(str(group_page_index + 1) + "/" + str(group_pages.size()))


func _highlight_current_attribute():
	if pages_data.is_empty():
		return

	var current_group = pages_data[current_page].get("group_id", "")

	for attr in attribute_buttons.keys():
		var button: TextureButton = attribute_buttons[attr]
		var is_active = (attr == current_group)

		# 🔹 Salva la posizione base la prima volta
		if not button.has_meta("base_position"):
			button.set_meta("base_position", button.position)

		var base_pos: Vector2 = button.get_meta("base_position")
		var target_pos = base_pos + Vector2(0, -20) if is_active else base_pos
		var target_color = Color(1, 1, 1, 1) if is_active else Color(0.5, 0.5, 0.5, 0.6)

		# 🧹 Ferma eventuale tween precedente
		if button.has_meta("active_tween"):
			var old_tween = button.get_meta("active_tween")
			if old_tween:
				old_tween.kill()

		# ✨ Crea nuovo tween per il movimento + colore
		var tween = create_tween()
		button.set_meta("active_tween", tween)

		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)

		tween.parallel().tween_property(button, "position", target_pos, 0.3)
		tween.parallel().tween_property(button, "modulate", target_color, 0.3)





			
func _on_attribute_button_pressed(attr: String):
	if pages_data.is_empty():
		return

	# Cerca la prima pagina di quel gruppo
	for i in range(pages_data.size()):
		if pages_data[i].get("group_id", "") == attr:
			_show_page(i)
			return



func _on_search_bar_submitted(text: String):
	text = text.strip_edges()
	if text.is_empty():
		# se barra vuota → torna alla vista standard
		_apply_default_filter()
	else:
		_apply_search_filter(text)
		
func _apply_search_filter(search_text: String):
	current_filter_mode = "Search"
	pages_data.clear()

	var deck_mana_counts := {}
	var deck_edit_mode := is_in_deck_edit_mode and current_deck_data != null

	# 🔹 Se siamo in deck edit mode → calcola i limiti di mana del deck
	if deck_edit_mode:
		deck_mana_counts = {
			"Fire": 0,
			"Wind": 0,
			"Water": 0,
			"Earth": 0
		}
		for mana_type in current_deck_data.get_mana_slots():
			if deck_mana_counts.has(mana_type):
				deck_mana_counts[mana_type] += 1

	var attribute_order = ["Fire", "Wind", "Water", "Earth"]
	var grouped_by_attr: Dictionary = {}
	for attr in attribute_order:
		grouped_by_attr[attr] = []

	search_text = search_text.to_lower()

	for path in all_card_paths:
		var card_data: CardData = load(path)
		if not card_data:
			continue

		# 🔎 Filtra testualmente
		var all_texts = [
			card_data.card_name,
			card_data.tooltip_name,
			card_data.card_attribute,
			card_data.card_type,
			card_data.creature_race,
			card_data.creature_race_2,
			card_data.card_class,
			card_data.card_class_2,
			card_data.talent_1,
			card_data.talent_2,
			card_data.talent_3,
			card_data.talent_4,
			card_data.talent_5,
			card_data.custom_effect_name,
			card_data.effect_1,
			card_data.effect_2,
			card_data.effect_3,
			card_data.effect_4
		]

		var match_found := false
		for t in all_texts:
			if str(t).to_lower().find(search_text) != -1:
				match_found = true
				break

		if not match_found:
			continue

		# 🔸 Se siamo in deck edit mode → applica ANCHE il vincolo di mana
		if deck_edit_mode:
			var mana_array := card_data.get_mana_cost_array()
			if not _card_respects_mana_limits(mana_array, deck_mana_counts):
				continue

		# ✅ Aggiungi la carta solo se supera tutti i filtri
		if grouped_by_attr.has(card_data.card_attribute):
			grouped_by_attr[card_data.card_attribute].append(card_data)

	# 🔹 Ordinamento e impaginazione come prima
	for attr in attribute_order:
		var cards_for_attr: Array = grouped_by_attr[attr]
		if cards_for_attr.is_empty():
			continue

		cards_for_attr.sort_custom(func(a: CardData, b: CardData) -> bool:
			var total_a = a.get_mana_cost()
			var total_b = b.get_mana_cost()
			if total_a != total_b:
				return total_a < total_b
			var color_count_a = a.get_mana_cost_array().filter(func(x): return x != "Colorless").size()
			var color_count_b = b.get_mana_cost_array().filter(func(x): return x != "Colorless").size()
			return color_count_a < color_count_b
		)

		for i in range(0, cards_for_attr.size(), cards_per_page):
			var page_cards = []
			for j in range(i, min(i + cards_per_page, cards_for_attr.size())):
				page_cards.append(cards_for_attr[j].resource_path)
			pages_data.append({
				"group_id": attr,
				"cards": page_cards
			})

	total_pages = pages_data.size()
	current_page = 0
	if total_pages > 0:
		_show_page(0)
	else:
		for c in card_area.get_children():
			c.queue_free()
		page_label.text = "0/0"

	_update_page_buttons()
	_update_page_label()
	_highlight_current_attribute()


# ----------------------------------------------------------
# ⌨️ Ricerca live
# ----------------------------------------------------------
func _on_search_bar_text_changed(new_text: String):
	# 🔹 Se la barra è vuota → torna alla visualizzazione standard
	if new_text.strip_edges().is_empty():
		_apply_default_filter()


func _preload_all_cards():
	card_cache.clear()
	card_instances_by_attr.clear()
	
	for path in all_card_paths:
		var data: CardData = load(path)
		if not data:
			continue
		card_cache[path] = data

		# istanzia subito la carta e la nasconde
		var card_instance = card_scene.instantiate()
		card_instance.card_data = data
		card_instance.scale = Vector2(card_scale, card_scale)
		card_instance.visible = false
		card_area.add_child(card_instance)

		var attr = data.card_attribute
		if not card_instances_by_attr.has(attr):
			card_instances_by_attr[attr] = []
		card_instances_by_attr[attr].append(card_instance)







func _load_existing_decks():
	# 🧹 Pulisce la lista precedente
	for child in deck_buttons_container.get_children():
		child.queue_free()

	deck_buttons_container = VBoxContainer.new()
	$DeckListPanel/VBoxContainer.add_child(deck_buttons_container, true)

	var deck_folder := "res://DeckResources"
	var dir := DirAccess.open(deck_folder)
	if not dir:
		print("⚠️ Nessuna cartella deck trovata:", deck_folder)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var deck_data: DeckData = load(deck_folder + "/" + file_name)
			if deck_data:
				# ✅ Controlla subito se il deck è invalido per rank > 100
				#_check_total_rank_validity(deck_data)
				# 🔹 Contenitore orizzontale per bottone + X
				var hbox = HBoxContainer.new()
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.custom_minimum_size = Vector2(0, 80)
				hbox.add_theme_constant_override("separation", 8)

				# 🔹 Bottone principale deck
				var deck_button = Button.new()
				deck_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				deck_button.custom_minimum_size = Vector2(0, 80)
				deck_button.focus_mode = Control.FOCUS_NONE
				deck_button.connect("pressed", func(): _on_deck_selected(deck_data))

				# Contenuto del deck button (nome + mana)
				var margin_container = MarginContainer.new()
				margin_container.add_theme_constant_override("margin_left", 12)
				margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				var vbox = VBoxContainer.new()
				vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
				vbox.add_theme_constant_override("separation", 4)

				var name_label = Label.new()
				name_label.text = deck_data.deck_name
				name_label.modulate = Color(1, 0.3, 0.3) if not deck_data.is_valid else Color(1, 1, 1)
				name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				name_label.add_theme_font_size_override("font_size", 20)
				vbox.add_child(name_label)

				var mana_hbox = HBoxContainer.new()
				mana_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
				mana_hbox.add_theme_constant_override("separation", 6)

				var mana_textures = {
					"Fire": preload("res://Assets/Mana/Fuoco.png"),
					"Wind": preload("res://Assets/Mana/Vento.png"),
					"Water": preload("res://Assets/Mana/Acqua.png"),
					"Earth": preload("res://Assets/Mana/Terra.png")
				}


				for mana_type in deck_data.get_mana_slots():
					if mana_type == "":
						continue
					var icon = TextureRect.new()
					icon.texture = mana_textures.get(mana_type, null)
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon.ignore_texture_size = true
					icon.scale = Vector2(1, 1)
					icon.custom_minimum_size = Vector2(40, 40)
					icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 👈 non blocca il click
					mana_hbox.add_child(icon)
				
				vbox.add_child(mana_hbox)
				margin_container.add_child(vbox)
				deck_button.add_child(margin_container)

				# 🔴 Bottone X per eliminare deck
				var delete_button = Button.new()
				delete_button.text = "❌"
				delete_button.custom_minimum_size = Vector2(60, 60)
				delete_button.focus_mode = Control.FOCUS_NONE
				delete_button.modulate = Color(1, 0.3, 0.3) # rosso tenue
				delete_button.connect("pressed", func():
					_on_delete_deck_pressed(deck_folder + "/" + file_name, deck_data.deck_name)
				)

				# ➕ Aggiungi entrambi all’HBox
				hbox.add_child(deck_button)
				hbox.add_child(delete_button)
				deck_buttons_container.add_child(hbox)

		file_name = dir.get_next()

	dir.list_dir_end()


func _on_delete_deck_pressed(deck_path: String, deck_name: String = ""):
	if not delete_popup:
		push_error("⚠️ DeleteDeckPopup mancante nella scena!")
		return

	# Aggiorna testo dinamicamente
	delete_popup.dialog_text = "Are you sure you want to delete this deck: '%s'?" % deck_name

	# 🔹 Rimuovi eventuali connessioni vecchie per evitare duplicazioni
	if delete_popup.confirmed.is_connected(_on_delete_deck_confirmed):
		delete_popup.confirmed.disconnect(_on_delete_deck_confirmed)

	# Collega il segnale
	delete_popup.confirmed.connect(func(): _on_delete_deck_confirmed(deck_path, deck_name))

	# Mostra popup
	delete_popup.popup_centered()



func _on_delete_deck_confirmed(deck_path: String, deck_name: String):
	var dir := DirAccess.open("res://DeckResources")
	if dir and dir.file_exists(deck_path):
		var err = dir.remove(deck_path)
		if err == OK:
			print("🗑️ Mazzo eliminato:", deck_name)

			# 🔹 Trova l'HBox corrispondente nella lista
			var hbox_to_remove: HBoxContainer = null
			for child in deck_buttons_container.get_children():
				for sub in child.get_children():
					if sub is Button and sub.get_child_count() > 0:
						var margin = sub.get_child(0)
						if margin and margin.get_child_count() > 0:
							var vbox = margin.get_child(0)
							if vbox and vbox.get_child_count() > 0:
								var name_label = vbox.get_child(0)
								if name_label is Label and name_label.text == deck_name:
									hbox_to_remove = child
									break
				if hbox_to_remove:
					break

			if hbox_to_remove:
				var index_to_remove = deck_buttons_container.get_children().find(hbox_to_remove)
				hbox_to_remove.queue_free()
				await get_tree().process_frame  # ⏳ aspetta aggiornamento UI

				# 🔹 Sposta i successivi verso l’alto con un tween
				for i in range(index_to_remove, deck_buttons_container.get_child_count()):
					var node = deck_buttons_container.get_child(i)
					var target_y = node.position.y - 84  # 80 altezza + 4 separazione

					# evita di andare sotto lo 0
					if target_y < 0:
						target_y = 0

					var tween = create_tween()
					tween.tween_property(node, "position:y", target_y, 0.25)\
						.set_trans(Tween.TRANS_SINE)\
						.set_ease(Tween.EASE_OUT)

			else:
				print("⚠️ Nessun nodo deck trovato per", deck_name)

		else:
			push_error("❌ Errore durante l'eliminazione di: " + deck_path)
	else:
		push_warning("⚠️ Deck file non trovato: " + deck_path)




func _on_deck_selected(deck_data: DeckData):
	print("🃏 Selezionato deck:", deck_data.deck_name)
	_enter_deck_edit_mode(deck_data)
	



# ----------------------------------------------------------
# 🆕 Creazione nuovo deck
# ----------------------------------------------------------
func _on_create_deck_pressed():
	create_deck_button.release_focus()
	deck_name_input.text = ""

	# 🔹 Pulisci TUTTI gli slot mana prima di mostrare il popup
	var slot_container = $DeckCreationPopup/MarginContainer/VBoxContainer/ManaSlotContainer
	for slot in slot_container.get_children():
		if slot.has_method("clear_slot"):
			slot.clear_slot()

	# 🔹 Mostra popup pulito
	deck_creation_popup.title = "Create New Deck"
	deck_creation_popup.popup_centered()





func _on_deck_creation_confirmed():
	var deck_name = deck_name_input.text.strip_edges()
	if deck_name.is_empty():
		print("⚠️ Nome mazzo non valido.")
		# Puoi anche mostrare un popup di errore se vuoi
		return

	# 🔹 Leggi i 5 slot nel popup
	var mana_slots := []
	var slot_container = $DeckCreationPopup/MarginContainer/VBoxContainer/ManaSlotContainer

	for slot in slot_container.get_children():
		if slot.has_method("clear_slot"):
			if slot.filled:
				mana_slots.append(slot.current_mana_type)
			else:
				mana_slots.append("")  # slot vuoto

	# Verifica che tutti siano riempiti
	if mana_slots.any(func(x): return x == ""):
		print("⚠️ Devi riempire tutti e 5 gli slot mana prima di confermare.")
		return

	# Se arriviamo qui → nome e slot OK ✅
	print("✅ Tutti i requisiti soddisfatti, creo il deck:", deck_name)
	
	var new_deck = DeckData.new()
	new_deck.deck_name = deck_name
	new_deck.mana_slot_1 = mana_slots[0]
	new_deck.mana_slot_2 = mana_slots[1]
	new_deck.mana_slot_3 = mana_slots[2]
	new_deck.mana_slot_4 = mana_slots[3]
	new_deck.mana_slot_5 = mana_slots[4]

	var save_dir = "res://DeckResources"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	var save_path = save_dir + "/" + deck_name + ".tres"
	var result = ResourceSaver.save(new_deck, save_path)
	if result == OK:
		print("💾 Salvato nuovo deck:", save_path)
		_enter_deck_edit_mode(new_deck)
	else:
		push_error("❌ Errore nel salvataggio del deck in " + save_path)

	# ✅ Reset del popup dopo la conferma
	deck_creation_popup.title = "Create New Deck"
	deck_name_input.text = ""

	for slot in slot_container.get_children():
		if slot.has_method("clear_slot"):
			slot.clear_slot()

func _enter_deck_edit_mode(deck_data: DeckData):
	print("🧱 Entrata in modalità creazione/edizione mazzo:", deck_data.deck_name)
	_clear_search_bar()  # 👈 svuota la barra di ricerca quando entri nel deck
	
	# 🔹 Carica lo stato di ordinamento salvato
	mana_order_state = deck_data.mana_sort_state
	rank_order_state = deck_data.rank_sort_state

	# 🔹 Aggiorna le icone visive
	_update_ordering_icon(mana_order_state, mana_ordering_icon)
	_update_ordering_icon(rank_order_state, rank_ordering_icon)

	# 🔹 Applica subito l’ordinamento se non è "none"
	if mana_order_state != "none" or rank_order_state != "none":
		_apply_deck_sorting()
	
	current_deck_data = deck_data
	original_deck_snapshot = _clone_deck_data(deck_data)  # 👈 salviamo l'originale
	is_in_deck_edit_mode = true
	create_deck_button.visible = false
	expand_deck_button.visible = true
	# 🔹 Rendi visibili i bottoni di ordinamento

	mana_ordering_button.visible = true
	rank_ordering_button.visible = true
	mana_ordering_icon.visible = true
	rank_ordering_icon.visible = true
	rank_sprite_for_label.visible = true
	deck_size_sprite_for_label.visible = true
	for child in deck_buttons_container.get_children():
		child.queue_free()


	# 🆕 --- HEADER COMPLETO CON NOME + MANA + INFO ---
	var header = Panel.new()
	header.name = "CurrentDeckHeader"
	header.custom_minimum_size = Vector2(0, 120)
	header.add_theme_color_override("panel", Color(0.15, 0.15, 0.15, 0.8))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
# 🆕 Sempre in primo piano
	header.z_index = 150
	# 🔹 VBox principale dentro l’header
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 4)

	# =========================================================
	# BLOCCO CLICCABILE (Nome + Mana)
	# =========================================================
	var clickable_vbox = VBoxContainer.new()
	clickable_vbox.name = "ClickableBlock"
	clickable_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Nome del deck
	var name_label = Label.new()
	name_label.name = "DeckNameLabel"  # 👈 aggiungi questo
	name_label.text = deck_data.deck_name
	name_label.modulate = Color(1, 0.3, 0.3) if not deck_data.is_valid else Color(1, 1, 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	clickable_vbox.add_child(name_label)

	# Riga mana (icone)
	var mana_hbox = HBoxContainer.new()
	mana_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mana_hbox.add_theme_constant_override("separation", 8)

	var mana_textures = {
		"Fire": preload("res://Assets/Mana/Fuoco.png"),
		"Wind": preload("res://Assets/Mana/Vento.png"),
		"Water": preload("res://Assets/Mana/Acqua.png"),
		"Earth": preload("res://Assets/Mana/Terra.png")
	}

	for mana_type in deck_data.get_mana_slots():
		if mana_type == "":
			continue
		var icon = TextureRect.new()
		icon.texture = mana_textures.get(mana_type, null)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.ignore_texture_size = true
		icon.custom_minimum_size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mana_hbox.add_child(icon)

	clickable_vbox.add_child(mana_hbox)

	# 👇 click solo su questo blocco
	clickable_vbox.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_edit_deck_header_clicked(deck_data)
	)

	main_vbox.add_child(clickable_vbox)

	# =========================================================
	# BLOCCO INFO (sotto la mana config)
	# =========================================================
	var info_hbox = HBoxContainer.new()
	info_hbox.name = "InfoBlock"
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_theme_constant_override("separation", 30)

	# =========================================================
	# BLOCCO CONTEGGIO CARTE (X + /40 separati)
	# =========================================================
	var card_count_hbox = HBoxContainer.new()
	card_count_hbox.name = "CardCountHBox"
	card_count_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_count_hbox.add_theme_constant_override("separation", 0)

	var total_cards := deck_data.cards.size()

	# 🔹 Label X
	var card_count_value_label = Label.new()
	card_count_value_label.name = "CardCountValueLabel"
	card_count_value_label.text = str(total_cards)
	card_count_value_label.add_theme_font_size_override("font_size", 20)

	if total_cards != 40:
		card_count_value_label.modulate = Color(1, 0.3, 0.3)  # rosso se ≠ 40
	else:
		card_count_value_label.modulate = Color(0.8, 0.9, 1)  # blu chiaro standard

	# 🔹 Label /40
	var card_count_suffix_label = Label.new()
	card_count_suffix_label.name = "CardCountSuffixLabel"
	card_count_suffix_label.text = "/40"
	card_count_suffix_label.add_theme_font_size_override("font_size", 20)
	card_count_suffix_label.modulate = Color(0.8, 0.9, 1)

	# 🔹 Aggiungi entrambe all’HBox
	card_count_hbox.add_child(card_count_value_label)
	card_count_hbox.add_child(card_count_suffix_label)

	info_hbox.add_child(card_count_hbox)

	# 🔹 Calcola il totale del rank
	var total_rank := 0
	for card_data in deck_data.cards:
		if card_data and card_data.card_rank != null:
			total_rank += card_data.card_rank

	# 🔹 HBox per mettere i due pezzi affiancati
	var rank_hbox = HBoxContainer.new()
	rank_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rank_hbox.add_theme_constant_override("separation", 0)

	# 🔸 Label per la parte X
	var rank_value_label = Label.new()
	rank_value_label.name = "RankValueLabel"  # 👈 AGGIUNGI QUESTO
	rank_value_label.text = str(total_rank)
	rank_value_label.add_theme_font_size_override("font_size", 20)

	if total_rank > 100:
		rank_value_label.modulate = Color(1, 0.3, 0.3)  # rosso se sopra 100
	else:
		rank_value_label.modulate = Color(1.0, 0.894, 0.875, 1)  # rosa chiarissimo (#FFE4DF)

	# 🔸 Label per la parte /100
	var rank_suffix_label = Label.new()
	rank_suffix_label.name = "RankSuffixLabel"  # 👈 AGGIUNGI QUESTO
	rank_suffix_label.text = "/100"
	rank_suffix_label.add_theme_font_size_override("font_size", 20)
	rank_suffix_label.modulate = Color(1.0, 0.894, 0.875, 1)  # rosa chiarissimo (#FFE4DF)

	# 🔹 Aggiungi entrambe all’HBox
	rank_hbox.add_child(rank_value_label)
	rank_hbox.add_child(rank_suffix_label)

	info_hbox.add_child(rank_hbox)


	main_vbox.add_child(info_hbox)
	header.add_child(main_vbox)

	# Inserisci in alto nella colonna
	var deck_vbox = $DeckListPanel/VBoxContainer
	if not deck_vbox.has_node("CurrentDeckHeader"):
		deck_vbox.add_child(header)
		deck_vbox.move_child(header, 0)



	back_button.text = "Back"

	# ✅ Collega il bottone "Save" in modo sicuro con il parametro
	if save_deck_button.is_connected("pressed", Callable(self, "_on_save_deck_pressed")):
		save_deck_button.disconnect("pressed", Callable(self, "_on_save_deck_pressed"))

	save_deck_button.pressed.connect(func(): _on_save_deck_pressed(current_deck_data))

	print("📦 Pronto per aggiungere carte al mazzo:", deck_data.deck_name)
	_show_deck_cards(deck_data)
	_update_collection_copy_labels()
	# 🔹 Filtra la collezione in base ai mana del deck
	_apply_mana_constraint_filter(deck_data)
	await get_tree().process_frame  # ⏳ aspetta che i nodi DeckCardDisplay siano istanziati
	_check_invalid_cards_in_deck(deck_data)
	_check_total_rank_validity(deck_data)
	_update_deck_header_stats(deck_data)
	
func _on_edit_deck_header_clicked(deck_data: DeckData):
	print("✏️ Modifica deck:", deck_data.deck_name)

	# Popola i campi del popup esistente
	deck_name_input.text = deck_data.deck_name
	deck_creation_popup.title = "Edit Deck: " + deck_data.deck_name

	# Precompila gli slot mana con le texture correnti
	var mana_textures = {
		"Fire": preload("res://Assets/Mana/Fuoco.png"),
		"Wind": preload("res://Assets/Mana/Vento.png"),
		"Water": preload("res://Assets/Mana/Acqua.png"),
		"Earth": preload("res://Assets/Mana/Terra.png")
	}
	var slot_container = $DeckCreationPopup/MarginContainer/VBoxContainer/ManaSlotContainer
	var mana_slots = deck_data.get_mana_slots()

	for i in range(min(slot_container.get_child_count(), mana_slots.size())):
		var slot = slot_container.get_child(i)
		if slot.has_method("clear_slot"):
			slot.clear_slot()
		if mana_slots[i] != "":
			slot.mana_icon.texture = mana_textures.get(mana_slots[i])
			slot.current_mana_type = mana_slots[i]
			slot.filled = true
			slot.mana_icon.visible = true

	# Mostra il popup (ricicliamo lo stesso)
	deck_creation_popup.popup_centered()

	# ✅ Disconnetti prima eventuali segnali esistenti
	if deck_creation_popup.confirmed.is_connected(_on_deck_creation_confirmed):
		deck_creation_popup.confirmed.disconnect(_on_deck_creation_confirmed)

	if _deck_edit_connected:
		if deck_creation_popup.confirmed.is_connected(_on_deck_edit_confirmed):
			deck_creation_popup.confirmed.disconnect(_on_deck_edit_confirmed)
		_deck_edit_connected = false

	# ✅ Collega solo il segnale per la modifica
	deck_creation_popup.confirmed.connect(_on_deck_edit_confirmed.bind(deck_data))
	_deck_edit_connected = true

	# Mostra il popup
	deck_creation_popup.popup_centered()


func _on_deck_edit_confirmed(deck_data: DeckData):
	var new_name = deck_name_input.text.strip_edges()
	if new_name.is_empty():
		print("⚠️ Nome mazzo non valido.")
		return

	var slot_container = $DeckCreationPopup/MarginContainer/VBoxContainer/ManaSlotContainer
	var new_slots: Array[String] = []
	for slot in slot_container.get_children():
		if slot.filled:
			new_slots.append(slot.current_mana_type)
		else:
			new_slots.append("")

	if new_slots.any(func(x): return x == ""):
		print("⚠️ Tutti gli slot mana devono essere riempiti.")
		return

	# 🔍 Controlla se nome o slot mana sono cambiati
	var modified := false
	if new_name != deck_data.deck_name:
		modified = true
	else:
		var old_slots = deck_data.get_mana_slots()
		for i in range(old_slots.size()):
			if old_slots[i] != new_slots[i]:
				modified = true
				break

	if not modified:
		print("ℹ️ Nessuna modifica rilevata, nessun salvataggio necessario.")
		return

	# ✅ C'è una modifica → mostra bottone SAVE
	deck_modified = true
	print("💡 Modificato — attivato bottone SAVE")
	_update_save_button_visibility()

	# 🔹 Aggiorna i dati in memoria (ma NON salvare ancora!)
	var old_name = deck_data.deck_name
	deck_data.deck_name = new_name
	deck_data.mana_slot_1 = new_slots[0]
	deck_data.mana_slot_2 = new_slots[1]
	deck_data.mana_slot_3 = new_slots[2]
	deck_data.mana_slot_4 = new_slots[3]
	deck_data.mana_slot_5 = new_slots[4]

	# 🔁 Aggiorna interfaccia visiva (header, icone, ecc.)
	_update_deck_header_visual(deck_data)

	await get_tree().process_frame

	# ✅ Ripristina comportamento standard del popup
	if not deck_creation_popup.confirmed.is_connected(_on_deck_creation_confirmed):
		deck_creation_popup.confirmed.connect(_on_deck_creation_confirmed)

	# ✅ Reset popup
	deck_creation_popup.title = "Create New Deck"
	deck_name_input.text = ""
	for slot in slot_container.get_children():
		if slot.has_method("clear_slot"):
			slot.clear_slot()

	print("✏️ Modifiche applicate in memoria, in attesa di salvataggio manuale.")

	# 👇 se siamo in expand mode, aggiorna la vista espansa
	if showing_deck_view:
		refreshing_expand_view = true
		_on_expand_deck_pressed()
		refreshing_expand_view = false
	else:
		# altrimenti aggiorna il filtro classico per la collezione
		_apply_mana_constraint_filter(deck_data)

	_check_invalid_cards_in_deck(deck_data)


func _check_invalid_cards_in_deck(deck_data: DeckData):
	if not deck_data or not deck_cards_area:
		return

	print("🔍 Controllo carte non valide nel deck:", deck_data.deck_name)

	# Calcola i conteggi di mana disponibili nel deck
	var deck_mana_counts := {
		"Fire": 0,
		"Wind": 0,
		"Water": 0,
		"Earth": 0
	}
	for mana_type in deck_data.get_mana_slots():
		if deck_mana_counts.has(mana_type):
			deck_mana_counts[mana_type] += 1

	var has_invalid_cards := false

	# 🔹 Controlla ogni carta nel pannello deck
	for card_display in deck_cards_area.get_children():
		if not (card_display is DeckCardDisplay):
			continue

		var card_data: CardData = card_display.card_data
		if not card_data:
			continue

		var mana_array := card_data.get_mana_cost_array()
		var respects := _card_respects_mana_limits(mana_array, deck_mana_counts)

		card_display.mark_as_invalid(not respects)

		if not respects:
			has_invalid_cards = true
			print("❌ Carta invalida:", card_data.card_name)

	deck_is_invalid_due_to_cards = has_invalid_cards

	# 🔹 Aggiorna stato complessivo
	deck_data.is_valid = not (deck_is_invalid_due_to_rank or deck_is_invalid_due_to_cards or deck_is_invalid_due_to_count)
	deck_is_invalid = not deck_data.is_valid

	_update_deck_validity_visual(deck_data, not deck_data.is_valid)

	# 🔹 Salva subito la proprietà nel file del deck
	var save_path = "res://DeckResources/" + deck_data.deck_name + ".tres"
	var dir := DirAccess.open("res://DeckResources")
	if dir and dir.file_exists(save_path.get_file()):
		var result = ResourceSaver.save(deck_data, save_path)
		if result == OK:
			print("💾 Stato validità salvato per deck:", deck_data.deck_name, "→", deck_data.is_valid)
		else:
			push_warning("⚠️ Impossibile salvare stato validità per " + deck_data.deck_name)
	else:
		print("⚠️ File deck non trovato, creazione nuovo:", save_path)
		var result = ResourceSaver.save(deck_data, save_path)





func _update_deck_validity_visual(deck_data: DeckData, is_invalid: bool):
	# 🔴 Aggiorna l’header del deck corrente
	var vbox = $DeckListPanel/VBoxContainer
	var header: Panel = vbox.get_node_or_null("CurrentDeckHeader")
	if header:
		# Cerca la label del nome anche se è annidata (ricorsivo)
		var name_label := header.find_child("DeckNameLabel", true, false)
		if name_label:
			name_label.modulate = Color(1, 0.3, 0.3) if is_invalid else Color(1, 1, 1)
	
	# 🔴 Aggiorna anche la lista dei deck nella colonna di selezione
	for hbox in deck_buttons_container.get_children():
		for sub in hbox.get_children():
			if sub is Button:
				var margin = sub.get_child(0)
				if margin and margin.get_child_count() > 0:
					var vbox2 = margin.get_child(0)
					if vbox2 and vbox2.get_child_count() > 0:
						var name_label = vbox2.get_child(0)
						if name_label is Label and name_label.text == deck_data.deck_name:
							name_label.modulate = Color(1, 0.3, 0.3) if is_invalid else Color(1, 1, 1)




	
func _on_save_deck_pressed(deck_data: DeckData):
	save_deck_button.release_focus()

	
	if not current_deck_data:
		push_warning("⚠️ Nessun deck selezionato per il salvataggio.")
		return

	var save_dir = "res://DeckResources"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	# ✅ 1️⃣ Prima di salvare → esegui il check di validità
	_check_invalid_cards_in_deck(deck_data)
	_check_total_rank_validity(current_deck_data)
	print("💾 Salvataggio mazzo:", deck_data.deck_name)
	print("💡 Stato finale validità:",
		" rank_invalid =", deck_is_invalid_due_to_rank,
		" cards_invalid =", deck_is_invalid_due_to_cards,
		" count_invalid =", deck_is_invalid_due_to_count,
		" → deck valido =", deck_data.is_valid)
		
	if not deck_data.is_valid:
		push_warning("⚠️ Attenzione: il deck contiene carte non valide!")
	else:
		print("✅ Deck valido — nessuna carta invalida trovata.")

	# 🔹 Rimuovi eventuale file vecchio se il nome è cambiato
	if original_deck_snapshot and original_deck_snapshot.deck_name != deck_data.deck_name:
		var old_path = save_dir + "/" + original_deck_snapshot.deck_name + ".tres"
		var dir := DirAccess.open(save_dir)
		if dir and dir.file_exists(old_path):
			var err = dir.remove(old_path)
			if err == OK:
				print("🗑️ Rimosso vecchio file del deck:", old_path)
			else:
				push_warning("⚠️ Impossibile rimuovere il vecchio file:", old_path)

	# 💾 Salva sempre (anche se invalido, così il flag resta aggiornato)
	var new_path = save_dir + "/" + deck_data.deck_name + ".tres"
	var result = ResourceSaver.save(deck_data, new_path)
	if result == OK:
		deck_modified = false
		_update_save_button_visibility()
		print("✅ Mazzo salvato correttamente:", new_path, "→ valido:", deck_data.is_valid)
	else:
		push_error("❌ Errore nel salvataggio del mazzo in " + new_path)


func add_card_to_current_deck(card_data: CardData):
	if not is_in_deck_edit_mode or not current_deck_data:
		print("⚠️ Tentativo di aggiungere carta fuori da deck editor.")
		return
	
	var was_new_card := false  # 👈 dichiarata qui
	# 🔎 Conta quante copie di questa carta esistono già nel deck
	var existing_copies := 0
	for c in current_deck_data.cards:
		if c == card_data:
			existing_copies += 1

	# 🚫 Se hai già 3 copie, blocca l'aggiunta e mostra feedback visivo
	if existing_copies >= 3:
		print("⛔ Hai già 3 copie di:", card_data.card_name)
		var card_display = _get_card_display_by_data(card_data)
		if card_display:
			card_display._show_max_copies_feedback()  # 👈 nuova funzione che aggiungi in card_display.gd
		return

	var existing_node: Node2D = null
	for c in deck_cards_area.get_children():
		if c.card_data == card_data:
			existing_node = c
			break

	# 💫 Avvia subito animazione del trasferimento (se disponibile)
	var card_display = _get_card_display_by_data(card_data)
	if card_display and has_method("animate_card_transfer"):
		animate_card_transfer(card_display, card_data)

	# Aggiungi subito nei dati (logica)
	current_deck_data.cards.append(card_data)
	deck_modified = true
	_update_save_button_visibility()

	# Ora differenziamo comportamento dopo un piccolo delay
	await get_tree().create_timer(0.3).timeout  # ⏳ aspetta fine animazione TEMPO DELAY PARI AL TEMPO ANIM

	if existing_node:
		# carta già presente → non è nuova
		existing_node.increment_copy_count()
		existing_node.pulse_highlight()
		was_new_card = false
	else:
		# carta nuova → prima copia
		_add_card_to_deck_panel(card_data)
		var new_node := deck_cards_area.get_child(deck_cards_area.get_child_count() - 1)
		if new_node and new_node.has_method("pulse_highlight"):
			new_node.pulse_highlight()
		was_new_card = true
			
	# 🔹 Aggiorna SOLO l’etichetta della carta aggiunta
	if card_display and card_display.card_data:
		var path = card_display.card_data.resource_path
		if current_deck_data:
			# Conta quante copie di quella carta sono ora nel deck
			var copies := 0
			for c in current_deck_data.cards:
				if c and c.resource_path == path:
					copies += 1
			# Aggiorna solo quella label
			card_display.update_deck_copy_count(copies)
			card_display._pulse_copy_label()
	
	await get_tree().process_frame
	_check_total_rank_validity(current_deck_data)
	_update_deck_header_stats(current_deck_data)
	
	# 🔄 Se c'è un ordinamento attivo, riapplica subito dopo l'aggiunta
	if was_new_card and (mana_order_state != "none" or rank_order_state != "none"):
		print("🔃 Ordinamento attivo — riapplico sorting dopo aggiunta")
		_apply_deck_sorting(true)
	


	
#func add_card_to_current_deck(card_data: CardData):
	#if not is_in_deck_edit_mode or not current_deck_data:
		#print("⚠️ Tentativo di aggiungere carta fuori da deck editor.")
		#return
#
	#var existing_node: Node2D = null
	#for c in deck_cards_area.get_children():
		#if c.card_data == card_data:
			#existing_node = c
			#break
#
	#if existing_node:
		#current_deck_data.cards.append(card_data)
		#existing_node.increment_copy_count()
		#existing_node.pulse_highlight()
	#else:
		#current_deck_data.cards.append(card_data)
		#_add_card_to_deck_panel(card_data)
#
	#deck_modified = true
	#_update_save_button_visibility()
	#_update_collection_copy_labels()
#
	## 👇 Pulse SOLO sulla carta cliccata nella collezione
	#var card_display = _get_card_display_by_data(card_data)
	#if card_display:
		#card_display._pulse_copy_label()


func _add_card_to_deck_panel(card_data: CardData):
	# Usa la scena semplificata per il deck editor
	var card_instance = deck_card_scene.instantiate()
	card_instance.card_data = card_data
	#card_instance.scale = Vector2(0.42, 0.42)
	card_instance.visible = true
	card_instance.update_display()

	# Calcola la posizione (lista verticale)
	var index = deck_cards_area.get_child_count()
	var spacing_y = 30
	var start_pos = DECK_PANEL_START_POS
	card_instance.position = start_pos + Vector2(0, index * spacing_y)

	deck_cards_area.add_child(card_instance)
	_update_scroll_state()
	print("🧩 Carta aggiunta al deck panel:", card_data.card_name, "→ posizione:", card_instance.position)


func remove_card_from_current_deck(card_data: CardData):
	if not is_in_deck_edit_mode or not current_deck_data:
		print("⚠️ Tentativo di rimuovere carta fuori da deck editor.")
		return

	# 🔹 Trova il nodo visivo corrispondente
	var target_node: Node2D = null
	var removed_index_panel := -1
	for i in range(deck_cards_area.get_child_count()):
		var card_node = deck_cards_area.get_child(i)
		if card_node.card_data == card_data:
			target_node = card_node
			removed_index_panel = i
			break

	if not target_node:
		print("⚠️ Nodo visivo non trovato per:", card_data.card_name)
		return

	# 🔹 Se ha più copie → riduci solo la label e rimuovi UNA copia dai dati
	if target_node.has_method("decrement_copy_count_and_update") and target_node.copy_count > 1:
		target_node.decrement_copy_count_and_update()
		if card_data in current_deck_data.cards:
			current_deck_data.cards.erase(card_data)
		print("🔻 Ridotta copia per:", card_data.card_name, "→", target_node.copy_count)
		deck_modified = true
		_update_save_button_visibility()
		_update_collection_copy_labels()  # 👈 AGGIUNGI QUESTO
		_update_deck_header_stats(current_deck_data)
		var card_display = _get_card_display_by_data(card_data)
		if card_display:
			card_display._pulse_copy_label()
		return

	# 🔹 Se è l’ultima copia → rimuovi completamente con animazione
	if card_data in current_deck_data.cards:
		current_deck_data.cards.erase(card_data)

	print("🗑️ Ultima copia rimossa con animazione:", card_data.card_name)

	# 🧊 Chiudi subito la card preview se visibile
	var preview_manager = get_node_or_null("/root/Collection/CardPreviewManager")
	if preview_manager:
		preview_manager.hide_preview()

	_update_collection_copy_labels()
	_update_deck_header_stats(current_deck_data)
	# 🎬 ANIMAZIONE "vola via e svanisce"
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target_node, "position:x", target_node.position.x - 140, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_node, "modulate:a", 0.0, 0.2)

	tween.finished.connect(func ():
		if is_instance_valid(target_node):
			target_node.queue_free()
			await get_tree().process_frame
			_reposition_deck_cards_from(removed_index_panel)
			deck_modified = true
			_update_save_button_visibility()
	)

	await tween.finished
	# 🔁 Se siamo in modalità "expand deck", ricarica la vista aggiornata
	if showing_deck_view:
		refreshing_expand_view = true
		_on_expand_deck_pressed()  # 🔁 forza refresh
		refreshing_expand_view = false
		
	# 🕒 Attendi un frame per garantire che il nodo sia effettivamente freed
	await get_tree().process_frame
	
	_check_total_rank_validity(current_deck_data)
	_check_invalid_cards_in_deck(current_deck_data)
	_update_scroll_state()


func remove_card_from_deck_panel(card_display_node: Node2D):
	if card_display_node and card_display_node.card_data:
		remove_card_from_current_deck(card_display_node.card_data)

# 🔹 Riposiziona SOLO le carte dopo un certo indice
func _reposition_deck_cards_from(start_index: int):
	var spacing_y = 30
	var start_pos = DECK_PANEL_START_POS
	for i in range(start_index, deck_cards_area.get_child_count()):
		var card_node = deck_cards_area.get_child(i)
		var new_pos = start_pos + Vector2(0, i * spacing_y)
		var tween = create_tween()
		tween.tween_property(card_node, "position", new_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ----------------------------------------------------------
# 🎴 Mostra le carte di un deck selezionato nell'area deck
# ----------------------------------------------------------
func _show_deck_cards(deck_data: DeckData):
	if not deck_cards_area:
		return

	# 🧹 Pulisci prima l'area deck
	for child in deck_cards_area.get_children():
		child.queue_free()

	await get_tree().process_frame  # ✅ aspetta la rimozione effettiva dei nodi

	# Ora l'area è veramente vuota → get_child_count() = 0
	# 🔹 Raggruppa le carte per tipo
	var card_counts: Dictionary = {}
	for card_data in deck_data.cards:
		if not card_data:
			continue
		if card_counts.has(card_data):
			card_counts[card_data] += 1
		else:
			card_counts[card_data] = 1

	# 🔁 Istanzia una sola carta per tipo e imposta la label ×N
	for card_data in card_counts.keys():
		_add_card_to_deck_panel(card_data)

		var last_card_node: Node2D = deck_cards_area.get_child(deck_cards_area.get_child_count() - 1)
		if last_card_node and last_card_node is DeckCardDisplay:
			last_card_node.copy_count = card_counts[card_data]
			last_card_node._update_count_label()

	print("📋 Caricate", deck_data.cards.size(), "carte totali (",
		card_counts.size(), " tipi unici ) per il deck:", deck_data.deck_name)

	# ✅ Dopo aver mostrato le carte, aggiorna subito i banner di invalidità
	if is_in_deck_edit_mode and deck_data == current_deck_data:
		_check_invalid_cards_in_deck(deck_data)




func _update_save_button_visibility():
	if not save_deck_button:
		return
	save_deck_button.visible = deck_modified


func _update_deck_header_visual(deck_data: DeckData):
	var header: Panel = $DeckListPanel/VBoxContainer.get_node_or_null("CurrentDeckHeader")
	if not header:
		return

	# 🔍 Trova ricorsivamente ClickableBlock (anche se nested)
	var clickable_block: VBoxContainer = null
	for node in header.find_children("ClickableBlock", "VBoxContainer", true, false):
		clickable_block = node
		break

	if not clickable_block:
		push_warning("⚠️ Nessun ClickableBlock trovato per aggiornare header.")
		return

	# 🔹 Aggiorna nome deck
	var name_label := clickable_block.get_child(0) if clickable_block.get_child_count() > 0 else null
	if name_label and name_label is Label:
		name_label.text = deck_data.deck_name
		name_label.modulate = Color(1, 0.3, 0.3) if not deck_data.is_valid else Color(1, 1, 1)

	# 🔹 Aggiorna icone mana
	var mana_hbox := clickable_block.get_child(1) if clickable_block.get_child_count() > 1 else null
	if mana_hbox and mana_hbox is HBoxContainer:
		for c in mana_hbox.get_children():
			c.queue_free()

		var mana_textures = {
			"Fire": preload("res://Assets/Mana/Fuoco.png"),
			"Wind": preload("res://Assets/Mana/Vento.png"),
			"Water": preload("res://Assets/Mana/Acqua.png"),
			"Earth": preload("res://Assets/Mana/Terra.png")
		}

		for mana_type in deck_data.get_mana_slots():
			if mana_type == "":
				continue
			var icon = TextureRect.new()
			icon.texture = mana_textures.get(mana_type, null)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.ignore_texture_size = true
			icon.custom_minimum_size = Vector2(40, 40)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mana_hbox.add_child(icon)




func _update_deck_header_stats(deck_data: DeckData):
	var vbox = $DeckListPanel/VBoxContainer
	var header: Panel = vbox.get_node_or_null("CurrentDeckHeader")
	if not header:
		return

	# =========================================================
	# 🔹 BLOCCO CONTEGGIO CARTE (X / 40)
	# =========================================================
	var card_count_value_label: Label = header.find_child("CardCountValueLabel", true, false)
	var card_count_suffix_label: Label = header.find_child("CardCountSuffixLabel", true, false)

	if card_count_value_label and card_count_suffix_label:
		var total_cards := deck_data.cards.size()
		card_count_value_label.text = str(total_cards)
		card_count_suffix_label.text = "/40"

		# X rosso se ≠ 40, blu chiaro se corretto
		if total_cards != 40:
			card_count_value_label.modulate = Color(1, 0.3, 0.3)
		else:
			card_count_value_label.modulate = Color(0.8, 0.9, 1)

		# Il /40 resta sempre blu chiaro
		card_count_suffix_label.modulate = Color(0.8, 0.9, 1)

	# =========================================================
	# 🔹 BLOCCO RANK TOTALE (X / 100)
	# =========================================================
	var total_rank := 0
	for card_data in deck_data.cards:
		if card_data and card_data.card_rank != null:
			total_rank += card_data.card_rank

	var rank_value_label: Label = header.find_child("RankValueLabel", true, false)
	var rank_suffix_label: Label = header.find_child("RankSuffixLabel", true, false)

	if rank_value_label and rank_suffix_label:
		rank_value_label.text = str(total_rank)
		rank_suffix_label.text = "/100"

		if total_rank > 100:
			rank_value_label.modulate = Color(1, 0.3, 0.3)  # rosso se sopra 100
		else:
			rank_value_label.modulate = Color(1.0, 0.894, 0.875, 1)  # rosa chiaro standard

		# Il /100 resta sempre rosa chiaro
		rank_suffix_label.modulate = Color(1.0, 0.894, 0.875, 1)






func _clone_deck_data(deck_data: DeckData) -> DeckData:
	var clone: DeckData = deck_data.duplicate(true)
	return clone


func _on_deck_creation_popup_closed():
	# Quando il popup viene chiuso (anche annullando)
	var slot_container = $DeckCreationPopup/MarginContainer/VBoxContainer/ManaSlotContainer
	for slot in slot_container.get_children():
		if slot.has_method("clear_slot"):
			slot.clear_slot()
	deck_name_input.text = ""
	deck_creation_popup.title = "Create New Deck"


func _update_collection_copy_labels():
	if not is_in_deck_edit_mode or not current_deck_data:
		# Nasconde tutte le label se non stiamo editando un deck
		for attr in card_instances_by_attr.keys():
			for card_display in card_instances_by_attr[attr]:
				card_display.update_deck_copy_count(0)
		return

	# Conta le copie per ogni carta nel deck attuale
	var card_counts: Dictionary = {}
	for card_data in current_deck_data.cards:
		if not card_data:
			continue
		if card_counts.has(card_data.resource_path):
			card_counts[card_data.resource_path] += 1
		else:
			card_counts[card_data.resource_path] = 1

	# Aggiorna tutte le card_display nella collezione
	for attr in card_instances_by_attr.keys():
		for card_display in card_instances_by_attr[attr]:
			var path = card_display.card_data.resource_path
			var count = card_counts.get(path, 0)
			card_display.update_deck_copy_count(count)




func _hide_all_collection_copy_labels():
	for attr in card_instances_by_attr.keys():
		for card_display in card_instances_by_attr[attr]:
			if card_display and card_display.has_method("update_deck_copy_count"):
				card_display.update_deck_copy_count(0)


func _get_card_display_by_data(card_data: CardData) -> CardDisplay:
	for attr in card_instances_by_attr.keys():
		for card_display in card_instances_by_attr[attr]:
			if card_display.card_data == card_data:
				return card_display
	return null


func animate_card_transfer(card_display: CardDisplay, card_data: CardData):
	if not deck_cards_area or not card_display or not card_data:
		return

	# 🧱 Crea un'istanza temporanea della carta (ghost)
	var ghost_card := deck_card_scene.instantiate()
	ghost_card.card_data = card_data
	ghost_card.update_display()
	add_child(ghost_card)

	# 🔝 Porta la ghost card in primo piano
	ghost_card.z_index = 300
	ghost_card.z_as_relative = false  # (opzionale: garantisce che ignori l’ordine del parent)
	# 🚫 Nascondi rank finché l'animazione non termina
	if ghost_card.rank_icon:
		ghost_card.rank_icon.visible = false
	if ghost_card.rank_label:
		ghost_card.rank_label.visible = false
		
	# 📍 Partenza = posizione della CardDisplay cliccata
	var start_pos = card_display.get_global_position()
	ghost_card.global_position = start_pos
	ghost_card.scale = Vector2(0.8, 0.8)
	ghost_card.modulate = Color(1, 1, 1, 1)

	# 🔎 Cerchiamo se esiste già una DeckCardDisplay con questa carta
	var existing_target: Node2D = null
	for child in deck_cards_area.get_children():
		if child is DeckCardDisplay and child.card_data == card_data:
			existing_target = child
			break

	var end_pos: Vector2
	if existing_target:
		# 🟢 Se esiste già → punta alla posizione del nodo attuale
		end_pos = existing_target.to_global(Vector2(0, 0))
	else:
		# 🆕 Altrimenti → calcola posizione del nuovo slot
		var end_index = deck_cards_area.get_child_count()
		var spacing_y = 30
		var start_offset = DECK_PANEL_START_POS
		var end_local_pos = start_offset + Vector2(0, end_index * spacing_y)
		end_pos = deck_cards_area.to_global(end_local_pos)

	# ✨ Animazione: sposta, rimpicciolisci, svanisce
	var tween = create_tween()
	tween.tween_property(ghost_card, "global_position", end_pos, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	#tween.tween_property(ghost_card, "scale", Vector2(0.45, 0.45), 0.2)
	#tween.tween_property(ghost_card, "modulate:a", 0.0, 0.1)

	tween.finished.connect(func():
		# ✅ Solo ora ri-mostri le icone rank
		if is_instance_valid(ghost_card):
			if ghost_card.rank_icon:
				ghost_card.rank_icon.visible = true
			if ghost_card.rank_label:
				ghost_card.rank_label.visible = true
			# e poi rimuovi il ghost
			ghost_card.queue_free())


func _on_expand_deck_pressed():
	if not is_in_deck_edit_mode or not current_deck_data:
		print("⚠️ Nessun deck attivo da espandere.")
		return

	if showing_deck_view and not refreshing_expand_view:
		print("STO MOSTRANDO DIOCANE")
		return

	await _animate_button_press(expand_deck_button)
	print("📖 Mostro solo le carte del deck:", current_deck_data.deck_name)

	showing_deck_view = true

	background.visible = false
	deck_background.visible = true

	# 🔸 Nascondi tutte le carte prima che inizi l’animazione del deck
	for child in card_area.get_children():
		child.visible = false

	var tween: Tween = null

	# -------------------------------------------------------------
	# 🟢 Solo se NON è refresh: animazione di apertura del deck
	# -------------------------------------------------------------
	if not refreshing_expand_view:
		deck_background.scale = Vector2(0.0, 0.893)
		tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(deck_background, "scale", Vector2(1.345, 0.893), 0.3)
	else:
		deck_background.scale = Vector2(1.345, 0.893)

	# 🔸 Nascondi i pulsanti degli attributi quando si espande il deck
	for attr_btn in attribute_buttons.values():
		attr_btn.visible = false

	# 🔹 Raggruppa le carte per path e conta le copie
	var card_counts: Dictionary = {}
	var ordered_unique_cards: Array[CardData] = []

	for c in current_deck_data.cards:
		if not c or c.resource_path == "":
			continue
		if not card_counts.has(c.resource_path):
			card_counts[c.resource_path] = 1
			ordered_unique_cards.append(c)
		else:
			card_counts[c.resource_path] += 1

	if ordered_unique_cards.is_empty():
		print("⚠️ Il deck è vuoto.")
		for child in card_area.get_children():
			child.visible = false
		page_label.text = "0/0"
		_update_page_buttons()
		return

	# 🔹 Crea una sola pagina con tutte le carte in ordine originale
	pages_data.clear()
	var page_cards: Array[String] = []
	for card_data in ordered_unique_cards:
		page_cards.append(card_data.resource_path)

	pages_data.append({
		"group_id": "Deck",
		"cards": page_cards
	})

	total_pages = 1
	current_page = 0

	# ------------------------------------------------------
	# ⚙️ Layout dinamico con colonne e scala adattive
	# ------------------------------------------------------
	var total_cards: int = ordered_unique_cards.size()
	var columns_for_expand := 6
	var scale_factor := 1.0
	var x_spacing := spacing_x
	var y_spacing := spacing_y
	var start_y_offset := start_offset.y

	var rows_needed: int = int(ceil(float(total_cards) / float(columns_for_expand)))

	if rows_needed > 3:
		columns_for_expand = 8
		rows_needed = int(ceil(float(total_cards) / float(columns_for_expand)))
		scale_factor = clamp(3.0 / float(rows_needed), 0.75, 0.75)

	if rows_needed > 4:
		columns_for_expand = 10
		rows_needed = int(ceil(float(total_cards) / float(columns_for_expand)))
		scale_factor = clamp(3.0 / float(rows_needed), 0.6, 0.6)

	x_spacing = spacing_x * scale_factor
	y_spacing = spacing_y * scale_factor
	start_y_offset = start_offset.y * 0.8

	print("🔧 Deck expand layout — cards:", total_cards,
		"rows:", rows_needed,
		"cols:", columns_for_expand,
		"scale:", scale_factor)

	# ------------------------------------------------------
	# 🕒 Mostra le carte (con o senza animazione)
	# ------------------------------------------------------
	if not refreshing_expand_view:
		await tween.finished

	for child in card_area.get_children():
		child.visible = false

	for i in range(page_cards.size()):
		var path = page_cards[i]
		if not card_cache.has(path):
			continue
		var card_instance = _find_instance_by_path(path)
		if not card_instance:
			continue

		var col = i % columns_for_expand
		var row = i / columns_for_expand
		card_instance.position = Vector2(
			start_offset.x + col * x_spacing,
			start_y_offset + row * y_spacing
		)
		card_instance.visible = true

		if not refreshing_expand_view:
			card_instance.scale = Vector2(0.0, 0.0)
			var pop_tween = create_tween()
			card_instance.set_meta("pop_tween", pop_tween)
			pop_tween.set_trans(Tween.TRANS_BACK) # 🔹 singolo rimbalzo
			pop_tween.set_ease(Tween.EASE_OUT)
			pop_tween.tween_property(
				card_instance,
				"scale",
				Vector2(card_scale * scale_factor, card_scale * scale_factor),
				0.5
			).set_delay(i * 0.02)

			pop_tween.finished.connect(func():
				card_instance.set_meta("pop_tween", null)
			)
					# 🕒 Aspetta un piccolo delay prima di passare alla prossima carta
			#await get_tree().create_timer(0.02).timeout
		else:
			card_instance.scale = Vector2(card_scale * scale_factor, card_scale * scale_factor)

	# 🔹 Aggiorna etichette e invalid banner
	for attr in card_instances_by_attr.keys():
		for card_display in card_instances_by_attr[attr]:
			if not is_instance_valid(card_display) or not card_display.card_data:
				continue
			var path = card_display.card_data.resource_path
			var count = card_counts.get(path, 0)
			card_display.update_deck_copy_count(count)

			var mana_array = card_display.card_data.get_mana_cost_array()
			var deck_mana_counts := {"Fire": 0, "Wind": 0, "Water": 0, "Earth": 0}
			for mana_type in current_deck_data.get_mana_slots():
				if deck_mana_counts.has(mana_type):
					deck_mana_counts[mana_type] += 1
			var respects := _card_respects_mana_limits(mana_array, deck_mana_counts)
			card_display.mark_as_invalid_in_expand(not respects)

	page_label.clear()
	page_label.append_text("1/1")
	prev_page_button.visible = false
	next_page_button.visible = false
	expand_deck_button.visible = false
	shrink_deck_button.visible = true




func _on_shrink_deck_pressed():
	if not showing_deck_view:
		return

	_animate_button_press(shrink_deck_button)
	print("📕 Ritorno alla collezione completa")
	showing_deck_view = false

	# 🔸 Interrompi eventuali tween "pop" ancora attivi e nascondi subito le carte del deck
	for child in card_area.get_children():
		if not is_instance_valid(child):
			continue

		var tween = child.get_meta("pop_tween", null)
		if tween and tween is Tween and tween.is_running():
			tween.kill()
			child.set_meta("pop_tween", null)

		child.scale = Vector2(card_scale, card_scale)
		child.visible = false

	if deck_background.visible:
		# 🔹 Tween: richiude orizzontalmente da sinistra verso destra
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(deck_background, "scale", Vector2(0.0, 0.893), 0.3)
		await tween.finished
		deck_background.visible = false

	# 🔹 Riattiva lo sfondo principale
	background.visible = true
	shrink_deck_button.visible = false
	expand_deck_button.visible = true
	
	# 🔸 Rendi di nuovo visibili i pulsanti degli attributi quando si chiude la vista deck
	for attr_btn in attribute_buttons.values():
		attr_btn.visible = true

	# 🔹 Pulisci la barra di ricerca
	_clear_search_bar()

	# 🔁 Se siamo in deck edit mode → riapplica il filtro di mana constraint
	if is_in_deck_edit_mode and current_deck_data:
		_apply_mana_constraint_filter(current_deck_data)
	else:
		if current_filter_mode == "Search":
			_apply_search_filter(search_bar.text)
		else:
			_apply_default_filter()

	# 🔹 Ripristina la scala originale per tutte le carte
	for attr in card_instances_by_attr.keys():
		for card_display in card_instances_by_attr[attr]:
			if not is_instance_valid(card_display):
				continue
			card_display.scale = Vector2(card_scale, card_scale)

			if card_display.has_method("mark_as_invalid_in_expand"):
				card_display.mark_as_invalid_in_expand(false)





		
func _display_filtered_cards(card_list: Array, card_counts: Dictionary):
	var columns := 6
	var max_rows := 3
	var spacing_x := 200
	var spacing_y := 270
	var start_offset := Vector2(200, 200)
	var scale_factor := 0.9

	var index := 0
	for card_data in card_list:
		var card_instance = card_scene.instantiate()
		card_instance.card_data = card_data
		card_instance.scale = Vector2(scale_factor, scale_factor)
		card_instance.update_display()
		card_area.add_child(card_instance)

		var col := index % columns
		var row := index / columns
		card_instance.position = start_offset + Vector2(col * spacing_x, row * spacing_y)
		index += 1

		# Etichetta “xN” se ci sono copie
		var copies = card_counts.get(card_data, 1)
		if copies > 1:
			var count_label := Label.new()
			count_label.text = "×" + str(copies)
			count_label.add_theme_font_size_override("font_size", 28)
			count_label.modulate = Color(1, 0.9, 0.2)
			count_label.position = Vector2(100, 20)
			card_instance.add_child(count_label)

func _apply_mana_constraint_filter(deck_data: DeckData):
	current_filter_mode = "ManaConstraint"
	pages_data.clear()

	var deck_mana_counts := {
		"Fire": 0,
		"Wind": 0,
		"Water": 0,
		"Earth": 0
	}
	for mana_type in deck_data.get_mana_slots():
		if deck_mana_counts.has(mana_type):
			deck_mana_counts[mana_type] += 1

	var attribute_order = ["Fire", "Wind", "Water", "Earth"]
	var grouped_by_attr: Dictionary = {}
	for attr in attribute_order:
		grouped_by_attr[attr] = []

	for path in all_card_paths:
		var card_data: CardData = load(path)
		if not card_data:
			continue

		var mana_array := card_data.get_mana_cost_array()
		if _card_respects_mana_limits(mana_array, deck_mana_counts):
			grouped_by_attr[card_data.card_attribute].append(card_data)

	# Ordina ogni gruppo come nel filtro standard
	for attr in attribute_order:
		var cards_for_attr: Array = grouped_by_attr[attr]
		if cards_for_attr.is_empty():
			continue

		cards_for_attr.sort_custom(func(a: CardData, b: CardData) -> bool:
			var total_a = a.get_mana_cost()
			var total_b = b.get_mana_cost()
			if total_a != total_b:
				return total_a < total_b
			var color_count_a = a.get_mana_cost_array().filter(func(x): return x != "Colorless").size()
			var color_count_b = b.get_mana_cost_array().filter(func(x): return x != "Colorless").size()
			return color_count_a < color_count_b
		)

		for i in range(0, cards_for_attr.size(), cards_per_page):
			var page_cards = []
			for j in range(i, min(i + cards_per_page, cards_for_attr.size())):
				page_cards.append(cards_for_attr[j].resource_path)
			pages_data.append({
				"group_id": attr,
				"cards": page_cards
			})

	total_pages = pages_data.size()
	current_page = 0
	if total_pages > 0:
		_show_page(0)
	else:
		for c in card_area.get_children():
			c.visible = false
		page_label.text = "0/0"

	_update_page_buttons()
	_update_page_label()
	_highlight_current_attribute()


# 🧩 Funzione di supporto
func _card_respects_mana_limits(mana_array: Array, deck_mana_counts: Dictionary) -> bool:
	var color_counts := {
		"Fire": 0,
		"Wind": 0,
		"Water": 0,
		"Earth": 0
	}

	for m in mana_array:
		if color_counts.has(m):
			color_counts[m] += 1

	# Confronta ogni colore con il limite del deck
	for color in color_counts.keys():
		if color_counts[color] > deck_mana_counts[color]:
			return false
	return true

func _clear_search_bar():
	if search_bar:
		# 🔹 Evita di emettere doppio segnale se il testo è già vuoto
		if search_bar.text != "":
			search_bar.text = ""
			# 🔸 Forza la chiamata manuale del segnale di testo cambiato
			_on_search_bar_text_changed("")


# ======================================================
# 🧮 ORDINAMENTO DECK
# ======================================================

func _on_mana_ordering_button_pressed():
	_animate_button_press(mana_ordering_button)  # 👈 animazione bottone
	print("ORDINA MANA")
	# Ruota stato: none → asc → desc → none
	match mana_order_state:
		"none":
			mana_order_state = "asc"
		"asc":
			mana_order_state = "desc"
		"desc":
			mana_order_state = "none"
			
	if current_deck_data:
		current_deck_data.mana_sort_state = mana_order_state
		ResourceSaver.save(current_deck_data, "res://DeckResources/%s.tres" % current_deck_data.deck_name)
	# Aggiorna icona
	_update_ordering_icon(mana_order_state, mana_ordering_icon)

	# Applica ordinamento
	_apply_deck_sorting()
	
	if showing_deck_view:
		refreshing_expand_view = true
		_on_expand_deck_pressed()
		refreshing_expand_view = false

func _on_rank_ordering_button_pressed():
	_animate_button_press(rank_ordering_button)
	print("ORDINA RANK")
	match rank_order_state:
		"none":
			rank_order_state = "asc"
		"asc":
			rank_order_state = "desc"
		"desc":
			rank_order_state = "none"

	if current_deck_data:
		current_deck_data.rank_sort_state = rank_order_state
		ResourceSaver.save(current_deck_data, "res://DeckResources/%s.tres" % current_deck_data.deck_name)

	_update_ordering_icon(rank_order_state, rank_ordering_icon)
	_apply_deck_sorting()

	if showing_deck_view:
		refreshing_expand_view = true
		_on_expand_deck_pressed()
		refreshing_expand_view = false

func _update_ordering_icon(state: String, icon_node: Sprite2D):
	if not icon_node:
		return

	match state:
		"asc":
			icon_node.texture = ICON_ASC
			icon_node.scale = Vector2(0.25, 0.25)  # 🔺 Triplo rispetto a none (0.1)
		"desc":
			icon_node.texture = ICON_DESC
			icon_node.scale = Vector2(0.25, 0.25)  # 🔺 Triplo rispetto a none
		_:
			icon_node.texture = ICON_NONE
			icon_node.scale = Vector2(0.1, 0.1)  # 🔹 Default (piccola)



func _apply_deck_sorting(was_new_card: bool = false):
	if not current_deck_data or not deck_cards_area:
		return

	var cards := current_deck_data.cards.duplicate(true)

	# 🔹 Priorità: se entrambi attivi, applica prima il mana e poi il rank
	if mana_order_state != "none":
		cards.sort_custom(func(a: CardData, b: CardData) -> bool:
			var cost_a = a.get_mana_cost()
			var cost_b = b.get_mana_cost()
			return cost_a < cost_b if mana_order_state == "asc" else cost_a > cost_b
		)

	if rank_order_state != "none":
		cards.sort_custom(func(a: CardData, b: CardData) -> bool:
			var rank_a = a.card_rank if "card_rank" in a else 0
			var rank_b = b.card_rank if "card_rank" in b else 0
			return rank_a < rank_b if rank_order_state == "asc" else rank_a > rank_b
		)

	# ✅ Pulisci le vecchie carte prima di ricrearle
	for child in deck_cards_area.get_children():
		child.queue_free()

	await get_tree().process_frame

	# 🔁 Aggiorna i dati e UI
	current_deck_data.cards = cards
	_show_deck_cards(current_deck_data)

	# 🔄 🔹 Solo se la carta aggiunta è nuova, aggiorna anche la vista espansa
	if showing_deck_view and was_new_card:
		refreshing_expand_view = true
		_on_expand_deck_pressed()
		refreshing_expand_view = false



func _animate_button_press(button: TextureButton):
	if not button:
		return

	# 🔹 Ferma eventuale tween precedente
	if button.has_meta("press_tween"):
		var old_tween = button.get_meta("press_tween")
		if old_tween:
			old_tween.kill()

	var tween = create_tween()
	button.set_meta("press_tween", tween)

	# 🔸 Parametri: restringe e scurisce
	var original_scale = button.scale
	var pressed_scale = original_scale * 0.9
	var original_color = button.modulate
	var pressed_color = Color(0.6, 0.6, 0.6, 1.0)

	# Fase 1 — pressione (veloce)
	tween.tween_property(button, "scale", pressed_scale, 0.07)
	tween.parallel().tween_property(button, "modulate", pressed_color, 0.07)

	# Fase 2 — rilascio (più lento e morbido)
	tween.tween_property(button, "scale", original_scale, 0.15)
	tween.parallel().tween_property(button, "modulate", original_color, 0.15)

	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)


func _check_total_rank_validity(deck_data: DeckData) -> void:
	var total_rank := 0
	for card_in_deck in deck_data.cards:
		if card_in_deck and card_in_deck.card_rank != null:
			total_rank += card_in_deck.card_rank

	deck_is_invalid_due_to_rank = total_rank > 100

	# 🔹 Nuovo controllo: numero carte (deve essere esattamente 40)
	var total_cards := deck_data.cards.size()
	deck_is_invalid_due_to_count = (total_cards != 40)

	# 🔹 Combina tutte le condizioni di invalidità
	deck_data.is_valid = not (deck_is_invalid_due_to_rank or deck_is_invalid_due_to_cards or deck_is_invalid_due_to_count)
	deck_is_invalid = not deck_data.is_valid

	_update_deck_validity_visual(deck_data, not deck_data.is_valid)

	# 🔹 Log di debug
	if deck_is_invalid_due_to_rank:
		print("⚠️ Deck invalido: rank totale", total_rank, "> 100")
	elif deck_is_invalid_due_to_count:
		print("⚠️ Deck invalido: numero carte", total_cards, "/40")
	else:
		print("✅ Deck valido: rank =", total_rank, " | carte =", total_cards)

	# ✅ Aggiorna i banner di invalidità visiva se serve
	if is_in_deck_edit_mode and current_deck_data == deck_data:
		_check_invalid_cards_in_deck(deck_data)

	# ✅ Aggiorna anche la UI delle statistiche (label X/40 e rank)
	_update_deck_header_stats(deck_data)


func _update_scroll_state():
	var unique_cards: Array = []
	for child in deck_cards_area.get_children():
		if child is DeckCardDisplay and child.card_data and not (child.card_data in unique_cards):
			unique_cards.append(child.card_data)

	scroll_enabled = unique_cards.size() >= 25

	if scroll_enabled:
		var total_cards := deck_cards_area.get_child_count()
		var visible_cards := 25
		var spacing_y := 30
		var extra_scroll := 120  # 🆕 margine extra in pixel dopo l’ultima carta

		scroll_min = -max(0, (total_cards - visible_cards) * spacing_y + extra_scroll)
		scroll_max = 0.0
	else:
		scroll_offset = 0.0
		scroll_min = 0.0
		scroll_max = 0.0

	deck_cards_area.position.y = scroll_offset



func _on_page_button_pressed(button: TextureButton):
	await _animate_button_press(button)

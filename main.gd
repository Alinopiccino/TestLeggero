extends Node2D

@export var player_field_scene: PackedScene
@export var enemy_field_scene: PackedScene
@onready var host_button := $HostButton
@onready var join_button := $JoinButton
@onready var ip_input := $IPInput
@onready var status_label := $StatusLabel
@onready var copy_ip_button: TextureButton = $CopyIPButton

var selected_deck: DeckData = null
var deck_buttons_container: VBoxContainer
var lobby_list_background: ColorRect
var lobby_list: VBoxContainer
var deck_list_background: ColorRect

# Multiplayer info
var local_deck_data: DeckData = null
var remote_deck_data: DeckData = null
var both_ready := false
var selected_hbox_ref: HBoxContainer = null
var deck_selected := false
var current_username := "Player"  # temporaneo, poi lo passerai dal main menu
var ip: String
var local_ready := false
var remote_ready := false

func _ready():
	# --- Connessioni multiplayer ---
	MultiplayerManager.connected.connect(_on_connected)
	MultiplayerManager.failed.connect(_on_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# --- Setup nodi ---
	deck_buttons_container = $DeckList
	lobby_list_background = $LobbyListBackground
	lobby_list = lobby_list_background.get_node("LobbyList")
	deck_list_background = $DeckListBackground
	_load_existing_decks()

	# --- Bottoni ---
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	ip_input.text_changed.connect(_on_ip_text_changed)
	copy_ip_button.pressed.connect(_on_copy_ip_pressed)

	join_button.disabled = true
	copy_ip_button.visible = false
	status_label.visible = false
	status_label.text = ""




# ==============================================================
# 📚 Caricamento deck (stile Collection, ma senza ❌)
# ==============================================================

func _load_existing_decks():
	for child in deck_buttons_container.get_children():
		child.queue_free()

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
				var hbox = HBoxContainer.new()
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.custom_minimum_size = Vector2(0, 80)
				hbox.add_theme_constant_override("separation", 8)

				var deck_button = Button.new()
				deck_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				deck_button.custom_minimum_size = Vector2(0, 80)
				deck_button.focus_mode = Control.FOCUS_NONE
				deck_button.connect("pressed", func(): _on_deck_selected(deck_data, hbox))

				var margin_container = MarginContainer.new()
				margin_container.add_theme_constant_override("margin_left", 12)
				margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				var vbox = VBoxContainer.new()
				vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
				vbox.add_theme_constant_override("separation", 4)

				var name_label = Label.new()
				name_label.text = deck_data.deck_name
				name_label.add_theme_font_size_override("font_size", 20)
				vbox.add_child(name_label)

				var mana_hbox = HBoxContainer.new()
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
					icon.custom_minimum_size = Vector2(40, 40)
					icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
					mana_hbox.add_child(icon)
				
				vbox.add_child(mana_hbox)
				margin_container.add_child(vbox)
				deck_button.add_child(margin_container)

				hbox.add_child(deck_button)
				deck_buttons_container.add_child(hbox)

		file_name = dir.get_next()

	dir.list_dir_end()


func _on_deck_selected(deck_data: DeckData, selected_hbox: HBoxContainer):
	if deck_selected and selected_hbox == selected_hbox_ref:
		# 🔁 Deselezione
		_deselect_all_decks()
		return

	print("✅ Deck selezionato:", deck_data.deck_name)
	selected_deck = deck_data
	selected_hbox_ref = selected_hbox
	deck_selected = true

	for child in deck_buttons_container.get_children():
		if child == selected_hbox:
			_animate_selected_deck(child)
		else:
			_animate_hide_deck(child)


func _animate_hide_deck(hbox: HBoxContainer):
	var tween := create_tween()
	tween.tween_property(hbox, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(hbox, "position:x", hbox.position.x - 150, 0.25)
	await tween.finished
	hbox.visible = false


func _animate_selected_deck(hbox: HBoxContainer):
	var tween := create_tween()
	tween.tween_property(hbox, "scale", Vector2(1.1, 1.1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	hbox.modulate = Color(0.6, 1.0, 0.6)


func _deselect_all_decks():
	if not deck_selected:
		return

	deck_selected = false
	selected_deck = null

	# 🔹 Riporta il deck selezionato alla scala e colore originali
	if selected_hbox_ref:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(selected_hbox_ref, "scale", Vector2(1, 1), 0.3)
		tween.parallel().tween_property(selected_hbox_ref, "modulate", Color(1, 1, 1, 1), 0.25)

	# 🔹 Riporta visibili tutti gli altri deck con animazione inversa dello “hide”
	for child in deck_buttons_container.get_children():
		if child == selected_hbox_ref:
			continue

		child.visible = true
		child.modulate.a = 0.0
		child.position.x -= 150  # parte da sinistra, così entra scorrendo

		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(child, "modulate:a", 1.0, 0.25)
		tween.parallel().tween_property(child, "position:x", 0.0, 0.25)

	selected_hbox_ref = null




# ==============================================================
# 🌐 MULTIPLAYER LOGIC (nuova versione)
# ==============================================================

func _on_host_pressed():
	if not selected_deck:
		print("⚠️ Seleziona prima un deck!")
		return
	local_deck_data = selected_deck  # ✅ QUI
	disable_buttons()
	MultiplayerManager.host()
	update_ip_label()
	copy_ip_button.visible = true



func get_local_ips() -> Dictionary:
	var result := {
		"lan": [],
		"vpn": []
	}

	for ip in IP.get_local_addresses():
		# LAN
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			result.lan.append(ip)

		# VPN comuni
		elif ip.begins_with("26.") or ip.begins_with("25.") or ip.begins_with("100."):
			result.vpn.append(ip)

	return result

var vpn_ip := ""
var lan_ip := ""

func update_ip_label():
	var ips = get_local_ips()
	var text := ""
	
	text += "Hosting a Game... " + "\n"
#
	#if ips.vpn.size() > 0:
		#vpn_ip = ips.vpn[0]
		#text += "[font_size=30]VPN IP (consigliato): " + vpn_ip + "[/font_size]\n"

	if ips.lan.size() > 0:
		lan_ip = ips.lan[0]
		text += "[font_size=30]LAN IP: " + lan_ip + "[/font_size]\n"

	status_label.visible = true
	status_label.text = text

#func _add_player_to_lobby(username: String, is_host := false):
	#var player_button = Button.new()
	#player_button.text = username
	#player_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#player_button.custom_minimum_size = Vector2(0, 60)
#
	#if is_host:
		#player_button.disabled = true
	#else:
		#player_button.pressed.connect(func():
			#print("🔗 Tentativo di connessione a host:", username)
			#_on_join_lobby_pressed()
		#)
#
	#lobby_list.add_child(player_button)

#func _on_join_lobby_pressed():
	#if not selected_deck:
		#print("⚠️ Seleziona prima un deck!")
		#return
	#disable_buttons()
	#MultiplayerManager.join()

func _on_join_pressed():
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Inserisci IP host!"
		return
	if not selected_deck:
		print("⚠️ Seleziona prima un deck!")
		return

	local_deck_data = selected_deck  # ✅ QUI
	disable_buttons()
	MultiplayerManager.join(ip)

func _on_connected():
	print("✅ _on_connected su:", multiplayer.get_unique_id(), " selected_deck:", selected_deck != null)
	local_deck_data = selected_deck

	# ❌ NON inviare nulla qui


func _on_peer_connected(peer_id: int):
	# ❌JOIN ignora se stesso
	if peer_id == multiplayer.get_unique_id():
		return


	if multiplayer.is_server():
		print("🎉 JOIN remoto connesso:", peer_id)
		# 1) manda deck host
		print("➡️ HOST manda il SUO deck al peer", peer_id)
		_send_deck_to_peer(local_deck_data, peer_id)

		# 2) richiede deck al client
		print("➡️ HOST richiede il deck al peer", peer_id)
		rpc_id(peer_id, "_rpc_request_deck")



@rpc("any_peer")
func _rpc_request_deck():
	var sender := multiplayer.get_remote_sender_id()
	print("📨 Richiesta deck da:", sender)

	while local_deck_data == null:
		await get_tree().process_frame  # ✅ aspetta finché è pronto

	_send_deck_to_peer(local_deck_data, sender)



# ==============================================================
# 📤📥 Invio e ricezione deck
# ==============================================================

#@rpc("any_peer")
#func _send_deck_to_peer(deck_data: DeckData, target_peer_id := 0):
	#var deck_dict = deck_data.to_dict()
#
	#if multiplayer.is_server():
		#print("📤 HOST → invio deck a peer:", target_peer_id)
		#rpc_id(target_peer_id, "_receive_deck_data", deck_dict)
	#else:
		#print("📤 CLIENT → invio deck all'HOST (1)")
		#rpc_id(1, "_receive_deck_data", deck_dict)
		
#func _send_deck_to_peer(deck_data: DeckData, target_peer_id: int):  #PRECEDENTE MA NON UFNZIONA CON VPN
	#if deck_data == null:
		#push_warning("❌ _send_deck_to_peer: deck_data è NULL, invio annullato")
		#return
#
	#var deck_dict = deck_data.to_dict()
	#print("📤 Invio deck a peer che ha ID pari a:", target_peer_id)
	#rpc_id(target_peer_id, "_receive_deck_data", deck_dict)

func _send_deck_to_peer(deck_data: DeckData, target_peer_id: int):
	if deck_data == null:
		push_warning("❌ _send_deck_to_peer: deck_data è NULL")
		return

	var light_dict = deck_data.to_light_dict()
	print("📤 Invio deck LIGHT a peer:", target_peer_id,
		  " | carte:", light_dict["cards"].size())
	# 🧪 DEBUG: dimensione payload RPC
	print("🧪 RPC DECK payload size approx:",
	var_to_bytes(light_dict).size(), "bytes")
	
	rpc_id(target_peer_id, "_receive_deck_data", light_dict)

@rpc("any_peer")
func _receive_deck_data(deck_dict: Dictionary):
	var sender := multiplayer.get_remote_sender_id()
	print("📥 Deck LIGHT ricevuto da:", sender)

	remote_deck_data = DeckData.from_light_dict(deck_dict)

	print("✅ Deck ricostruito:",
		  remote_deck_data.deck_name,
		  " | carte:", remote_deck_data.cards.size())

	_check_both_ready()
	


#func _check_both_ready():
	#if local_deck_data and remote_deck_data and not both_ready:
		#both_ready = true
		#print("✅ Entrambi i deck ricevuti — avvio scena.")
		#_start_game()
func _check_both_ready():
	if not multiplayer.is_server():
		return

	if local_deck_data and remote_deck_data and not both_ready:
		both_ready = true
		print("✅ Entrambi pronti — avvio partita")
		rpc("_rpc_start_game")


@rpc("any_peer", "call_local")
func _rpc_start_game():
	_start_game()

# ==============================================================
# 🎮 ISTANZIA SCENE QUANDO PRONTI
# ==============================================================

func _start_game():
	print("🎮 START GAME su peer:", multiplayer.get_unique_id())
	print("   local_deck:", local_deck_data != null)
	print("   remote_deck:", remote_deck_data != null)
	deck_buttons_container.visible = false
	lobby_list_background.visible = false
	lobby_list.visible = false
	deck_list_background.visible = false
	disable_buttons()
	
	var player_scene = player_field_scene.instantiate()
	var enemy_scene = enemy_field_scene.instantiate()

	player_scene.name = "PlayerField"
	enemy_scene.name = "EnemyField"
	add_child(player_scene)
	add_child(enemy_scene)

	if multiplayer.is_server():
		# Host gioca con local deck, nemico = remote
		player_scene.get_node("Deck").set_deck_data(local_deck_data)
		enemy_scene.get_node("EnemyDeck").set_deck_data(remote_deck_data)
		player_scene.host_set_up()
		enemy_scene.client_set_up()
	else:
		# Client gioca con local deck, nemico = remote
		player_scene.get_node("Deck").set_deck_data(local_deck_data)
		enemy_scene.get_node("EnemyDeck").set_deck_data(remote_deck_data)
		player_scene.client_set_up()
		enemy_scene.host_set_up()

func _on_peer_disconnected(peer_id):
	print("❌ Peer disconnesso:", peer_id)

func _on_failed():
	print("🚫 Connessione fallita")

func disable_buttons():
	$HostButton.visible = false
	$JoinButton.visible = false
	ip_input.visible = false
	status_label.visible = false
	copy_ip_button.visible = false

func _on_ip_text_changed(new_text: String):
	join_button.disabled = not _is_valid_ip(new_text)
	
func _is_valid_ip(ip: String) -> bool:
	var regex := RegEx.new()
	regex.compile(
		"^((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)\\.){3}"
		+ "(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)$"
	)
	return regex.search(ip) != null

func _on_copy_ip_pressed():
	if vpn_ip != "":
		DisplayServer.clipboard_set(vpn_ip)
	elif lan_ip != "":
		DisplayServer.clipboard_set(lan_ip)
	
	

extends Node2D

@onready var phase_manager = get_node("../PhaseManager")

const CARD_SCENE_PATH = "res://Scene/Card.tscn"
const CARD_DRAW_SPEED = 0.25   #aumenta per rallentare animazione pescaggio
const STARTING_HAND_SIZE = 6

@export var deck_data: DeckData
var player_deck = []
var deck_timer
#var drawn_card_this_turn = false

func _ready() -> void:
	#scale = Vector2(0.2, 0.2)
	deck_timer = $DeckTimer
	deck_timer.one_shot = true
	deck_timer.wait_time = 1.0
	#if deck_data:
		#print("📦 Loaded deck:", deck_data.resource_path)
	#if deck_data:
		#player_deck = deck_data.cards.duplicate()
		#
	#player_deck.shuffle()
	#$RichTextLabel.text = str(player_deck.size())
	 #
	#for i in range(STARTING_HAND_SIZE):
		#draw_card()
		
func set_deck_data(new_deck_data: DeckData):
	deck_data = new_deck_data
	print("🃏 Deck PLAYER caricato:", deck_data.resource_path)
	player_deck = deck_data.cards.duplicate()
	player_deck.shuffle()
	$RichTextLabel.text = str(player_deck.size())
	
	#for i in range(player_deck.size()):
		#if player_deck[i] == null:
			#print("❌ ATTENZIONE: Carta null nel mazzo all'indice", i)
		#elif typeof(player_deck[i]) != TYPE_OBJECT or not player_deck[i] is CardData:
			#print("❌ Tipo non valido nel mazzo all'indice", i, ":", player_deck[i])
		#else:
			#print("✔️ Carta nel mazzo:", player_deck[i].card_name)

	
	# 🎨 Genera gli slot mana → Player usa "ManaSlots"
	var mana_slots = deck_data.get_mana_slots()
	var mana_manager = get_parent().get_node("ManaSlots")
	if mana_manager:
		mana_manager.set_mana_slots(mana_slots)
	#for i in range(STARTING_HAND_SIZE):
		#draw_card()
	
#func _ready():
	#if not multiplayer.is_server():
		#queue_free() # se non sono il player, distruggo il nodo
		#return
	
	# Altrimenti eseguo la logica
	#scale = Vector2(0.2, 0.2)
	#if deck_data:
		#player_deck = deck_data.cards.duplicate()
	#player_deck.shuffle()
	#$RichTextLabel.text = str(player_deck.size())
	#for i in range(STARTING_HAND_SIZE):
		#draw_card()
func draw_initial_hand():
	# 🔒 Disattiva input all'inizio
	var input_manager = get_node("../InputManager")
	input_manager.inputs_disabled = true

	deck_timer.start()
	await deck_timer.timeout
	deck_timer.wait_time = 0.1
	var player_id = multiplayer.get_unique_id()
	for i in range(STARTING_HAND_SIZE):
		draw_here_and_for_clients_opponent(player_id)
		rpc("draw_here_and_for_clients_opponent", player_id)
		deck_timer.start()
		await deck_timer.timeout

	# 🔓 Riattiva input dopo la pesca
	input_manager.inputs_disabled = false

	# 📦 Passa la fase START automaticamente
	var phase_manager = get_node("../PhaseManager")
	if phase_manager.current_phase == phase_manager.Phase.START and not phase_manager.has_passed_this_phase:
		phase_manager.on_player_pass_button_pressed()
		
		#drawn_card_this_turn = false
	#drawn_card_this_turn = true
#func draw_initial_hand(): ------------------- questa e' quella che ho standard ma vediamo
	#
	##deck_timer.start()
	##await deck_timer.timeout
	#var player_id = multiplayer.get_unique_id   #get player id del player che pesca
	#
	#for i in range(STARTING_HAND_SIZE):
		#var card = player_deck[0]
		#player_deck.erase(card)
#
		#var scene = preload(CARD_SCENE_PATH)
		#var new_card = scene.instantiate()
		#$"../CardManager".add_child(new_card)
		#new_card.set_card_data(card.make_runtime_copy())
		#$"../PlayerHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
#
		#var final_position = new_card.position_in_hand
		#rpc("draw_here_and_for_clients_opponent", multiplayer.get_unique_id, card.make_runtime_copy(), final_position)
		#$RichTextLabel.text = str(player_deck.size())
		##drawn_card_this_turn = false
	##drawn_card_this_turn = true
	
@rpc("any_peer")
func draw_here_and_for_clients_opponent(player_id, card_data: CardData = null, final_position: Vector2 = Vector2.ZERO):
	if multiplayer.get_unique_id() == player_id:
		draw_card()
	else:
		get_parent().get_parent().get_node("EnemyField/EnemyDeck").draw_card()

func deck_clicked():
	
	print("GIOCO VERITIERO NON CLICCO DECK")
	return
	
	var input_manager = get_node("../InputManager")
	var phase_manager = get_node("../PhaseManager")
	phase_manager.draw_prompt_label.visible = false  # 👈 Nasconde la label
	
	# 🔒 Disabilita gli input durante la pescata
	input_manager.inputs_disabled = true

	var player_id = multiplayer.get_unique_id()
	draw_here_and_for_clients_opponent(player_id)
	rpc("draw_here_and_for_clients_opponent", player_id)

	# Attendi che l'animazione sia finita prima di riabilitare
	await get_tree().create_timer(CARD_DRAW_SPEED).timeout

	# 🔓 Riabilita gli input
	input_manager.inputs_disabled = false

	# Se sei in START phase, passa automaticamente
	if phase_manager.current_phase == phase_manager.Phase.START and not phase_manager.has_passed_this_phase:
		phase_manager.on_player_pass_button_pressed()

func draw_card():
	
	if player_deck.size() == 0:   #blocco di pescata se e' vuoto
		print("⚠️ Tentativo di pescare da un mazzo vuoto.")
		$Area2D/CollisionShape2D.disabled = true
		$Sprite2D.visible = false
		return
		#$RichTextLabel.visible = false
	#drawn_card_this_turn = true
	var card_drawn =  player_deck[0]
	player_deck.erase(card_drawn)
	print("Deck size: ", player_deck.size())
	
	
	if player_deck.size() == 0:   #dopo che hai pescato ed e' vuoto
		$Sprite2D.visible = false
		$Area2D/CollisionShape2D.disabled = true
	
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	new_card.hover_enabled = false   # 👈 disabilita subito
	$"../CardManager".add_child(new_card)
	new_card.name = "Card"
	new_card.card_unique_id = "%s_%d" % [card_drawn.card_name, randi()]
	# Aggiunta alla mano (calcolo posizione incluso)
	$"../PlayerHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
	#print("🖐️ Carta appena aggiunta → position_in_hand:", new_card.position_in_hand)
	new_card.set_card_data(card_drawn.make_runtime_copy())
	var final_position = new_card.position_in_hand
	#new_card.set_card_data(card_drawn)
	#new_card.set_card_data(card_drawn.duplicate(true)) #IMPORTANTE per duplicare carte
	
	var anim = new_card.get_node_or_null("AnimationPlayer")
	if anim:
		anim.play("card_flip")
		
	new_card.is_in_hand()
	# 🟡 Invia RPC al client avversario con dati e posizione
	var player_id = multiplayer.get_unique_id()
	rpc("draw_here_and_for_clients_opponent", player_id, card_drawn.make_runtime_copy(), final_position)
	
	$RichTextLabel.text = str(player_deck.size())

func remove_card_from_deck(card_data: CardData):
	if card_data in player_deck:
		player_deck.erase(card_data)
		$RichTextLabel.text = str(player_deck.size())
		print("🗑️ Rimosso dal deck:", card_data.card_name)
		

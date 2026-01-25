extends Node2D

const CARD_SCENE_PATH = "res://Scene/EnemyCard.tscn"
const CARD_DRAW_SPEED = 0.25
const STARTING_oppoHAND_SIZE = 5

@export var deck_data: DeckData

var opponent_deck = []
var enemy_deck_timer
#var drawn_card_this_turn = false

func _ready() -> void:
	scale = Vector2(1, 1)
	#enemy_deck_timer = $EnemyDeckTimer
	#enemy_deck_timer.one_shot = true
	#enemy_deck_timer.wait_time = 1.0
	#if deck_data:
		#print("📦 Loaded deck:", deck_data.resource_path)
	#if deck_data:
		#opponent_deck = deck_data.cards.duplicate()
#
	#opponent_deck.shuffle()
	#$RichTextLabel.text = str(opponent_deck.size())
	#
	#for i in range(STARTING_oppoHAND_SIZE):
		#draw_card()
		
func set_deck_data(new_deck_data: DeckData):
	deck_data = new_deck_data
	print("🃏 Deck ENEMY caricato:", deck_data.resource_path)
	opponent_deck = deck_data.cards.duplicate()
	opponent_deck.shuffle()
	$RichTextLabel.text = str(opponent_deck.size())
	
	# 🎨 Genera gli slot mana → Enemy usa "EnemyManaSlots"
	var mana_slots = deck_data.get_mana_slots()
	var mana_manager = get_parent().get_node("ManaSlots")
	if mana_manager:
		mana_manager.set_mana_slots(mana_slots)

	
	


	#for i in range(opponent_deck.size()):
		#if opponent_deck[i] == null:
			#print("❌ ATTENZIONE: Carta null nel mazzo all'indice", i)
		#elif typeof(opponent_deck[i]) != TYPE_OBJECT or not opponent_deck[i] is CardData:
			#print("❌ Tipo non valido nel mazzo all'indice", i, ":", opponent_deck[i])
		#else:
			#print("✔️ Carta nel mazzo:", opponent_deck[i].card_name)
			
		# 🎨 Genera gli slot mana



	#for i in range(STARTING_oppoHAND_SIZE):
		#draw_card()

#func _ready():
	#if multiplayer.is_server():
		#queue_free() # se sono l'host, non mi serve EnemyDeck (è per il client)
		#return
#
	#scale = Vector2(0.2, 0.2)
	#if deck_data:
		#opponent_deck = deck_data.cards.duplicate()
	#opponent_deck.shuffle()
	#$RichTextLabel.text = str(opponent_deck.size())
	#for i in range(STARTING_oppoHAND_SIZE):
		#draw_card()
#func draw_initial_hand():
	#
	##enemy_deck_timer.start()
	##await enemy_deck_timer.timeout
	#var player_id = multiplayer.get_unique_id   #get player id del player che pesca
	#
	#for i in range(STARTING_oppoHAND_SIZE):
		#draw_here_and_for_clients_opponent(player_id)
		#rpc("draw_here_and_for_clients_opponent", player_id)
		#$RichTextLabel.text = str(opponent_deck.size())
		#
#@rpc("any_peer")
#func draw_here_and_for_clients_opponent(player_id, card_data: CardData = null, final_position: Vector2 = Vector2.ZERO):
	#if multiplayer.get_unique_id == player_id:
		#draw_card()
	#else:
		## Lato client avversario → replica visiva della carta
		#print("🛰️ [Replica RPC] Posizione ricevuta per carta:", final_position)
		#if card_data != null:
			#var card_scene = preload("res://Scene/Card.tscn")
			#var new_card = card_scene.instantiate()
			#new_card.set_card_data(card_data)
#
			#$"../CardManager".add_child(new_card)
			#new_card.name = "Card"
#
			## Posizione iniziale: sopra mazzo nemico
			#new_card.position = Vector2(1600, 200)  # personalizza se necessario
			#new_card.position_in_hand = final_position
#
			#var tween = get_tree().create_tween()
			#tween.tween_property(new_card, "position", final_position, CARD_DRAW_SPEED)
#
			#var anim = new_card.get_node_or_null("AnimationPlayer")
			#if anim:
				#anim.play("card_flip")
		#else:
			#print("⚠️ Client ha ricevuto draw RPC ma card_data è null.")
#
#func deck_clicked():
	#
	##if drawn_card_this_turn:
		##return
	#var player_id = multiplayer.get_unique_id
	#draw_here_and_for_clients_opponent(player_id)
	#rpc("draw_here_and_for_clients_opponent", player_id)

func draw_card():
	#if drawn_card_this_turn:
		#return
	#drawn_card_this_turn = true
	if opponent_deck.size() == 0:
		print("⚠️ Tentativo di pescare da un mazzo vuoto.")
		#$Area2D/CollisionShape2D.disabled = true
		#$Sprite2D.visible = false
		return

	var card_drawn = opponent_deck[0]
	if card_drawn == null:
		print("❌ Carta pescata è null, qualcosa è andato storto.")
		return
	opponent_deck.erase(card_drawn)
	print("[EnemyDeck.gd] 🃏 Deck size:", opponent_deck.size())


	
	
	if opponent_deck.size() == 0:   #dopo che hai pescato ed e' vuoto
		$Sprite2D.visible = false
		#$Area2D.get_node("CollisionShape2D").disabled = true

	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	$"../CardManager".add_child(new_card)
	new_card.name = "OpponentCard"
	$"../EnemyHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
	#new_card.set_card_data(card_drawn)
	#new_card.set_card_data(card_drawn.duplicate(true)) #IMPORTANTE duplicare carte
	new_card.set_card_data(card_drawn.make_runtime_copy())
	new_card.card_unique_id = "%s_%d" % [card_drawn.card_name, randi()]
	new_card.is_in_hand()
	
	$RichTextLabel.text = str(opponent_deck.size())
	# Le carte dell'avversario non si flippano, quindi non chiamiamo l'animazione
# var anim = new_card.get_node_or_null("AnimationPlayer")
# if anim:
#	anim.play("card_flip")
func remove_card_from_deck(card_data: CardData):
	if card_data in opponent_deck:
		opponent_deck.erase(card_data)
		$RichTextLabel.text = str(opponent_deck.size())
		print("🗑️ Rimosso dal deck:", card_data.card_name)
		

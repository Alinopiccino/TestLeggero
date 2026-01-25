extends Node2D

const CARD_WIDTH = 155
const HAND_Y_POSITION = 0   # In alto invece che in basso
const DEFAULT_CARD_MOVE_SPEED = 0.1

var opponent_hand = []
var center_screen_x

func _ready() -> void:
	center_screen_x = get_viewport().size.x / 2

func add_card_to_hand(card, speed): 
	#IMPORTANTE, qui avviene la duplicazione, ogni volta che si chiama questa funzione
	#per ora viene chiamata solo quando si pesca dal deck, ma verra' usata per recupero carte da terreno/GY
	if card not in opponent_hand:
		if card.card_data == null:
			push_warning("⚠️ Attenzione: stai cercando di aggiungere una carta senza dati (card_data == null)")
		elif card.card_data.resource_path != "":
			card.card_data = card.card_data.duplicate(true)

		opponent_hand.insert(0, card)
		update_hand_positions(speed)
	else:
		animate_card_to_position(card, card.position_in_hand, DEFAULT_CARD_MOVE_SPEED)

func update_hand_positions(speed):
	for i in range(opponent_hand.size()):
		var new_position = Vector2(calculate_card_position(i), HAND_Y_POSITION)
		var card = opponent_hand[i]
		card.position_in_hand = new_position
		#print("📦 [update_hand_positions] Carta:", card.name, " → Posizione finale:", new_position)
		animate_card_to_position(card, new_position, speed)

func calculate_card_position(index):
	var dynamic_width = get_dynamic_card_width()
	var total_width = (opponent_hand.size() - 1) * dynamic_width
	var x_offset = center_screen_x + index * dynamic_width - total_width / 2
	return x_offset


func get_dynamic_card_width() -> float:
	var base_width := float(CARD_WIDTH)
	var hand_size := opponent_hand.size()  # o opponent_hand.size()

	if hand_size <= 6:
		return base_width

	var min_width := 60.0
	var max_extra_cards := 10
	var extra_cards = min(hand_size - 6, max_extra_cards)

	var factor := float(extra_cards) / float(max_extra_cards)
	return lerp(base_width, min_width, factor)



func animate_card_to_position(card, new_position, speed):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, speed)

func remove_card_from_hand(card):
	if card in opponent_hand:
		opponent_hand.erase(card)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)

func get_card_position_by_name(card_name: String) -> Vector2:
	for card in opponent_hand:
		if card.card_data and card.card_data.card_name == card_name:
			return card.position
	return Vector2.ZERO
	
func remove_any_card():
	if opponent_hand.size() == 0:
		return
	
	var random_card = opponent_hand.pop_back()
	random_card.queue_free()  # Se vuoi farla sparire dalla scena
	update_hand_positions(DEFAULT_CARD_MOVE_SPEED)

#extends Node
#
### Preloada le scene una sola volta
#const CARD_SCENE = preload("res://Scene/Card.tscn")
#const ENEMY_CARD_SCENE = preload("res://Scene/EnemyCard.tscn")
#
#
### Spawna una carta per il giocatore (normale)
#func spawn_player_card(card_data_dict: Dictionary) -> Node2D:
	#
	#var card_data = CardData.from_dict(card_data_dict)
	#var card = CARD_SCENE.instantiate()
	#
	#card.set_card_data(card_data)
	#card.name = card_data.card_name
	#
	#return card
#
### Spawna una carta dell'avversario (EnemyCard.tscn)
#func spawn_enemy_card(card_data_dict: Dictionary) -> Node2D:
	#var card_data = CardData.from_dict(card_data_dict)
	#var card = ENEMY_CARD_SCENE.instantiate()
	#
	##card.set_card_data(card_data)
	#card.name = card_data.card_name
	#card.call_deferred("set_card_data", card_data)
	#
	#return card

extends Node2D


@export var card_scene: PackedScene
@export var deck_data: DeckData

@onready var card_container = $CardContainer  # GridContainer, VBoxContainer, etc.

func _ready():
	if deck_data and card_scene:
		spawn_deck()

func spawn_deck():
	for card_data in deck_data.cards:
		var card_instance = card_scene.instantiate()
		card_instance.card_data = card_data
		card_container.add_child(card_instance)

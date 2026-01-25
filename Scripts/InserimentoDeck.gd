extends Node2D


@export var card_scene: PackedScene
var deck_data

@onready var card_container =  $"../CardContainer" # GridContainer, VBoxContainer, etc.


func _ready():
	if deck_data and card_scene:
		spawn_deck()
	

func spawn_deck():
	for card_data in deck_data.cards:
		var card_instance = card_scene.instantiate()
		card_instance.card_data = card_data
		card_container.add_child(card_instance)

func connect_card_signals(card):
	card.connect("hovered", Callable(self, "_on_card_hovered"))
	card.connect("hovered_off", Callable(self, "_on_card_hovered_off"))

func _on_card_hovered(card):
	print("Carta in hover:", card)

func _on_card_hovered_off(card):
	print("Hover off:", card)

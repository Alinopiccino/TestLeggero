extends Node2D

const STARTING_LP = 5000
const STARTING_SP = 0

func host_set_up():
	$EnemyLP.text = str(STARTING_LP)
	$EnemySP.text = str(STARTING_SP)
	get_parent().get_node("PlayerField/PlayerLP").text = str(STARTING_LP)
	get_parent().get_node("PlayerField/PlayerSP").text = str(STARTING_SP)
	#$TurnManager.player_LP
	#$TurnManager.enemy_LP
	
	#get_parent().get_node("EnemyField/EnemyDeck").deck_size = str(opponent_deck.size())
	#get_parent().get_node("EnemyField/EnemyDeck/RichTextLabel").text = "str(opponent_deck.size())"
	#$EnemyDeck.draw_initial_hand()
	#
	#$EndTurnButton.visible = true
	#$EndTurnButton.disabled = false
	#$InputManager.inputs_disabled = false
	#set deck text count and draw starting hand
	
	#end turn visible perche' host inizia per primo
	
	#enable inputs
	
	
	
func client_set_up():
	$EnemyLP.text = str(STARTING_LP)
	$EnemySP.text = str(STARTING_SP)
	get_parent().get_node("PlayerField/PlayerLP").text = str(STARTING_LP)
	get_parent().get_node("PlayerField/PlayerSP").text = str(STARTING_SP)
	
	#$EnemyDeck.draw_initial_hand()
	#$TurnManager.player_LP
	#$TurnManager.enemy_LP
	
	#get_parent().get_node("EnemyField/EnemyDeck").deck_size = str(opponent_deck.size())
	#get_parent().get_node("EnemyField/EnemyDeck/RichTextLabel").text = "str(opponent_deck.size())"
	

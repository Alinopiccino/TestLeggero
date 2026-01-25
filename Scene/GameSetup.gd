extends Node2D

const STARTING_LP = 5000
const STARTING_SP = 0

func host_set_up():
	$PlayerLP.text = str(STARTING_LP)
	$PlayerSP.text = str(STARTING_SP)
	get_parent().get_node("EnemyField/EnemyLP").text = str(STARTING_LP)
	get_parent().get_node("EnemyField/EnemySP").text = str(STARTING_SP)
	$CombatManager.player_LP = STARTING_LP
	$CombatManager.enemy_LP = STARTING_LP
	$CombatManager.player_SP = STARTING_SP
	$CombatManager.enemy_SP = STARTING_SP
	
	#get_parent().get_node("EnemyField/EnemyDeck").deck_size = str(opponent_deck.size())
	#get_parent().get_node("EnemyField/EnemyDeck/RichTextLabel").text = "str(opponent_deck.size())"
	
	$PhaseManager.decide_starting_roles()
	await get_tree().process_frame # 👈 aspetta
	$PhaseManager.update_role_icons() # 👈 chiama update dopo che la scena è pronta
	$Deck.draw_initial_hand()
	
	
	#$EndTurnButton.visible = true
	#$EndTurnButton.disabled = false
	$InputManager.inputs_disabled = false
	
	#set deck text count and draw starting hand
	
	#end turn visible perche' host inizia per primo
	
	#enable inputs
	
	
	
func client_set_up():
	$PlayerLP.text = str(STARTING_LP)
	$PlayerSP.text = str(STARTING_SP)
	get_parent().get_node("EnemyField/EnemyLP").text = str(STARTING_LP)
	get_parent().get_node("EnemyField/EnemySP").text = str(STARTING_SP)
	$CombatManager.player_LP = STARTING_LP
	$CombatManager.enemy_LP = STARTING_LP
	$CombatManager.player_SP = STARTING_SP
	$CombatManager.enemy_SP = STARTING_SP
	#get_parent().get_node("EnemyField/EnemyDeck").deck_size = str(opponent_deck.size())
	#get_parent().get_node("EnemyField/EnemyDeck/RichTextLabel").text = "str(opponent_deck.size())"
	
	$Deck.draw_initial_hand()

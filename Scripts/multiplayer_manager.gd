#extends Node
#
#signal connected
#signal failed
#
#func host():
	#var peer = ENetMultiplayerPeer.new()
	#var result = peer.create_server(9999)
	#print("HOST RESULT:%d" % result)
	#if result == OK:
		#multiplayer.multiplayer_peer = peer
		#connected.emit()
	#else:
		#failed.emit()
#
#func join():
	#var peer = ENetMultiplayerPeer.new()
	#var result = peer.create_client("127.0.0.1", 9999) # <--- Cambia IP se necessario
	#print("JOIN RESULT:%d" % result)
	#if result == OK:
		#multiplayer.multiplayer_peer = peer
		#connected.emit()
	#else:
		#failed.emit()


extends Node  #VERSIONE PC DIVERSI

signal connected
signal failed

const PORT := 9999

func host():
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(PORT)
	print("HOST RESULT:", result)

	if result == OK:
		multiplayer.multiplayer_peer = peer
		connected.emit()
	else:
		failed.emit()

func join(ip_address: String):
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(ip_address, PORT)
	print("JOIN RESULT:", result)

	if result == OK:
		multiplayer.multiplayer_peer = peer
		connected.emit()
	else:
		failed.emit()

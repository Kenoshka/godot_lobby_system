extends Node

const PORT = 30123

var MULTI : SceneMultiplayer
var is_server = false

var lobby_counter = 0
const game_scene = preload("") # Scene of root node of your game
const lobby_scene = preload("") # Lobby scene
var game : Node3D # Root node of Game, where lobbies are stored on server side
var LOBBIES : Array = []
var lobby_name = ""

var PLAYERS_LOBBIES = {} # PlayerID:Lobby

func _ready():
	MULTI = get_tree().get_multiplayer()
	MULTI.peer_connected.connect(_peer_connected)
	MULTI.peer_disconnected.connect(_peer_disconnected)

func _peer_connected(id):
	if is_server:
		rpc("debug_massage", str(id) + " connected")
		PLAYERS_LOBBIES[id] = null
	else:
		pass

func _peer_disconnected(id):
	if is_server:
		rpc("debug_massage", str(id) + " disconnected")
		if PLAYERS_LOBBIES[id] != null:
			PLAYERS_LOBBIES[id].PLAYERS.erase(id)
		PLAYERS_LOBBIES.erase(id)
	else:
		pass

#================[SERVER CODE]==============================

func create_server():
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(30123, 10) == 0:
		MULTI.multiplayer_peer = peer
		print("Created server")
	else:
		print("Failed to create server")

@rpc("any_peer", "call_local")
func debug_massage(text):
	var id = MULTI.get_remote_sender_id()
	print(str(id) + ": " + text)

@rpc("any_peer", "call_local")
func create_lobby():
	var lobby = lobby_scene.instantiate()
	lobby_counter += 1
	lobby.name = str(lobby_counter)
	game.add_child(lobby)
	LOBBIES.append(lobby)
	var id = MULTI.get_remote_sender_id()
	if id != 1 and id != 0:
		rpc_id(id, "go_to_lobby", str(lobby_counter))

@rpc("any_peer", "reliable")
func asked_for_lobbies():
	var id = MULTI.get_remote_sender_id()
	var lobbies_infos = []
	for lobby in LOBBIES:
		if lobby.PLAYERS.size() < lobby.CAPACITY:
			lobbies_infos.append([lobby.name, lobby.PLAYERS.size(), lobby.CAPACITY])
	rpc_id(id, "get_lobbies", lobbies_infos)

@rpc("any_peer")
func connect_user_to_lobby(lobb_name):
	var id = MULTI.get_remote_sender_id() # Here you need to add different verifications of player's ability to connect
	if get_lobby_by_name(lobb_name):
		rpc_id(id, "go_to_lobby", str(lobb_name))


@rpc("any_peer", "reliable")
func notify_lobby_connection(lob_name):
	var id = MULTI.get_remote_sender_id()
	var lobby = get_lobby_by_name(lob_name)
	if lobby != null:
		lobby.PLAYERS.append(id)
		PLAYERS_LOBBIES[id] = lobby
	else:
		print("Error finding lobby " + lob_name)


func get_lobby_by_name(lob_name):
	for lobby in LOBBIES:
		if lobby.name == lob_name:
			return lobby
	return null


#================[CLIENT CODE]==============================

signal lobbies_got

func create_client():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("localhost", 30123)
	MULTI.multiplayer_peer = peer
	print("Connection...")

@rpc("authority", "call_local")
func go_to_lobby(lob_name):
	lobby_name = lob_name
	get_tree().change_scene_to_packed(game_scene)

@rpc("authority")
func get_lobbies(lobbies_infos):
	LOBBIES = lobbies_infos
	lobbies_got.emit()

func is_connected_to_server():
	return true if MULTI.get_peers().has(1) else false

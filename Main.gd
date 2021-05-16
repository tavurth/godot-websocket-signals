extends ItemList

const SERVER_PORT = 5000
const SERVER_URL = "ws://localhost:%s" % SERVER_PORT


# NOTE: Client callbacks
#       ----------------
func _client_connection_closed(was_clean: bool):
	self.add_item("[Network]: Connection closed, clean: " + str(was_clean))
	set_physics_process(false)
	
func _client_connection_error():
	self.add_item("[Network]: Connection error")
	set_physics_process(false)

func _client_server_close_request(code: int, reason: String):
	self.add_item("[Network]: Server will close for %s, code: %s" % [reason, code])
	set_physics_process(false)

func _client_connection_established(protocol: String):
	self.add_item("[Network]: Connected %s" % protocol)

func _client_connection_succeeded():
	self.add_item("[Network]: Undocumented Connected")


# NOTE: Server callbacks 
#       ----------------
func _server_client_connected(id: int, protocol: String):
	self.add_item("[Network]: Client %d connected, protocol: %s" % [id, protocol])

func _server_client_disconnected(id: int, was_clean: bool, protocol: String):
	self.add_item("[Network]: Client %d disconnected. Was clean: %s, protocol: %s" % [id, was_clean, protocol])

func _server_client_close_request(id: int, code: int, reason: String):
	self.add_item("[Network]: Client %d will disconnect for %s. Code: %s" % [id, reason, code])

	
# NOTE: Network setup 
#       ----------------
func create_server():
	var server = WebSocketServer.new()

	var error = server.listen(SERVER_PORT, [], true)
	
	server.connect("client_connected", self, "_server_client_connected")
	server.connect("client_disconnected", self, "_server_client_disconnected")
	server.connect("client_close_request", self, "_server_client_disconnected")
	
	if error != OK:
		return null
	
	return server

func create_client():
	var peer = WebSocketClient.new()

	var error = peer.connect_to_url(SERVER_URL, [], true, [])

	# NOTE: This signal comes from NetworkedMultiplayerPeer and works correctly
	peer.connect("connection_succeeded", self, "_client_connection_succeeded")

	peer.connect("connection_error", self, "_client_connection_error")
	peer.connect("connection_closed", self, "_client_connection_closed")
	peer.connect("server_close_request", self, "_client_server_close_request")
	peer.connect("connection_established", self, "_client_connection_established")
	
	if error != OK:
		return null
	
	return peer

func is_server():
	return OS.has_feature("Server") or "--server" in OS.get_cmdline_args() 

func is_client():
	return not is_server()

func get_peer():
	return create_server() if is_server() else create_client()

func is_online():
	var peer = get_tree().get_network_peer()
	if not peer: return false
	return peer.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED

func create_connection():
	var peer = get_peer()
	if not peer:
		push_error("Failed to create network peer")
		return

	get_tree().set_network_peer(peer)
	set_physics_process(true)

func connection_loop():
	create_connection()

	# We will listen for clients
	if is_server(): return

	while true:
		yield(get_tree().create_timer(5), "timeout")
		
		if is_online():
			continue

		create_connection()

func _physics_process(_delta: float):
	if get_tree().has_network_peer():
		get_tree().get_network_peer().poll()

func _ready():
	connection_loop()

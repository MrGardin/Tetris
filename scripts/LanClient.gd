extends Node
class_name LanClient
## WebSocket-клиент Tetris:Windbound.
## Подключается к серверу, отправляет запросы и получает ответы.

signal status_changed(text: String)
signal match_found(room_code: String, role: String)
signal room_created(room_code: String)
signal opponent_left
signal server_message(data: Dictionary)

const DEFAULT_SERVER_URL := "wss://portsmouth-joining-examined-munich.trycloudflare.com"

var server_url := DEFAULT_SERVER_URL

var _socket := WebSocketPeer.new()
var _pending_message: Dictionary = {}
var _was_open := false


func _process(_delta: float) -> void:
	_socket.poll()

	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			status_changed.emit("Подключено к серверу.")

		if not _pending_message.is_empty():
			var message_to_send := _pending_message
			_pending_message = {}
			_send_now(message_to_send)

		while _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet()
			var text := packet.get_string_from_utf8()
			_handle_server_message(text)

	elif state == WebSocketPeer.STATE_CLOSED:
		if _was_open:
			_was_open = false
			status_changed.emit("Соединение с сервером закрыто.")


func find_random_player() -> void:
	_request({
		"type": "find_random"
	})


func cancel_search() -> void:
	_request({
		"type": "cancel_search"
	})


func create_room() -> void:
	_request({
		"type": "create_room"
	})


func join_room(room_code: String) -> void:
	_request({
		"type": "join_room",
		"room": room_code.strip_edges().to_upper()
	})


func send_progress(height: float) -> void:
	_request({
		"type": "progress",
		"height": height
	})


func send_game_over() -> void:
	_request({
		"type": "game_over"
	})


func close_connection() -> void:
	_pending_message = {}

	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()

	_was_open = false


func _request(data: Dictionary) -> void:
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		_send_now(data)
		return

	if state == WebSocketPeer.STATE_CONNECTING:
		_pending_message = data
		status_changed.emit("Подключаемся к серверу...")
		return

	if server_url.strip_edges().is_empty():
		status_changed.emit("Не задан адрес сервера.")
		return

	_socket = WebSocketPeer.new()
	_pending_message = data

	var error := _socket.connect_to_url(server_url.strip_edges())
	if error != OK:
		_pending_message = {}
		status_changed.emit("Не удалось начать подключение. Код: %s" % error)
		return

	_was_open = false
	status_changed.emit("Подключаемся к серверу...")


func _send_now(data: Dictionary) -> void:
	var error := _socket.send_text(JSON.stringify(data))

	if error != OK:
		status_changed.emit("Не удалось отправить запрос серверу.")


func _handle_server_message(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)

	if not parsed is Dictionary:
		status_changed.emit("Сервер прислал некорректное сообщение.")
		return

	var data: Dictionary = parsed
	server_message.emit(data)

	match str(data.get("type", "")):
		"searching":
			status_changed.emit("Ищем случайного соперника...")
		"search_cancelled":
			status_changed.emit("Поиск отменён.")
		"room_created":
			var code := str(data.get("room", ""))
			room_created.emit(code)
			status_changed.emit("Комната создана. Код: %s" % code)
		"match_found":
			var code := str(data.get("room", ""))
			var role := str(data.get("role", ""))
			match_found.emit(code, role)
			status_changed.emit("Соперник найден! Код комнаты: %s" % code)
		"game_start":
			status_changed.emit("Оба игрока подключены. Матч найден.")
		"opponent_left":
			opponent_left.emit()
			status_changed.emit("Соперник отключился.")
		"error":
			status_changed.emit(str(data.get("message", "Ошибка сервера.")))
		"progress":
			status_changed.emit("Получен прогресс соперника.")
		_:
			pass

extends Node
class_name LanClient
## Сетевой клиент. Добавить в Autoload с именем Net.

signal status_changed(text: String)
signal room_created(room_code: String)
signal match_found(room_code: String, role: String)
signal match_started
signal opponent_left
signal opponent_progress_received(value: float)
signal match_result_received(result: String, message: String)
signal network_event_started(event_name: String, direction: int, warning_duration: float)
signal network_event_execute
signal network_event_ended
signal opponent_proof_received(image_base64: String)

const SERVER_URL: String = "wss://applicant-differently-resolutions-recommends.trycloudflare.com"

var room_code: String = ""
var player_role: String = ""
var match_ready: bool = false

var _socket: WebSocketPeer = WebSocketPeer.new()
var _pending_messages: Array[Dictionary] = []
var _was_open: bool = false
var _closed_notice_sent: bool = false


func _process(_delta: float) -> void:
	_socket.poll()

	var state: int = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_closed_notice_sent = false
			status_changed.emit("Подключено к серверу.")

		while not _pending_messages.is_empty():
			var data: Dictionary = _pending_messages.pop_front()
			_send_now(data)

		while _socket.get_available_packet_count() > 0:
			var packet: PackedByteArray = _socket.get_packet()
			_handle_message(packet.get_string_from_utf8())

	elif state == WebSocketPeer.STATE_CLOSED and _was_open:
		_was_open = false

		if not _closed_notice_sent:
			_closed_notice_sent = true
			status_changed.emit("Соединение с сервером закрыто.")


func find_random_player() -> void:
	_send_or_queue({"type": "find_random"})


func cancel_search() -> void:
	_send_or_queue({"type": "cancel_search"})


func create_room() -> void:
	_send_or_queue({"type": "create_room"})


func join_room(code: String) -> void:
	_send_or_queue({
		"type": "join_room",
		"room": code.strip_edges().to_upper()
	})


func send_progress(value: float) -> void:
	_send_or_queue({
		"type": "progress",
		"progress": clampf(value, 0.0, 1.0)
	})


func send_goal_reached() -> void:
	_send_or_queue({"type": "goal_reached"})


func send_tower_proof(image_base64: String) -> void:
	_send_or_queue({
		"type": "tower_proof",
		"image": image_base64
	})


func close_connection() -> void:
	_pending_messages.clear()
	match_ready = false
	room_code = ""
	player_role = ""

	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()

	_was_open = false


func _send_or_queue(data: Dictionary) -> void:
	var state: int = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		_send_now(data)
		return

	_pending_messages.append(data)

	if state == WebSocketPeer.STATE_CONNECTING:
		status_changed.emit("Подключаемся к серверу...")
		return

	_socket = WebSocketPeer.new()
	_was_open = false
	_closed_notice_sent = false

	var error: Error = _socket.connect_to_url(SERVER_URL)
	if error != OK:
		_pending_messages.clear()
		status_changed.emit("Не удалось подключиться. Код: %s" % error)
		return

	status_changed.emit("Подключаемся к серверу...")


func _send_now(data: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_pending_messages.push_front(data)
		return

	var error: Error = _socket.send_text(JSON.stringify(data))
	if error != OK:
		status_changed.emit("Не удалось отправить сообщение серверу.")


func _handle_message(raw_text: String) -> void:
	var parsed: Variant = JSON.parse_string(raw_text)

	if not parsed is Dictionary:
		status_changed.emit("Сервер прислал некорректный ответ.")
		return

	var data: Dictionary = parsed
	var message_type: String = str(data.get("type", ""))

	match message_type:
		"searching":
			status_changed.emit("Ищем случайного соперника...")

		"search_cancelled":
			status_changed.emit("Поиск отменён.")

		"room_created":
			room_code = str(data.get("room", ""))
			room_created.emit(room_code)
			status_changed.emit("Комната создана. Код: %s" % room_code)

		"match_found":
			room_code = str(data.get("room", ""))
			player_role = str(data.get("role", ""))
			match_found.emit(room_code, player_role)
			status_changed.emit("Соперник найден.")

		"game_start":
			room_code = str(data.get("room", room_code))
			match_ready = true
			match_started.emit()
			status_changed.emit("Матч начинается!")

		"progress":
			opponent_progress_received.emit(
				clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
			)

		"event_start":
			network_event_started.emit(
				str(data.get("event", "")),
				int(data.get("direction", 1)),
				float(data.get("warning_duration", 2.2))
			)

		"event_execute":
			network_event_execute.emit()

		"event_end":
			network_event_ended.emit()

		"match_result":
			var result: String = str(data.get("result", ""))
			var message: String = str(data.get("message", "Матч завершён."))
			match_result_received.emit(result, message)
			status_changed.emit(message)

		"tower_proof":
			opponent_proof_received.emit(str(data.get("image", "")))

		"opponent_left":
			match_ready = false
			opponent_left.emit()
			status_changed.emit("Соперник отключился.")

		"error":
			status_changed.emit(str(data.get("message", "Ошибка сервера.")))

		_:
			pass

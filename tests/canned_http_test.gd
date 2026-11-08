class_name CannedHttpTest
extends GutTest
## A base for the tests of what talks HTTP: a small server here (`_server`, on `_port`) that the
## test answers as it likes, and the request it was sent read back as text.

## Nothing listens here, so a request is refused at once.
const CLOSED_ENDPOINT := "http://127.0.0.1:9/v1"
## Waiting for the request gives up after this many milliseconds. Time, not frames: a headless
## frame takes microseconds, so a busy machine (tests run in parallel) used up any frame count
## before the client had connected.
const WAIT_MSEC := 5000

var _server: TCPServer
var _port := 0
## The server's end of the connection the client opened.
var _peer: StreamPeerTCP


func before_each() -> void:
	_server = TCPServer.new()
	# Port 0: the system picks a free one. A fixed range was shared by the parallel test
	# processes, so a late request of one process's test could reach another's server.
	assert_eq(_server.listen(0, "127.0.0.1"), OK, "a port to listen on")
	_port = _server.get_local_port()


func after_each() -> void:
	_server.stop()


## An HTTP response with that status line and body.
static func _response(status: String, body: String) -> String:
	return (
		(
			"HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\n"
			% [status, body.to_utf8_buffer().size()]
		)
		+ "Connection: close\r\n\r\n"
		+ body
	)


## The JSON body of a request, which `_received_request` gave as text.
static func _body_of(request: String) -> Variant:
	return JSON.parse_string(request.substr(request.find("\r\n\r\n") + 4))


## Runs `ask` (which returns what the client made of the answer), answers its request with
## `response` and gives [the request as text, what `ask` returned].
func _ask_and_answer(ask: Callable, response: String) -> Array:
	_peer = null
	var results := []
	var run := func() -> void: results.append(await ask.call())
	run.call()
	var request := await _received_request()
	if request != "":
		_peer.put_data(response.to_utf8_buffer())
		_peer.disconnect_from_host()
	await wait_until(func() -> bool: return not results.is_empty(), 5.0)
	return [request, results[0] if not results.is_empty() else null]


## The whole request the client sent, headers and body, or "" if none came.
func _received_request() -> String:
	var received := PackedByteArray()
	var deadline := Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _peer == null and _server.is_connection_available():
			_peer = _server.take_connection()
		if _peer != null:
			_peer.poll()
			var available := _peer.get_available_bytes()
			if available > 0:
				received.append_array(_peer.get_data(available)[1])
			var text := received.get_string_from_utf8()
			var head_end := text.find("\r\n\r\n")
			var length := RegEx.create_from_string("(?i)content-length: *(\\d+)").search(text)
			# A request without a body, such as a GET, may say no length.
			var body_length := int(length.get_string(1)) if length != null else 0
			if head_end >= 0 and text.length() - head_end - 4 >= body_length:
				return text
		await get_tree().process_frame
	return ""

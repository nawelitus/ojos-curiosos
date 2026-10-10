extends RefCounted
## Caps how many messages each peer may send per second. Pure logic: the
## caller passes the current time.

const MAX_PER_SECOND := 20

var _windows: Dictionary = {}  # peer id -> { "start": float, "count": int }


## True if a message arriving at `now` (seconds) from `peer_id` may be handled.
func allow(peer_id: int, now: float) -> bool:
	var window: Dictionary = _windows.get(peer_id, {"start": now, "count": 0})
	if now - window["start"] >= 1.0:
		window = {"start": now, "count": 0}
	window["count"] += 1
	_windows[peer_id] = window
	return window["count"] <= MAX_PER_SECOND


func forget(peer_id: int) -> void:
	_windows.erase(peer_id)

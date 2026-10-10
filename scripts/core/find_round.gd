extends RefCounted
## Rules of one solo round: which objects to find, what a tap does, hints,
## and the stars earned. Pure logic. Time is the round's own clock (`elapsed`),
## advanced by tick(), so tests need no real waiting.

enum Tap {
	FOUND,     ## a pending target was tapped
	MISS,      ## nothing to find there: counts as a wrong tap and starts the pause
	LOCKED,    ## tapped during the pause after a wrong tap: ignored
	IGNORED,   ## tapped an object already found, or the round is over: no penalty
}

## Pause after a wrong tap. It costs no points; it only stops random mashing.
const LOCKOUT_SECONDS := 1.0
const HINT_COOLDOWN_SECONDS := 30.0
## Up to this many wrong taps still earn the "few mistakes" star.
const MAX_WRONG_TAPS_FOR_STAR := 2

var targets: Array[String] = []
var found: Array[String] = []
var wrong_taps: int = 0
var hints_used: int = 0
var elapsed: float = 0.0

var _locked_until: float = 0.0
var _hint_ready_at: float = 0.0


## Picks `count` different ids from `pool`. Same rng state, same result, so a
## multiplayer host can later draw once for everybody.
static func draw_targets(pool: Array[String], count: int, rng: RandomNumberGenerator) -> Array[String]:
	var remaining := pool.duplicate()
	var drawn: Array[String] = []
	while drawn.size() < count and not remaining.is_empty():
		var index := rng.randi_range(0, remaining.size() - 1)
		drawn.append(remaining[index])
		remaining.remove_at(index)
	return drawn


func _init(p_targets: Array[String]) -> void:
	targets = p_targets.duplicate()


func tick(delta: float) -> void:
	if not is_complete():
		elapsed += maxf(delta, 0.0)


func is_complete() -> bool:
	return found.size() >= targets.size()


func pending() -> Array[String]:
	var result: Array[String] = []
	for target in targets:
		if not found.has(target):
			result.append(target)
	return result


func is_locked() -> bool:
	return elapsed < _locked_until


## `hit_id` is the target under the finger, or "" when there is none.
func register_tap(hit_id: String) -> Tap:
	if is_complete() or found.has(hit_id):
		return Tap.IGNORED
	if is_locked():
		return Tap.LOCKED
	if targets.has(hit_id):
		found.append(hit_id)
		return Tap.FOUND
	wrong_taps += 1
	_locked_until = elapsed + LOCKOUT_SECONDS
	return Tap.MISS


func can_hint() -> bool:
	return not is_complete() and elapsed >= _hint_ready_at


func hint_wait() -> float:
	return maxf(_hint_ready_at - elapsed, 0.0)


## Returns the id of a pending target to point at, or "" if no hint is available.
func use_hint(rng: RandomNumberGenerator) -> String:
	if not can_hint():
		return ""
	var options := pending()
	hints_used += 1
	_hint_ready_at = elapsed + HINT_COOLDOWN_SECONDS
	return options[rng.randi_range(0, options.size() - 1)]


## 0 until the round is complete; then 1 for finishing, +1 for few wrong taps,
## +1 for using no hints.
func stars() -> int:
	if not is_complete():
		return 0
	var total := 1
	if wrong_taps <= MAX_WRONG_TAPS_FOR_STAR:
		total += 1
	if hints_used == 0:
		total += 1
	return total

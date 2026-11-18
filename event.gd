extends Node2D
## Repeating event manager.
## Cycle: 10 seconds calm, then 10 seconds of meteor shower, repeating indefinitely.

const CALM_DURATION := 10.0
const EVENT_DURATION := 10.0

signal meteor_event_started(direction: int) # -1 = left, +1 = right
signal meteor_event_ended

var cycle_time := 0.0
var active := false
var stopped := false

func _process(delta: float) -> void:
	if stopped:
		return
	cycle_time += delta
	var cycle_length := CALM_DURATION + EVENT_DURATION
	var phase := fposmod(cycle_time, cycle_length)
	var should_be_active := phase >= CALM_DURATION
	if should_be_active and not active:
		active = true
		meteor_event_started.emit(-1 if randi_range(0, 1) == 0 else 1)
	elif not should_be_active and active:
		active = false
		meteor_event_ended.emit()

func stop_events() -> void:
	stopped = true
	if active:
		active = false
		meteor_event_ended.emit()

extends Node2D
## Random event manager. Add as child node "Events" under Main.
## Every round has 10 calm seconds, then one equally likely implemented event.
## To add an event: add an ID to the enum/pool and handle its signals below.

enum EventType { METEOR_SHOWER, PLANET_PURGE }

const CALM_DURATION := 10.0
const METEOR_DURATION := 10.0
const PURGE_WARNING_DURATION := 2.2
const PURGE_FADE_DURATION := 0.45

signal meteor_event_started(direction: int) # -1 left, +1 right
signal meteor_event_ended
signal purge_event_started(warning_duration: float)
signal purge_event_execute
signal purge_event_ended

var calm_timer := 0.0
var event_timer := 0.0
var active_event := -1
var stopped := false

func _process(delta: float) -> void:
	if stopped:
		return
	if active_event == -1:
		calm_timer += delta
		if calm_timer >= CALM_DURATION:
			calm_timer -= CALM_DURATION
			_start_random_event()
		return

	event_timer += delta
	match active_event:
		EventType.METEOR_SHOWER:
			if event_timer >= METEOR_DURATION:
				_end_active_event()
		EventType.PLANET_PURGE:
			if event_timer >= PURGE_WARNING_DURATION and event_timer - delta < PURGE_WARNING_DURATION:
				purge_event_execute.emit()
			if event_timer >= PURGE_WARNING_DURATION + PURGE_FADE_DURATION:
				_end_active_event()

func _start_random_event() -> void:
	# All available event types have the same chance; add future events to this pool.
	var choices: Array[int] = [EventType.METEOR_SHOWER, EventType.PLANET_PURGE]
	active_event = choices[randi_range(0, choices.size() - 1)]
	event_timer = 0.0
	match active_event:
		EventType.METEOR_SHOWER:
			meteor_event_started.emit(-1 if randi_range(0, 1) == 0 else 1)
		EventType.PLANET_PURGE:
			purge_event_started.emit(PURGE_WARNING_DURATION)

func _end_active_event() -> void:
	match active_event:
		EventType.METEOR_SHOWER:
			meteor_event_ended.emit()
		EventType.PLANET_PURGE:
			purge_event_ended.emit()
	active_event = -1
	event_timer = 0.0

func stop_events() -> void:
	stopped = true
	if active_event != -1:
		_end_active_event()

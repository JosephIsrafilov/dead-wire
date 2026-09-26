class_name MoonWeather
extends Node

## The moonlight through the north pane, and what passes in front of it.
##
## Clouds dim the moon now and then. The figure in the window dims it exactly
## the same way while it stands there. Sitting with his back to the pane, the
## operator sees the light on the wall and the floor go down and come back —
## and cannot know which it was. The figure touches nothing (GDD §10): it only
## stands between the moon and the room, and it is gone the moment the window
## is looked at, so the light comes back as he turns.
##
## At the end of the watch the same light carries the dawn.

@export var moon_light: SpotLight3D = null
@export var window_event: AttentionObservationTarget = null
## Depth of a dim, 0..1 of the moon's energy. Clouds and the figure share it.
@export var dim_depth: float = 0.55
## Seconds to fall into a dim and to recover from one.
@export var dim_fade_seconds: float = 1.6
## Cloud cadence: a dim every so often, held for a few seconds.
@export var cloud_interval_min: float = 30.0
@export var cloud_interval_max: float = 75.0
@export var cloud_hold_min: float = 3.0
@export var cloud_hold_max: float = 6.5
## Dawn: the moon's cold light warms and strengthens over this long.
@export var dawn_seconds: float = 22.0
@export var dawn_color: Color = Color(0.86, 0.74, 0.62)
@export var dawn_energy_scale: float = 1.9

var dim: float = 0.0
var dawn: float = 0.0

var _rest_energy: float = 0.0
var _night_color: Color = Color.WHITE
var _rng := RandomNumberGenerator.new()
var _until_cloud: float = 0.0
var _cloud_left: float = 0.0
var _dawn_running: bool = false

func _ready() -> void:
	_rng.seed = 18941014
	var office := get_parent()
	if moon_light == null and office != null:
		moon_light = office.get_node_or_null("WindowBounceLight") as SpotLight3D
	if window_event == null and office != null:
		window_event = office.get_node_or_null("WindowObservationEvent") as AttentionObservationTarget
	if moon_light != null:
		_rest_energy = moon_light.light_energy
		_night_color = moon_light.light_color
	_until_cloud = _rng.randf_range(cloud_interval_min, cloud_interval_max)

func _process(delta: float) -> void:
	advance(delta)

## True while something is between the moon and the room: a cloud, or it.
func is_dimmed_now() -> bool:
	return _cloud_left > 0.0 or _figure_present()

func begin_dawn() -> void:
	_dawn_running = true

## Separated from _process so tests can drive the sky deterministically.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	if _cloud_left > 0.0:
		_cloud_left -= delta
	else:
		_until_cloud -= delta
		if _until_cloud <= 0.0:
			_cloud_left = _rng.randf_range(cloud_hold_min, cloud_hold_max)
			_until_cloud = _rng.randf_range(cloud_interval_min, cloud_interval_max)
	var target := dim_depth if is_dimmed_now() and not _dawn_running else 0.0
	dim = move_toward(dim, target, delta * dim_depth / maxf(dim_fade_seconds, 0.01))
	if _dawn_running:
		dawn = minf(dawn + delta / maxf(dawn_seconds, 0.01), 1.0)
	if moon_light != null:
		var d := smoothstep(0.0, 1.0, dawn)
		moon_light.light_energy = _rest_energy * lerpf(1.0, dawn_energy_scale, d) * (1.0 - dim)
		moon_light.light_color = _night_color.lerp(dawn_color, d)

func get_rest_energy() -> float:
	return _rest_energy

func _figure_present() -> bool:
	if window_event == null:
		return false
	var indicator := window_event.get_visual_indicator()
	return indicator != null and indicator.visible

extends Node2D

const INTRO_DURATION = 3.8

@onready var fading_in = false
@onready var progression = 0.0
@onready var fade_duration = get_node("../FrontLayer/Fader/FadeDuration")
@onready var fader = get_node("../FrontLayer/Fader")
@onready var current_fade_nb = 0

var tween : Tween
var title_tween : Tween

func _ready() -> void:
	$TitleMusic.play(0.5)
	
func ease_cam(t : float) -> float:
	return 0.01 + 0.99 * (1.0 - pow(t, 18.0))

func _process(delta: float) -> void:
	if progression < INTRO_DURATION:
		var t = progression / INTRO_DURATION
		progression += delta * ease_cam(t)
		$Path2D/PathFollow2D.progress_ratio = t
		
	if not $Title/Rythm.is_stopped():
		var t = fposmod(0.2 + $Title/Rythm.time_left / $Title/Rythm.wait_time, 1.0)
		var eased_t = pow(sin(2.0 * PI * t - 0.5 * PI), 9.0)
		
		$Title.scale = lerp(Vector2(1.975, 1.975), Vector2(2.1, 2.1), abs(eased_t))
		$Title.rotation = deg_to_rad(3.0) * eased_t
		
		

func fade_in() -> void:
	reset_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(fader, "color", Color(0.0, 0.0, 0.0, 1.0), 0.15)
	fading_in = true
	
func fade_out() -> void:
	reset_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(fader, "color", Color(0.0, 0.0, 0.0, 0.0), 0.15)
	fading_in = false

func reset_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	
func reset_title_tween() -> void:
	if title_tween:
		title_tween.kill()
	title_tween = create_tween()
	
func _on_first_fade_timeout() -> void:
	fade_in()
	fade_duration.start()
	
func _on_second_fade_timeout() -> void:
	fade_in()
	fade_duration.start()
	$CanvasLayer.layer = 2
	$CanvasLayer/Play.disabled = false

func _on_fade_duration_timeout() -> void:
	progression = [0.37, 0.69][current_fade_nb] * INTRO_DURATION
	current_fade_nb += 1
	if fading_in:
		fade_out()

func _on_start_zoom_out_timeout() -> void:
	reset_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property($Path2D/PathFollow2D/Camera2D, "zoom", Vector2(1.0, 1.0), 1.0)
	
func _on_boing_timeout() -> void:
	reset_title_tween()
	title_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	title_tween.tween_property($Title, "scale", Vector2(2.8, 2.8), 0.15)

func _on_boing_end_timeout() -> void:
	reset_title_tween()
	title_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	title_tween.tween_property($Title, "scale", Vector2(1.975, 1.975), 0.6)

func _on_start_dancing_timeout() -> void:
	$Title/Rythm.start()
	$ChipExplosion.restart()
	$ChipRain.emitting = true

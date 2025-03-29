extends Node2D

const INTRO_DURATION = 3.8

@onready var fading_in = false
@onready var progression = 0.0
@onready var fade_duration = get_node("../Fader/FadeDuration")
@onready var fader = get_node("../Fader")
@onready var current_fade_nb = 0

var tween : Tween

func _ready() -> void:
	$TitleMusic.play(0.5)
	
func ease_cam(t : float) -> float:
	return 0.01 + 0.99 * (1.0 - pow(t, 18.0))

func _process(delta: float) -> void:
	if progression < INTRO_DURATION:
		var t = progression / INTRO_DURATION
		progression += delta * ease_cam(t)
		$Path2D/PathFollow2D.progress_ratio = t

func fade_in() -> void:
	reset_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(fader, "color", Color(0.0, 0.0, 0.0, 1.0), 0.1)
	fading_in = true
	
func fade_out() -> void:
	reset_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(fader, "color", Color(0.0, 0.0, 0.0, 0.0), 0.1)
	fading_in = false

func reset_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	
func _on_first_fade_timeout() -> void:
	fade_in()
	fade_duration.start()
	
func _on_second_fade_timeout() -> void:
	fade_in()
	fade_duration.start()
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
	

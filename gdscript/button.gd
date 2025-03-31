extends Button

var tween : Tween

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	

func _on_mouse_entered() -> void:
	if disabled:
		return
	reset_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2(1.07, 1.07), 0.4)
	
func _on_mouse_exited() -> void:
	reset_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)
	
func reset_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween()

func _on_pressed() -> void:
	if $/root/GameRoom/MusicPlayer != null:
		$/root/GameRoom/MusicPlayer.button_sfx()

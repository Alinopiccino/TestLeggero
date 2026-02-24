extends Node2D

@onready var background := $Background
@onready var logo := $Logo

func _ready():
	play_intro()

func play_intro():
	logo.modulate.a = 0.0

	var fade := create_tween()
	fade.tween_property(logo, "modulate:a", 1.0, 0.8)

	await fade.finished
	await get_tree().create_timer(0.4).timeout

	var screen_height := get_viewport_rect().size.y + 300

	# 🔹 1️⃣ Micro movimento verso l'alto (rallenta tantissimo alla fine)
	var pre_slide := create_tween()
	pre_slide.tween_property(background, "position:y", -20, 0.25) \
		.set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)

	#pre_slide.parallel().tween_property(
		#logo,
		#"position:y",
		#logo.position.y - 10,
		#0.1
	#).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await pre_slide.finished
	#await get_tree().create_timer(0.3).timeout
	

	# 🔹 2️⃣ Accelerazione forte verso l’alto
	var slide := create_tween()
	slide.tween_property(background, "position:y", -screen_height, 0.2) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)

	slide.parallel().tween_property(
		logo,
		"position:y",
		logo.position.y - screen_height,
		0.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await slide.finished
	await get_tree().create_timer(0.5).timeout
	
	var next_scene = load("res://Scene/main_menu.tscn").instantiate()
	get_tree().root.add_child(next_scene)
	queue_free()

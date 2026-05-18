extends Button
@onready var texture_rect_distort_target: TextureRect = $"../TextureRect_distort_target"
@onready var texture_rect_fluid_raw: TextureRect = $"../TextureRect_fluid_raw"

func _ready() -> void:
	texture_rect_fluid_raw.visible = false
	text = "Show raw fluid sim"

func _on_pressed() -> void:
	if texture_rect_fluid_raw.visible:
		texture_rect_fluid_raw.visible = false
		text = "Show raw fluid sim"
	else:
		texture_rect_fluid_raw.visible = true
		text = "Show applied as distortion"

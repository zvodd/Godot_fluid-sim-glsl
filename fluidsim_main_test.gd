class_name FluidSimulation
extends Node2D

# exports
@export var resolution : Vector2i = Vector2i(256, 256)
@export var vel_scale : float = 20.0
@export var dt_override : float = 0.016
@export var brush_radius : int = 4
@export var density_amount : float = 0.6
@export var dissipation : float = 0.995

# onready
@onready var sub_vp : SubViewport = $SubViewport
@onready var color_rect : CanvasItem = $SubViewport/ColorRect
@onready var texture_rect: TextureRect = $TextureRect_fluid_raw


# vars
var cpu_image : Image
var gpu_tex : ImageTexture
var mouse_prev : Vector2 = Vector2.ZERO

func _ready() -> void:
	cpu_image = Image.create(resolution.x, resolution.y, false, Image.FORMAT_RGBA8)
	# initialize neutral state: vel = 0 => encoded 0.5, density=0, pressure=0
	var neutral := Color(0.5, 0.5, 0.0, 0.0)
	for y in range(resolution.y):
		for x in range(resolution.x):
			cpu_image.set_pixel(x, y, neutral)

	gpu_tex = ImageTexture.create_from_image(cpu_image)
	# assign texture to shader
	var mat := color_rect.material
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("prev_state", gpu_tex)
		mat.set_shader_parameter("res", Vector2(resolution.x, resolution.y))
		mat.set_shader_parameter("vel_scale", vel_scale)
		mat.set_shader_parameter("dt", dt_override)
		mat.set_shader_parameter("dissipation", dissipation)

	# configure SubViewport
	sub_vp.size = resolution
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	#sub_vp.own_world = true

func _process(_delta: float) -> void:
	# read GPU -> cpu_image (blocking). Keep resolution low.
	_read_gpu()
	# input and inject
	_handle_input()
	# write CPU -> GPU texture
	_write_gpu()

func _read_gpu() -> void:
	var tex := sub_vp.get_texture()
	if tex == null:
		return
	var snap : Image = tex.get_image()
	if snap == null:
		return
	# ensure same size; copy_from handles format conversion
	cpu_image.copy_from(snap)

func _write_gpu() -> void:
	gpu_tex.update(cpu_image)

# public helpers
func inject_at_grid(grid_pos : Vector2i, vel : Vector2, amount : float = 1.0) -> void:
	for oy in range(-brush_radius, brush_radius + 1):
		for ox in range(-brush_radius, brush_radius + 1):
			var tx := grid_pos.x + ox
			var ty := grid_pos.y + oy
			if tx < 0 or ty < 0 or tx >= resolution.x or ty >= resolution.y:
				continue
			# distance falloff
			var d := sqrt(float(ox*ox + oy*oy))
			if d > float(brush_radius):
				continue
			var fall := 1.0 - (d / float(brush_radius))
			var cur : Color = cpu_image.get_pixel(tx, ty)
			# decode current velocity
			var cur_vel := (Vector2(cur.r, cur.g) - Vector2(0.5,0.5)) * 2.0 * vel_scale
			# add injected velocity
			var new_vel := cur_vel + vel * fall
			# clamp to vel_scale
			new_vel.x = clampf(new_vel.x, -vel_scale, vel_scale)
			new_vel.y = clampf(new_vel.y, -vel_scale, vel_scale)
			# encode back
			var enc_r := (new_vel.x / vel_scale) * 0.5 + 0.5
			var enc_g := (new_vel.y / vel_scale) * 0.5 + 0.5
			var enc_b := clampf(cur.b + density_amount * amount * fall, 0.0, 1.0)
			var enc_a := cur.a # leave pressure unchanged on injection
			cpu_image.set_pixel(tx, ty, Color(enc_r, enc_g, enc_b, enc_a))

# private input mapping (simple screen->grid map)
func _handle_input() -> void:
	var target: TextureRect = texture_rect
	
	# Local space mouse (handles scale/pos/rotation)
	var local_mp := target.get_local_mouse_position()
	var rect_size := target.size
	
	# Normalize to 0.0 - 1.0
	var u := clampf(local_mp.x / rect_size.x, 0.0, 1.0)
	var v := clampf(local_mp.y / rect_size.y, 0.0, 1.0)
	
	# Map to grid res
	var grid_pos := Vector2i(
		int(u * float(resolution.x)), 
		int(v * float(resolution.y))
	)
	
	# Delta logic
	var mouse_curr := get_viewport().get_mouse_position()
	var mouse_delta := mouse_curr - mouse_prev
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var vel_pixels := Vector2(mouse_delta.x, -mouse_delta.y) * 2.0
		inject_at_grid(grid_pos, vel_pixels, 1.0)
		
	mouse_prev = mouse_curr

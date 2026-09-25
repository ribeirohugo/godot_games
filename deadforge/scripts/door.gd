extends AnimatableBody3D
## A sliding door filling one map cell. It rises when the player (or, for plain doors, an enemy
## chasing the player) walks up to it and drops again a few seconds after the doorway is clear.
## Key doors carry a glowing band in their color.

const Tex := preload("res://scripts/textures.gd")

const OPEN_TIME := 0.7  # seconds to rise or fall
const HOLD := 3.0  # seconds it stays open once nobody is near

var world
var cell := Vector2i.ZERO
var key := ""  # "", "red" or "blue"
var open_amount := 0.0  # 0 closed, 1 fully open
var target := 0.0
var hold := 0.0
var slab: MeshInstance3D


func setup(world_ref, at: Vector2i, key_color: String, across_x: bool) -> void:
	world = world_ref
	cell = at
	key = key_color
	sync_to_physics = false
	collision_layer = world.LAYER_WORLD
	collision_mask = 0
	var size := Vector3(world.CELL, world.HEIGHT, 0.5) if across_x else Vector3(0.5, world.HEIGHT, world.CELL)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = world.HEIGHT / 2.0
	add_child(col)
	slab = MeshInstance3D.new()
	slab.mesh = Tex.box(size, Vector2(1.0, 1.0))
	slab.position.y = world.HEIGHT / 2.0
	var mat := Tex.material("door" if key == "" else "door_" + key)
	mat.set_shader_parameter("light", world._rgb(world.light_level(position)) * 1.1)
	slab.material_override = mat
	add_child(slab)


func open() -> void:
	if target < 1.0 and open_amount < 0.05:
		world.game.sfx.play_at("door", position + Vector3(0, 2, 0))
	target = 1.0
	hold = HOLD


func _physics_process(delta: float) -> void:
	hold -= delta
	if hold <= 0.0 and target > 0.0:
		if world.doorway_busy(cell):
			hold = 0.5
		else:
			target = 0.0
			world.game.sfx.play_at("door", position + Vector3(0, 2, 0))
	open_amount = move_toward(open_amount, target, delta / OPEN_TIME)
	# Stop a little short of the ceiling so a sliver shows, like the doors of old.
	position.y = open_amount * (world.HEIGHT - 0.25)

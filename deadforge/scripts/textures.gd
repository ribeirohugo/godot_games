extends RefCounted
## Procedural textures, the meshes built from them and the one shader everything in the world uses.
## Nothing is loaded from files: every surface is painted into an Image here.
##
## The shader is unshaded: walls, floors and ceilings carry their light in vertex colors, worked out
## once when the level is built (see world.gd), and moving things set `light` from the level's light
## grid. Pixels with alpha below 1 glow: they ignore the light, like the embers in a cinder's skin.

const SIZE := 64

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 light = vec3(1.0);
uniform float glow = 0.0;
uniform vec2 scroll = vec2(0.0);
uniform float flash = 0.0;
uniform float color_scale = 1.0;  // world surfaces store vertex light at half brightness

void fragment() {
	vec4 t = texture(tex, UV + scroll * TIME);
	vec3 lit = mix(COLOR.rgb * color_scale * light, vec3(1.0), max(glow, 1.0 - t.a));
	ALBEDO = mix(t.rgb * tint.rgb * lit, vec3(1.0, 0.85, 0.7), flash);
}
"""

static var _shader: Shader
static var _textures := {}


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


## A new material using texture `kind`. Every enemy gets its own, so it can flash and be lit alone.
static func material(kind: String, tint := Color.WHITE, glow := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader()
	mat.set_shader_parameter("tex", texture(kind))
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("glow", glow)
	return mat


static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var img := _paint(kind)
		img.generate_mipmaps()
		_textures[kind] = ImageTexture.create_from_image(img)
	return _textures[kind]


# --- Painting ------------------------------------------------------------------------------

static func _noise(seed_value: int, frequency: float, octaves := 3) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise


## Tileable noise in 0..1: sampled on a torus so the texture repeats without seams.
static func _tile(noise: FastNoiseLite, x: int, y: int) -> float:
	var a := TAU * x / SIZE
	var b := TAU * y / SIZE
	var r := SIZE / TAU
	return noise.get_noise_3d(cos(a) * r, sin(a) * r + cos(b) * r * 1.7, sin(b) * r) * 0.5 + 0.5


static func _paint(kind: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var grain := _noise(hash(kind) & 0xffff, 0.35, 2)
	var blotch := _noise((hash(kind) >> 8) & 0xffff, 0.08, 4)
	match kind:
		"brick":
			var shades := {}
			for y in SIZE:
				for x in SIZE:
					var row := y / 8
					var bx := (x + (4 if row % 2 == 1 else 0) + SIZE) % SIZE
					var id := row * 16 + bx / 16
					if not shades.has(id):
						shades[id] = rng.randf_range(-0.07, 0.07)
					var mortar := y % 8 == 7 or bx % 16 == 15
					var n := _tile(grain, x, y) * 0.12 + _tile(blotch, x, y) * 0.18
					var c := Color(0.13, 0.10, 0.09) if mortar else Color(0.45, 0.19, 0.13).lightened(shades[id])
					if not mortar and y % 8 == 0:
						c = c.lightened(0.08)
					img.set_pixel(x, y, c.darkened(0.25 - n))
		"metal", "door", "door_red", "door_blue":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(grain, x, y) * 0.1 + _tile(blotch, x, y) * 0.2
					var c := Color(0.30, 0.32, 0.35).darkened(0.15 - n)
					var px := x % 32
					var py := y % 32
					if px == 0 or py == 0:
						c = Color(0.10, 0.10, 0.12)
					elif px == 1 or py == 1:
						c = c.lightened(0.2)
					elif (px == 4 or px == 28) and (py == 4 or py == 28):
						c = Color(0.62, 0.62, 0.60)
					var rust := _tile(blotch, x + 17, y + 5)
					if rust > 0.62:
						c = c.lerp(Color(0.40, 0.20, 0.10), clampf((rust - 0.62) * 5.0, 0.0, 0.7))
					if kind != "metal":
						c = _door_pixel(kind, x, y, c)
					img.set_pixel(x, y, c)
		"rock":
			var cracks := _noise(91, 0.12, 2)
			cracks.fractal_type = FastNoiseLite.FRACTAL_RIDGED
			for y in SIZE:
				for x in SIZE:
					var n := _tile(blotch, x, y)
					var c := Color(0.33, 0.27, 0.23).lerp(Color(0.46, 0.36, 0.29), n)
					c = c.darkened(0.12 - _tile(grain, x, y) * 0.15)
					if _tile(cracks, x, y) > 0.9:
						c = c.darkened(0.45)
					img.set_pixel(x, y, c)
		"stone":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(grain, x, y) * 0.15 + _tile(blotch, x, y) * 0.2
					var c := Color(0.32, 0.29, 0.26).darkened(0.2 - n)
					var tile := (x / 32 + (y / 32) * 2)
					c = c.lightened([0.0, 0.05, -0.03, 0.02][tile])
					if x % 32 == 0 or y % 32 == 0:
						c = c.darkened(0.45)
					img.set_pixel(x, y, c)
		"grate":
			for y in SIZE:
				for x in SIZE:
					var c := Color(0.06, 0.05, 0.05)
					if x % 8 < 2 or y % 16 < 3:
						c = Color(0.34, 0.33, 0.33).darkened(0.25 - _tile(blotch, x, y) * 0.3)
					if y % 16 == 0 or x % 8 == 0:
						c = c.lightened(0.15)
					img.set_pixel(x, y, c)
		"ceiling":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(grain, x, y) * 0.2 + _tile(blotch, x, y) * 0.3
					var c := Color(0.17, 0.15, 0.14).darkened(0.2 - n)
					if x % 32 == 0 or y % 32 == 0:
						c = c.darkened(0.3)
					img.set_pixel(x, y, c)
		"lava":
			var swirl := _noise(7, 0.06, 4)
			for y in SIZE:
				for x in SIZE:
					var n := _tile(swirl, x, y)
					var c := Color(0.55, 0.06, 0.0).lerp(Color(1.0, 0.45, 0.05), smoothstep(0.35, 0.7, n))
					c = c.lerp(Color(1.0, 0.9, 0.5), smoothstep(0.72, 0.85, n))
					c.a = 0.0
					img.set_pixel(x, y, c)
		"exit":
			for y in SIZE:
				for x in SIZE:
					var d := maxf(absf(x - 31.5), absf(y - 31.5))
					var ring := fmod(d, 10.0) < 2.5
					var c := Color(0.08, 0.20, 0.10)
					if ring:
						c = Color(0.3, 1.0, 0.45)
						c.a = 0.0
					img.set_pixel(x, y, c)
		"flesh":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(blotch, x, y)
					var c := Color(0.36, 0.40, 0.30).lerp(Color(0.46, 0.30, 0.28), n)
					c = c.darkened(0.2 - _tile(grain, x, y) * 0.25)
					if _tile(grain, x + 9, y + 3) > 0.8:
						c = Color(0.35, 0.05, 0.04)
					img.set_pixel(x, y, c)
		"char":
			var cracks := _noise(33, 0.1, 2)
			cracks.fractal_type = FastNoiseLite.FRACTAL_RIDGED
			for y in SIZE:
				for x in SIZE:
					var c := Color(0.10, 0.08, 0.08).lightened(_tile(grain, x, y) * 0.1)
					var k := _tile(cracks, x, y)
					if k > 0.78:
						c = Color(1.0, 0.55, 0.1).lerp(Color(1.0, 0.9, 0.4), (k - 0.78) * 4.0)
						c.a = 0.0
					img.set_pixel(x, y, c)
		"hide":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(blotch, x, y)
					var c := Color(0.42, 0.14, 0.10).lerp(Color(0.25, 0.08, 0.07), n)
					c = c.darkened(0.15 - _tile(grain, x, y) * 0.3)
					img.set_pixel(x, y, c)
		"steel":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(grain, x, y) * 0.15
					var c := Color(0.22, 0.22, 0.24).lightened(n)
					if y % 16 == 0:
						c = Color(0.08, 0.08, 0.09)
					elif y % 16 == 1:
						c = c.lightened(0.25)
					img.set_pixel(x, y, c)
		"glow":
			img.fill(Color(1, 1, 1, 0))
		_:  # "plain": lightly speckled white, tinted by the material
			for y in SIZE:
				for x in SIZE:
					img.set_pixel(x, y, Color.WHITE.darkened(0.25 - _tile(grain, x, y) * 0.25))
	return img


## Doors: hazard stripes along the bottom, and a colored band for the key doors.
static func _door_pixel(kind: String, x: int, y: int, c: Color) -> Color:
	if y >= 54:
		return Color(0.85, 0.65, 0.1) if (x + y) % 12 < 6 else Color(0.08, 0.08, 0.08)
	if x % 16 == 8:
		c = c.darkened(0.35)
	elif x % 16 == 9:
		c = c.lightened(0.15)
	if kind != "door" and y >= 24 and y < 36:
		var band := Color(0.9, 0.12, 0.08) if kind == "door_red" else Color(0.15, 0.35, 1.0)
		if y == 24 or y == 35:
			return band.darkened(0.4)
		band.a = 0.0  # the band glows, so the key doors can be spotted in the dark
		return band
	return c


# --- Meshes --------------------------------------------------------------------------------

## A box whose every face shows the whole texture, `uv_scale` times.
static func box(size: Vector3, uv_scale := Vector2.ONE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size / 2.0
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for face in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var center := n * h
		var eu := u * h
		var ev := v * h
		var corners := [center - eu + ev, center + eu + ev, center + eu - ev, center - eu - ev]
		var uvs := [Vector2(0, 0), Vector2(uv_scale.x, 0), uv_scale, Vector2(0, uv_scale.y)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])
	return st.commit()

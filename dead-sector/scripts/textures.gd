extends RefCounted
## Procedural textures and the materials built from them. Nothing is loaded from files: every surface
## is painted into an Image here. Level surfaces use world-space triplanar mapping, so walls, floors
## and crates of any size show the texture at the same scale without UV work.

const SIZE := 128

## How strongly each surface's relief shows, and whether its light parts are the low ones (mortar).
const RELIEF := {"sandstone": [-3.0], "tiles": [2.5], "slabs": [2.0], "plaster": [2.0], "wood": [3.0],
		"concrete": [2.0], "asphalt": [1.5], "metal": [3.0], "sand": [1.5], "plain": [1.0], "brick": [-3.0],
		"panel": [2.5], "grate": [4.0], "dirt": [2.0], "grass": [1.5], "whitetile": [2.0], "darkmetal": [3.0]}

static var _textures := {}
static var _normals := {}
static var _materials := {}


static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var img := _paint(kind)
		_normals[kind] = _normal_map(img, RELIEF.get(kind, [1.0])[0])
		img.generate_mipmaps()
		_textures[kind] = ImageTexture.create_from_image(img)
	return _textures[kind]


## Bumps from the painted image's brightness (dark mortar and cracks sink in), as a normal map.
static func normal_texture(kind: String) -> Texture2D:
	texture(kind)
	return _normals[kind]


static func _normal_map(img: Image, strength: float) -> ImageTexture:
	var bump := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var v := img.get_pixel(x, y).get_luminance()
			if strength < 0.0:
				v = 1.0 - v
			bump.set_pixel(x, y, Color(v, v, v))
	bump.bump_map_to_normal_map(absf(strength))
	bump.generate_mipmaps()
	return ImageTexture.create_from_image(bump)


## A level surface: `kind` repeats every `meters`, mapped in world space (or per object when local).
static func surface(kind: String, meters := 2.0, tint := Color.WHITE, local := false) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s" % [kind, meters, tint.to_html(), local]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = texture(kind)
		mat.albedo_color = tint
		mat.roughness = 0.9 if not kind in ["metal", "darkmetal", "grate", "panel"] else 0.55
		mat.metallic = 0.3 if kind in ["metal", "darkmetal", "grate"] else 0.0
		mat.normal_enabled = true
		mat.normal_texture = normal_texture(kind)
		mat.normal_scale = 1.0
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = not local
		mat.uv1_scale = Vector3.ONE / meters
		if local:
			mat.uv1_offset = Vector3(0.5, 0.5, 0.5)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials[key] = mat
	return _materials[key]


## A plain color, shared by everything that uses the same one. `viewmodel` materials are for the
## weapon in the player's hands: drawn with their own field of view and squeezed towards the camera,
## so the gun never pokes into a wall.
static func flat(color: Color, glow := 0.0, metal := 0.0, viewmodel := false) -> StandardMaterial3D:
	var key := "flat/%s/%s/%s/%s" % [color.to_html(), glow, metal, viewmodel]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.45 if metal > 0.0 else 0.85
		mat.metallic = metal
		if glow <= 0.0 and color.a >= 1.0:
			# Fine grain, so painted parts don't look like plastic.
			mat.albedo_texture = texture("plain")
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3.ONE * 3.0
			mat.normal_enabled = true
			mat.normal_texture = normal_texture("plain")
			mat.normal_scale = 0.35
		if viewmodel:
			mat.use_z_clip_scale = true
			mat.z_clip_scale = 0.25
			mat.use_fov_override = true
			mat.fov_override = 62.0
		if glow > 0.0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = glow
		if color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = mat
	return _materials[key]


## Like flat(), but the color comes from the mesh's vertices: for models merged into one mesh.
static func painted(metal := 0.0) -> StandardMaterial3D:
	var key := "painted/%s" % metal
	if not _materials.has(key):
		var mat := flat(Color.WHITE, 0.0, metal).duplicate() as StandardMaterial3D
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		_materials[key] = mat
	return _materials[key]


## Thick, faintly green safety glass.
static func glass() -> StandardMaterial3D:
	if not _materials.has("glass"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.7, 0.68, 0.22)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.05
		mat.metallic = 0.4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["glass"] = mat
	return _materials["glass"]


## Dark, still, reflective water.
static func water() -> StandardMaterial3D:
	if not _materials.has("water"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.06, 0.09, 0.08, 0.82)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.04
		mat.metallic = 0.6
		mat.normal_enabled = true
		mat.normal_texture = normal_texture("plain")
		mat.normal_scale = 0.4
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * 0.5
		_materials["water"] = mat
	return _materials["water"]


## A fresh unshaded, see-through material, for effects that fade on their own.
static func fading(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


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
	var grain := _noise(hash(kind) & 0xffff, 0.3, 2)
	var blotch := _noise((hash(kind) >> 8) & 0xffff, 0.05, 4)
	match kind:
		"sand":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(blotch, x, y)
					var c := Color(0.71, 0.58, 0.40).lerp(Color(0.80, 0.68, 0.49), n)
					c = c.darkened(0.08 - _tile(grain, x, y) * 0.16)
					if rng.randf() < 0.012:
						c = c.darkened(0.25)
					img.set_pixel(x, y, c)
		"tiles", "slabs":
			var count := 4 if kind == "tiles" else 2
			var cell := SIZE / count
			var shades := {}
			var base := Color(0.72, 0.62, 0.48) if kind == "tiles" else Color(0.55, 0.55, 0.53)
			for y in SIZE:
				for x in SIZE:
					var id := (y / cell) * count + x / cell
					if not shades.has(id):
						shades[id] = rng.randf_range(-0.08, 0.08)
					var c := base.lightened(shades[id])
					c = c.darkened(0.1 - _tile(grain, x, y) * 0.14 - _tile(blotch, x, y) * 0.08)
					if x % cell < 2 or y % cell < 2:
						c = c.darkened(0.35)
					img.set_pixel(x, y, c)
		"sandstone":
			# Big blocks in running courses, with pale mortar.
			var shades := {}
			for y in SIZE:
				for x in SIZE:
					var row := y / 32
					var bx := (x + (32 if row % 2 == 1 else 0)) % SIZE
					var id := row * 8 + bx / 64
					if not shades.has(id):
						shades[id] = rng.randf_range(-0.06, 0.06)
					var c := Color(0.80, 0.68, 0.50).lightened(shades[id])
					c = c.darkened(0.12 - _tile(grain, x, y) * 0.12 - _tile(blotch, x, y) * 0.12)
					if y % 32 < 2 or bx % 64 < 2:
						c = Color(0.86, 0.80, 0.68).darkened(_tile(grain, x, y) * 0.1)
					elif y % 32 == 2:
						c = c.darkened(0.12)
					img.set_pixel(x, y, c)
		"plaster":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(blotch, x, y)
					var c := Color(0.86, 0.78, 0.64).darkened(0.05 + n * 0.12 - _tile(grain, x, y) * 0.06)
					if n > 0.72:
						# Plaster flaked off, bricks showing through.
						c = Color(0.62, 0.40, 0.28) if (y / 8 + (x / 16) % 2) % 2 == 0 or y % 8 == 0 else Color(0.55, 0.36, 0.25)
					img.set_pixel(x, y, c)
		"wood":
			# A crate side: vertical planks inside a frame.
			for y in SIZE:
				for x in SIZE:
					var plank := x / 21
					var c := Color(0.55, 0.38, 0.21).lightened((plank % 3) * 0.04)
					var ring := sin((x % 21) * 0.9 + _tile(blotch, x, y) * 9.0 + y * 0.03)
					c = c.darkened(0.08 + ring * 0.06 - _tile(grain, x, y) * 0.1)
					if x % 21 == 0:
						c = c.darkened(0.45)
					var frame := x < 12 or x >= SIZE - 12 or y < 12 or y >= SIZE - 12
					if frame:
						c = Color(0.45, 0.30, 0.16).darkened(0.05 - _tile(grain, x, y) * 0.12)
						if x == 11 or y == 11 or x == SIZE - 12 or y == SIZE - 12:
							c = c.darkened(0.5)
					if absi(x - y) < 7 or absi(x + y - SIZE) < 7:
						if not frame:
							c = Color(0.47, 0.32, 0.17).darkened(0.05 - _tile(grain, x, y) * 0.1)
					img.set_pixel(x, y, c)
		"concrete":
			for y in SIZE:
				for x in SIZE:
					var c := Color(0.58, 0.58, 0.56).darkened(0.1 + _tile(blotch, x, y) * 0.16 - _tile(grain, x, y) * 0.12)
					if x % 64 < 2 or y % 64 < 2:
						c = c.darkened(0.3)
					if (x % 64 == 12 or x % 64 == 52) and (y % 64 == 12 or y % 64 == 52):
						c = c.darkened(0.45)
					img.set_pixel(x, y, c)
		"asphalt":
			for y in SIZE:
				for x in SIZE:
					var c := Color(0.25, 0.25, 0.26).lightened(_tile(grain, x, y) * 0.12)
					c = c.darkened(_tile(blotch, x, y) * 0.2)
					if rng.randf() < 0.03:
						c = c.lightened(0.18)
					img.set_pixel(x, y, c)
		"metal":
			# Corrugated container wall, tinted by the material.
			for y in SIZE:
				for x in SIZE:
					var rib := sin(x * TAU / 16.0)
					var c := Color(0.72, 0.72, 0.72).lightened(rib * 0.12)
					c = c.darkened(_tile(blotch, x, y) * 0.18 - _tile(grain, x, y) * 0.05)
					var rust := _tile(blotch, x + 40, y + 11)
					if rust > 0.66:
						c = c.lerp(Color(0.45, 0.25, 0.12), clampf((rust - 0.66) * 4.0, 0.0, 0.8))
					img.set_pixel(x, y, c)
		"brick":
			# Red-brown bricks in stretcher bond, with grey mortar and soot.
			var shades := {}
			for y in SIZE:
				for x in SIZE:
					var row := y / 16
					var bx := (x + (16 if row % 2 == 1 else 0)) % SIZE
					var id := row * 4 + bx / 32
					if not shades.has(id):
						shades[id] = rng.randf_range(-0.1, 0.1)
					var c := Color(0.52, 0.27, 0.19).lightened(shades[id])
					c = c.darkened(0.1 - _tile(grain, x, y) * 0.16 + _tile(blotch, x, y) * 0.15)
					if y % 16 < 2 or bx % 32 < 2:
						c = Color(0.55, 0.53, 0.5).darkened(_tile(grain, x, y) * 0.2)
					img.set_pixel(x, y, c)
		"panel":
			# Laboratory wall panels: pale, with seams, rivets and a dark kick strip.
			for y in SIZE:
				for x in SIZE:
					var c := Color(0.78, 0.8, 0.8).darkened(0.04 + _tile(blotch, x, y) * 0.1 - _tile(grain, x, y) * 0.05)
					if x % 64 < 2 or y % 64 < 2:
						c = c.darkened(0.4)
					elif x % 64 == 4 and y % 16 == 8:
						c = c.darkened(0.3)
					if y > SIZE - 10:
						c = Color(0.25, 0.27, 0.28).darkened(_tile(grain, x, y) * 0.1)
					img.set_pixel(x, y, c)
		"grate":
			# Steel floor grating over darkness.
			for y in SIZE:
				for x in SIZE:
					var c := Color(0.04, 0.04, 0.045)
					if x % 16 < 3 or y % 8 < 2:
						c = Color(0.46, 0.47, 0.48).darkened(_tile(blotch, x, y) * 0.3 - _tile(grain, x, y) * 0.1)
						var rust := _tile(blotch, x + 17, y + 5)
						if rust > 0.68:
							c = c.lerp(Color(0.42, 0.24, 0.12), 0.5)
					img.set_pixel(x, y, c)
		"dirt":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(blotch, x, y)
					var c := Color(0.36, 0.30, 0.22).lerp(Color(0.45, 0.38, 0.27), n)
					c = c.darkened(0.1 - _tile(grain, x, y) * 0.2)
					if rng.randf() < 0.02:
						c = c.lightened(0.2)
					img.set_pixel(x, y, c)
		"grass":
			for y in SIZE:
				for x in SIZE:
					var n := _tile(blotch, x, y)
					var c := Color(0.25, 0.3, 0.14).lerp(Color(0.38, 0.4, 0.2), n)
					c = c.darkened(0.12 - _tile(grain, x, y) * 0.24)
					if n < 0.3:
						c = c.lerp(Color(0.4, 0.34, 0.24), 0.5)  # bare, trampled earth
					img.set_pixel(x, y, c)
		"whitetile":
			for y in SIZE:
				for x in SIZE:
					var c := Color(0.82, 0.84, 0.83).darkened(0.03 + _tile(blotch, x, y) * 0.12 - _tile(grain, x, y) * 0.04)
					if x % 32 < 2 or y % 32 < 2:
						c = Color(0.45, 0.46, 0.45).darkened(_tile(blotch, x, y) * 0.3)
					img.set_pixel(x, y, c)
		"darkmetal":
			# Black Division plating: dark panels with bolts and scuffs.
			for y in SIZE:
				for x in SIZE:
					var c := Color(0.2, 0.21, 0.22).lightened(_tile(grain, x, y) * 0.08 - _tile(blotch, x, y) * 0.06)
					if x % 64 < 2 or y % 32 < 2:
						c = c.darkened(0.5)
					elif (x % 64 == 6 or x % 64 == 58) and (y % 32 == 6 or y % 32 == 26):
						c = c.lightened(0.3)
					img.set_pixel(x, y, c)
		_:  # "plain": lightly speckled white, tinted by the material
			for y in SIZE:
				for x in SIZE:
					img.set_pixel(x, y, Color.WHITE.darkened(0.12 - _tile(grain, x, y) * 0.12))
	return img

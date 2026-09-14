shader_type canvas_item;
// Light sweeping around the metallic border of the round logo.

uniform float angle = 0.0; // radians, where the brightest point of the shine is
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float ring_inner = 0.81; // ring starts at this fraction of the logo radius
uniform float ring_outer = 0.995;
uniform vec3 shine_color : source_color = vec3(1.0, 1.0, 1.0);

float angular_distance(float a, float b) {
	return abs(mod(a - b + PI, TAU) - PI);
}

void fragment() {
	vec4 tex = COLOR; // already the texture multiplied by modulate
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);

	float ring = smoothstep(ring_inner - 0.02, ring_inner + 0.02, r) * (1.0 - smoothstep(ring_outer - 0.01, ring_outer, r));
	// Only the grey metal shines, not the blue circuit board.
	float saturation = max(tex.r, max(tex.g, tex.b)) - min(tex.r, min(tex.g, tex.b));
	float metal = ring * (1.0 - smoothstep(0.12, 0.25, saturation));

	float d = angular_distance(a, angle);
	// Wide soft glow, a sharp bright core, and a fainter reflection on the opposite side.
	float band = 0.5 * exp(-d * d * 10.0) + 1.2 * exp(-d * d * 90.0) + 0.3 * exp(-pow(angular_distance(a, angle + PI), 2.0) * 40.0);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float light = band * metal * strength * (0.5 + luma);

	// Darken the rest of the ring a little so the moving light stands out.
	vec3 base = tex.rgb * (1.0 - 0.25 * metal * strength);
	COLOR = vec4(base + shine_color * light, tex.a);
}

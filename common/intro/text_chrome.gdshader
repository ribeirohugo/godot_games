shader_type canvas_item;
// Chrome gradient for the "WebPlatinum" title (see common/design/intro_text_design.png):
// bright at the top, a sharp dark horizon line near the bottom, then lighter again.

uniform float text_top = 0.0;     // local y of the top of the capital letters
uniform float text_bottom = 1.0;  // local y of the baseline
uniform float sweep_x = -10000.0; // local x of the moving highlight
uniform float sweep_width = 60.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

vec3 chrome(float t) {
	vec3 top = vec3(242.0, 244.0, 247.0) / 255.0;
	vec3 upper = vec3(205.0, 214.0, 224.0) / 255.0;
	vec3 horizon = vec3(115.0, 127.0, 141.0) / 255.0;
	vec3 lower = vec3(200.0, 206.0, 215.0) / 255.0;
	if (t < 0.66) {
		return mix(top, upper, t / 0.66);
	} else if (t < 0.76) {
		return mix(upper, horizon, smoothstep(0.66, 0.76, t));
	}
	return mix(horizon, lower, clamp((t - 0.76) / 0.24, 0.0, 1.0));
}

void fragment() {
	float t = clamp((local_pos.y - text_top) / (text_bottom - text_top), 0.0, 1.0);
	float dx = (local_pos.x - sweep_x) / sweep_width;
	vec3 color = chrome(t) + vec3(0.35) * exp(-dx * dx);
	COLOR = vec4(min(color, vec3(1.0)), COLOR.a);
}

shader_type canvas_item;
render_mode unshaded;

uniform vec2 curve_factor = vec2(8.0, 8.0);
uniform float zoom: hint_range(0.5, 2) = 1.05;
uniform float scanline_count: hint_range(0, 1080) = 50;

vec2 uv_curve(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	
	uv.x *= 1.0 + pow(abs(uv.y) / curve_factor.y, 2.0);
	uv.y *= 1.0 + pow(abs(uv.x) / curve_factor.x, 2.0);
	
	uv /= zoom;
	
	uv = (uv / 2.0) + 0.5;
	
	return uv;
}

void fragment() {
	float r = texture(SCREEN_TEXTURE, uv_curve(SCREEN_UV) + vec2(SCREEN_PIXEL_SIZE.x * 1.0, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv_curve(SCREEN_UV) + vec2(SCREEN_PIXEL_SIZE.x * 0.0, 0.0)).g;
	float b = texture(SCREEN_TEXTURE, uv_curve(SCREEN_UV) + vec2(SCREEN_PIXEL_SIZE.x *-1.0, 0.0)).b;
	
	float s = sin(uv_curve(SCREEN_UV).y * scanline_count * 2.0);
	s = (s * 0.5 + 0.5) * 0.9 + 0.1;
	
	vec4 scanline = vec4(vec3(pow(s, 0.25)), 1.0);
	
	COLOR = vec4(r, g, b, 1.0) * scanline;
}
shader_type canvas_item;
render_mode unshaded;

uniform float pixel_size : hint_range(1.0, 10.0, 1.0) = 1.0;

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * pixel_size;
	vec2 sample_uv = floor(UV / step_uv) * step_uv + step_uv * 0.5;
	COLOR = texture(TEXTURE, sample_uv);
}

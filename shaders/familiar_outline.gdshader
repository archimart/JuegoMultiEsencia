shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 4.0) = 1.0;
uniform vec4  outline_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a > 0.1) {
		COLOR = col;
	} else {
		vec2 px = outline_width * TEXTURE_PIXEL_SIZE;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2( px.x,  0.0 )).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x,  0.0 )).a);
		a = max(a, texture(TEXTURE, UV + vec2( 0.0,   px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2( 0.0,  -px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);
		COLOR = vec4(outline_color.rgb, outline_color.a * step(0.1, a));
	}
}

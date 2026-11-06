shader_type canvas_item;

// Color de referencia del cabello en el sprite original (detectado por distancia).
// Sin source_color: se comparan valores sRGB directamente, igual que lo que
// devuelve texture() en GL Compatibility.
uniform vec4 hair_source = vec4(0.761, 0.557, 0.239, 1.0);
uniform vec4 hair_target = vec4(0.761, 0.557, 0.239, 1.0);
// Tolerancia de detección (0.0 = solo píxeles exactos, mayor = más píxeles afectados)
uniform float threshold: hint_range(0.01, 0.8) = 0.32;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a < 0.05) {
		COLOR = col;
		return;
	}

	float dist = length(col.rgb - hair_source.rgb);
	if (dist <= threshold) {
		// Preservar luminancia relativa del píxel respecto al color fuente.
		// Esto mantiene sombras y brillos del cabello con el nuevo color.
		float src_lum = dot(hair_source.rgb, vec3(0.299, 0.587, 0.114));
		float pix_lum = dot(col.rgb,         vec3(0.299, 0.587, 0.114));
		float ratio   = (src_lum > 0.001) ? clamp(pix_lum / src_lum, 0.0, 2.5) : 1.0;
		COLOR = vec4(clamp(hair_target.rgb * ratio, 0.0, 1.0), col.a);
	} else {
		COLOR = col;
	}
}

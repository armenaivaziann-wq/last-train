shader_type canvas_item;
// Золотой вертикальный градиент для логотипа: светлые пиксели текста окрашиваются,
// тёмная обводка остаётся как есть.

uniform vec4 top_color : source_color = vec4(1.0, 0.95, 0.6, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.6, 0.18, 1.0);
uniform float height = 100.0;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float t = clamp(local_y / height, 0.0, 1.0);
	vec3 grad = mix(top_color.rgb, bottom_color.rgb, t);
	COLOR = vec4(mix(c.rgb, grad, step(0.5, lum)), c.a);
}

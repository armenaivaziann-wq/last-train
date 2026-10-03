shader_type canvas_item;
// Вид записи камеры наблюдения: холодный тон, строки развёртки, виньетка, лёгкий шум.
// night — ночной режим (улучшение камер): зелёный усилитель яркости.

uniform float night = 0.0;
uniform float time_s = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float gray = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 tint = mix(c.rgb, vec3(gray) * vec3(0.8, 0.95, 1.12), 0.4);
	vec3 nv = vec3(gray * 0.55, gray * 1.45 + 0.06, gray * 0.65);
	tint = mix(tint, nv, night);
	float scan = 0.9 + 0.1 * sin(UV.y * 700.0 + time_s * 4.0);
	float vig = smoothstep(0.9, 0.3, distance(UV, vec2(0.5)));
	float n = fract(sin(dot(floor(UV * 240.0) + vec2(time_s * 37.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(tint * scan * (0.62 + 0.38 * vig) + (n - 0.5) * 0.06, 1.0);
}

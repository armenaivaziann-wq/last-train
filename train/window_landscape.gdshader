shader_type canvas_item;
// Пейзаж за окнами вагонов: слои с параллаксом (небо, горы, лес, ближний план),
// туннель, огни станции и капли дождя на стекле. Рисуется за лицевой стеной вагонов.

uniform sampler2D sky_tex : repeat_enable, filter_nearest;
uniform sampler2D mountains_tex : repeat_enable, filter_nearest;
uniform sampler2D forest_tex : repeat_enable, filter_nearest;
uniform sampler2D near_tex : repeat_enable, filter_nearest;
uniform sampler2D tunnel_tex : repeat_enable, filter_nearest;
uniform sampler2D station_tex : repeat_enable, filter_nearest;
uniform sampler2D rain_tex : repeat_enable, filter_nearest;
uniform vec2 rect_size = vec2(1376.0, 48.0);
uniform float scroll = 0.0;
uniform float tunnel = 0.0;
uniform float station = 0.0;
uniform float rain = 0.0;
uniform float rain_time = 0.0;

vec4 layer(sampler2D tex, vec2 px, float speed) {
	vec2 ts = vec2(textureSize(tex, 0));
	vec2 uv = vec2((px.x + floor(scroll * speed)) / ts.x, px.y / ts.y);
	return texture(tex, uv);
}

void fragment() {
	vec2 px = floor(UV * rect_size);
	vec4 col = layer(sky_tex, px, 0.02);
	vec4 m = layer(mountains_tex, px, 0.08);
	col = mix(col, m, m.a);
	vec4 f = layer(forest_tex, px, 0.3);
	col = mix(col, f, f.a);
	vec4 n = layer(near_tex, px, 1.0);
	col = mix(col, n, n.a);
	vec4 st = layer(station_tex, px, 0.9);
	col = mix(col, st, st.a * station);
	vec4 tu = layer(tunnel_tex, px, 1.0);
	col = mix(col, tu, tunnel);
	if (rain > 0.001) {
		vec2 rts = vec2(textureSize(rain_tex, 0));
		vec2 rp = floor(px + vec2(rain_time * 30.0, -rain_time * 55.0));
		vec4 r = texture(rain_tex, rp / rts);
		col.rgb = mix(col.rgb, r.rgb, r.a * rain);
		col.rgb = mix(col.rgb, vec3(0.25, 0.3, 0.5), 0.12 * rain);
	}
	COLOR = vec4(col.rgb, 1.0);
}

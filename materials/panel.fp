#version 140

in mediump vec2 var_uv;
in mediump float var_facing;

out vec4 out_fragColor;

// Per cell (one texel each): r target, g judged coverage, b unjudged coverage, a contact.
uniform mediump sampler2D cells;
// The same texture, filtered, for soft contact shadows.
uniform mediump sampler2D soft;
// Per cell, r: how strongly the selected piece casts onto it (outlined in `accent`).
uniform mediump sampler2D focus;
// Per cell, the light received and wanted: rgb a glass colour when a = 1,
// darkness (ink) when a = 0.
uniform mediump sampler2D received;
uniform mediump sampler2D target;

uniform fs_uniforms
{
    // xy: grid size in cells, z: margin around the grid in cells
    mediump vec4 dims;
    // x: opacity, y: pulse (1 at the moment a wall is satisfied, fading), z: satisfied glow
    mediump vec4 opacity;
    // the selected piece's colour
    mediump vec4 accent;
    mediump vec4 base;
    mediump vec4 ink;
    mediump vec4 warn;
};

float roundedBox(vec2 p, vec2 half_size, float radius)
{
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main()
{
    vec2 grid = var_uv * dims.xy;
    vec2 cell = floor(grid);
    vec2 local = fract(grid) - 0.5;

    // Panel body: a rounded slab filling the quad. Panels seen from behind fade out.
    float body_d = roundedBox(grid - dims.xy * 0.5, dims.xy * 0.5 + dims.z, 0.32);
    float body_mask = (1.0 - smoothstep(-0.02, 0.02, body_d)) * smoothstep(0.0, 0.2, var_facing) * opacity.x;
    if (body_mask <= 0.0)
    {
        discard;
    }

    bool inside = all(greaterThanEqual(var_uv, vec2(0.0))) && all(lessThan(var_uv, vec2(1.0)));
    vec2 cell_uv = (cell + 0.5) / dims.xy;
    vec4 s = inside ? texture(cells, cell_uv) : vec4(0.0);
    vec4 received_t = inside ? texture(received, cell_uv) : vec4(0.0);
    vec4 want_t = inside ? texture(target, cell_uv) : vec4(0.0);
    vec3 received_color = mix(ink.rgb, received_t.rgb, received_t.a);
    vec3 want_color = mix(ink.rgb, want_t.rgb, want_t.a);
    // Covered with the wrong light: the wanted colour stays visible as a ring over the fill.
    float wrong = s.r * s.g * smoothstep(0.04, 0.15, distance(received_color, want_color));
    float contact = texture(soft, var_uv).a;
    // Unjudged coverage (the floor's live shadow) and contact are read filtered, so both are soft.

    float aa = max(0.015, length(fwidth(grid)));
    float d = roundedBox(local, vec2(0.44), 0.12);
    float fill = inside ? 1.0 - smoothstep(-aa, aa, d) : 0.0;
    float ring = 1.0 - smoothstep(0.0, 2.0 * aa, abs(d + 0.04) - 0.025);
    float grown = roundedBox(local, vec2(0.44) * mix(0.45, 1.0, s.g), 0.12 * mix(0.6, 1.0, s.g));
    float covered = inside ? 1.0 - smoothstep(-aa, aa, grown) : 0.0;
    float shade = texture(soft, var_uv).b;

    vec3 color = base.rgb * (1.0 - 0.14 * contact);
    color = mix(color, color * 0.93, fill);
    color = mix(color, base.rgb * vec3(0.8, 0.81, 0.86), shade * mix(0.55, 1.0, fill));
    color = mix(color, mix(base.rgb, want_color, mix(0.6, 1.0, want_t.a)), s.r * ring);
    color = mix(color, mix(warn.rgb, received_color, s.r), s.g * covered);
    color = mix(color, want_color, wrong * ring);

    float echo = inside ? texture(focus, cell_uv).r : 0.0;
    float echo_d = roundedBox(local, vec2(0.485), 0.16);
    float echo_ring = 1.0 - smoothstep(0.0, 2.0 * aa, abs(echo_d + 0.025) - 0.022);
    vec3 echo_color = accent.rgb * 0.82;
    color = mix(color, echo_color, echo * echo_ring);
    color = mix(color, mix(color, accent.rgb, 0.35), echo * covered * 0.5);

    float frame = 1.0 - smoothstep(0.0, 0.05, abs(body_d + 0.05) - 0.02 - 0.03 * opacity.z);
    vec3 frame_color = mix(base.rgb * 0.86, mix(base.rgb, ink.rgb, 0.7), opacity.z);
    color = mix(color, frame_color, frame * (0.6 + 0.4 * opacity.z));
    color = mix(color, vec3(1.0), 0.18 * opacity.y * (fill + frame));

    out_fragColor = vec4(color, body_mask);
}

#version 140

in highp vec3 var_position;
in mediump vec3 var_normal;
in mediump vec2 var_uv;
in mediump vec4 var_edge;
in mediump float var_ao;
in mediump vec3 var_key;
in mediump vec3 var_up;

out vec4 out_fragColor;

uniform fs_uniforms
{
    mediump vec4 tint;
    // x: selection highlight, y: x-ray (see-through), z: invalid placement, w: hover
    mediump vec4 fx;
    // x: pattern number (1..6) drawn on the faces so pieces differ by more than colour; 0 = none
    mediump vec4 pattern;
    mediump vec4 sky;
    mediump vec4 ground;
    mediump vec4 key_color;
    // x: 1 for glass, drawn as a filter that multiplies what lies behind it
    mediump vec4 glass;
    // x: highlight along outer edges, y: brightness at the outline, z: darkening along seams
    mediump vec4 edges;
};

// Coverage of a simple pattern in face uv: dots, stripes, cross, rings, bars or checks.
float patternMask(float id, vec2 uv)
{
    vec2 p = uv - 0.5;
    if (id < 1.5) return 1.0 - smoothstep(0.1, 0.13, length(p));
    if (id < 2.5) return step(0.5, fract((uv.x + uv.y) * 3.0));
    if (id < 3.5) return max(1.0 - smoothstep(0.05, 0.08, abs(p.x)), 1.0 - smoothstep(0.05, 0.08, abs(p.y)));
    if (id < 4.5) return 1.0 - smoothstep(0.02, 0.05, abs(length(p) - 0.22));
    if (id < 5.5) return step(0.5, fract(uv.y * 3.0));
    return abs(step(0.5, fract(uv.x * 2.0)) - step(0.5, fract(uv.y * 2.0)));
}

// Distance to the nearest face side whose flag (per side: u0, u1, v0, v1) is set.
float flaggedDistance(vec4 flags)
{
    vec4 d = vec4(var_uv.x, 1.0 - var_uv.x, var_uv.y, 1.0 - var_uv.y);
    vec4 masked = mix(vec4(1.0), d, flags);
    return min(min(masked.x, masked.y), min(masked.z, masked.w));
}

void main()
{
    vec3 n = normalize(var_normal);
    vec3 v = normalize(-var_position);

    vec3 hemi = mix(ground.rgb, sky.rgb, dot(n, var_up) * 0.5 + 0.5);
    vec3 key = key_color.rgb * max(dot(n, var_key), 0.0);
    float occlusion = mix(0.62, 1.0, var_ao);
    vec3 base = tint.rgb;
    if (pattern.x > 0.5)
    {
        base = mix(base, base * 0.78, patternMask(pattern.x, var_uv));
    }
    vec3 lit = (hemi + key) * occlusion;
    // Glass keeps its filter colour, paler on lit faces so the piece still reads as a solid.
    vec3 color = glass.x > 0.5 ? mix(base, vec3(1.0), 0.35 * clamp(dot(lit, vec3(0.333)) - 0.6, 0.0, 1.0)) : base * lit;

    // Edge lines are at least about a pixel wide and fade as they would get thinner, so
    // they stay crisp up close and never shimmer in the distance.
    float pixel = length(fwidth(var_uv));
    float outer = flaggedDistance(var_edge);
    float seam = flaggedDistance(vec4(1.0) - var_edge);
    float outer_width = max(0.025, pixel);
    float seam_width = max(0.02, pixel);
    color += vec3(edges.x) * (1.0 - smoothstep(0.0, max(0.08, 2.0 * pixel), outer));
    color *= mix(edges.y, 1.0, smoothstep(0.0, outer_width, outer));
    float seam_fade = clamp(0.02 / seam_width, 0.0, 1.0);
    color *= mix(1.0 - edges.z * seam_fade, 1.0, smoothstep(0.0, seam_width, seam));

    // Selection lifts the whole piece and adds a rim light in a pale version of its own colour,
    // leaving the edges alone so it never reads as the bevel highlight. Hover is a lighter lift.
    float rim = pow(1.0 - max(dot(n, v), 0.0), 2.5);
    vec3 rim_color = mix(tint.rgb, vec3(1.0), 0.55);
    color += vec3(0.06) * rim;
    color = mix(color, color * 1.06 + 0.03, fx.x);
    color += rim_color * rim * 0.35 * fx.x;
    color = mix(color, color * 1.05 + 0.025, fx.w * (1.0 - fx.x));
    float band = 1.0 - smoothstep(0.0, 0.14, outer);

    float grey = dot(color, vec3(0.3, 0.59, 0.11));
    color = mix(color, vec3(grey) * vec3(1.0, 0.92, 0.92), 0.65 * fx.z);
    color = mix(color, vec3(0.93, 0.4, 0.38), fx.z * band);

    float alpha = (1.0 - 0.5 * fx.y) * (1.0 - 0.4 * fx.z);
    out_fragColor = glass.x > 0.5 ? vec4(min(mix(vec3(1.0), color, alpha), 1.0), 1.0) : vec4(color * alpha, alpha);
}

#version 140

in highp vec3 var_position;
in mediump vec3 var_normal;
in mediump vec3 var_tangent;
in mediump vec2 var_uv;
in mediump vec4 var_edge;
in mediump float var_ao;
in mediump vec3 var_key;
in mediump vec3 var_up;

out vec4 out_fragColor;

uniform fs_uniforms
{
    mediump vec4 tint;
    // x: selection highlight, y: x-ray (0 solid .. 1 a ghost), z: invalid placement, w: hover
    mediump vec4 fx;
    // x: pattern number (1..6) drawn on the faces so pieces differ by more than colour; 0 = none
    mediump vec4 pattern;
    mediump vec4 sky;
    mediump vec4 ground;
    mediump vec4 key_color;
    // x: 1 for glass: frosted coloured glass blended over what lies behind it
    mediump vec4 glass;
    // x: bevel width in face uv, y: gloss, z: fill light from the viewer
    mediump vec4 finish;
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

// The face normal turned over the piece's outer edges, as if the block were chamfered and
// rounded: up to halfway towards the neighbouring face at the edge, a cube corner where two meet.
vec3 bevelled(vec3 n, float width)
{
    vec3 t = normalize(var_tangent);
    vec3 b = cross(n, t);
    vec4 d = vec4(var_uv.x, 1.0 - var_uv.x, var_uv.y, 1.0 - var_uv.y);
    vec4 x = var_edge * smoothstep(0.0, 1.0, clamp(1.0 - d / width, 0.0, 1.0)) * 0.7071;
    vec2 tilt = vec2(x.y - x.x, x.w - x.z);
    tilt *= min(1.0, 0.8165 / max(length(tilt), 0.001));
    return normalize(n * sqrt(1.0 - dot(tilt, tilt)) + t * tilt.x + b * tilt.y);
}

void main()
{
    vec3 v = normalize(-var_position);
    vec3 n = bevelled(normalize(var_normal), finish.x);
    float outer = flaggedDistance(var_edge);
    float rim = 1.0 - smoothstep(0.0, finish.x * 1.5, outer);

    float up = dot(n, var_up);
    vec3 hemi = mix(ground.rgb, sky.rgb, up * 0.5 + 0.5);
    vec3 key = key_color.rgb * (max(dot(n, var_key), 0.0) + finish.z * max(dot(n, v), 0.0));
    float occlusion = mix(0.62, 1.0, var_ao);
    vec3 lit = (hemi + key) * occlusion;

    // A glossy surface: a broad sheen from the key light and the room at grazing angles.
    vec3 h = normalize(var_key + v);
    float fresnel = 0.04 + 0.96 * pow(1.0 - max(dot(n, v), 0.0), 5.0);
    vec3 room = mix(ground.rgb, sky.rgb * 1.2, dot(reflect(-v, n), var_up) * 0.5 + 0.5);
    float sheen = pow(max(dot(n, h), 0.0), 14.0);

    vec3 base = tint.rgb;
    if (pattern.x > 0.5)
    {
        base = mix(base, base * 0.78, patternMask(pattern.x, var_uv));
    }

    // X-ray fades the piece toward a ghost: faint inside, its outline kept, so walls read through.
    float outline = 1.0 - smoothstep(0.0, 0.08, outer);
    float see_through = mix(1.0, mix(0.08, 0.55, outline), fx.y);

    vec3 color;
    float alpha;
    if (glass.x > 0.5)
    {
        // Frosted glass in a deep version of its light's colour, clearer in the middle of each
        // face and denser towards edges and grazing angles, with bright edges and glints.
        vec3 deep = base * base;
        float density = mix(0.55, 0.9, max(rim, fresnel));
        vec3 body = deep * (0.55 + 0.6 * lit);
        vec3 glint = key_color.rgb * pow(max(dot(n, h), 0.0), 40.0) * 0.35 + vec3(0.12) * rim * fresnel + room * fresnel * 0.2;
        alpha = density * see_through;
        color = body + glint / max(alpha, 0.05);
    }
    else
    {
        color = base * lit + (key_color.rgb * sheen * 0.9 + room * fresnel * 0.6) * finish.y * occlusion;
        alpha = see_through;
    }

    // Selection lifts the whole piece and adds a rim light in a pale version of its own colour.
    // Hover is a lighter lift.
    float edge_light = pow(1.0 - max(dot(n, v), 0.0), 2.5);
    vec3 rim_color = mix(tint.rgb, vec3(1.0), 0.55);
    color = mix(color, color * 1.06 + 0.03, fx.x);
    color += rim_color * edge_light * 0.35 * fx.x;
    color = mix(color, color * 1.05 + 0.025, fx.w * (1.0 - fx.x));

    float band = 1.0 - smoothstep(0.0, 0.14, outer);
    float grey = dot(color, vec3(0.3, 0.59, 0.11));
    color = mix(color, vec3(grey) * vec3(1.0, 0.92, 0.92), 0.65 * fx.z);
    color = mix(color, vec3(0.93, 0.4, 0.38), fx.z * band);

    alpha *= 1.0 - 0.4 * fx.z;
    out_fragColor = vec4(color * alpha, alpha);
}

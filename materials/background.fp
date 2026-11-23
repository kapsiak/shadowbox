#version 140

in mediump vec2 var_screen;

out vec4 out_fragColor;

// The workshop wall behind the board: plaster lit from above, a window's light falling across
// its upper left with dust drifting in it, and a vignette. Kept away from the middle of the
// screen, where the board stands.
uniform fs_uniforms
{
    mediump vec4 top;
    mediump vec4 bottom;
    // rgb: the window light's colour, a: its strength
    mediump vec4 window_light;
    // x: seconds, y: window aspect (width / height), z: 1 to keep the dust still
    mediump vec4 clock;
};

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float plaster(vec2 p)
{
    return noise(p * 3.0) * 0.5 + noise(p * 9.0) * 0.3 + noise(p * 60.0) * 0.2;
}

// The window's light on the wall: four panes, sheared as light falling from the upper left,
// soft at the edges. p is centred on the screen, in units of screen height.
float windowPatch(vec2 p, float aspect)
{
    vec2 q = p - vec2(-0.36 * aspect, 0.16);
    q.x += q.y * 0.45;
    q /= vec2(0.24, 0.3);
    vec2 inside = smoothstep(vec2(-1.0), vec2(-0.75), q) * (1.0 - smoothstep(vec2(0.75), vec2(1.0), q));
    vec2 bars = smoothstep(0.02, 0.07, abs(q));
    return inside.x * inside.y * bars.x * bars.y;
}

// Motes on a drifting grid of cells, one in a few cells lit, each wandering about its cell.
float dust(vec2 p, float t)
{
    float total = 0.0;
    for (int layer = 0; layer < 2; layer++)
    {
        float scale = layer == 0 ? 14.0 : 23.0;
        vec2 uv = p * scale + vec2(t * 0.11, t * 0.05) * (1.0 + float(layer));
        vec2 cell = floor(uv);
        float h = hash(cell + float(layer) * 17.0);
        vec2 at = cell + 0.5 + 0.3 * vec2(sin(t * 0.4 + h * 40.0), cos(t * 0.33 + h * 23.0));
        float size = layer == 0 ? 0.09 : 0.06;
        total += step(0.9, h) * (1.0 - smoothstep(0.0, size, length(uv - at)));
    }
    return total;
}

void main()
{
    float aspect = clock.y;
    vec2 p = vec2((var_screen.x - 0.5) * aspect, var_screen.y - 0.5);
    float t = clock.x * (1.0 - clock.z);

    vec3 color = mix(bottom.rgb, top.rgb, smoothstep(0.0, 1.0, var_screen.y));
    color *= 0.96 + 0.06 * plaster(p);

    float light = windowPatch(p, aspect);
    float lamp = 1.0 - smoothstep(0.0, 0.85, length(p * vec2(0.8, 1.2) - vec2(0.0, 0.1)));
    color *= 1.0 + 0.08 * lamp;
    color = mix(color, color * window_light.rgb * 1.5, light * window_light.a);
    color += window_light.rgb * dust(p, t) * light * 0.25;

    vec2 v = var_screen - 0.5;
    color *= 1.0 - 0.28 * smoothstep(0.3, 0.85, length(v * vec2(1.1, 1.0)));
    out_fragColor = vec4(color, 1.0);
}

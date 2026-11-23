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
    // rgb: a soft glow behind the board, a: its strength
    mediump vec4 glow;
    // rgb: the colour of an overhead spotlight on the board and its pool of light, a: its strength
    mediump vec4 stage;
    // rgb: the colour of a faint isometric lattice, a: its strength (it fades out behind the board)
    mediump vec4 lattice;
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

// A soft cone of light from above the screen down to the board's floor, and the pool it makes.
float beam(vec2 p)
{
    float floor_y = -0.22;
    float t = clamp((0.6 - p.y) / (0.6 - floor_y), 0.0, 1.0);
    float half_width = mix(0.07, 0.4, t);
    float across = 1.0 - smoothstep(half_width * 0.45, half_width, abs(p.x));
    return across * mix(0.4, 1.0, t) * (1.0 - smoothstep(floor_y - 0.02, floor_y - 0.08, p.y));
}

float pool(vec2 p)
{
    return 1.0 - smoothstep(0.15, 1.0, length((p - vec2(0.0, -0.22)) / vec2(0.55, 0.12)));
}

// Distance to the nearest line of an isometric lattice (vertical lines and lines at 30 and 150
// degrees, meeting at shared points), in cells; `cells` rows of cells per screen height.
float latticeDistance(vec2 p, float cells)
{
    vec2 q = p * cells;
    vec3 along = vec3(q.x, dot(q, vec2(0.5, 0.866)), dot(q, vec2(-0.5, 0.866)));
    vec3 d = abs(fract(along + 0.5) - 0.5);
    return min(min(d.x, d.y), d.z);
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
    color += glow.rgb * glow.a * lamp;
    color = mix(color, color * window_light.rgb * 1.5, light * window_light.a);
    color += window_light.rgb * dust(p, t) * light * window_light.a;

    float cone = beam(p);
    color += stage.rgb * stage.a * (0.3 * cone + 0.8 * pool(p));
    color += stage.rgb * dust(p, t) * cone * stage.a * 0.8;

    float line_d = latticeDistance(p, 9.0);
    float lines = 1.0 - smoothstep(0.0, 1.5 * fwidth(line_d), line_d);
    float away = smoothstep(0.22, 0.7, length(p * vec2(0.75, 1.0)));
    color = mix(color, lattice.rgb, lines * lattice.a * away);

    vec2 v = var_screen - 0.5;
    color *= 1.0 - 0.28 * smoothstep(0.3, 0.85, length(v * vec2(1.1, 1.0)));
    out_fragColor = vec4(color, 1.0);
}

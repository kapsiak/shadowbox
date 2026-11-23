#version 140

in mediump vec2 var_screen;

out vec4 out_fragColor;

// The wall behind the board: a faintly textured gradient, a soft glow behind the board, an
// isometric lattice that fades out behind the board, and a vignette.
uniform fs_uniforms
{
    mediump vec4 top;
    mediump vec4 bottom;
    // x: window aspect (width / height)
    mediump vec4 aspect;
    // rgb: a soft glow behind the board, a: its strength
    mediump vec4 glow;
    // rgb: the colour of the lattice, a: its strength
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

float grit(vec2 p)
{
    return noise(p * 3.0) * 0.5 + noise(p * 9.0) * 0.3 + noise(p * 60.0) * 0.2;
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
    vec2 p = vec2((var_screen.x - 0.5) * aspect.x, var_screen.y - 0.5);

    vec3 color = mix(bottom.rgb, top.rgb, smoothstep(0.0, 1.0, var_screen.y));
    color *= 0.96 + 0.06 * grit(p);

    float lamp = 1.0 - smoothstep(0.0, 0.85, length(p * vec2(0.8, 1.2) - vec2(0.0, 0.1)));
    color += glow.rgb * glow.a * lamp;

    float line_d = latticeDistance(p, 9.0);
    float lines = 1.0 - smoothstep(0.0, 1.5 * fwidth(line_d), line_d);
    float away = smoothstep(0.22, 0.7, length(p * vec2(0.75, 1.0)));
    color = mix(color, lattice.rgb, lines * lattice.a * away);

    vec2 v = var_screen - 0.5;
    color *= 1.0 - 0.28 * smoothstep(0.3, 0.85, length(v * vec2(1.1, 1.0)));
    out_fragColor = vec4(color, 1.0);
}

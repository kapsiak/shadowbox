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
// Per cell, the light received and wanted: rgb a glass colour when a = 1, darkness when a = 0.
uniform mediump sampler2D received;
uniform mediump sampler2D target;

uniform fs_uniforms
{
    // xy: grid size in cells
    mediump vec4 dims;
    // The panel's border beyond each side of the grid in cells: u0, u1, v0, v1
    mediump vec4 margins;
    // x: opacity, y: pulse (1 at the moment a wall is satisfied, fading), z: satisfied glow
    mediump vec4 opacity;
    // the selected piece's colour
    mediump vec4 accent;
    mediump vec4 paper;
    mediump vec4 shadow;
    mediump vec4 pencil;
    mediump vec4 frame;
};

const vec2 SIDES[4] = vec2[4](vec2(-1.0, 0.0), vec2(1.0, 0.0), vec2(0.0, -1.0), vec2(0.0, 1.0));
const vec2 CORNERS[4] = vec2[4](vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0));

float roundedBox(vec2 p, vec2 half_size, float radius)
{
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

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

bool inGrid(vec2 c)
{
    return all(greaterThanEqual(c, vec2(0.0))) && all(lessThan(c, dims.xy));
}

vec4 cellAt(vec2 c)
{
    return inGrid(c) ? texture(cells, (c + 0.5) / dims.xy) : vec4(0.0);
}

// The light a cell wants, as a key that differs between any two wanted lights.
vec3 wantAt(vec2 c)
{
    vec4 w = inGrid(c) ? texture(target, (c + 0.5) / dims.xy) : vec4(0.0);
    return w.a > 0.5 ? w.rgb : vec3(-1.0);
}

float focusAt(vec2 c)
{
    return inGrid(c) ? texture(focus, (c + 0.5) / dims.xy).r : 0.0;
}

// Distance from p (cell-local, centred) to the edge of a region of cells, counting each side and
// corner by how far its neighbour lies outside it (0 to 1), so neighbouring cells merge seamlessly
// and smoothly as they come and go. Capped at 1, beyond any point in the cell.
float edgeDistance(vec2 p, vec4 side_out, vec4 corner_out)
{
    float d = 1.0;
    d = min(d, mix(1.0, p.x + 0.5, side_out.x));
    d = min(d, mix(1.0, 0.5 - p.x, side_out.y));
    d = min(d, mix(1.0, p.y + 0.5, side_out.z));
    d = min(d, mix(1.0, 0.5 - p.y, side_out.w));
    for (int i = 0; i < 4; i++)
    {
        float out_i = i == 0 ? corner_out.x : i == 1 ? corner_out.y : i == 2 ? corner_out.z : corner_out.w;
        d = min(d, mix(1.0, length(p - CORNERS[i] * 0.5), out_i));
    }
    return d;
}

void main()
{
    vec2 grid = var_uv * dims.xy;
    vec2 cell = floor(grid);
    vec2 local = fract(grid) - 0.5;

    // Panel body: a square slab filling the quad. Panels seen from behind fade out.
    vec2 body_lo = -margins.xz;
    vec2 body_hi = dims.xy + margins.yw;
    float body_d = roundedBox(grid - (body_lo + body_hi) * 0.5, (body_hi - body_lo) * 0.5, 0.02);
    float body_mask = (1.0 - smoothstep(-0.02, 0.02, body_d)) * smoothstep(0.0, 0.2, var_facing) * opacity.x;
    if (body_mask <= 0.0)
    {
        discard;
    }

    float aa = max(0.01, length(fwidth(grid)));
    bool inside = inGrid(cell);
    vec4 s = cellAt(cell);

    // Neighbour membership of the target (r, split where the wanted light changes), coverage (g)
    // and focus regions.
    vec3 want_key = wantAt(cell);
    vec4 t_side, g_side, f_side, t_corner, g_corner, f_corner;
    for (int i = 0; i < 4; i++)
    {
        vec4 n = cellAt(cell + SIDES[i]);
        vec4 c = cellAt(cell + CORNERS[i]);
        float side_differs = step(0.05, distance(wantAt(cell + SIDES[i]), want_key));
        float corner_differs = step(0.05, distance(wantAt(cell + CORNERS[i]), want_key));
        t_side[i] = max(step(n.r, 0.5), side_differs);
        g_side[i] = 1.0 - n.g;
        f_side[i] = step(focusAt(cell + SIDES[i]), 0.5);
        t_corner[i] = max(step(c.r, 0.5), corner_differs);
        g_corner[i] = 1.0 - c.g;
        f_corner[i] = step(focusAt(cell + CORNERS[i]), 0.5);
    }

    vec2 cell_uv = (cell + 0.5) / dims.xy;
    vec4 received_t = inside ? texture(received, cell_uv) : vec4(0.0);
    vec4 want_t = inside ? texture(target, cell_uv) : vec4(0.0);
    vec3 received_color = mix(shadow.rgb, paper.rgb * received_t.rgb, received_t.a);
    vec3 want_color = mix(shadow.rgb, paper.rgb * want_t.rgb, want_t.a);
    float matches = 1.0 - smoothstep(0.04, 0.15, distance(received_color, want_color));

    // Paper: faint grain and a light pencil grid so cells stay countable.
    vec3 color = paper.rgb * (0.99 + 0.015 * noise(grid * 14.0));
    vec2 to_line = abs(fract(grid + 0.5) - 0.5);
    float grid_line = inside ? 1.0 - smoothstep(0.0, 1.5 * aa, min(to_line.x, to_line.y)) : 0.0;
    color = mix(color, pencil.rgb, 0.08 * grid_line);

    // Floor: the live shadow (or glass light) while unjudged and soft contact under pieces.
    vec4 soft_t = texture(soft, var_uv);
    color = mix(color, received_color, 0.45 * soft_t.b);
    color *= 1.0 - 0.12 * soft_t.a;

    // Missing target cells keep a faint wash of the wanted light.
    float in_target = s.r * step(0.5, s.r);
    color = mix(color, mix(pencil.rgb, want_color, want_t.a), 0.07 * in_target * (1.0 - s.g));

    // Coverage: grows from each cell's centre; merged with covered neighbours.
    float g_edge = edgeDistance(local, g_side, g_corner);
    float covered = inside ? smoothstep(-aa, aa, g_edge - 0.5 * (1.0 - s.g)) * smoothstep(0.0, 0.2, s.g) : 0.0;
    color = mix(color, received_color, covered);

    // Unwanted coverage is crossed out with paper-coloured hatching.
    float stripe = abs(fract((grid.x + grid.y) * 3.0) - 0.5);
    float hatch = 1.0 - smoothstep(0.12, 0.12 + 3.0 * aa, stripe);
    color = mix(color, paper.rgb, 0.55 * hatch * covered * max(0.0, s.g - s.r));

    // Target contour: a pencil line inside the region's edge, swallowed by a matching shadow,
    // turning to ink as the wall is satisfied.
    float t_edge = edgeDistance(local, t_side, t_corner);
    float line_width = 0.045 + 0.02 * opacity.z;
    float contour = inside ? in_target * (1.0 - smoothstep(line_width, line_width + aa, t_edge)) : 0.0;
    float sketchy = 0.8 + 0.2 * noise(grid * vec2(9.0, 7.0));
    vec3 ink = mix(pencil.rgb, pencil.rgb * 0.45, opacity.z);
    vec3 line_color = mix(ink, want_color * 0.8, want_t.a);
    color = mix(color, line_color, contour * sketchy * (1.0 - 0.85 * s.g * matches));

    // The selected piece's cast: a tint and an outline in its colour.
    float f_own = inside ? focusAt(cell) : 0.0;
    float f_edge = edgeDistance(local, f_side, f_corner);
    float f_line = f_own * (1.0 - smoothstep(0.06, 0.06 + aa, f_edge));
    color = mix(color, mix(color, accent.rgb, 0.3), f_own * step(0.5, f_own));
    color = mix(color, accent.rgb * 0.85, f_line);

    // Wooden frame around the paper.
    // Only sides with a border carry it, so a wall's foot meets the floor's frame cleanly.
    vec4 to_edge = vec4(grid.x - body_lo.x, body_hi.x - grid.x, grid.y - body_lo.y, body_hi.y - grid.y);
    vec4 framed = mix(vec4(8.0), to_edge, step(0.1, margins));
    float frame_d = min(min(framed.x, framed.y), min(framed.z, framed.w));
    float frame_band = 1.0 - smoothstep(0.07, 0.07 + aa, frame_d);
    vec3 wood = frame.rgb * (0.9 + 0.12 * noise(grid * vec2(1.5, 18.0)));
    color = mix(color, wood, frame_band);

    // A satisfied wall's light brightens for a moment.
    color = mix(color, vec3(1.0), 0.15 * opacity.y * (1.0 - frame_band));

    out_fragColor = vec4(color, body_mask);
}

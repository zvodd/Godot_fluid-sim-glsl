shader_type canvas_item;

uniform sampler2D prev_state : source_color;
uniform vec2 res = vec2(256.0,256.0);
uniform float dt = 0.016;
uniform float vel_scale = 20.0; // max velocity encoded
uniform float dissipation = 0.995;

vec4 sample_clamp(vec2 uv) {
    uv = clamp(uv, vec2(0.0), vec2(1.0));
    return texture(prev_state, uv);
}

vec2 decode_vel(vec4 s) {
    // R,G encode signed velocity mapped around 0.5
    return (s.rg - 0.5) * 2.0 * vel_scale;
}

float decode_scalar(float c) {
    // B/A store 0..1
    return clamp(c, 0.0, 1.0);
}

vec4 encode_out(vec2 vel, float density, float pressure) {
    vec2 enc_vel = (vel / vel_scale) * 0.5 + 0.5;
    enc_vel = clamp(enc_vel, vec2(0.0), vec2(1.0));
    return vec4(enc_vel.x, enc_vel.y, clamp(density,0.0,1.0), clamp(pressure,0.0,1.0));
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 px = 1.0 / res;

    // read current state
    vec4 cur = sample_clamp(uv);
    vec2 cur_vel = decode_vel(cur);
    float cur_den = decode_scalar(cur.b);
    float cur_p = decode_scalar(cur.a);

    // Advection: backtrace using velocity (pixels/sec -> uv/sec)
    vec2 back_uv = uv - (cur_vel * dt) / res;
    vec4 adv = sample_clamp(back_uv);
    vec2 adv_vel = decode_vel(adv);
    float adv_den = decode_scalar(adv.b);
    float adv_p = decode_scalar(adv.a);

    // Diffusion / simple damping on velocity and density
    // Laplacian sample
    vec4 n = sample_clamp(uv + vec2(0.0, px.y));
    vec4 s = sample_clamp(uv - vec2(0.0, px.y));
    vec4 e = sample_clamp(uv + vec2(px.x, 0.0));
    vec4 w = sample_clamp(uv - vec2(px.x, 0.0));

    vec2 n_vel = decode_vel(n);
    vec2 s_vel = decode_vel(s);
    vec2 e_vel = decode_vel(e);
    vec2 w_vel = decode_vel(w);

    // simple pressure/projection
    float div = 0.5 * ((e_vel.x - w_vel.x) + (n_vel.y - s_vel.y)) / vel_scale; // normalized approx
    float pressure = adv_p;
    // Jacobi-like one-step (very approximate)
    float neighbor_p = (n.a + s.a + e.a + w.a) * 0.25;
    pressure = mix(pressure, neighbor_p - div * 0.25, 0.5);

    // subtract gradient from velocity (project)
    float grad_px = 0.5 * (e.a - w.a) * vel_scale;
    float grad_py = 0.5 * (n.a - s.a) * vel_scale;
    vec2 proj_vel = adv_vel - vec2(grad_px, grad_py);

    // dissipation
    proj_vel *= dissipation;
    adv_den *= dissipation;

    // pack and output
    COLOR = encode_out(proj_vel, adv_den, pressure);
}
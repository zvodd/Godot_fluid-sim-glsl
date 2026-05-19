shader_type canvas_item;

uniform sampler2D prev_state : source_color;
uniform vec2 res = vec2(256.0, 256.0);
uniform float dt = 0.016;
uniform float vel_scale = 20.0; 
uniform float dissipation = 0.995;
uniform float wave_strength = 0.05; // Ocean feel
uniform float TIME_VAL; // Pass TIME here

vec4 sample_clamp(vec2 uv) {
    return texture(prev_state, clamp(uv, vec2(0.0), vec2(1.0)));
}

vec2 decode_vel(vec4 s) {
    return (s.rg - 0.5) * 2.0 * vel_scale;
}

float decode_scalar(float c) {
    return clamp(c, 0.0, 1.0);
}

vec4 encode_out(vec2 vel, float density, float pressure) {
    vec2 enc_vel = (vel / (vel_scale * 2.0)) + 0.5;
    return vec4(clamp(enc_vel, 0.0, 1.0), clamp(density, 0.0, 1.0), clamp(pressure, 0.0, 1.0));
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 px = 1.0 / res;

    // 1. Advection (Semi-Lagrangian)
    vec4 cur = sample_clamp(uv);
    vec2 cur_vel = decode_vel(cur);
    // Backtrace: use normalized UV units
    vec2 back_uv = uv - (cur_vel * dt * px); 
    vec4 adv = sample_clamp(back_uv);
    
    vec2 vel = decode_vel(adv);
    float density = decode_scalar(adv.b);
    float pressure = decode_scalar(adv.a);

    // 2. Neighbor Sampling
    vec4 n = sample_clamp(uv + vec2(0.0, px.y));
    vec4 s = sample_clamp(uv - vec2(0.0, px.y));
    vec4 e = sample_clamp(uv + vec2(px.x, 0.0));
    vec4 w = sample_clamp(uv - vec2(px.x, 0.0));

    vec2 n_v = decode_vel(n);
    vec2 s_v = decode_vel(s);
    vec2 e_v = decode_vel(e);
    vec2 w_v = decode_vel(w);

    // 3. Divergence & Pressure (Poisson approx)
    // Div = (du/dx + dv/dy)
    float div = 0.5 * ((e_v.x - w_v.x) + (n_v.y - s_v.y));
    float p_neighbor = (n.a + s.a + e.a + w.a) * 0.25;
    pressure = p_neighbor - (div * 0.125); // Relax divergence

    // 4. Gradient Subtraction (Projection)
    // Project velocity to be mass-conserving
    vec2 grad_p = vec2(e.a - w.a, n.a - s.a) * 0.5;
    vel -= grad_p * vel_scale * 0.5; 

    // 5. Ocean Force (Ambient motion)
    // Sinusoidal force prevents static death
    float ocean_force = sin(uv.x * 10.0 + TIME_VAL) * cos(uv.y * 10.0 + TIME_VAL);
    vel.y += ocean_force * wave_strength;

    // 6. Dissipation
    vel *= dissipation;
    density *= dissipation;

    COLOR = encode_out(vel, density, pressure);
}
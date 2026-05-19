shader_type canvas_item;

uniform sampler2D prev_state : source_color;
uniform vec2 res = vec2(256.0, 256.0);
uniform float dt = 0.016;
uniform float vel_scale = 20.0; 
uniform float dissipation = 0.99;
uniform float wave_strength = 2.0;
uniform float noise_scale = 5.0;
uniform float noise_speed = 0.5;
uniform float TIME_VAL;

// Pseudo-random hash for noise
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Gradient noise for smooth vector fields
vec2 noise_field(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

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

    // 1. Current State
    vec4 cur = sample_clamp(uv);
    vec2 cur_vel = decode_vel(cur);

    // 2. Advection (Backtrace)
    vec2 back_uv = uv - (cur_vel * dt * px);
    vec4 adv = sample_clamp(back_uv);
    
    vec2 vel = decode_vel(adv);
    float density = decode_scalar(adv.b);
    float pressure = decode_scalar(adv.a);

    // 3. Neighbor Sampling (Laplacian)
    vec4 n = sample_clamp(uv + vec2(0.0, px.y));
    vec4 s = sample_clamp(uv - vec2(0.0, px.y));
    vec4 e = sample_clamp(uv + vec2(px.x, 0.0));
    vec4 w = sample_clamp(uv - vec2(px.x, 0.0));

    vec2 n_v = decode_vel(n);
    vec2 s_v = decode_vel(s);
    vec2 e_v = decode_vel(e);
    vec2 w_v = decode_vel(w);

    // 4. Pressure & Divergence
    float div = 0.5 * ((e_v.x - w_v.x) + (n_v.y - s_v.y));
    float p_neighbor = (n.a + s.a + e.a + w.a) * 0.25;
    pressure = p_neighbor - (div * 0.125);

    // 5. Gradient Subtraction (Projection)
    vec2 grad_p = vec2(e.a - w.a, n.a - s.a) * 0.5;
    vel -= grad_p * vel_scale * 0.5;

    // 6. Turbulence Injection (FBM style)
    vec2 motion_uv = uv * noise_scale;
    float t = TIME_VAL * noise_speed;
    vec2 noise_force = noise_field(motion_uv + t);
    noise_force += noise_field(motion_uv * 2.1 - t * 1.2) * 0.5;
    
    vel += noise_force * wave_strength * dt * 10.0;
    density += length(noise_force) * 0.1 * dt; // Ambient density ripple

    // 7. Dissipation
    vel *= dissipation;
    density *= (dissipation * 0.99); // Density fades slightly faster

    COLOR = encode_out(vel, density, pressure);
}
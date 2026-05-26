shader_type canvas_item;

uniform sampler2D prev_state : source_color;
uniform vec2 res = vec2(256.0, 256.0);
uniform float dt = 0.016;
uniform float vel_scale = 20.0; 
uniform float dissipation = 0.99;
uniform float wave_strength = 3.0;
uniform float noise_delta_force = 2.0; 
uniform float noise_scale = 4.0;
uniform float noise_speed = 0.8;
uniform float orbital_radius = 0.5; 

// --- ARRAY UNIFORMS ---
const int MAX_AFFECTORS = 16;
// (4 floats * 16 vectors) + 1 slot for length = 65 floats total.
// To pass flat float arrays to uniforms, we declare them as a float array.
uniform float affector_data[65]; 
uniform float circle_radius = 2.0; // Radius of affectors in grid cells (pixels)

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

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
    vec2 uv = UV;
    vec2 px = 1.0 / res;
    float TIME_VAL = TIME;

    // Current fragment position in grid/pixel coordinates
    vec2 current_grid_pos = uv * res;

    // 1. Fetch
    vec4 cur = sample_clamp(uv);
    vec2 cur_vel = decode_vel(cur);

    // 2. Advection
    vec2 back_uv = uv - (cur_vel * dt * px);
    vec4 adv = sample_clamp(back_uv);
    vec2 vel = decode_vel(adv);
    float density = decode_scalar(adv.b);

    // 3. Neighbors
    vec4 n = sample_clamp(uv + vec2(0.0, px.y));
    vec4 s = sample_clamp(uv - vec2(0.0, px.y));
    vec4 e = sample_clamp(uv + vec2(px.x, 0.0));
    vec4 w = sample_clamp(uv - vec2(px.x, 0.0));

    // 4. Pressure/Div
    vec2 n_v = decode_vel(n); vec2 s_v = decode_vel(s);
    vec2 e_v = decode_vel(e); vec2 w_v = decode_vel(w);
    float div = 0.5 * ((e_v.x - w_v.x) + (n_v.y - s_v.y));
    float pressure = ((n.a + s.a + e.a + w.a) * 0.25) - (div * 0.125);

    // 5. Projection
    vec2 grad_p = vec2(e.a - w.a, n.a - s.a) * 0.5;
    vel -= grad_p * vel_scale * 0.5;

    // 6. Orbital Turbulence
    float t = TIME_VAL * noise_speed;
    vec2 orbital_offset = vec2(cos(t), sin(t)) * orbital_radius;
    vec2 noise_uv1 = (uv * noise_scale) + orbital_offset;
    vec2 noise_uv2 = (uv * noise_scale * 1.5) - (orbital_offset * 1.3);
    vec2 noise_force = noise_field(noise_uv1);
    noise_force += noise_field(noise_uv2) * 0.5;
    
    vel += noise_force * wave_strength * dt * noise_delta_force;
    density += length(noise_force) * 0.2 * dt;

	// === 6.5 PROCESS CUSTOM AFFECTORS FROM PACKED ARRAY ===
    // Index 0 holds the total number of elements as a float
    int total_affectors = int(affector_data[0]);
    
    for (int i = 0; i < total_affectors; i++) {
        // Step over the length slot (1) and stride by 4 floats per affector
        int idx = 1 + (i * 4);
        
        // Unpack the flat float data into clean vectors
        vec2 affector_grid_pos = vec2(affector_data[idx],     affector_data[idx+1]);
        vec2 force_vec         = vec2(affector_data[idx+2],   affector_data[idx+3]);
        
        // Calculate distance from current fragment to the affector center (in pixels)
        float dist = length(current_grid_pos - affector_grid_pos);
        
        // Create a smooth 2D circle mask based on the radius
        float mask = smoothstep(circle_radius, circle_radius - 1.0, dist);
        
        // Inject density and force into the fluid simulation
        density += mask * 0.5; 
        //vel += mask * force_vec * dt * 1000.0; // Adjust 100.0 multiplier to change impact strength
        vel += mask * vec2(0.5,0.5) * dt * 1000.0; // Adjust 100.0 multiplier to change impact strength
    }
	
	//float dist = length(current_grid_pos - vec2(128.0));
	//float mask = smoothstep(circle_radius, circle_radius - 1.0, dist);
	//density += mask * 0.5;
	//vel += mask * vec2(0.5,0.5) * dt * 100.0; // Adjust 100.0 multiplier to change impact strength

    // 7. Step
    vel *= dissipation;
    density *= (dissipation * 0.98);

    COLOR = encode_out(vel, density, pressure);
}
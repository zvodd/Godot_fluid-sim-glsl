shader_type canvas_item;

uniform sampler2D prev_state : source_color, filter_linear;
uniform vec2 res = vec2(256.0, 256.0);
uniform float dt = 0.016;
uniform float vel_scale = 20.0; 
uniform float dissipation = 0.98;
uniform float brownian_strength = 2.5;
uniform float brownian_speed = 0.6;

uniform float affector_data[65]; 
uniform float circle_radius = 2.0;

// --- MATH ---

vec2 hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123) * 2.0 - 1.0;
}

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(hash(i + vec2(0,0)), f - vec2(0,0)), dot(hash(i + vec2(1,0)), f - vec2(1,0)), u.x),
			   mix(dot(hash(i + vec2(0,1)), f - vec2(0,1)), dot(hash(i + vec2(1,1)), f - vec2(1,1)), u.x), u.y);
}

// Curl-Noise for divergence-free Brownian flow
vec2 brownian_curl(vec2 p, float t) {
	float eps = 0.1;
	float n1 = noise(p + vec2(0.0, t));
	float n2 = noise(p + vec2(eps, t));
	float n3 = noise(p + vec2(0.0, eps + t));
	return vec2(n3 - n1, -(n2 - n1)) / eps;
}

vec2 decode_v(vec4 s) { return (s.xy - 0.5) * 2.0 * vel_scale; }
vec4 encode(vec2 v, float d, float p) { return vec4((v / (vel_scale * 2.0)) + 0.5, d, p); }

void fragment() {
	vec2 uv = UV;
	vec2 dx = vec2(1.0 / res.x, 0.0);
	vec2 dy = vec2(0.0, 1.0 / res.y);

	// 1. ADVECTION (Sample previous state at back-projected position)
	vec2 v_prev = decode_v(texture(prev_state, uv));
	vec2 back_uv = uv - v_prev * dt * (1.0 / res);
	vec4 state_adv = texture(prev_state, back_uv);
	
	vec2 v = decode_v(state_adv);
	float dens = state_adv.b;
	float press = state_adv.a;

	// 2. FORCE INJECTION (Brownian + Affectors)
	v += brownian_curl(uv * 5.0, TIME * brownian_speed) * brownian_strength * dt;
	
	int total = int(affector_data[0]);
	for (int i = 0; i < total; i++) {
		int idx = 1 + (i * 4);
		vec2 a_pos = vec2(affector_data[idx], affector_data[idx+1]);
		vec2 a_force = vec2(affector_data[idx+2], affector_data[idx+3]);
		float mask = smoothstep(circle_radius, 0.0, length((uv * res) - a_pos));
		//if (i == 0){ a_force *= 5.0;}
		v += a_force * mask * dt * 15.0;
		dens += mask * 0.5;
	}

	// 3. JACOBIAN PRESSURE SOLVER (Poisson Equation)
	// Fetch 4-way neighbors
	vec4 pL = texture(prev_state, uv - dx);
	vec4 pR = texture(prev_state, uv + dx);
	vec4 pB = texture(prev_state, uv - dy);
	vec4 pT = texture(prev_state, uv + dy);

	// Calculate divergence (Central Difference)
	float div = 0.5 * ((decode_v(pR).x - decode_v(pL).x) + (decode_v(pT).y - decode_v(pB).y));
	
	// Jacobi Iteration: p_new = (sum(neighbors) - div) / 4
	// Note: We use the advected pressure as initial guess
	float p_new = (pL.a + pR.a + pB.a + pT.a - div) * 0.25;

	// 4. PROJECTION (Subtract Pressure Gradient)
	vec2 grad_p = 0.5 * vec2(pR.a - pL.a, pT.a - pB.a);
	v -= grad_p * vel_scale;

	// 5. STABILIZATION
	v *= dissipation;
	dens *= (dissipation * 0.99);

	COLOR = encode(v, clamp(dens, 0.0, 1.0), clamp(p_new, 0.0, 1.0));
}
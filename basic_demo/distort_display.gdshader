shader_type canvas_item;

uniform sampler2D fluid_texture; // Output from SubViewport
uniform sampler2D source_image;  // Target image to distort
uniform float distort_strength = 0.05;
uniform float vel_scale = 20.0;

void fragment() {
    // 1. Read fluid state
    vec4 fluid = texture(fluid_texture, UV);
    
    // 2. Decode velocity (RGBA8 packing: 0.5 is neutral)
    vec2 vel = (fluid.rg - 0.5) * 2.0;
    
    // 3. Offset UVs based on velocity
    // Density (B) can modulate strength so static areas don't jitter
    float density = fluid.b;
    vec2 uv_offset = vel * distort_strength * density;
    
    // 4. Sample source image with distorted UV
    vec4 color = texture(source_image, UV - uv_offset);
    
    // 5. Optional: Mix in fluid color/density for visual flair
    // color.rgb += density * vec3(0.1, 0.2, 0.5); 
    
    COLOR = color;
}
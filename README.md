# Eulerian Fluid via OpenGL (RGBA8 Pipeline) in Godot

## Overview

High-performance 2D fluid simulation designed for **Compatibility Mode (OpenGL 3.3)**. Unlike modern compute-heavy solutions, this project uses a standard **SubViewport/ColorRect loop** and **RGBA8 packing** to run on legacy hardware or web platforms where Compute Shaders are unavailable.


https://github.com/user-attachments/assets/8f13809f-2b25-4897-80ee-e37ff5b42ab0


## Tech Specs

- **Grid:** Eulerian (Grid-based) simulation.
- **Precision:** 8-bit fixed-point (RGBA8).
- **Core Loop:** GPU-accelerated Advection + Diffusion + Projection via Jacobi iterations.
- **Input:** Real-time CPU injection via `Image` buffer updates.
- **Distortion:** Dynamic UV-offsetting of arbitrary textures using the velocity field.

## Setup

1. **SubViewport:** Set size (e.g., 256x256). `Update Mode: Always`.
2. **Simulation:** Attach `FluidSimulation.gd` to a `ColorRect` inside the viewport.
3. **Materials:**
    - `fluid_logic.gdshader` handles the physics.
    - `distort_display.gdshader` handles the visual output.
4. **Display:** Apply the distortion shader to any `TextureRect` or 3D surface, feeding it the `ViewportTexture`.

## Key Feature: OpenGL Compatibility

Most Godot fluid sims require Forward+ (Vulkan/Compute). This implementation bypasses that requirement by:

- Encoding signed velocity `(-max_vel to +max_vel)` into `0.0 to 1.0` range.
- Using a feedback loop where the viewport samples its own previous frame.
- Maintaining interactive speeds on low-end hardware.

## Controls

- **Click & Drag:** Inject velocity and density into the fluid.
- **Parameters:** Adjust `vel_scale` and `distort_strength` in the inspector to tune the "viscosity" and visual impact.

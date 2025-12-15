#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uLevel;

out vec4 fragColor;

// TRON TIME GATE - Extreme Psychedelic Vortex
// Heavily music-reactive, swirling 3D grid tunnels

#define PI 3.14159265359
#define TAU 6.28318530718

// 2D/3D Rotation
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Hash for procedural noise
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Psychedelic Palette (shifting with audio)
vec3 palette(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.33, 0.67); // Shift based on audio
    d += vec3(uLevel * 0.2);
    return a + b * cos(TAU * (c * t + d));
}

// SDF for tunnel (cylinder)
float sdCylinder(vec3 p, float r) {
    return length(p.xy) - r;
}

// Grid pattern (Tron aesthetic) - simplified for Flutter
float grid(vec2 p, float scale) {
    p *= scale;
    vec2 grid = abs(fract(p) - 0.5);
    float line = min(grid.x, grid.y);
    return smoothstep(0.02, 0.0, line);
}

// 3D Grid on tunnel surface
float grid3D(vec3 p, float scale) {
    // Polar coordinates for cylindrical mapping
    float angle = atan(p.y, p.x);
    float radius = length(p.xy);
    
    vec2 uv = vec2(angle / TAU, p.z) * scale;
    return grid(uv, 1.0);
}

// Multi-layer Scene
float map(vec3 p) {
    // Audio-reactive speed and twist
    float speed = 3.0 + uLevel * 6.0;
    float twist = p.z * (0.3 + uLevel * 0.4) + uTime * 0.3;
    
    // Extreme swirl distortion
    p.xy *= rot(twist);
    p.x += sin(p.z * 0.8 + uTime * 2.0) * (0.8 + uLevel);
    p.y += cos(p.z * 0.6 - uTime * 1.5) * (0.8 + uLevel);
    
    // Pulsating tunnel radius
    float pulseRadius = 2.5 + sin(uTime * 4.0 + uLevel * 10.0) * 0.5 * uLevel;
    
    // Multiple nested tunnels
    float tunnel1 = sdCylinder(p, pulseRadius);
    float tunnel2 = sdCylinder(p * 0.7, pulseRadius * 0.6);
    float tunnel3 = sdCylinder(p * 1.3, pulseRadius * 1.2);
    
    // Combine tunnels (SDF union)
    return min(min(tunnel1, tunnel2), tunnel3);
}

void main() {
    vec2 fragCoord = FlutterFragCoord();
    vec2 resolution = vec2(uResolutionX, uResolutionY);
    vec2 uv = (fragCoord * 2.0 - resolution) / min(resolution.x, resolution.y);
    
    // Camera setup - flying through vortex
    float speed = 5.0 + uLevel * 8.0; // Audio drives speed
    vec3 ro = vec3(0.0, 0.0, uTime * speed);
    
    // Wobbling camera (audio-reactive)
    float shake = uLevel * 0.15;
    ro.x += sin(uTime * 8.0 + uLevel * 15.0) * shake;
    ro.y += cos(uTime * 6.0 + uLevel * 12.0) * shake;
    
    // Wide FOV for distortion effect
    vec3 rd = normalize(vec3(uv, 0.7 - length(uv) * 0.3));
    
    // Rotate camera for spiral effect
    rd.xy *= rot(uTime * 0.5 + uLevel * 2.0);
    
    // Raymarching
    float t = 0.0;
    vec3 col = vec3(0.0);
    float glow = 0.0;
    vec3 gridAccum = vec3(0.0);
    
    for(int i = 0; i < 100; i++) {
        vec3 p = ro + rd * t;
        
        // Extra domain warping for psychedelic effect
        p.xy *= rot(p.z * (0.1 + uLevel * 0.2));
        p.xz *= rot(sin(uTime * 2.0) * uLevel * 0.5);
        
        float d = map(p);
        
        // Volumetric glow (increases with audio)
        float glowIntensity = 0.02 / (abs(d) + 0.01);
        glow += glowIntensity * (1.5 + uLevel * 4.0);
        
        // Sample grid pattern near surface
        if (abs(d) < 1.5) {
            float gridScale = 8.0 + uLevel * 10.0; // Audio modulates grid density
            float g = grid3D(p, gridScale);
            
            // Multiple grid layers at different scales
            float g2 = grid3D(p * 1.5, gridScale * 0.5);
            float g3 = grid3D(p * 0.6, gridScale * 2.0);
            
            float gridMix = g + g2 * 0.5 + g3 * 0.3;
            gridAccum += vec3(gridMix) * 0.015 * (1.0 + uLevel * 2.0);
        }
        
        t += d * 0.5; // Step size
        if (t > 60.0 || abs(d) < 0.001) break;
    }
    
    // Colorize based on depth and glow
    float colorShift = t * 0.03 + uTime * 0.2 + uLevel * 0.5;
    vec3 baseCol = palette(colorShift);
    
    // Combine glow and grids
    col = glow * baseCol;
    col += gridAccum * baseCol * 2.0; // Grids with same color palette
    
    // Neon highlights (Tron style)
    col += vec3(0.0, 0.5, 1.0) * glow * 0.3; // Cyan glow
    col += vec3(1.0, 0.3, 0.0) * gridAccum * 0.5; // Orange grid
    
    // Deep space background fade
    col = mix(col, vec3(0.0, 0.0, 0.05), 1.0 - exp(-0.03 * t));
    
    // Intense vignette
    float vig = 1.5 - length(uv) * 0.8;
    col *= vig;
    
    // Heavy chromatic aberration (audio-driven)
    float aberration = 0.03 * (1.0 + uLevel * 2.0);
    col.r *= 1.0 + aberration;
    col.b *= 1.0 - aberration * 0.5;
    
    // Scanlines (Tron/CRT aesthetic)
    float scanline = sin(uv.y * 300.0 + uTime * 15.0) * 0.05;
    col += scanline;
    
    // Pulsing flash effect on beats
    float beatFlash = smoothstep(0.7, 1.0, uLevel) * 0.3;
    col += beatFlash;
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    fragColor = vec4(col, 1.0);
}

#version 460 core

// Precision override for performance on web
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uLevel; // Audio reactivity level (0.0 to 1.0)

out vec4 fragColor;

// Rotate 2D vector
vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c) * v;
}

// Pseudo-random function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Noise function
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void main() {
    vec2 uResolution = vec2(uResolutionX, uResolutionY);
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = (fragCoord - 0.5 * uResolution.xy) / min(uResolution.x, uResolution.y);
    
    // Audio reactivity
    float speed = 1.0 + uLevel * 1.5;
    
    // Time with modulus for precision
    float time = mod(uTime, 600.0); 
    float t = time * speed;
    
    // Tunnel depth from radius
    float r = length(uv);
    r = max(r, 0.001);
    float depth = 1.0 / r;
    
    // Rotate UV coordinates to create spiral effect
    // The key insight: sample noise using the FULL 2D rotated coordinates
    // This eliminates any seam because 2D noise is continuous in all directions
    float spiralAngle = depth * 0.5 + t * 0.15;
    vec2 rotatedUv = rotate(uv, spiralAngle);
    
    // Scale by depth to create tunnel perspective
    // Add time offset for forward motion illusion
    vec2 tunnelCoord = rotatedUv * depth * 0.5;
    tunnelCoord.y -= t * 0.2;
    
    // Sample noise at multiple scales using 2D coordinates (no seams!)
    float n1 = noise(tunnelCoord * 1.5);
    float n2 = noise(tunnelCoord * 3.0 + vec2(5.0, 3.0));
    float n3 = noise(tunnelCoord * 6.0 + vec2(10.0, 7.0));
    
    // Combine noise octaves
    float noiseVal = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
    
    // Create high-contrast B&W pattern
    float pattern = smoothstep(0.3, 0.7, noiseVal);
    
    // Add some variation with a second pattern layer
    float pattern2 = smoothstep(0.4, 0.6, abs(sin(noiseVal * 6.0 + depth * 0.1)));
    pattern = mix(pattern, pattern2, 0.5);
    
    // Subtle pulsing based on audio
    float pulse = 0.85 + 0.15 * sin(t * 0.4) * (1.0 + uLevel);
    
    // Vignette - fade at center and far edges
    float vignette = smoothstep(0.0, 0.3, r) * smoothstep(1.5, 0.4, r);
    
    // Final brightness
    float finalVal = pattern * vignette * pulse;
    
    vec3 color = vec3(finalVal);
    
    // Subtle film grain
    float grain = random(uv + fract(time * 0.1)) * 0.02;
    color += grain;
    
    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}



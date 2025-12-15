#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uLevel;

out vec4 fragColor;

// Time Gate - 3D raymarched time portal tunnel
// Inspired by temporal vortex effects

#define PI 3.14159265359
#define TWO_PI 6.28318530718

// Rotation matrices
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Hash function for procedural generation
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float hash3(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Smooth noise
float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash3(i);
    float b = hash3(i + vec3(1.0, 0.0, 0.0));
    float c = hash3(i + vec3(0.0, 1.0, 0.0));
    float d = hash3(i + vec3(1.0, 1.0, 0.0));
    float e = hash3(i + vec3(0.0, 0.0, 1.0));
    float f1 = hash3(i + vec3(1.0, 0.0, 1.0));
    float g = hash3(i + vec3(0.0, 1.0, 1.0));
    float h = hash3(i + vec3(1.0, 1.0, 1.0));
    
    return mix(
        mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
        mix(mix(e, f1, f.x), mix(g, h, f.x), f.y),
        f.z
    );
}

// FBM (Fractal Brownian Motion) for turbulence
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Tunnel SDF - torus-like shape
float sdTunnel(vec3 p, float r1, float r2) {
    vec2 q = vec2(length(p.xy) - r1, p.z);
    return length(q) - r2;
}

// Scene mapping
float map(vec3 p) {
    // Twist the tunnel based on z-position and time
    float twist = p.z * 0.3 + uTime * 0.5;
    p.xy = rot(twist) * p.xy;
    
    // Main tunnel
    float tunnel = sdTunnel(p, 2.0, 1.0);
    
    // Add turbulence based on audio
    float turbulence = fbm(p * 0.5 + uTime * 0.2) * uLevel * 0.3;
    tunnel += turbulence;
    
    return tunnel;
}

vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

void main() {
    vec2 fragCoord = FlutterFragCoord();
    vec2 resolution = vec2(uResolutionX, uResolutionY);
    vec2 uv = (fragCoord * 2.0 - resolution) / min(resolution.x, resolution.y);
    
    // Camera flying through tunnel
    float speed = 2.0 + uLevel * 3.0;
    vec3 ro = vec3(0.0, 0.0, -uTime * speed);
    
    // Look forward through tunnel
    vec3 forward = vec3(0.0, 0.0, 1.0);
    vec3 right = vec3(1.0, 0.0, 0.0);
    vec3 up = vec3(0.0, 1.0, 0.0);
    
    // Add slight camera wobble
    float wobble = sin(uTime * 2.0 + uLevel * 5.0) * 0.1;
    ro.xy += vec2(sin(uTime * 1.3), cos(uTime * 1.7)) * wobble * uLevel;
    
    vec3 rd = normalize(forward + uv.x * right + uv.y * up);
    
    // Raymarching
    float t = 0.0;
    vec3 col = vec3(0.0);
    bool hit = false;
    
    for (int i = 0; i < 128; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        
        if (d < 0.001) {
            hit = true;
            vec3 n = calcNormal(p);
            
            // Calculate position along tunnel for coloring
            float zDist = mod(p.z, 4.0);
            float angle = atan(p.y, p.x);
            
            // Time-warping color cycles
            float colorPhase = p.z * 0.2 + uTime * 2.0 + uLevel * 3.0;
            
            // Color palette - purple, cyan, pink time portal colors
            vec3 color1 = vec3(0.5, 0.0, 1.0);  // Purple
            vec3 color2 = vec3(0.0, 1.0, 1.0);  // Cyan
            vec3 color3 = vec3(1.0, 0.0, 0.8);  // Pink
            
            float mixer = sin(colorPhase) * 0.5 + 0.5;
            vec3 baseColor = mix(color1, color2, mixer);
            baseColor = mix(baseColor, color3, sin(colorPhase * 0.7) * 0.5 + 0.5);
            
            // Spiral pattern
            float spiralPattern = sin(angle * 8.0 - p.z * 2.0 + uTime * 3.0) * 0.5 + 0.5;
            
            // Ring pattern
            float rings = sin(zDist * 3.0 + uTime * 2.0) * 0.5 + 0.5;
            
            // Combine patterns
            float pattern = mix(spiralPattern, rings, 0.5);
            
            // Lighting
            vec3 light = normalize(vec3(sin(uTime), 1.0, cos(uTime)));
            float diff = max(dot(n, light), 0.0);
            float spec = pow(max(dot(reflect(-light, n), -rd), 0.0), 32.0);
            
            col = baseColor * (0.3 + diff * 0.5 + pattern * 0.4);
            col += vec3(1.0) * spec * 0.5;
            
            // Audio reactive glow
            col += baseColor * uLevel * 1.2;
            
            // Energy particles
            float particles = fbm(p * 8.0 + uTime * 2.0);
            col += vec3(particles) * 0.3 * uLevel;
            
            break;
        }
        
        // Glow accumulation
        if (d < 0.5) {
            float glow = 0.02 / (d + 0.01);
            vec3 glowColor = mix(vec3(0.5, 0.0, 1.0), vec3(0.0, 1.0, 1.0), 
                                sin(uTime * 2.0 + t * 0.5) * 0.5 + 0.5);
            col += glowColor * glow * 0.01 * (1.0 + uLevel);
        }
        
        t += d * 0.7; // Slow down for better detail
        if (t > 50.0) break;
    }
    
    // Add time distortion effect to background
    if (!hit) {
        float distort = length(uv) * 2.0;
        vec3 bgColor = mix(
            vec3(0.02, 0.0, 0.05),
            vec3(0.1, 0.0, 0.15),
            distort
        );
        col += bgColor;
        
        // Add swirling energy in background
        float swirl = sin(atan(uv.y, uv.x) * 5.0 + uTime * 2.0 + length(uv) * 3.0);
        col += vec3(0.3, 0.1, 0.5) * swirl * 0.1 * (1.0 + uLevel * 0.5);
    }
    
    // Chromatic aberration effect
    float aberration = length(uv) * 0.02 * uLevel;
    
    // Vignette
    float vignette = 1.0 - length(uv) * 0.5;
    vignette = smoothstep(0.3, 1.0, vignette);
    col *= vignette;
    
    // Temporal flicker
    float flicker = sin(uTime * 50.0 + hash3(vec3(uv, uTime))) * 0.02 + 0.98;
    col *= flicker;
    
    col = clamp(col, 0.0, 1.0);
    
    fragColor = vec4(col, 1.0);
}

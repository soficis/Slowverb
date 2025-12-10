#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uLevel;

out vec4 fragColor;

// 3D Pipes visualizer inspired by Windows screensaver
// Creates colorful pipe-like structures that grow and twist

// Rotation matrix around Z axis
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Pipe distance function - cylinder with rounded ends
float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 ab = b - a;
    vec3 ap = p - a;
    float t = clamp(dot(ap, ab) / dot(ab, ab), 0.0, 1.0);
    vec3 c = a + t * ab;
    return length(p - c) - r;
}

// Hash for pseudo-random numbers
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

// Smooth noise
float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float n = i.x + i.y * 57.0 + i.z * 113.0;
    float a = hash(n);
    float b = hash(n + 1.0);
    float c = hash(n + 57.0);
    float d = hash(n + 58.0);
    float e = hash(n + 113.0);
    float f1 = hash(n + 114.0);
    float g = hash(n + 170.0);
    float h = hash(n + 171.0);
    
    return mix(
        mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
        mix(mix(e, f1, f.x), mix(g, h, f.x), f.y),
        f.z
    );
}

// Scene - multiple pipes
float map(vec3 p) {
    float t = uTime * 0.3;
    float d = 1e10;
    
    // Generate several pipe segments
    for (int i = 0; i < 6; i++) {
        float phase = float(i) * 1.047; // 60 degrees apart
        float offset = float(i) * 0.5;
        
        // Pipe path based on time and audio level
        vec3 a = vec3(
            cos(t + phase) * 2.0,
            sin(t * 0.7 + phase) * 2.0,
            -3.0 + offset
        );
        vec3 b = vec3(
            cos(t + phase + 0.5) * 2.0 * (1.0 + uLevel * 0.5),
            sin(t * 0.7 + phase + 0.5) * 2.0,
            -1.0 + offset
        );
        
        float pipeRadius = 0.15 + uLevel * 0.1;
        d = min(d, sdCapsule(p, a, b, pipeRadius));
    }
    
    return d;
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
    
    // Camera setup
    vec3 ro = vec3(0.0, 0.0, 4.0);
    vec3 rd = normalize(vec3(uv, -1.5));
    
    // Rotate view based on time
    rd.xz *= rot(uTime * 0.1);
    rd.yz *= rot(sin(uTime * 0.15) * 0.3);
    
    // Raymarching
    float t = 0.0;
    vec3 col = vec3(0.02, 0.02, 0.05); // Dark background
    
    for (int i = 0; i < 64; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        
        if (d < 0.001) {
            // Hit! Calculate color based on position and normal
            vec3 n = calcNormal(p);
            
            // Colorful pipes - cycle through vaporwave colors
            float pipeId = floor(hash(floor(p.z * 2.0)) * 6.0);
            vec3 pipeColor;
            
            if (pipeId < 1.0) pipeColor = vec3(1.0, 0.2, 0.6);      // Hot pink
            else if (pipeId < 2.0) pipeColor = vec3(0.0, 1.0, 0.8); // Cyan
            else if (pipeId < 3.0) pipeColor = vec3(0.8, 0.3, 1.0); // Purple
            else if (pipeId < 4.0) pipeColor = vec3(0.0, 0.8, 0.4); // Green
            else if (pipeId < 5.0) pipeColor = vec3(1.0, 0.6, 0.0); // Orange
            else pipeColor = vec3(0.0, 0.5, 1.0);                    // Blue
            
            // Simple lighting
            vec3 light = normalize(vec3(1.0, 1.0, 1.0));
            float diff = max(dot(n, light), 0.0);
            float spec = pow(max(dot(reflect(-light, n), -rd), 0.0), 32.0);
            
            col = pipeColor * (0.3 + diff * 0.5) + vec3(1.0) * spec * 0.3;
            
            // Audio reactive glow
            col += pipeColor * uLevel * 0.5;
            break;
        }
        
        t += d;
        if (t > 20.0) break;
    }
    
    // Vignette
    vec2 q = fragCoord / resolution;
    col *= 0.5 + 0.5 * pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.15);
    
    fragColor = vec4(col, 1.0);
}

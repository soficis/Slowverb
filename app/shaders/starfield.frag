// Flutter runtime effect shader
#include <flutter/runtime_effect.glsl>

// All uniforms as sequential floats
uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uLevel;

out vec4 fragColor;

// Pseudo-random function
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / vec2(uResolutionX, uResolutionY);
    vec2 center = vec2(0.5, 0.5);
    vec2 centeredUV = uv - center;
    
    float warpSpeed = 1.0 + uLevel * 2.0;
    float time = uTime * warpSpeed;
    
    // Deep space background
    vec3 color = vec3(0.0, 0.0, 0.02);
    
    // Nebula gradient
    float nebula = length(centeredUV);
    color += vec3(0.03, 0.01, 0.05) * (1.0 - nebula);
    
    // Star color (white with slight blue tint)
    vec3 starColor = vec3(0.9, 0.95, 1.0);
    
    // Multiple star layers
    for (int layer = 0; layer < 4; layer++) {
        float depth = 10.0 + float(layer) * 20.0;
        float layerSpeed = 0.5 + float(layer) * 0.3;
        
        vec2 offset = centeredUV * (1.0 + time * layerSpeed * 0.1);
        vec2 scaledUV = (offset + 0.5) * depth;
        vec2 grid = floor(scaledUV);
        vec2 local = fract(scaledUV) - 0.5;
        
        float rand = hash(grid);
        
        if (rand > 0.7) {
            vec2 starPos = vec2(hash(grid + 0.1) - 0.5, hash(grid + 0.2) - 0.5) * 0.8;
            float dist = length(local - starPos);
            
            float baseSize = 0.02 + rand * 0.03;
            float size = baseSize * (1.0 + uLevel * 0.5);
            
            float twinkle = sin(time * (1.0 + rand * 3.0) + rand * 6.28) * 0.3 + 0.7;
            float brightness = smoothstep(size, size * 0.3, dist) * twinkle;
            
            vec3 thisStarColor = starColor;
            if (rand > 0.9) {
                thisStarColor = mix(thisStarColor, vec3(1.0, 0.8, 0.9), 0.3);
            }
            
            color += thisStarColor * brightness * (0.5 + float(layer) * 0.2);
        }
    }
    
    // Warp streaks when level is high
    if (uLevel > 0.4) {
        float streakIntensity = (uLevel - 0.4) / 0.6;
        float angle = atan(centeredUV.y, centeredUV.x);
        float radius = length(centeredUV);
        
        float streak = sin(angle * 50.0 + time * 5.0) * 0.5 + 0.5;
        streak *= smoothstep(0.0, 0.3, radius);
        streak *= smoothstep(0.7, 0.4, radius);
        streak *= streakIntensity;
        
        color += starColor * streak * 0.3;
    }
    
    // Central glow
    float pulse = 0.1 + uLevel * 0.3;
    float centerGlow = smoothstep(pulse, 0.0, length(centeredUV));
    color += starColor * centerGlow * 0.2;
    
    // Vignette
    float vignette = 1.0 - length(centeredUV) * 1.2;
    vignette = clamp(vignette, 0.0, 1.0);
    color *= vignette;
    
    color = clamp(color, 0.0, 1.0);
    
    fragColor = vec4(color, 1.0);
}

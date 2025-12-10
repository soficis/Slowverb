// Flutter runtime effect shader
#include <flutter/runtime_effect.glsl>

// All uniforms as sequential floats
uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uLevel;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / vec2(uResolutionX, uResolutionY);
    vec2 center = vec2(0.5, 0.5);
    
    // Background gradient
    vec3 bgColor = mix(
        vec3(0.02, 0.01, 0.05),
        vec3(0.05, 0.02, 0.08),
        uv.y
    );
    
    vec3 color = bgColor;
    
    // Cyan and Pink colors
    vec3 cyan = vec3(0.0, 1.0, 1.0);
    vec3 pink = vec3(1.0, 0.0, 0.5);
    
    // === SPECTRUM BARS (simulated from level) ===
    if (uv.y < 0.45) {
        float barRegionY = uv.y / 0.45;
        
        int barIndex = int(uv.x * 16.0);
        float barWidth = 1.0 / 16.0;
        float barCenter = (float(barIndex) + 0.5) * barWidth;
        float distFromCenter = abs(uv.x - barCenter) / (barWidth * 0.5);
        
        // Simulate bar height based on position and level
        float phase = float(barIndex) * 0.5 + uTime * 2.0;
        float barHeight = (sin(phase) * 0.3 + 0.5) * uLevel;
        barHeight = clamp(barHeight, 0.1, 0.9);
        
        float barEdge = smoothstep(0.9, 0.5, distFromCenter);
        
        if (barRegionY < barHeight && barEdge > 0.0) {
            float heightRatio = barRegionY / barHeight;
            vec3 barColor = mix(pink, cyan, heightRatio);
            
            if (heightRatio > 0.9) {
                barColor = mix(barColor, vec3(1.0), (heightRatio - 0.9) * 10.0);
            }
            
            float glow = barEdge * (1.0 + uLevel * 0.5);
            color = barColor * glow;
        }
    }
    
    // === OSCILLOSCOPE WAVE (upper half) ===
    if (uv.y >= 0.45) {
        float waveRegionY = (uv.y - 0.45) / 0.55;
        float waveCenter = 0.5;
        
        float waveY = waveCenter + sin(uv.x * 10.0 + uTime * 3.0) * 0.2 * uLevel;
        waveY += sin(uv.x * 25.0 - uTime * 2.0) * 0.1 * uLevel;
        
        float distFromWave = abs(waveRegionY - waveY);
        
        float lineWidth = 0.02 + uLevel * 0.01;
        if (distFromWave < lineWidth) {
            float lineIntensity = 1.0 - (distFromWave / lineWidth);
            vec3 waveColor = mix(cyan, vec3(1.0), lineIntensity * 0.3);
            color = waveColor * lineIntensity;
        }
        
        float glowWidth = 0.08;
        if (distFromWave < glowWidth && distFromWave >= lineWidth) {
            float glowIntensity = 1.0 - (distFromWave / glowWidth);
            glowIntensity *= glowIntensity;
            color += cyan * glowIntensity * 0.4;
        }
    }
    
    // === SCANLINES ===
    float scanline = sin(uv.y * uResolutionY * 0.5) * 0.03 + 0.97;
    color *= scanline;
    
    // === VIGNETTE ===
    float vignette = 1.0 - length(uv - center) * 0.6;
    color *= vignette;
    
    fragColor = vec4(color, 1.0);
}

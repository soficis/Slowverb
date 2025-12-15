#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uLevel;

out vec4 fragColor;

// 3D Rainy Window - GPU raymarched scene
// Full 3D scene with PC, CRT monitor, desk, rain, and lightning

#define PI 3.14159265359
#define MAX_STEPS 100
#define MAX_DIST 50.0
#define SURF_DIST 0.01

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Hash for randomness
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

// SDF primitives
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdCylinder(vec3 p, float h, float r) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

// Scene components
float mapPCBox(vec3 p) {
    vec3 boxPos = p - vec3(-2.5, -0.8, -1.0);
    float box = sdRoundBox(boxPos, vec3(0.3, 0.6, 0.4), 0.02);
    
    // Drive bays
    vec3 bay1 = boxPos - vec3(0.0, 0.3, -0.41);
    float drive1 = sdBox(bay1, vec3(0.2, 0.05, 0.01));
    
    vec3 bay2 = boxPos - vec3(0.0, 0.15, -0.41);
    float drive2 = sdBox(bay2, vec3(0.2, 0.05, 0.01));
    
    return min(box, min(drive1, drive2));
}

float mapCRTMonitor(vec3 p) {
    vec3 monPos = p - vec3(-1.2, 0.0, -0.8);
    
    // Monitor casing
    float casing = sdRoundBox(monPos, vec3(0.5, 0.4, 0.3), 0.05);
    
    // Screen (slightly inset)
    vec3 screenPos = monPos - vec3(0.0, 0.0, -0.31);
    float screen = sdBox(screenPos, vec3(0.42, 0.32, 0.01));
    
    return min(casing, screen);
}

float mapDesk(vec3 p) {
    vec3 deskPos = p - vec3(0.0, -1.5, 0.0);
    return sdBox(deskPos, vec3(5.0, 0.1, 3.0));
}

float mapWindow(vec3 p) {
    vec3 winPos = p - vec3(0.0, 0.5, -3.0);
    float window = sdBox(winPos, vec3(2.5, 1.5, 0.05));
    
    // Window panes
    float frames = min(
        min(
            sdBox(winPos, vec3(0.02, 1.5, 0.06)),
            sdBox(winPos + vec3(1.2, 0.0, 0.0), vec3(0.02, 1.5, 0.06))
        ),
        sdBox(winPos, vec3(2.5, 0.02, 0.06))
    );
    
    return min(window, frames);
}

float mapCoffeeMug(vec3 p) {
    vec3 mugPos = p - vec3(1.0, -0.9, 0.5);
    
    // Mug body
    float outer = sdCylinder(mugPos, 0.15, 0.12);
    float inner = sdCylinder(mugPos + vec3(0.0, 0.05, 0.0), 0.12, 0.1);
    float mug = max(outer, -inner);
    
    // Handle
    vec3 handlePos = mugPos - vec3(0.15, 0.0, 0.0);
    float handleOuter = sdSphere(handlePos, 0.1);
    float handleInner = sdSphere(handlePos, 0.07);
    float handle = max(handleOuter, -handleInner);
    handle = max(handle, -sdBox(mugPos - vec3(0.2, 0.0, 0.0), vec3(0.15, 0.2, 0.2)));
    
    return min(mug, handle);
}

// Main scene
float map(vec3 p) {
    float scene = mapDesk(p);
    scene = min(scene, mapPCBox(p));
    scene = min(scene, mapCRTMonitor(p));
    scene = min(scene, mapWindow(p));
    scene = min(scene, mapCoffeeMug(p));
    
    return scene;
}

vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

// Material colors
vec3 getMaterial(vec3 p) {
    // PC box - beige
    if (length(p - vec3(-2.5, -0.8, -1.0)) < 1.0) {
        return vec3(0.91, 0.84, 0.72);
    }
    // CRT - beige/gray
    if (length(p - vec3(-1.2, 0.0, -0.8)) < 1.0) {
        vec3 monPos = p - vec3(-1.2, 0.0, -0.8);
        vec3 screenPos = monPos - vec3(0.0, 0.0, -0.31);
        if (length(screenPos) < 0.5) {
            // CRT screen - dark with green glow
            float screenEffect = hash13(p * 100.0 + uTime) * 0.2;
            return vec3(0.0, 0.2 + screenEffect * uLevel, 0.15);
        }
        return vec3(0.83, 0.82, 0.78);
    }
    // Coffee mug - cream
    if (length(p - vec3(1.0, -0.9, 0.5)) < 0.3) {
        return vec3(0.93, 0.91, 0.84);
    }
    // Window frame - dark gray
    if (abs(p.z + 3.0) < 0.2) {
        return vec3(0.29, 0.29, 0.29);
    }
    // Desk - brown
    if (p.y < -1.3) {
        return vec3(0.55, 0.45, 0.33);
    }
    
    return vec3(0.5);
}

void main() {
    vec2 fragCoord = FlutterFragCoord();
    vec2 resolution = vec2(uResolutionX, uResolutionY);
    // Flip Y-axis for correct orientation
    vec2 uv = (fragCoord * 2.0 - resolution) / min(resolution.x, resolution.y);
    uv.y = -uv.y;
    
    // Camera position
    vec3 ro = vec3(0.0, 0.0, 3.0);
    vec3 lookAt = vec3(0.0, -0.3, 0.0);
    
    vec3 forward = normalize(lookAt - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    
    vec3 rd = normalize(uv.x * right + uv.y * up + forward * 1.5);
    
    // Raymarching
    float t = 0.0;
    vec3 col = vec3(0.0);
    
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        
        if (d < SURF_DIST) {
            // Hit surface
            vec3 n = calcNormal(p);
            vec3 material = getMaterial(p);
            
            // Lighting
            vec3 lightPos = vec3(2.0, 2.0, 2.0);
            vec3 lightDir = normalize(lightPos - p);
            
            float diff = max(dot(n, lightDir), 0.0);
            float spec = pow(max(dot(reflect(-lightDir, n), -rd), 0.0), 16.0);
            
            col = material * (0.3 + diff * 0.6);
            col += vec3(1.0) * spec * 0.2;
            
            // Ambient occlusion (simple)
            float ao = 1.0 - float(i) / float(MAX_STEPS);
            col *= ao;
            
            break;
        }
        
        if (t > MAX_DIST) break;
        t += d;
    }
    
    // Background - stormy sky through window
    if (t >= MAX_DIST || map(ro + rd * t) > SURF_DIST) {
        vec3 skyCol = mix(vec3(0.1, 0.1, 0.18), vec3(0.18, 0.21, 0.38), uv.y * 0.5 + 0.5);
        col = skyCol;
    }
    
    // Rain effect
    const int maxRainDrops = 120;
    float rainDensity = 60.0 + uLevel * 40.0;
    
    for (int i = 0; i < maxRainDrops; i++) {
        // Skip drops beyond current density
        if (float(i) >= rainDensity) break;
        
        vec2 rainUV = uv + vec2(hash(vec2(float(i), 0.0)) - 0.5, 0.0) * 3.0;
        float rainY = fract((rainUV.y + uTime * (1.5 + hash(vec2(float(i), 1.0)))));
        float rainDrop = smoothstep(0.1, 0.0, abs(rainUV.x) * 20.0) * 
                        smoothstep(0.05, 0.0, abs(rainY - rainUV.y));
        col += vec3(0.47, 0.55, 0.71) * rainDrop * 0.3;
    }
    
    // Lightning flash
    if (uLevel > 0.65) {
        float flash = (uLevel - 0.65) / 0.35;
        col += vec3(1.0) * flash * 0.3;
        
        // Lightning bolt in sky
        float bolt = smoothstep(0.02, 0.0, abs(uv.x - 0.3 + sin(uv.y * 10.0 + uTime * 50.0) * 0.1));
        bolt *= smoothstep(1.0, 0.0, uv.y) * flash;
        col += vec3(1.0) * bolt;
    }
    
    // Warm desk lamp glow
    vec2 lampPos = vec2(0.6, -0.4);
    float lampDist = length(uv - lampPos);
    float lampGlow = exp(-lampDist * 2.0) * 0.3;
    col += vec3(1.0, 0.8, 0.4) * lampGlow;
    
    // CRT screen glow
    vec2 crtScreenPos = vec2(-0.3, 0.1);
    float crtDist = length(uv - crtScreenPos);
    float crtGlow = exp(-crtDist * 4.0) * (0.2 + uLevel * 0.3);
    col += vec3(0.0, 1.0, 0.5) * crtGlow;
    
    // Vignette
    float vignette = 1.0 - length(uv) * 0.4;
    col *= smoothstep(0.0, 1.0, vignette);
    
    col = clamp(col, 0.0, 1.0);
    
    fragColor = vec4(col, 1.0);
}

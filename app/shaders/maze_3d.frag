#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uLevel;

out vec4 fragColor;

// Maze shader inspired by Windows 98 3D Maze screensaver
// First-person view traveling through a maze with audio-reactive effects

// Hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Maze cell check - returns 1 if wall, 0 if path
float mazeCell(vec2 cell) {
    // Create a procedural maze using hash
    float h = hash(cell);
    // Make roughly 35% walls
    return step(0.35, h);
}

// Box distance function
float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

// Map the maze scene
float map(vec3 p) {
    // Floor and ceiling
    float floorDist = p.y + 1.0;
    float ceilingDist = 2.0 - p.y;
    
    // Maze walls - check current cell
    vec2 cell = floor(p.xz / 2.0);
    float isWall = mazeCell(cell);
    
    // Wall distance
    float wall = 1e10;
    if (isWall > 0.5) {
        // Wall pillar
        vec3 cellCenter = vec3(cell.x * 2.0 + 1.0, 0.5, cell.y * 2.0 + 1.0);
        wall = sdBox(p - cellCenter, vec3(0.9, 1.5, 0.9));
    }
    
    return min(min(floorDist, ceilingDist), wall);
}

// Calculate normal
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
    
    // Camera moves through the maze
    float t = uTime * 0.5;
    vec3 ro = vec3(
        sin(t * 0.3) * 3.0 + t * 2.0,
        0.0,
        cos(t * 0.2) * 3.0 + sin(t * 0.5) * 2.0
    );
    
    // Look direction (forward with slight wobble)
    vec3 lookAt = ro + vec3(
        cos(t * 0.3) * 2.0,
        sin(uTime) * 0.1 * uLevel,
        sin(t * 0.2) * 2.0
    );
    
    // Camera matrix
    vec3 forward = normalize(lookAt - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    
    vec3 rd = normalize(uv.x * right + uv.y * up + 1.5 * forward);
    
    // Raymarching
    float dist = 0.0;
    vec3 col = vec3(0.0);
    bool hit = false;
    
    for (int i = 0; i < 64; i++) {
        vec3 p = ro + rd * dist;
        float d = map(p);
        
        if (d < 0.01) {
            hit = true;
            vec3 n = calcNormal(p);
            
            // Determine surface type
            vec3 baseColor;
            if (p.y < -0.9) {
                // Floor - checkered pattern with audio glow
                vec2 checker = floor(p.xz);
                float c = mod(checker.x + checker.y, 2.0);
                baseColor = mix(
                    vec3(0.2, 0.1, 0.3),  // Dark purple
                    vec3(0.3, 0.15, 0.4), // Light purple
                    c
                );
                baseColor += vec3(0.0, uLevel * 0.3, uLevel * 0.2);
            } else if (p.y > 1.9) {
                // Ceiling
                baseColor = vec3(0.1, 0.1, 0.15);
            } else {
                // Walls - vaporwave colored bricks
                vec2 brick = floor(p.xz * 2.0 + p.y * 4.0);
                float brickPattern = hash(brick);
                
                vec3 wallColor1 = vec3(1.0, 0.2, 0.6);  // Hot pink
                vec3 wallColor2 = vec3(0.0, 0.8, 1.0);  // Cyan
                vec3 wallColor3 = vec3(0.7, 0.2, 1.0);  // Purple
                
                if (brickPattern < 0.33) baseColor = wallColor1;
                else if (brickPattern < 0.66) baseColor = wallColor2;
                else baseColor = wallColor3;
                
                // Audio reactive brightness
                baseColor *= (0.5 + uLevel * 0.8);
            }
            
            // Simple lighting
            vec3 light = normalize(vec3(1.0, 2.0, -1.0));
            float diff = max(dot(n, light), 0.2);
            
            col = baseColor * diff;
            
            // Fog for depth
            float fog = 1.0 - exp(-dist * 0.05);
            col = mix(col, vec3(0.05, 0.0, 0.1), fog);
            break;
        }
        
        dist += d;
        if (dist > 50.0) break;
    }
    
    if (!hit) {
        // Sky / void
        col = vec3(0.02, 0.0, 0.05);
    }
    
    // Scanlines for retro feel
    col *= 0.9 + 0.1 * sin(fragCoord.y * 3.0);
    
    // Vignette
    vec2 q = fragCoord / resolution;
    col *= 0.5 + 0.5 * pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.2);
    
    fragColor = vec4(col, 1.0);
}

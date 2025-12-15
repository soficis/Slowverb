// Flutter runtime effect shader - Fractal Dreams 3D post-processing
#include <flutter/runtime_effect.glsl>

// Controls
uniform float uTime;
uniform vec2 uResolution; // (width, height)
uniform float uWarp;    // 0..1
uniform float uChroma;  // 0..1
uniform float uVig;     // 0..1
uniform float uGrain;   // 0..1

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;
  vec2 c = uv - 0.5;
  c.x *= uResolution.x / uResolution.y;

  float r = length(c);

  // Slow "lens breathing" warp (dissociation-friendly: subtle, not wobbly)
  float breath = 0.5 + 0.5 * sin(uTime * 0.18);
  float k = (0.06 + 0.10 * breath) * uWarp;        // warp amount
  vec2 cw = c * (1.0 + k * r * r);

  vec2 uvw = cw;
  uvw.x /= (uResolution.x / uResolution.y);
  uvw += 0.5;

  // Edge-weighted chromatic mis-registration
  float edge = smoothstep(0.15, 0.95, r);
  float ca = (0.0008 + 0.0025 * edge) * uChroma;   // in UV units
  vec2 dir = (r > 1e-5) ? (c / r) : vec2(1, 0);
  vec2 off = dir * ca;

  // Sample the base visualizer with chromatic aberration
  // Note: For now, we'll use the warped UV without texture sampling
  // The actual texture sampling would happen via FlutterFragCoord 
  // but we need to render base visualizer first
  vec2 uvR = uvw + off;
  vec2 uvG = uvw;
  vec2 uvB = uvw - off;

  // For this implementation, we'll create a gradient effect
  // In a full post-processing setup, this would sample from the base layer
  vec3 baseColor = vec3(
    0.5 + 0.5 * sin(uTime + uvR.x * 10.0),
    0.5 + 0.5 * sin(uTime + uvG.y * 10.0),
    0.5 + 0.5 * sin(uTime + uvB.x * 5.0 + uvB.y * 5.0)
  );

  vec3 col = baseColor;

  // Vignette (soft, "tunnel" feel)
  float vig = 1.0 - (0.55 * uVig) * smoothstep(0.25, 1.05, r);
  col *= vig;

  // Grain (tiny; avoid shimmer by keeping it subtle)
  float n = hash(fragCoord + uTime * 11.0) - 0.5;
  col += vec3(n * (0.06 * uGrain));

  fragColor = vec4(col, 1.0);
}

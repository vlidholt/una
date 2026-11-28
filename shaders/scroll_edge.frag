// The soft scroll edge of a Liquid Glass bar where the renderer has no
// shader image filters (every browser): the page under the bar, from a
// small snapshot of it, blurred more the nearer it is to the screen's edge.
//
// One pass over one image. The blur's sigma falls smoothly from uMaxSigma
// at the screen's edge to nothing at the far end of the rectangle, and
// where it is lighter than the snapshot can show (a texel is a few logical
// pixels), the result fades out and the sharp page underneath shows
// instead, so the edge has no line where it ends. The page-colour veil
// over it is drawn separately.
//
// Used by lib/src/utils/scroll_edge_shader.dart; keep the uniforms in step.

#version 460 core

#include <flutter/runtime_effect.glsl>

// The rectangle drawn, in the canvas's coordinates, logical pixels.
uniform vec2 uOrigin;
uniform vec2 uSize;
// The sigma at the screen's edge, in logical pixels.
uniform float uMaxSigma;
// Texels of the snapshot per logical pixel.
uniform float uTexScale;
// 1 for the bottom edge of the screen (blurred most at the bottom), else 0.
uniform float uFromBottom;
// The page colour, premultiplied: what the snapshot is laid over. The
// snapshot holds the page's content but not the scaffold's background, so
// text on a plain page blurred to near nothing and stayed sharp beneath.
uniform vec4 uBackground;

// The page under the rectangle, exactly covering it.
uniform sampler2D uImage;

out vec4 fragColor;

// Taps each side of the centre, per axis: a 9 × 9 kernel.
const int kHalf = 4;

void main() {
  vec2 p = FlutterFragCoord().xy - uOrigin;
  vec2 uv = p / uSize;
  // 0 at the screen's edge, 1 at the far end.
  float d = clamp(uFromBottom > 0.5 ? 1.0 - uv.y : uv.y, 0.0, 1.0);
  // Eased at both ends: strongest held near the edge, no knee at the end.
  float s = 1.0 - smoothstep(0.0, 1.0, d);
  float sigma = uMaxSigma * s * s;

  // Lighter than about a texel and a half, the snapshot cannot show the
  // blur: give way to the page underneath, which is sharp.
  float texel = 1.0 / max(uTexScale, 1e-3);
  float alpha = smoothstep(0.5 * texel, 1.4 * texel, sigma);
  if (alpha <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // The taps reach 2.5 sigma either way, at least a texel apart.
  float step = max(sigma * 2.5 / float(kHalf), texel * 0.5);
  vec2 stepUv = vec2(step) / uSize;
  float inv = 1.0 / (2.0 * sigma * sigma);
  vec4 sum = vec4(0.0);
  float weights = 0.0;
  for (int y = -kHalf; y <= kHalf; y++) {
    for (int x = -kHalf; x <= kHalf; x++) {
      vec2 o = vec2(float(x), float(y)) * step;
      float w = exp(-dot(o, o) * inv);
      vec2 tap = clamp(uv + vec2(float(x), float(y)) * stepUv, 0.0, 1.0);
      sum += texture(uImage, tap) * w;
      weights += w;
    }
  }
  // The snapshot is premultiplied, and so is the output: over the page
  // colour, so that the blur covers the sharp page where it is drawn.
  vec4 blurred = sum / weights;
  fragColor = (blurred + uBackground * (1.0 - blurred.a)) * alpha;
}

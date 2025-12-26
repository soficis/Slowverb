#pragma once

#include <wasm_simd128.h>

namespace bakuage {
namespace simd {

namespace detail {
constexpr float kExpHi = 88.3762626647949f;
constexpr float kExpLo = -88.3762626647949f;
constexpr float kLog2e = 1.44269504088896341f;
constexpr float kLn10 = 2.302585092994046f;
constexpr float kDbScale = 4.342944819032518f; // 10 / ln(10)
constexpr float kMinNormPos = 1.17549435e-38f;
constexpr float kSqrtHalf = 0.707106781186547524f;

constexpr float kExpC1 = 0.693359375f;
constexpr float kExpC2 = -2.12194440e-4f;
constexpr float kExpP0 = 1.9875691500E-4f;
constexpr float kExpP1 = 1.3981999507E-3f;
constexpr float kExpP2 = 8.3334519073E-3f;
constexpr float kExpP3 = 4.1665795894E-2f;
constexpr float kExpP4 = 1.6666665459E-1f;
constexpr float kExpP5 = 5.0000001201E-1f;

constexpr float kLogP0 = 7.0376836292E-2f;
constexpr float kLogP1 = -1.1514610310E-1f;
constexpr float kLogP2 = 1.1676998740E-1f;
constexpr float kLogP3 = -1.2420140846E-1f;
constexpr float kLogP4 = 1.4249322787E-1f;
constexpr float kLogP5 = -1.6668057665E-1f;
constexpr float kLogP6 = 2.0000714765E-1f;
constexpr float kLogP7 = -2.4999993993E-1f;
constexpr float kLogP8 = 3.3333331174E-1f;
constexpr float kLogQ1 = -2.12194440e-4f;
constexpr float kLogQ2 = 0.693359375f;
} // namespace detail

inline v128_t fast_exp_ps(v128_t x) {
  x = wasm_f32x4_min(x, wasm_f32x4_splat(detail::kExpHi));
  x = wasm_f32x4_max(x, wasm_f32x4_splat(detail::kExpLo));

  v128_t fx = wasm_f32x4_mul(x, wasm_f32x4_splat(detail::kLog2e));
  fx = wasm_f32x4_add(fx, wasm_f32x4_splat(0.5f));

  v128_t fx_floor = wasm_f32x4_floor(fx);
  v128_t tmp = wasm_f32x4_mul(fx_floor, wasm_f32x4_splat(detail::kExpC1));
  v128_t z = wasm_f32x4_mul(fx_floor, wasm_f32x4_splat(detail::kExpC2));
  x = wasm_f32x4_sub(x, tmp);
  x = wasm_f32x4_sub(x, z);

  v128_t y = wasm_f32x4_splat(detail::kExpP0);
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kExpP1));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kExpP2));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kExpP3));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kExpP4));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kExpP5));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x), wasm_f32x4_splat(1.0f));

  v128_t emm0 = wasm_i32x4_trunc_sat_f32x4(fx_floor);
  emm0 = wasm_i32x4_add(emm0, wasm_i32x4_splat(0x7f));
  emm0 = wasm_i32x4_shl(emm0, 23);
  v128_t pow2n = emm0;

  return wasm_f32x4_mul(y, pow2n);
}

inline v128_t fast_log_ps(v128_t x) {
  x = wasm_f32x4_max(x, wasm_f32x4_splat(detail::kMinNormPos));

  v128_t xi = x;
  v128_t emm0 = wasm_i32x4_shr(xi, 23);
  xi = wasm_v128_and(xi, wasm_i32x4_splat(0x007fffff));
  xi = wasm_v128_or(xi, wasm_i32x4_splat(0x3f000000));
  x = xi;

  emm0 = wasm_i32x4_sub(emm0, wasm_i32x4_splat(0x7f));
  v128_t e = wasm_f32x4_convert_i32x4(emm0);

  v128_t mask = wasm_f32x4_lt(x, wasm_f32x4_splat(detail::kSqrtHalf));
  v128_t tmp = wasm_v128_bitselect(x, wasm_f32x4_splat(0.0f), mask);
  x = wasm_f32x4_sub(x, wasm_f32x4_splat(1.0f));
  e = wasm_f32x4_sub(e,
                     wasm_v128_bitselect(wasm_f32x4_splat(1.0f),
                                         wasm_f32x4_splat(0.0f), mask));
  x = wasm_f32x4_add(x, tmp);

  v128_t z = wasm_f32x4_mul(x, x);

  v128_t y = wasm_f32x4_splat(detail::kLogP0);
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kLogP1));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kLogP2));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kLogP3));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kLogP4));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kLogP5));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kLogP6));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kLogP7));
  y = wasm_f32x4_add(wasm_f32x4_mul(y, x),
                     wasm_f32x4_splat(detail::kLogP8));
  y = wasm_f32x4_mul(y, x);
  y = wasm_f32x4_mul(y, z);

  v128_t y1 =
      wasm_f32x4_mul(e, wasm_f32x4_splat(detail::kLogQ1));
  y = wasm_f32x4_add(y, y1);
  y = wasm_f32x4_sub(y, wasm_f32x4_mul(z, wasm_f32x4_splat(0.5f)));
  x = wasm_f32x4_add(x, y);
  x = wasm_f32x4_add(x,
                     wasm_f32x4_mul(e, wasm_f32x4_splat(detail::kLogQ2)));
  return x;
}

inline v128_t fast_pow10_ps(v128_t x) {
  return fast_exp_ps(wasm_f32x4_mul(x, wasm_f32x4_splat(detail::kLn10)));
}

inline v128_t db_to_linear(v128_t db) {
  return fast_pow10_ps(wasm_f32x4_mul(db, wasm_f32x4_splat(0.1f)));
}

inline v128_t linear_to_db(v128_t lin) {
  return wasm_f32x4_mul(fast_log_ps(lin),
                        wasm_f32x4_splat(detail::kDbScale));
}

} // namespace simd
} // namespace bakuage

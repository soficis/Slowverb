#include "phase_limiter/auto_mastering.h"

#include "gflags/gflags.h"
#include "picojson.h"
#include "tbb/tbb.h"
#include <algorithm>
#include <boost/archive/binary_iarchive.hpp>
#include <chrono>
#include <cmath>
#include <deque>
#include <fstream>
#include <iostream>
#include <limits>
#include <mutex>
#include <optim.hpp>
#include <stdexcept>
#include <string>
#include <vector>

#include "bakuage/decimator.h"
#include "bakuage/fir_design.h"
#include "bakuage/fir_filter2.h"
#include "bakuage/ms_compressor_filter.h"
#include "bakuage/simd_utils.h"
#include "bakuage/sound_quality2.h"
#include "bakuage/utils.h"

DECLARE_string(sound_quality2_cache);
DECLARE_string(mastering5_optimization_algorithm);
DECLARE_int32(mastering5_optimization_max_eval_count);
DECLARE_int32(mastering5_early_termination_patience);
DECLARE_double(mastering5_mastering_level);
DECLARE_string(mastering5_mastering_reference_file);
DECLARE_bool(mastering5_use_warm_start);
DECLARE_int32(mastering5_analysis_downsample_factor);

typedef float Float;
using namespace bakuage;

namespace {
// compress(x) -> wet_gain -> output
// x -> dry_gain -> output
class LoudnessMapping {
public:
  LoudnessMapping() {}
  LoudnessMapping(Float original_mean, Float relative_threshold, Float wet_gain,
                  Float relative_dry_gain, Float ratio)
      : original_mean_(original_mean), target_mean_(original_mean + wet_gain),
        threshold_(original_mean + relative_threshold),
        dry_gain_(wet_gain + relative_dry_gain), inv_ratio_(1.0 / ratio) {}

  struct Params {
    Float original_mean;
    Float target_mean;
    Float threshold;
    Float dry_gain;
    Float inv_ratio;
  };

  Float operator()(Float x) const {
    static const float log10_div_20 = std::log(10) / 20;
    Float w = std::max(threshold_, x);
    Float gain = (w - original_mean_) * inv_ratio_ + target_mean_ - w;
    Float y = x + gain;
    Float z = x + dry_gain_;
    return 20 * std::log10(1e-37 + 0.5 * std::exp(log10_div_20 * y) +
                           0.5 * std::exp(log10_div_20 * z));
  }

  Params GetParams() const {
    return {original_mean_, target_mean_, threshold_, dry_gain_, inv_ratio_};
  }

  Float threshold() const { return threshold_; }

private:
  Float original_mean_;
  Float target_mean_;
  Float threshold_;
  Float dry_gain_;
  Float inv_ratio_;
};
typedef MsCompressorFilter<Float, LoudnessMapping, LoudnessMapping> Compressor;

typedef arma::vec EffectParams;

struct BandEffect {
  LoudnessMapping loudness_mapping;
  LoudnessMapping ms_loudness_mapping;
};

// 空間は重要。最適化のしやすさに関わる
// (あきらかに同じ値を返すような点が複数あると効率が悪い) param変換。param in
// [a, b]。0で恒等変換になるようにする 両側に均等なものはparam in [-1,
// 1]だが、そうでないものは[0, 1]とかもありえる
Float ToRelThreshold(Float x) { return 20 * x; }
Float ToWetGain(Float x) { return 10 * x; }
Float ToRelativeDryGain(Float x) { return 10 * x; }
Float ToRatio(Float x) { return std::pow(5, x); }

// すべてゼロで恒等変換になるようにする
struct Effect {
  Effect(const Eigen::VectorXd &original_mean, const EffectParams &params) {
    const int band_count = params.size() / 8;
    band_effects.resize(band_count);
    // Clamp parameters to safe ranges to prevent numerical instability
    // (Inf/NaN) The optimizer might explore outside bounds, so we enforce them
    // here.
    for (int i = 0; i < band_count; i++) {
      // Param mapping indices: 0=thresh, 1=wet, 2=dry, 3=ratio
      // Same for ms (4,5,6,7)

      // Clamp Ratio input (index 3 and 7) to avoid Ratio -> 0 (Expansion
      // Explosion) Bound was -0.01. Let's clamp to -0.01.
      Float p_ratio = std::max<Float>(-0.01, params(8 * i + 3));
      Float ms_p_ratio = std::max<Float>(-0.01, params(8 * i + 7));

      band_effects[i].loudness_mapping = LoudnessMapping(
          original_mean[2 * i + 0], ToRelThreshold(params(8 * i + 0)),
          ToWetGain(params(8 * i + 1)), ToRelativeDryGain(params(8 * i + 2)),
          ToRatio(p_ratio));
      band_effects[i].ms_loudness_mapping = LoudnessMapping(
          original_mean[2 * i + 1], ToRelThreshold(params(8 * i + 4)),
          ToWetGain(params(8 * i + 5)), ToRelativeDryGain(params(8 * i + 6)),
          ToRatio(ms_p_ratio));
    }
  }
  std::vector<BandEffect> band_effects;
};

#if defined(__wasm_simd128__)
struct MappingParamsBlock {
  alignas(16) Float original_mean[4];
  alignas(16) Float target_mean[4];
  alignas(16) Float threshold[4];
  alignas(16) Float dry_gain[4];
  alignas(16) Float inv_ratio[4];
};

struct MappingParamsSIMD {
  v128_t original_mean;
  v128_t target_mean;
  v128_t threshold;
  v128_t dry_gain;
  v128_t inv_ratio;
};

MappingParamsBlock GetMidParamsBlock(const std::vector<BandEffect> &band_effects,
                                     int base) {
  MappingParamsBlock block;
  for (int lane = 0; lane < 4; lane++) {
    const auto params = band_effects[base + lane].loudness_mapping.GetParams();
    block.original_mean[lane] = params.original_mean;
    block.target_mean[lane] = params.target_mean;
    block.threshold[lane] = params.threshold;
    block.dry_gain[lane] = params.dry_gain;
    block.inv_ratio[lane] = params.inv_ratio;
  }
  return block;
}

MappingParamsBlock GetSideParamsBlock(const std::vector<BandEffect> &band_effects,
                                      int base) {
  MappingParamsBlock block;
  for (int lane = 0; lane < 4; lane++) {
    const auto params =
        band_effects[base + lane].ms_loudness_mapping.GetParams();
    block.original_mean[lane] = params.original_mean;
    block.target_mean[lane] = params.target_mean;
    block.threshold[lane] = params.threshold;
    block.dry_gain[lane] = params.dry_gain;
    block.inv_ratio[lane] = params.inv_ratio;
  }
  return block;
}

MappingParamsSIMD LoadMappingParamsSIMD(const MappingParamsBlock &block) {
  MappingParamsSIMD params;
  params.original_mean = wasm_v128_load(block.original_mean);
  params.target_mean = wasm_v128_load(block.target_mean);
  params.threshold = wasm_v128_load(block.threshold);
  params.dry_gain = wasm_v128_load(block.dry_gain);
  params.inv_ratio = wasm_v128_load(block.inv_ratio);
  return params;
}

v128_t ApplyLoudnessMappingSIMD(v128_t x, const MappingParamsSIMD &params) {
  const v128_t log10_div_20 = wasm_f32x4_splat(0.11512925464970229f);
  v128_t w = wasm_f32x4_max(params.threshold, x);
  v128_t gain = wasm_f32x4_add(
      wasm_f32x4_mul(wasm_f32x4_sub(w, params.original_mean), params.inv_ratio),
      wasm_f32x4_sub(params.target_mean, w));
  v128_t y = wasm_f32x4_add(x, gain);
  v128_t z = wasm_f32x4_add(x, params.dry_gain);
  v128_t exp_y = simd::fast_exp_ps(wasm_f32x4_mul(log10_div_20, y));
  v128_t exp_z = simd::fast_exp_ps(wasm_f32x4_mul(log10_div_20, z));
  v128_t sum =
      wasm_f32x4_add(wasm_f32x4_mul(exp_y, wasm_f32x4_splat(0.5f)),
                     wasm_f32x4_mul(exp_z, wasm_f32x4_splat(0.5f)));
  sum = wasm_f32x4_add(sum, wasm_f32x4_splat(1e-37f));
  v128_t db = simd::linear_to_db(sum);
  return wasm_f32x4_mul(db, wasm_f32x4_splat(2.0f));
}
#endif

void ApplyEffectScalar(const Effect &effect, const Float *input,
                       Float *output) {
  for (int i = 0; i < effect.band_effects.size(); i++) {
    const auto &band_effect = effect.band_effects[i];
    static const float log10_div_20 = std::log(10) / 20;

    Float input_m = input[2 * i + 0];
    Float input_s = input[2 * i + 1];
    Float rms_m = std::pow(10, 0.1 * input_m);
    Float rms_s = std::pow(10, 0.1 * input_s);

    Float total_loudness = -0.691 + 10 * std::log10(rms_m + rms_s + 1e-37);
    Float mapped_loudness = band_effect.loudness_mapping(total_loudness);

    Float mid_to_side_loudness = input_s - input_m;
    Float side_gain = std::exp(
        log10_div_20 *
        (band_effect.ms_loudness_mapping(mid_to_side_loudness) -
         mid_to_side_loudness));

    Float total_loudness_with_side_gain =
        -0.691 + 10 * std::log10(rms_m + rms_s * bakuage::Sqr(side_gain) +
                                 1e-37);
    Float gain = std::exp(log10_div_20 *
                          (mapped_loudness - total_loudness_with_side_gain));

    output[2 * i + 0] = 10 * std::log10(rms_m * bakuage::Sqr(gain));
    output[2 * i + 1] =
        10 * std::log10(rms_s * bakuage::Sqr(side_gain * gain));
  }
}

#if defined(__wasm_simd128__)
void ApplyEffectSIMD(const Effect &effect, const Float *input, Float *output) {
  const auto &band_effects = effect.band_effects;
  const int band_count = static_cast<int>(band_effects.size());
  const v128_t log10_div_20 = wasm_f32x4_splat(0.11512925464970229f);
  const v128_t bias = wasm_f32x4_splat(-0.691f);
  const v128_t eps = wasm_f32x4_splat(1e-37f);

  int i = 0;
  for (; i + 3 < band_count; i += 4) {
    v128_t in0 = wasm_v128_load(&input[2 * i]);
    v128_t in1 = wasm_v128_load(&input[2 * i + 4]);
    v128_t input_m = wasm_i32x4_shuffle(in0, in1, 0, 2, 4, 6);
    v128_t input_s = wasm_i32x4_shuffle(in0, in1, 1, 3, 5, 7);

    const auto mid_block = GetMidParamsBlock(band_effects, i);
    const auto side_block = GetSideParamsBlock(band_effects, i);
    const auto mid_params = LoadMappingParamsSIMD(mid_block);
    const auto side_params = LoadMappingParamsSIMD(side_block);

    v128_t rms_m = simd::db_to_linear(input_m);
    v128_t rms_s = simd::db_to_linear(input_s);
    v128_t total_loudness =
        wasm_f32x4_add(bias, simd::linear_to_db(wasm_f32x4_add(
                                    wasm_f32x4_add(rms_m, rms_s), eps)));
    v128_t mapped_loudness = ApplyLoudnessMappingSIMD(total_loudness, mid_params);

    v128_t mid_to_side = wasm_f32x4_sub(input_s, input_m);
    v128_t ms_mapped = ApplyLoudnessMappingSIMD(mid_to_side, side_params);
    v128_t side_gain = simd::fast_exp_ps(
        wasm_f32x4_mul(log10_div_20, wasm_f32x4_sub(ms_mapped, mid_to_side)));
    v128_t side_gain_sq = wasm_f32x4_mul(side_gain, side_gain);

    v128_t total_loudness_with_side_gain = wasm_f32x4_add(
        bias, simd::linear_to_db(wasm_f32x4_add(
                  wasm_f32x4_add(rms_m, wasm_f32x4_mul(rms_s, side_gain_sq)),
                  eps)));
    v128_t gain = simd::fast_exp_ps(wasm_f32x4_mul(
        log10_div_20,
        wasm_f32x4_sub(mapped_loudness, total_loudness_with_side_gain)));
    v128_t gain_sq = wasm_f32x4_mul(gain, gain);

    v128_t output_m =
        simd::linear_to_db(wasm_f32x4_mul(rms_m, gain_sq));
    v128_t output_s =
        simd::linear_to_db(wasm_f32x4_mul(rms_s,
                                          wasm_f32x4_mul(side_gain_sq, gain_sq)));

    v128_t out0 = wasm_i32x4_shuffle(output_m, output_s, 0, 4, 1, 5);
    v128_t out1 = wasm_i32x4_shuffle(output_m, output_s, 2, 6, 3, 7);
    wasm_v128_store(&output[2 * i], out0);
    wasm_v128_store(&output[2 * i + 4], out1);
  }

  for (; i < band_count; i++) {
    const auto &band_effect = band_effects[i];
    static const float log10_div_20_scalar = std::log(10) / 20;

    Float input_m = input[2 * i + 0];
    Float input_s = input[2 * i + 1];
    Float rms_m = std::pow(10, 0.1 * input_m);
    Float rms_s = std::pow(10, 0.1 * input_s);

    Float total_loudness = -0.691 + 10 * std::log10(rms_m + rms_s + 1e-37);
    Float mapped_loudness = band_effect.loudness_mapping(total_loudness);

    Float mid_to_side_loudness = input_s - input_m;
    Float side_gain = std::exp(
        log10_div_20_scalar *
        (band_effect.ms_loudness_mapping(mid_to_side_loudness) -
         mid_to_side_loudness));

    Float total_loudness_with_side_gain =
        -0.691 + 10 * std::log10(rms_m + rms_s * bakuage::Sqr(side_gain) +
                                 1e-37);
    Float gain = std::exp(
        log10_div_20_scalar *
        (mapped_loudness - total_loudness_with_side_gain));

    output[2 * i + 0] = 10 * std::log10(rms_m * bakuage::Sqr(gain));
    output[2 * i + 1] =
        10 * std::log10(rms_s * bakuage::Sqr(side_gain * gain));
  }
}
#endif

void ApplyEffectToBandLoudness(const Effect &effect, const Float *input,
                               Float *output) {
#if defined(__wasm_simd128__)
  ApplyEffectSIMD(effect, input, output);
#else
  ApplyEffectScalar(effect, input, output);
#endif
}

int GetCompBandIndex(const SoundQuality2CalculatorUnit::Band &band,
                     int sample_rate) {
  const double high =
      band.high_freq > 0 ? band.high_freq : sample_rate * 0.5;
  const double center = 0.5 * (band.low_freq + high);
  if (center < 400.0) {
    return 0;
  }
  if (center < 1000.0) {
    return 1;
  }
  if (center < 5000.0) {
    return 2;
  }
  return 3;
}

EffectParams GetLevel3WarmStart(
    const std::vector<float> &wave, int sample_rate,
    const SoundQuality2Calculator &calculator,
    const std::function<void(float)> &progress_callback) {
  const auto params3 = phase_limiter::GetMastering3OptimumParams(
      wave, sample_rate, progress_callback);
  const int band_count = calculator.band_count();
  EffectParams warm_params(8 * band_count, arma::fill::zeros);

  if (params3.comp_band_count <= 0) {
    return warm_params;
  }
  const int expected_size = 2 * params3.comp_band_count;
  if (params3.compressor_ratios.size() < expected_size ||
      params3.compressor_thresholds.size() < expected_size ||
      params3.compressor_wets.size() < expected_size ||
      params3.compressor_gains.size() < expected_size) {
    return warm_params;
  }

  const auto &bands = calculator.bands();
  const double log5 = std::log(5.0);

  auto to_param_ratio = [&](double ratio) {
    const double safe_ratio = std::max(1e-6, ratio);
    return std::log(safe_ratio) / log5;
  };

  auto to_param_wet_gain = [&](double gain_linear) {
    const double safe_gain = std::max(1e-6, gain_linear);
    const double wet_gain_db = 20.0 * std::log10(safe_gain);
    return wet_gain_db / 10.0;
  };

  auto to_param_rel_threshold = [&](double threshold_db) {
    return threshold_db / 20.0;
  };

  auto to_param_rel_dry_gain = [&](double wet, double wet_gain_db) {
    const double dry_gain_db =
        20.0 * std::log10(std::max(1e-3, 1.0 - wet));
    const double rel_dry_gain_db = dry_gain_db - wet_gain_db;
    return rel_dry_gain_db / 10.0;
  };

  for (int i = 0; i < band_count; i++) {
    const int comp_index =
        std::min(params3.comp_band_count - 1,
                 GetCompBandIndex(bands[i], sample_rate));
    const int mid_index = 2 * comp_index;
    const int side_index = 2 * comp_index + 1;

    const double mid_ratio = params3.compressor_ratios[mid_index];
    const double mid_threshold = params3.compressor_thresholds[mid_index];
    const double mid_wet = params3.compressor_wets[mid_index];
    const double mid_gain = params3.compressor_gains[mid_index];
    const double mid_wet_gain_db =
        20.0 * std::log10(std::max(1e-6, mid_gain));

    warm_params(8 * i + 0) = to_param_rel_threshold(mid_threshold);
    warm_params(8 * i + 1) = to_param_wet_gain(mid_gain);
    warm_params(8 * i + 2) = to_param_rel_dry_gain(mid_wet, mid_wet_gain_db);
    warm_params(8 * i + 3) = to_param_ratio(mid_ratio);

    const double side_ratio = params3.compressor_ratios[side_index];
    const double side_threshold = params3.compressor_thresholds[side_index];
    const double side_wet = params3.compressor_wets[side_index];
    const double side_gain = params3.compressor_gains[side_index];
    const double side_wet_gain_db =
        20.0 * std::log10(std::max(1e-6, side_gain));

    warm_params(8 * i + 4) = to_param_rel_threshold(side_threshold);
    warm_params(8 * i + 5) = to_param_wet_gain(side_gain);
    warm_params(8 * i + 6) = to_param_rel_dry_gain(side_wet, side_wet_gain_db);
    warm_params(8 * i + 7) = to_param_ratio(side_ratio);
  }

  for (int i = 0; i < warm_params.size(); i++) {
    if (!std::isfinite(warm_params(i))) {
      warm_params(i) = 0.0;
    }
  }

  return warm_params;
}

void ClampParams(EffectParams *params, const arma::vec &lower_bounds,
                 const arma::vec &upper_bounds) {
  if (!params) {
    return;
  }
  for (int i = 0; i < params->size(); i++) {
    if ((*params)(i) < lower_bounds(i)) {
      (*params)(i) = lower_bounds(i);
    } else if ((*params)(i) > upper_bounds(i)) {
      (*params)(i) = upper_bounds(i);
    }
  }
}

struct ConvergenceState {
  float last_best = std::numeric_limits<float>::infinity();
  int evals_since_improvement = 0;
  std::deque<float> recent_evals;
  std::deque<float> recent_best;
  std::chrono::steady_clock::time_point start_time =
      std::chrono::steady_clock::now();
};

void PushRecent(std::deque<float> *values, float value, size_t max_size) {
  values->push_back(value);
  if (values->size() > max_size) {
    values->pop_front();
  }
}

bool HasLowImprovement(const std::deque<float> &recent_best,
                       float threshold, size_t window) {
  if (recent_best.size() < window) {
    return false;
  }
  const float start = recent_best.front();
  const float end = recent_best.back();
  const float scale = std::max(1e-6f, std::abs(start));
  const float rel_improvement = (start - end) / scale;
  return rel_improvement < threshold;
}

bool IsDiversityLow(const std::deque<float> &values, float threshold) {
  if (values.size() < 20) {
    return false;
  }
  float min_val = values.front();
  float max_val = values.front();
  for (float v : values) {
    min_val = std::min(min_val, v);
    max_val = std::max(max_val, v);
  }
  const float scale = std::max(1e-6f, std::abs(max_val));
  const float rel_range = (max_val - min_val) / scale;
  return rel_range < threshold;
}

bool IsOscillating(const std::deque<float> &values) {
  if (values.size() < 20) {
    return false;
  }
  int sign_changes = 0;
  float prev_diff = values[1] - values[0];
  for (size_t i = 2; i < values.size(); i++) {
    const float diff = values[i] - values[i - 1];
    if ((diff > 0) != (prev_diff > 0)) {
      sign_changes++;
    }
    if (std::abs(diff) > 1e-6f) {
      prev_diff = diff;
    }
  }
  float min_val = values.front();
  float max_val = values.front();
  for (float v : values) {
    min_val = std::min(min_val, v);
    max_val = std::max(max_val, v);
  }
  const float range = max_val - min_val;
  const float net = values.back() - values.front();
  if (range <= 1e-6f) {
    return false;
  }
  return std::abs(net) < 0.1f * range &&
         sign_changes > static_cast<int>(values.size() / 3);
}

bool IsTimeBudgetExceeded(const ConvergenceState &state,
                          std::chrono::seconds budget) {
  return std::chrono::steady_clock::now() - state.start_time >= budget;
}

bool ShouldTerminate(const ConvergenceState &state, int patience) {
  if (state.evals_since_improvement >= patience) {
    return true;
  }
  if (IsTimeBudgetExceeded(state, std::chrono::seconds(30))) {
    return true;
  }
  if (HasLowImprovement(state.recent_best, 0.001f, 100)) {
    return true;
  }
  if (IsDiversityLow(state.recent_evals, 0.001f)) {
    return true;
  }
  if (IsOscillating(state.recent_evals)) {
    return true;
  }
  return false;
}

struct StageConfig {
  int analysis_factor;
  int max_eval_count;
  int early_patience;
  const char *name;
};

struct StageResult {
  EffectParams params;
  Eigen::VectorXd original_mean;
};

StageResult OptimizeParamsForStage(
    const std::vector<float> &wave, int sample_rate,
    const SoundQuality2Calculator &calculator,
    const bakuage::MasteringReference2 &mastering_reference,
    const StageConfig &stage,
    const std::function<void(float)> &progress_callback,
    const EffectParams *initial_params) {
  const int frames = wave.size() / 2;
  const int channels = 2;
  const float block_sec = 0.4;
  const int analysis_factor = std::max(1, stage.analysis_factor);
  const int analysis_rate = std::max(1, sample_rate / analysis_factor);
  std::vector<float> analysis_wave;
  const std::vector<float> *analysis_wave_ptr = &wave;
  int analysis_frames = frames;

  if (analysis_factor > 1) {
    bakuage::Decimator<float> decimator(analysis_factor);
    analysis_wave = decimator.Process(wave, channels);
    if (!analysis_wave.empty()) {
      analysis_wave_ptr = &analysis_wave;
      analysis_frames = analysis_wave.size() / channels;
    }
  }

  std::cerr << "Starting optimization stage: " << stage.name << std::endl;

  // calculate original band loudness vectors
  std::vector<bakuage::AlignedPodVector<float>> band_loudnesses;
  {
    // 400ms block
    const int sample_freq = analysis_rate;
    const int width = bakuage::CeilPowerOf2(sample_freq * block_sec);
    const int shift =
        width / 2; // 50% overlap
    const int samples = analysis_frames;
    bakuage::AlignedPodVector<Float> filtered(channels * samples);
    for (int i = 0; i < channels; i++) {
      LoudnessFilter<float> filter(sample_freq);
      for (int j = 0; j < samples; j++) {
        int k = channels * j + i;
        filtered[k] = filter.Clock((*analysis_wave_ptr)[k]);
      }
    }

    const int spec_len = width / 2 + 1;

    // FFT (sqrt(hanning))
    bakuage::AlignedPodVector<float> window(width);
    bakuage::CopyHanning(width, window.data(), 1.0 / std::sqrt(width));

    band_loudnesses.resize(bakuage::CeilInt(samples, shift) / shift);
    tbb::parallel_for<int>(0, band_loudnesses.size(), [&](int pos_idx) {
      const int pos = pos_idx * shift;
      const int end = samples;

      auto &pool = bakuage::ThreadLocalDftPool<
          bakuage::RealDft<float>>::GetThreadInstance();
      auto dft = pool.Get(width);

      bakuage::AlignedPodVector<float> fft_input(width);
      std::vector<bakuage::AlignedPodVector<std::complex<float>>> fft_outputs(
          channels);
      for (int ch = 0; ch < channels; ch++) {
        fft_outputs[ch].resize(spec_len);
      }
      const int band_count = calculator.band_count();
      bakuage::AlignedPodVector<float> band_loudness(2 * band_count);

      // FFT
      for (int ch = 0; ch < channels; ch++) {
        for (int i = 0; i < width; i++) {
          fft_input[i] = pos + i < end
                             ? filtered[channels * (pos + i) + ch] * window[i]
                             : 0;
        }
        dft->Forward(fft_input.data(), (float *)fft_outputs[ch].data(),
                     pool.work());
      }

      // band loudness
      for (int band_index = 0; band_index < band_count; band_index++) {
        int low_bin_index =
            std::floor(width * calculator.bands()[band_index].low_freq /
                       sample_freq);
        int high_bin_index = std::min<int>(
            std::floor(width *
                       (calculator.bands()[band_index].high_freq == 0
                            ? 0.5
                            : calculator.bands()[band_index].high_freq /
                                  sample_freq)),
            spec_len);

        double sum_mid = 0;
        double sum_side = 0;
        int i = low_bin_index;
#if defined(__wasm_simd128__)
        for (; i + 1 < high_bin_index; i += 2) {
          const float *ch0_ptr =
              reinterpret_cast<const float *>(&fft_outputs[0][i]);
          const float *ch1_ptr =
              reinterpret_cast<const float *>(&fft_outputs[1][i]);
          v128_t ch0 = wasm_v128_load(ch0_ptr);
          v128_t ch1 = wasm_v128_load(ch1_ptr);
          v128_t mid = wasm_f32x4_add(ch0, ch1);
          v128_t side = wasm_f32x4_sub(ch0, ch1);
          v128_t mid_sq = wasm_f32x4_mul(mid, mid);
          v128_t side_sq = wasm_f32x4_mul(side, side);
          v128_t mid_pair = wasm_f32x4_add(
              mid_sq, wasm_i32x4_shuffle(mid_sq, mid_sq, 1, 0, 3, 2));
          v128_t side_pair = wasm_f32x4_add(
              side_sq, wasm_i32x4_shuffle(side_sq, side_sq, 1, 0, 3, 2));
          sum_mid += wasm_f32x4_extract_lane(mid_pair, 0) +
                     wasm_f32x4_extract_lane(mid_pair, 2);
          sum_side += wasm_f32x4_extract_lane(side_pair, 0) +
                      wasm_f32x4_extract_lane(side_pair, 2);
        }
#endif
        for (; i < high_bin_index; i++) {
          sum_mid += std::norm(fft_outputs[0][i] + fft_outputs[1][i]);
          sum_side += std::norm(fft_outputs[0][i] - fft_outputs[1][i]);
        }
        band_loudness[2 * band_index + 0] =
            10 * std::log10(1e-7 + sum_mid / (0.5 * width));
        band_loudness[2 * band_index + 1] =
            10 * std::log10(1e-7 + sum_side / (0.5 * width));
      }

      band_loudnesses[pos_idx] = std::move(band_loudness);
    });
  }
  progress_callback(0.1f);

  const int band_count = calculator.band_count();

  const auto calc_mean_cov = [band_count, &band_loudnesses](
                                 const Effect *effect,
                                 Eigen::VectorXd *mean_vec,
                                 Eigen::MatrixXd *cov, float *mse) {
    const auto relative_threshold_db = -20;
    mean_vec->resize(2 * band_count);
    cov->resize(2 * band_count, 2 * band_count);
    *mse = 0;

    // apply effect
    bakuage::AlignedPodVector<float> applied(2 * band_count);
    std::vector<bakuage::AlignedPodVector<float>> loudness_blocks(2 *
                                                                  band_count);
    for (int i = 0; i < 2 * band_count; i++) {
      loudness_blocks[i].resize(band_loudnesses.size());
    }
    for (int i = 0; i < band_loudnesses.size(); i++) {
      if (effect) {
        ApplyEffectToBandLoudness(*effect, band_loudnesses[i].data(),
                                  applied.data());
      } else {
        bakuage::TypedMemcpy(applied.data(), band_loudnesses[i].data(),
                             applied.size());
      }
      for (int j = 0; j < applied.size(); j++) {
        *mse += bakuage::Sqr(band_loudnesses[i][j] - applied[j]);
        loudness_blocks[j][i] = applied[j];
      }
    }
    *mse /= band_loudnesses.size() * applied.size();

    // calculate mean
    bakuage::AlignedPodVector<Float> thresholds(2 * band_count);
    for (int band_index = 0; band_index < 2 * band_count; band_index++) {
      const auto &band_blocks = loudness_blocks[band_index];

      double threshold = -1e10;
      for (int k = 0; k < 2; k++) {
        Float count = 0;
        Float sum = 0;
        for (const auto &z : band_blocks) {
          const bool valid = z >= threshold;
          count += valid;
          sum += valid ? z : 0;
        }

        double mean = sum / (1e-37 + count);
        if (k == 0) {
          threshold = mean + relative_threshold_db;
          thresholds[band_index] = threshold;
        } else if (k == 1) {
          (*mean_vec)[band_index] = mean;
        }
      }
    }

    // calculate covariance
    for (int band_index1 = 0; band_index1 < 2 * band_count; band_index1++) {
      for (int band_index2 = band_index1; band_index2 < 2 * band_count;
           band_index2++) {
        const Float mean1 = (*mean_vec)[band_index1];
        const Float mean2 = (*mean_vec)[band_index2];
        const Float threshold1 = thresholds[band_index1];
        const Float threshold2 = thresholds[band_index2];

        const auto &band_blocks1 = loudness_blocks[band_index1];
        const auto &band_blocks2 = loudness_blocks[band_index2];

        Float v = 0;
        Float c = 0;
        for (int i = 0; i < band_blocks1.size(); i++) {
          const auto x1 = band_blocks1[i];
          const auto x2 = band_blocks2[i];
          const bool valid = (x1 >= threshold1) & (x2 >= threshold2);
          v += valid * (x1 - mean1) * (x2 - mean2);
          c += valid;
        }
        v /= (1e-37 + c);
        (*cov)(band_index1, band_index2) = v;
        (*cov)(band_index2, band_index1) = v;
      }
    }
  };

  Eigen::VectorXd original_mean;
  Eigen::MatrixXd original_cov;
  float original_mse;
  calc_mean_cov(nullptr, &original_mean, &original_cov, &original_mse);

  arma::vec lower_bounds(8 * band_count);
  arma::vec upper_bounds(8 * band_count);
  for (int i = 0; i < band_count; i++) {
    lower_bounds(8 * i + 0) = -1;
    upper_bounds(8 * i + 0) = 0.01;
    lower_bounds(8 * i + 1) = -1;
    upper_bounds(8 * i + 1) = 1;
    lower_bounds(8 * i + 2) = -1;
    upper_bounds(8 * i + 2) = 0.01;
    lower_bounds(8 * i + 3) = -0.01;
    upper_bounds(8 * i + 3) = 1;
    lower_bounds(8 * i + 4) = -1;
    upper_bounds(8 * i + 4) = 0.01;
    lower_bounds(8 * i + 5) = -1;
    upper_bounds(8 * i + 5) = 1;
    lower_bounds(8 * i + 6) = -1;
    upper_bounds(8 * i + 6) = 0.01;
    lower_bounds(8 * i + 7) = -0.01;
    upper_bounds(8 * i + 7) = 1;
  }
  {
    const double scale = 1e-2 + FLAGS_mastering5_mastering_level;
    lower_bounds *= scale;
    upper_bounds *= scale;
  }

  std::mutex eval_mtx;
  float min_eval = 1e100;
  int eval_count = 0;
  ConvergenceState convergence_state;
  bool should_terminate_early = false;
  EffectParams best_params(8 * band_count, arma::fill::zeros);
  const auto calc_eval = [calc_mean_cov, &calculator, &original_mean,
                          &min_eval, &eval_count, &eval_mtx, &progress_callback,
                          &lower_bounds, &upper_bounds, &mastering_reference,
                          &best_params, &convergence_state,
                          &should_terminate_early, band_count,
                          &stage](const EffectParams &params) -> double {
    {
      std::lock_guard<std::mutex> lock(eval_mtx);
      if (should_terminate_early) {
        return min_eval;
      }
    }
    if (params.size() != 8 * band_count) {
      std::cerr << "CRITICAL ERROR: params.size() (" << params.size()
                << ") != 8 * band_count (" << 8 * band_count << ")"
                << std::endl;
      throw std::runtime_error("params.size() mismatch");
    }

    Eigen::VectorXd mean;
    Eigen::MatrixXd cov;
    float msp = 0;
    for (int i = 0; i < params.size(); i++) {
      msp += bakuage::Sqr(params(i));
    }
    msp /= params.size();
    float bound_error = 0;
    for (int i = 0; i < params.size(); i++) {
      bound_error +=
          bakuage::Sqr(std::max<float>(0, lower_bounds[i] - params[i]));
      bound_error +=
          bakuage::Sqr(std::max<float>(0, params[i] - upper_bounds[i]));
    }
    float mse;
    Effect effect(original_mean, params);
    calc_mean_cov(&effect, &mean, &cov, &mse);

    const bakuage::MasteringReference2 target(mean, cov);
    float main_eval = 0;
    if (FLAGS_mastering5_mastering_reference_file.empty()) {
      float sound_quality;
      calculator.CalculateSoundQuality(target, &sound_quality, nullptr);
      main_eval = -sound_quality;
    } else {
      main_eval = calculator.CalculateDistance(mastering_reference, target);
    }

    const float target_mse =
        bakuage::Sqr(4 * (1e-2 + FLAGS_mastering5_mastering_level));
    const float alpha = 0.02 / std::sqrt(target_mse);
    const float beta = bakuage::Sqr(10.0) * alpha;
    const float eval = main_eval + alpha * mse + beta * msp + bound_error * 1e4;
    {
      std::lock_guard<std::mutex> lock(eval_mtx);
      eval_count++;
      PushRecent(&convergence_state.recent_evals, eval, 100);
      if (eval_count % 50 == 0 || eval_count < 10) {
        std::cerr << "eval_count: " << eval_count << " eval: " << eval
                  << " min_eval: " << min_eval << std::endl;
      }
      int progress_interval = std::max<int>(1, stage.max_eval_count / 100);
      if (eval_count % progress_interval == 0 &&
          eval_count < stage.max_eval_count) {
        progress_callback(0.1 +
                          0.5 * eval_count / stage.max_eval_count);
      }
      if (min_eval > eval) {
        min_eval = eval;
        best_params = params;
        convergence_state.evals_since_improvement = 0;
        convergence_state.last_best = min_eval;
        std::cerr << "NEW BEST " << eval_count << "\t" << min_eval << "\t"
                  << main_eval << "\t" << mse << "\t" << msp << std::endl;
      } else {
        convergence_state.evals_since_improvement++;
      }
      PushRecent(&convergence_state.recent_best, min_eval, 100);
      if (!should_terminate_early &&
          ShouldTerminate(convergence_state, stage.early_patience)) {
        std::cerr << "Early termination: convergence detected" << std::endl;
        should_terminate_early = true;
      }
    }
    return eval;
  };

  EffectParams zero_params(8 * band_count);
  for (int i = 0; i < zero_params.size(); i++) {
    zero_params(i) = 0;
  }
  EffectParams start_params = initial_params ? *initial_params : zero_params;
  ClampParams(&start_params, lower_bounds, upper_bounds);

  const auto initial_eval = calc_eval(start_params);
  std::cerr << "optimization initial_eval: " << initial_eval << std::endl;

  const auto find_params =
      [calc_eval, band_count, &start_params, &lower_bounds, &upper_bounds,
       &best_params, &min_eval, &stage, initial_eval]() -> EffectParams {
    optim::algo_settings_t settings;
#if 1
    settings.de_initial_lb = lower_bounds;
    settings.de_initial_ub = upper_bounds;
    settings.pso_initial_lb = lower_bounds;
    settings.pso_initial_ub = upper_bounds;
#endif
    auto result = start_params;
    bool success = true;

    settings.iter_max = 50;
    settings.de_max_fn_eval = stage.max_eval_count;

    std::cerr << "Initial evaluation: " << initial_eval << std::endl;
    if (FLAGS_mastering5_optimization_algorithm == "nm") {
      settings.iter_max = stage.max_eval_count / lower_bounds.size();
      success = optim::nm(
          result,
          [calc_eval](const arma::vec &vec, arma::vec *grad_out,
                      void *opt_data) { return calc_eval(vec); },
          nullptr, settings);
    } else if (FLAGS_mastering5_optimization_algorithm == "pso") {
      settings.pso_n_pop = 20;
      settings.pso_n_gen = 10;
      success = optim::pso(
          result,
          [calc_eval](const arma::vec &vec, arma::vec *grad_out,
                      void *opt_data) { return calc_eval(vec); },
          nullptr, settings);
    } else if (FLAGS_mastering5_optimization_algorithm == "pso_dv") {
      settings.pso_n_pop = 20;
      settings.pso_n_gen = 10;
      success = optim::pso_dv(
          result,
          [calc_eval](const arma::vec &vec, arma::vec *grad_out,
                      void *opt_data) { return calc_eval(vec); },
          nullptr, settings);
    } else if (FLAGS_mastering5_optimization_algorithm == "de") {
      success = optim::de(
          result,
          [calc_eval](const arma::vec &vec, arma::vec *grad_out,
                      void *opt_data) { return calc_eval(vec); },
          nullptr, settings);
    } else if (FLAGS_mastering5_optimization_algorithm == "de_prmm") {
      success = optim::de(
          result,
          [calc_eval](const arma::vec &vec, arma::vec *grad_out,
                      void *opt_data) { return calc_eval(vec); },
          nullptr, settings);
    } else {
      throw std::logic_error(
          std::string("unknown FLAGS_mastering5_optimization_algorithm " +
                      FLAGS_mastering5_optimization_algorithm));
    }
    const auto result_eval = calc_eval(result);
    std::cerr << "optimization success: " << success << std::endl;
    std::cerr << "optimization solution y: " << result_eval << std::endl;
    for (int i = 0; i < band_count; i++) {
      std::cerr << "optimization solution x " << i << "\t" << result(8 * i + 0)
                << "\t" << result(8 * i + 1) << "\t" << result(8 * i + 2)
                << "\t" << result(8 * i + 3) << std::endl;
      std::cerr << "optimization solution x ms " << i << "\t"
                << result(8 * i + 4) << "\t" << result(8 * i + 5) << "\t"
                << result(8 * i + 6) << "\t" << result(8 * i + 7)
                << std::endl;
    }
    if (success) {
      std::cerr << "Optimization succeeded." << std::endl;
    } else {
      std::cerr << "Optimization failed." << std::endl;
    }
    std::cerr << "Returning best_params found (eval=" << min_eval << ")"
              << std::endl;
    return best_params;
  };

  StageResult result;
  result.params = find_params();
  result.original_mean = original_mean;
  return result;
}

} // namespace

namespace phase_limiter {

// audio_analyzer(CalculateMultibandLoudness2)の仕様に合わせて、mean,
// covを計算する。 エフェクトはloudness vector上でシミュレーションする
// 基準ラウドネスの違いとかはホワイトノイズを処理して補正値を計算して補正する
void AutoMastering5(std::vector<float> *_wave, const int sample_rate,
                    const std::function<void(float)> &progress_callback) {
  try {
    const int frames = _wave->size() / 2;
    const int channels = 2;

    // initialize sound quality calculator
    bakuage::SoundQuality2Calculator calculator;
    {
      std::cerr << "load sound_quality2_cache: " << FLAGS_sound_quality2_cache
                << std::endl;
      std::ifstream ifs(FLAGS_sound_quality2_cache, std::ios::binary);
      if (!ifs) {
        std::cerr << "Failed to open cache file!" << std::endl;
      }
      std::cerr << "Opening archive..." << std::endl;
      boost::archive::binary_iarchive ia(ifs);
      std::cerr << "Archive initialized. Loading calculator..." << std::endl;
      ia >> calculator;
      std::cerr << "Calculator loaded." << std::endl;
    }
    const auto band_count = calculator.band_count();

    // initialize reference
    bakuage::MasteringReference2 mastering_reference;
    if (!FLAGS_mastering5_mastering_reference_file.empty()) {
      Eigen::VectorXd mean;
      Eigen::MatrixXd cov;
      bakuage::SoundQuality2CalculatorUnit::ParseReference(
          bakuage::LoadStrFromFile(
              FLAGS_mastering5_mastering_reference_file.c_str())
              .c_str(),
          &mean, &cov);
      mastering_reference = bakuage::MasteringReference2(mean, cov);
    }

    std::cerr << "Starting optimization..." << std::endl;
    std::cerr << "INPUT wave L2 norm BEFORE optimization: "
              << bakuage::VectorL2(_wave->data(), _wave->size()) << std::endl;

    EffectParams warm_params;
    const EffectParams *warm_params_ptr = nullptr;
    if (FLAGS_mastering5_use_warm_start) {
      const auto warm_progress = [&progress_callback](float p) {
        progress_callback(0.05f * p);
      };
      warm_params = GetLevel3WarmStart(*_wave, sample_rate, calculator,
                                       warm_progress);
      warm_params_ptr = &warm_params;
    }

    const int stage1_factor =
        std::max(1, FLAGS_mastering5_analysis_downsample_factor);
    const int stage2_factor = std::max(1, stage1_factor / 2);

    const StageConfig stage1{stage1_factor, 200, 100, "stage1_11k"};
    const StageConfig stage2{stage2_factor, 100, 50, "stage2_22k"};

    const auto stage1_progress = [&progress_callback](float p) {
      const float local =
          std::min(1.0f, std::max(0.0f, (p - 0.1f) / 0.5f));
      progress_callback(0.05f + 0.25f * local);
    };
    const auto stage2_progress = [&progress_callback](float p) {
      const float local =
          std::min(1.0f, std::max(0.0f, (p - 0.1f) / 0.5f));
      progress_callback(0.30f + 0.30f * local);
    };

    const auto stage1_result = OptimizeParamsForStage(
        *_wave, sample_rate, calculator, mastering_reference, stage1,
        stage1_progress, warm_params_ptr);
    const auto stage2_result = OptimizeParamsForStage(
        *_wave, sample_rate, calculator, mastering_reference, stage2,
        stage2_progress, &stage1_result.params);

    const auto &effect_params = stage2_result.params;
    const auto &original_mean = stage2_result.original_mean;

    std::cerr << "Optimization finished. Parameters size: "
              << effect_params.size() << std::endl;
    std::cerr << "Effect params[0..7]: ";
    for (int i = 0; i < std::min(8, (int)effect_params.size()); i++) {
      std::cerr << effect_params(i) << " ";
    }
    std::cerr << std::endl;
    const Effect effect(original_mean, effect_params);
    std::cerr << "Effect object created." << std::endl;
    std::mutex result_mtx;
    std::mutex progression_mtx;
    std::vector<std::function<void()>> tasks;
    std::vector<Float> result(_wave->size(), 0);
    bakuage::AlignedPodVector<Float> progressions(band_count);

    const auto update_progression = [&progressions, &progression_mtx,
                                     progress_callback](int i, Float p) {
      std::lock_guard<std::mutex> lock(progression_mtx);
      Float total = 0;
      progressions[i] = p;
      for (const auto &a : progressions) {
        total += a;
      }
      progress_callback(0.6 + 0.4 * total / progressions.size());
    };

    for (int band_index = 0; band_index < band_count; band_index++) {
      const auto &band = calculator.bands()[band_index];
      const auto update_progression_bound =
          std::bind(update_progression, band_index, std::placeholders::_1);
      const auto &band_effect = effect.band_effects[band_index];
      tasks.push_back([band, band_effect, band_index, sample_rate, frames,
                       _wave, &result, &result_mtx, update_progression_bound,
                       channels]() {
        const float *wave_ptr = &(*_wave)[0];

        int fir_delay_samples;
        std::vector<Float> fir;
        {
          fir_delay_samples = static_cast<int>(0.2 * sample_rate);
          const int n = 2 * fir_delay_samples + 1;
          Float freq1 = std::min<Float>(0.5, band.low_freq / sample_rate);
          Float freq2 = std::min<Float>(
              0.5, band.high_freq == 0 ? 0.5 : band.high_freq / sample_rate);
          fir = CalculateBandPassFir<Float>(freq1, freq2, n, 4);
        }
        update_progression_bound(0.1);

        const int len = frames + fir.size() - 1;
        bakuage::AlignedPodVector<float> filtered(channels * len);
        {
          FirFilter2<Float> fir_filter(fir.begin(), fir.end());
          bakuage::AlignedPodVector<Float> filter_temp_input(
              (size_t)(frames + fir_delay_samples), 0);
          bakuage::AlignedPodVector<Float> filter_temp_output(
              (size_t)(frames + fir_delay_samples), 0);
          for (int ch = 0; ch < channels; ch++) {
            fir_filter.Clear();
            for (int i = 0; i < frames; i++) {
              filter_temp_input[i] = wave_ptr[channels * i + ch];
            }
            fir_filter.Clock(filter_temp_input.data(),
                             filter_temp_input.data() + frames +
                                 fir_delay_samples,
                             filter_temp_output.data());
            for (int i = 0; i < frames; i++) {
              filtered[channels * i + ch] =
                  filter_temp_output[i + fir_delay_samples];
            }
          }
        }
        update_progression_bound(0.2);

        Compressor::Config compressor_config;
        compressor_config.loudness_mapping_func = band_effect.loudness_mapping;
        compressor_config.ms_loudness_mapping_func =
            band_effect.ms_loudness_mapping;
        compressor_config.max_mean_sec = 0.2;
        compressor_config.num_channels = channels;
        compressor_config.sample_rate = sample_rate;
        Compressor compressor(compressor_config);

        const int shift = compressor.delay_samples();
        const int len2 = frames + shift;
        filtered.resize(channels * len2);
        bakuage::AlignedPodVector<Float> temp_input((size_t)channels, 0);
        bakuage::AlignedPodVector<Float> temp_output((size_t)channels, 0);

        // filteredにin-placeで書き込んでから共有のresultに足しこむ
        for (int j = 0; j < len2; j++) {
          for (int i = 0; i < channels; i++) {
            temp_input[i] = filtered[channels * j + i];
          }
          compressor.Clock(&temp_input[0], &temp_output[0]);
          for (int i = 0; i < channels; i++) {
            filtered[channels * j + i] = temp_output[i];
          }
        }
        update_progression_bound(0.8);

        {
          std::lock_guard<std::mutex> lock(result_mtx);
          const int len3 = frames * channels;
          const int channels_shift = channels * shift;
          bakuage::VectorAddInplace(filtered.data() + channels_shift,
                                    result.data(), len3);
        }
        update_progression_bound(1);
      });
    }

    std::cerr << "Starting final parallel processing with " << tasks.size()
              << " tasks..." << std::endl;
    tbb::parallel_for(0, (int)tasks.size(), [&tasks](int task_i) {
      try {
        tasks[task_i]();
      } catch (const std::exception &e) {
        std::cerr << "Task " << task_i << " failed: " << e.what() << std::endl;
        throw;
      } catch (...) {
        std::cerr << "Task " << task_i << " failed with unknown error"
                  << std::endl;
        throw;
      }
    });
    std::cerr << "Final parallel processing finished." << std::endl;

    *_wave = std::move(result);
    std::cerr << "Final wave L2 norm: "
              << bakuage::VectorL2(_wave->data(), _wave->size()) << std::endl;
    std::cerr << "AutoMastering5 completed successfully." << std::endl;
  } catch (const std::exception &e) {
    std::cerr << "AutoMastering5 EXCEPTION: " << e.what() << std::endl;
    throw;
  } catch (...) {
    std::cerr << "AutoMastering5 UNKNOWN EXCEPTION" << std::endl;
    throw;
  }
}

} // namespace phase_limiter


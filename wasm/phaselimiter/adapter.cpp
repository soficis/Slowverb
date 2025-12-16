#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

namespace {
using ProgressCallback = void (*)(float);

enum class ErrorCode : int {
  Success = 0,
  InvalidBuffer = 1,
  InvalidSampleRate = 2,
  ProcessingFailed = 3,
  OutOfMemory = 4,
};

float calculateRmsDb(const std::vector<float>& samples) {
  if (samples.empty()) return -120.0f;
  double sumSquares = 0.0;
  for (float sample : samples) {
    sumSquares += static_cast<double>(sample) * static_cast<double>(sample);
  }
  const double meanSquares = sumSquares / static_cast<double>(samples.size());
  const double rms = std::sqrt(meanSquares);
  return 20.0f * static_cast<float>(std::log10(rms + 1e-12));
}

float lowpassAlpha(int sampleRate, float cutoffHz) {
  if (sampleRate <= 0) return 1.0f;
  const float omega = 2.0f * 3.14159265358979323846f * cutoffHz;
  const float dt = 1.0f / static_cast<float>(sampleRate);
  const float x = omega * dt;
  return x / (1.0f + x);
}

void applySpectralGain(std::vector<float>& samples, int sampleRate, float gain, float bassPreservation) {
  if (samples.empty()) return;

  const float p = std::clamp(bassPreservation, 0.0f, 1.0f);

  // Split into low (one-pole LP @ 200Hz) and high (residual).
  // Apply full gain to highs, and reduced gain to lows based on bassPreservation.
  // p=0 => lows get full gain, p=1 => lows get unity gain.
  const float alpha = lowpassAlpha(sampleRate, 200.0f);
  const float gainLow = (1.0f - p) * gain + p;
  float low = 0.0f;
  for (float& sample : samples) {
    low += alpha * (sample - low);
    const float high = sample - low;
    sample = low * gainLow + high * gain;
  }
}

float calculatePeak(const std::vector<float>& left, const std::vector<float>& right) {
  float peak = 0.0f;
  for (size_t i = 0; i < left.size(); i++) {
    peak = std::max(peak, std::abs(left[i]));
    peak = std::max(peak, std::abs(right[i]));
  }
  return peak;
}

void applyGain(std::vector<float>& samples, float gain) {
  for (float& sample : samples) {
    sample *= gain;
  }
}

void applyHardLimiter(std::vector<float>& left, std::vector<float>& right, float ceiling) {
  const float peak = calculatePeak(left, right);
  if (peak <= ceiling) return;
  const float scale = ceiling / (peak + 1e-12f);
  applyGain(left, scale);
  applyGain(right, scale);
}

void postProgress(ProgressCallback callback, float value) {
  if (!callback) return;
  callback(std::clamp(value, 0.0f, 1.0f));
}
}  // namespace

extern "C" {
int run_phase_limiter(uintptr_t leftChannelPtr, uintptr_t rightChannelPtr, int sampleCount, int sampleRate,
                      float targetLufs, float bassPreservation, uintptr_t progressCallbackPtr) {
  try {
    if (leftChannelPtr == 0 || rightChannelPtr == 0) {
      return static_cast<int>(ErrorCode::InvalidBuffer);
    }
    if (sampleCount <= 0 || sampleRate < 8000 || sampleRate > 192000) {
      return static_cast<int>(ErrorCode::InvalidSampleRate);
    }

    auto* leftData = reinterpret_cast<float*>(leftChannelPtr);
    auto* rightData = reinterpret_cast<float*>(rightChannelPtr);
    if (!leftData || !rightData) {
      return static_cast<int>(ErrorCode::InvalidBuffer);
    }

    const auto progressCallback = reinterpret_cast<ProgressCallback>(progressCallbackPtr);
    postProgress(progressCallback, 0.0f);

    std::vector<float> left(leftData, leftData + sampleCount);
    std::vector<float> right(rightData, rightData + sampleCount);

    const float inputDb = std::max(calculateRmsDb(left), calculateRmsDb(right));
    const float gainDb = targetLufs - inputDb;
    const float gain = std::pow(10.0f, gainDb / 20.0f);

    postProgress(progressCallback, 0.5f);
    applySpectralGain(left, sampleRate, gain, bassPreservation);
    applySpectralGain(right, sampleRate, gain, bassPreservation);
    applyHardLimiter(left, right, 0.95f);
    postProgress(progressCallback, 1.0f);

    std::copy(left.begin(), left.end(), leftData);
    std::copy(right.begin(), right.end(), rightData);
    return static_cast<int>(ErrorCode::Success);
  } catch (const std::bad_alloc&) {
    return static_cast<int>(ErrorCode::OutOfMemory);
  } catch (...) {
    return static_cast<int>(ErrorCode::ProcessingFailed);
  }
}
}

#include "src/phase_limiter/auto_mastering.h"
#include <cmath>
#include <emscripten.h>
#include <iostream>
#include <vector>

extern "C" {

EMSCRIPTEN_KEEPALIVE
int phaselimiter_pro_process(float *left_ptr, float *right_ptr, int length,
                             int sample_rate, int mode) {
  if (!left_ptr || !right_ptr)
    return -1;
  // Channels is implied 2 for now
  int channels = 2;

  try {
    std::vector<float> wave(length * channels);
    for (int i = 0; i < length; ++i) {
      wave[i * 2] = left_ptr[i];
      wave[i * 2 + 1] = right_ptr[i];
    }

    if (mode == 2) {
      phase_limiter::AutoMastering2(&wave, sample_rate, [](float p) {});
    } else if (mode == 5) {
      phase_limiter::AutoMastering5(&wave, sample_rate, [](float p) {});
    } else {
      // Default to Level 3 (Standard Pro)
      phase_limiter::AutoMastering3(&wave, sample_rate, [](float p) {});
    }

    // Copy back
    int output_frames = wave.size() / channels;
    // We can only write back up to input 'length' because we didn't allocate
    // more in JS. If output is larger, we truncate. If smaller, we fill.
    // Ideally, we should support dynamic size, but for now we assume logic
    // preserves length approx.
    int frames_to_copy = std::min(output_frames, length);

    for (int i = 0; i < frames_to_copy; ++i) {
      left_ptr[i] = wave[i * 2];
      right_ptr[i] = wave[i * 2 + 1];
    }

    // If output was shorter, zero fill?
    if (frames_to_copy < length) {
      std::fill(left_ptr + frames_to_copy, left_ptr + length, 0.0f);
      std::fill(right_ptr + frames_to_copy, right_ptr + length, 0.0f);
    }

    return 0;

  } catch (const std::exception &e) {
    std::cerr << "PhaseLimiter Pro Error: " << e.what() << std::endl;
    return -3;
  } catch (...) {
    std::cerr << "PhaseLimiter Pro Unknown Error" << std::endl;
    return -4;
  }
}
}

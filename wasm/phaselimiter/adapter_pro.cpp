#include "src/phase_limiter/auto_mastering.h"
#include <cmath>
#include <emscripten.h>
#include <iostream>
#include <string>
#include <sys/stat.h>
#include <sys/types.h>
#include <vector>

// Forward declare gflags variables or use DECLARE_string if you prefer macros
#include "gflags/gflags.h"
DECLARE_string(sound_quality2_cache);

extern "C" {

EMSCRIPTEN_KEEPALIVE
int phaselimiter_pro_process(float *left_ptr, float *right_ptr, int length,
                             int sample_rate, int mode) {
  if (!left_ptr || !right_ptr)
    return -1;
  int channels = 2;

  std::cerr << "[adapter_pro] START: len=" << length << ", rate=" << sample_rate
            << ", mode=" << mode << std::endl;
  std::cerr << "[adapter_pro] DEBUG: sizeof(long)=" << sizeof(long)
            << ", sizeof(size_t)=" << sizeof(size_t) << std::endl;

  bool fallback_occurred = false;

  try {
    // Check filesystem for preloaded data
    struct stat st;
    if (stat("/sound_quality2_cache", &st) == 0) {
      std::cerr << "[adapter_pro] Found /sound_quality2_cache, size: "
                << (long long)st.st_size << " bytes" << std::endl;
    } else {
      std::cerr << "[adapter_pro] ERROR: /sound_quality2_cache NOT FOUND!"
                << std::endl;
    }

    std::cerr << "[adapter_pro] Copying data to vector..." << std::endl;
    std::vector<float> wave(length * channels);
    for (int i = 0; i < length; ++i) {
      wave[i * 2] = left_ptr[i];
      wave[i * 2 + 1] = right_ptr[i];
    }
    std::cerr << "[adapter_pro] Data copied. Vector size: " << wave.size()
              << std::endl;

    if (mode == 2) {
      std::cerr << "[adapter_pro] Calling AutoMastering2" << std::endl;
      phase_limiter::AutoMastering2(&wave, sample_rate, [](float p) {
        // no progress log here to avoid clutter
      });
    } else if (mode == 3) {
      std::cerr << "[adapter_pro] Calling AutoMastering3" << std::endl;
      phase_limiter::AutoMastering3(&wave, sample_rate, [](float p) {
        // no progress log
      });
    } else {
      std::cerr << "[adapter_pro] Calling AutoMastering5" << std::endl;

      // Set the cache path
      FLAGS_sound_quality2_cache = "/sound_quality2_cache";

      std::cerr << "[adapter_pro] FLAGS_sound_quality2_cache set to: "
                << FLAGS_sound_quality2_cache << std::endl;

      try {
        phase_limiter::AutoMastering5(&wave, sample_rate, [](float p) {
          // no progress log
        });
      } catch (const std::exception &e) {
        std::cerr << "[adapter_pro] Level 5 failed: " << e.what()
                  << ". Falling back to Level 3..." << std::endl;
        phase_limiter::AutoMastering3(&wave, sample_rate, [](float p) {
          // no progress log
        });
        fallback_occurred = true;
      } catch (...) {
        std::cerr << "[adapter_pro] Level 5 failed with unknown error. Falling "
                     "back to Level 3..."
                  << std::endl;
        phase_limiter::AutoMastering3(&wave, sample_rate, [](float p) {
          // no progress log
        });
        fallback_occurred = true;
      }
    }

    std::cerr << "[adapter_pro] Mastering finished. Copying back..."
              << std::endl;

    int output_frames = wave.size() / channels;
    int frames_to_copy = std::min(output_frames, length);

    for (int i = 0; i < frames_to_copy; ++i) {
      left_ptr[i] = wave[i * 2];
      right_ptr[i] = wave[i * 2 + 1];
    }

    if (frames_to_copy < length) {
      std::fill(left_ptr + frames_to_copy, left_ptr + length, 0.0f);
      std::fill(right_ptr + frames_to_copy, right_ptr + length, 0.0f);
    }

    if (fallback_occurred) {
      std::cerr << "[adapter_pro] SUCCESS (with fallback to lvl 3)"
                << std::endl;
      return 1; // 1 means success with fallback
    }

    std::cerr << "[adapter_pro] SUCCESS" << std::endl;
    return 0;

  } catch (const std::exception &e) {
    std::cerr << "[adapter_pro] CRITICAL C++ exception: " << e.what()
              << std::endl;
    return -3;
  } catch (const std::string &s) {
    std::cerr << "[adapter_pro] CRITICAL String exception: " << s << std::endl;
    return -4;
  } catch (const char *c) {
    std::cerr << "[adapter_pro] CRITICAL Char* exception: " << c << std::endl;
    return -5;
  } catch (...) {
    std::cerr << "[adapter_pro] CRITICAL Unknown exception caught!"
              << std::endl;
    return -6;
  }
}
}

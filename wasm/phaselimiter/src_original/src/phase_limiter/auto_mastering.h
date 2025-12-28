#ifndef PHASE_LIMITER_AUTO_MASTERING_H_
#define PHASE_LIMITER_AUTO_MASTERING_H_

#include <functional>
#include <vector>

namespace phase_limiter {
    struct Mastering3OptimumParams {
        int comp_band_count = 0;
        std::vector<float> compressor_ratios;
        std::vector<float> compressor_thresholds;
        std::vector<float> compressor_wets;
        std::vector<float> compressor_gains;
    };

    void AutoMastering(std::vector<float> *_wave, const float **irs, const int *ir_lens, const int sample_rate, const std::function<void (float)> &progress_callback);
    void AutoMastering2(std::vector<float> *_wave, const int sample_rate, const std::function<void(float)> &progress_callback);
    void AutoMastering3(std::vector<float> *_wave, const int sample_rate, const std::function<void(float)> &progress_callback);
    Mastering3OptimumParams GetMastering3OptimumParams(const std::vector<float> &wave, const int sample_rate, const std::function<void(float)> &progress_callback);
    void AutoMastering5(std::vector<float> *_wave, const int sample_rate, const std::function<void (float)> &progress_callback);
}

#endif

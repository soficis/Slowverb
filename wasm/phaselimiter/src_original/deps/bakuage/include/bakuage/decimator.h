#ifndef BAKUAGE_BAKUAGE_DECIMATOR_H_
#define BAKUAGE_BAKUAGE_DECIMATOR_H_

#include <algorithm>
#include <vector>
#include "bakuage/fir_design.h"
#include "bakuage/fir_filter.h"

namespace bakuage {

template <typename Float>
class Decimator {
public:
  explicit Decimator(int factor, int filter_order = 64)
      : factor_(std::max(1, factor)) {
    if (factor_ <= 1) {
      return;
    }

    int order = std::max(3, filter_order);
    if (order % 2 == 0) {
      order += 1;
    }

    const double cutoff = 0.5 / factor_ * 0.9;
    const double transition = std::max(0.01, cutoff * 0.1);
    int suggested_n = order;
    Float alpha = 0;
    CalcKeiserFirParams(96.0, transition, &suggested_n, &alpha);
    if (suggested_n > order) {
      order = suggested_n;
      if (order % 2 == 0) {
        order += 1;
      }
    }

    lowpass_fir_ =
        CalculateBandPassFir<Float>(0.0, static_cast<Float>(cutoff), order,
                                    alpha);
  }

  std::vector<Float> Process(const std::vector<Float> &input, int channels) {
    if (factor_ <= 1) {
      return input;
    }
    if (channels <= 0) {
      return {};
    }

    const int frames = static_cast<int>(input.size() / channels);
    const int output_frames = frames / factor_;
    if (output_frames <= 0) {
      return {};
    }

    std::vector<Float> output(output_frames * channels);
    for (int ch = 0; ch < channels; ch++) {
      FirFilter<Float> filter(lowpass_fir_.begin(), lowpass_fir_.end());
      int out_index = 0;
      for (int i = 0; i < frames; i++) {
        const Float y = filter.Clock(input[channels * i + ch]);
        if (i % factor_ == 0) {
          output[channels * out_index + ch] = y;
          out_index++;
          if (out_index >= output_frames) {
            break;
          }
        }
      }
    }

    return output;
  }

private:
  int factor_ = 1;
  std::vector<Float> lowpass_fir_;
};

} // namespace bakuage

#endif

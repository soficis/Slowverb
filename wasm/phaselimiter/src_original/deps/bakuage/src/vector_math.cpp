#include "bakuage/vector_math.h"

#include "bakuage/memory.h"
#include "ipp.h"
#include <algorithm>
#include <cmath>
#include <complex>

static_assert(sizeof(std::complex<float>) == sizeof(Ipp32fc),
              "ipp float complex size must be same as std complex size");
static_assert(sizeof(std::complex<double>) == sizeof(Ipp64fc),
              "ipp double complex size must be same as std complex size");

namespace bakuage {

// Helper macro for loops
#define LOOP(n) for (int i = 0; i < (n); ++i)

template <>
void VectorMulConstantInplace<float, float>(const float &c, float *output,
                                            int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstantInplace<double, float>(const double &c, float *output,
                                             int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstantInplace<double, double>(const double &c, double *output,
                                              int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstantInplace<float, double>(const float &c, double *output,
                                             int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstantInplace<float, std::complex<float>>(
    const float &c, std::complex<float> *output, int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstantInplace<double, std::complex<float>>(
    const double &c, std::complex<float> *output, int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstantInplace<double, std::complex<double>>(
    const double &c, std::complex<double> *output, int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstantInplace<std::complex<float>, std::complex<float>>(
    const std::complex<float> &c, std::complex<float> *output, int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstantInplace<std::complex<double>, std::complex<double>>(
    const std::complex<double> &c, std::complex<double> *output, int n) {
  LOOP(n) output[i] *= c;
}

template <>
void VectorMulConstant<float>(const float *x, const float &c, float *output,
                              int n) {
  LOOP(n) output[i] = x[i] * c;
}

template <>
void VectorMulConstant<double>(const double *x, const double &c, double *output,
                               int n) {
  LOOP(n) output[i] = x[i] * c;
}

template <>
void VectorMulInplace<float, float>(const float *x, float *output, int n) {
  LOOP(n) output[i] *= x[i];
}

template <>
void VectorMulInplace<double, double>(const double *x, double *output, int n) {
  LOOP(n) output[i] *= x[i];
}

template <>
void VectorMulInplace<float, std::complex<float>>(const float *x,
                                                  std::complex<float> *output,
                                                  int n) {
  LOOP(n) output[i] *= x[i];
}

template <>
void VectorMulInplace<double, std::complex<double>>(
    const double *x, std::complex<double> *output, int n) {
  LOOP(n) output[i] *= x[i];
}

template <>
void VectorMulInplace<std::complex<float>, std::complex<float>>(
    const std::complex<float> *x, std::complex<float> *output, int n) {
  LOOP(n) output[i] *= x[i];
}

template <>
void VectorMulInplace<std::complex<double>, std::complex<double>>(
    const std::complex<double> *x, std::complex<double> *output, int n) {
  LOOP(n) output[i] *= x[i];
}

template <>
void VectorMul<float, float>(const float *x, const float *y, float *output,
                             int n) {
  LOOP(n) output[i] = x[i] * y[i];
}

template <>
void VectorMul<double, double>(const double *x, const double *y, double *output,
                               int n) {
  LOOP(n) output[i] = x[i] * y[i];
}

template <>
void VectorMul<float, std::complex<float>>(const float *x,
                                           const std::complex<float> *y,
                                           std::complex<float> *output, int n) {
  LOOP(n) output[i] = x[i] * y[i];
}

template <>
void VectorMul<std::complex<float>, std::complex<float>>(
    const std::complex<float> *x, const std::complex<float> *y,
    std::complex<float> *output, int n) {
  LOOP(n) output[i] = x[i] * y[i];
}

template <>
void VectorMul<double, std::complex<double>>(const double *x,
                                             const std::complex<double> *y,
                                             std::complex<double> *output,
                                             int n) {
  LOOP(n) output[i] = x[i] * y[i];
}

template <>
void VectorMul<std::complex<double>, std::complex<double>>(
    const std::complex<double> *x, const std::complex<double> *y,
    std::complex<double> *output, int n) {
  LOOP(n) output[i] = x[i] * y[i];
}

template <>
void VectorMulPermInplace<std::complex<float>>(const std::complex<float> *x,
                                               std::complex<float> *output,
                                               int n) {
  if (n > 0) {
    float dc = output[0].real() * x[0].real();
    float ny = output[0].imag() * x[0].imag();
    output[0] = std::complex<float>(dc, ny);
  }
  for (int i = 1; i < n; ++i) {
    output[i] *= x[i];
  }
}

template <>
void VectorMulPermInplace<std::complex<double>>(const std::complex<double> *x,
                                                std::complex<double> *output,
                                                int n) {
  if (n > 0) {
    double dc = output[0].real() * x[0].real();
    double ny = output[0].imag() * x[0].imag();
    output[0] = std::complex<double>(dc, ny);
  }
  for (int i = 1; i < n; ++i) {
    output[i] *= x[i];
  }
}

template <>
void VectorMulConj<std::complex<float>>(const std::complex<float> *x,
                                        const std::complex<float> *y,
                                        std::complex<float> *output, int n) {
  LOOP(n) output[i] = x[i] * std::conj(y[i]);
}

template <>
void VectorMulConj<std::complex<double>>(const std::complex<double> *x,
                                         const std::complex<double> *y,
                                         std::complex<double> *output, int n) {
  LOOP(n) output[i] = x[i] * std::conj(y[i]);
}

template <>
void VectorAddConstantInplace<float>(const float &c, float *output, int n) {
  LOOP(n) output[i] += c;
}

template <>
void VectorAddConstantInplace<double>(const double &c, double *output, int n) {
  LOOP(n) output[i] += c;
}

template <> void VectorAddInplace<float>(const float *x, float *output, int n) {
  LOOP(n) output[i] += x[i];
}

template <>
void VectorAddInplace<double>(const double *x, double *output, int n) {
  LOOP(n) output[i] += x[i];
}

template <>
void VectorAddInplace<std::complex<float>>(const std::complex<float> *x,
                                           std::complex<float> *output, int n) {
  LOOP(n) output[i] += x[i];
}

template <>
void VectorAddInplace<std::complex<double>>(const std::complex<double> *x,
                                            std::complex<double> *output,
                                            int n) {
  LOOP(n) output[i] += x[i];
}

template <>
void VectorAdd<float>(const float *x, const float *y, float *output, int n) {
  LOOP(n) output[i] = x[i] + y[i];
}

template <>
void VectorAdd<double>(const double *x, const double *y, double *output,
                       int n) {
  LOOP(n) output[i] = x[i] + y[i];
}

template <>
void VectorAdd<std::complex<float>>(const std::complex<float> *x,
                                    const std::complex<float> *y,
                                    std::complex<float> *output, int n) {
  LOOP(n) output[i] = x[i] + y[i];
}

template <>
void VectorAdd<std::complex<double>>(const std::complex<double> *x,
                                     const std::complex<double> *y,
                                     std::complex<double> *output, int n) {
  LOOP(n) output[i] = x[i] + y[i];
}

template <>
void VectorSubConstantRev<float>(const float *x, const float &c, float *output,
                                 int n) {
  LOOP(n) output[i] = c - x[i];
}

template <> void VectorDivInplace<float>(const float *x, float *output, int n) {
  LOOP(n) output[i] /= x[i];
}

template <>
void VectorDivInplace<double>(const double *x, double *output, int n) {
  LOOP(n) output[i] /= x[i];
}

template <>
void VectorMadInplace<float>(const float *x, const float *y, float *output,
                             int n) {
  LOOP(n) output[i] += x[i] * y[i];
}

template <>
void VectorMadInplace<double>(const double *x, const double *y, double *output,
                              int n) {
  LOOP(n) output[i] += x[i] * y[i];
}

template <>
void VectorMadInplace<std::complex<float>>(const std::complex<float> *x,
                                           const std::complex<float> *y,
                                           std::complex<float> *output, int n) {
  LOOP(n) output[i] += x[i] * y[i];
}

template <>
void VectorMadInplace<std::complex<double>>(const std::complex<double> *x,
                                            const std::complex<double> *y,
                                            std::complex<double> *output,
                                            int n) {
  LOOP(n) output[i] += x[i] * y[i];
}

template <>
void VectorMadConstantInplace<float>(const float *x, const float &c,
                                     float *output, int n) {
  LOOP(n) output[i] += x[i] * c;
}

template <>
void VectorMadConstantInplace<double>(const double *x, const double &c,
                                      double *output, int n) {
  LOOP(n) output[i] += x[i] * c;
}

template <>
void VectorPowConstant<float>(const float *x, const float &c, float *output,
                              int n) {
  LOOP(n) output[i] = std::pow(x[i], c);
}

template <>
void VectorPowConstant<double>(const double *x, const double &c, double *output,
                               int n) {
  LOOP(n) output[i] = std::pow(x[i], c);
}

template <> void VectorSqrtInplace<float>(float *output, int n) {
  LOOP(n) output[i] = std::sqrt(output[i]);
}

template <> void VectorSqrtInplace<double>(double *output, int n) {
  LOOP(n) output[i] = std::sqrt(output[i]);
}

template <>
void VectorNorm<std::complex<float>, float>(const std::complex<float> *x,
                                            float *output, int n) {
  LOOP(n) output[i] = std::norm(x[i]);
}

template <>
void VectorNorm<std::complex<double>, double>(const std::complex<double> *x,
                                              double *output, int n) {
  LOOP(n) output[i] = std::norm(x[i]);
}

template <>
float VectorNormDiffL1<float>(const float *x, const float *y, int n) {
  float sum = 0;
  LOOP(n) sum += std::abs(x[i] - y[i]);
  return sum;
}

template <>
double VectorNormDiffL1<double>(const double *x, const double *y, int n) {
  double sum = 0;
  LOOP(n) sum += std::abs(x[i] - y[i]);
  return sum;
}

template <>
float VectorNormDiffL2<float>(const float *x, const float *y, int n) {
  float sum = 0;
  LOOP(n) {
    float diff = x[i] - y[i];
    sum += diff * diff;
  }
  return std::sqrt(sum);
}

template <>
double VectorNormDiffL2<double>(const double *x, const double *y, int n) {
  double sum = 0;
  LOOP(n) {
    double diff = x[i] - y[i];
    sum += diff * diff;
  }
  return std::sqrt(sum);
}

template <>
float VectorNormDiffInf<float>(const float *x, const float *y, int n) {
  float max_diff = 0;
  LOOP(n) max_diff = std::max(max_diff, std::abs(x[i] - y[i]));
  return max_diff;
}

template <>
double VectorNormDiffInf<double>(const double *x, const double *y, int n) {
  double max_diff = 0;
  LOOP(n) max_diff = std::max(max_diff, std::abs(x[i] - y[i]));
  return max_diff;
}

template <> float VectorLInf<float>(const float *x, int n) {
  float max_val = 0;
  LOOP(n) max_val = std::max(max_val, std::abs(x[i]));
  return max_val;
}

template <> double VectorLInf<double>(const double *x, int n) {
  double max_val = 0;
  LOOP(n) max_val = std::max(max_val, std::abs(x[i]));
  return max_val;
}

template <> float VectorL2<float>(const float *x, int n) {
  float sum = 0;
  LOOP(n) sum += x[i] * x[i];
  return std::sqrt(sum);
}

template <>
float VectorL2<std::complex<float>>(const std::complex<float> *x, int n) {
  float sum = 0;
  LOOP(n) sum += std::norm(x[i]);
  return std::sqrt(sum);
}

template <> double VectorL2<double>(const double *x, int n) {
  double sum = 0;
  LOOP(n) sum += x[i] * x[i];
  return std::sqrt(sum);
}

template <>
double VectorL2<std::complex<double>>(const std::complex<double> *x, int n) {
  double sum = 0;
  LOOP(n) sum += std::norm(x[i]);
  return std::sqrt(sum);
}

template <> float VectorL2Sqr<float>(const std::complex<float> *x, int n) {
  float sum = 0;
  LOOP(n) sum += std::norm(x[i]);
  return sum;
}

template <> float VectorSum<float>(const float *x, int n) {
  float sum = 0;
  LOOP(n) sum += x[i];
  return sum;
}

template <> double VectorSum<double>(const double *x, int n) {
  double sum = 0;
  LOOP(n) sum += x[i];
  return sum;
}

template <> void VectorInvInplace<float>(float *output, int n) {
  LOOP(n) output[i] = 1.0f / output[i];
}

template <> void VectorInvInplace<double>(double *output, int n) {
  LOOP(n) output[i] = 1.0 / output[i];
}

template <> void VectorSet<float>(const float &c, float *output, int n) {
  std::fill(output, output + n, c);
}

template <> void VectorSet<double>(const double &c, double *output, int n) {
  std::fill(output, output + n, c);
}

template <> void VectorSet<int>(const int &c, int *output, int n) {
  std::fill(output, output + n, c);
}

template <>
void VectorDecimate<float>(const float *x, int src_n, float *output,
                           int factor) {
  int k = 0;
  for (int i = 0; i < src_n; i += factor) {
    output[k++] = x[i];
  }
}

template <>
void VectorDecimate<double>(const double *x, int src_n, double *output,
                            int factor) {
  int k = 0;
  for (int i = 0; i < src_n; i += factor) {
    output[k++] = x[i];
  }
}

template <>
void VectorInterpolate<float>(const float *x, int src_n, float *output,
                              int factor) {
  // Simple zero-stuffing interpolation (may need windowing/filtering if logic
  // expects it) IPP's SampleUp inserts zeros.
  int dest_len = src_n * factor;
  std::fill(output, output + dest_len, 0.0f);
  for (int i = 0; i < src_n; ++i) {
    output[i * factor] = x[i];
  }
}

template <>
void VectorInterpolate<double>(const double *x, int src_n, double *output,
                               int factor) {
  int dest_len = src_n * factor;
  std::fill(output, output + dest_len, 0.0);
  for (int i = 0; i < src_n; ++i) {
    output[i * factor] = x[i];
  }
}

template <>
void VectorInterpolateHold<float>(const float *x, int src_n, float *output,
                                  int factor) {
  int k = 0;
  for (int i = 0; i < src_n; i++) {
    for (int j = 0; j < factor; j++) {
      output[k++] = x[i];
    }
  }
}

template <>
void VectorInterpolateHold<double>(const double *x, int src_n, double *output,
                                   int factor) {
  int k = 0;
  for (int i = 0; i < src_n; i++) {
    for (int j = 0; j < factor; j++) {
      output[k++] = x[i];
    }
  }
}

template <>
void VectorReverseInplace<std::complex<float>>(std::complex<float> *output,
                                               int n) {
  std::reverse(output, output + n);
}

template <>
void VectorReverseInplace<std::complex<double>>(std::complex<double> *output,
                                                int n) {
  std::reverse(output, output + n);
}

template <> void VectorReverse<float>(const float *x, float *output, int n) {
  std::reverse_copy(x, x + n, output);
}

template <> void VectorReverse<double>(const double *x, double *output, int n) {
  std::reverse_copy(x, x + n, output);
}

template <>
void VectorReverse<std::complex<float>>(const std::complex<float> *x,
                                        std::complex<float> *output, int n) {
  std::reverse_copy(x, x + n, output);
}

template <>
void VectorReverse<std::complex<double>>(const std::complex<double> *x,
                                         std::complex<double> *output, int n) {
  std::reverse_copy(x, x + n, output);
}

template <>
void VectorConjInplace<std::complex<float>>(std::complex<float> *output,
                                            int n) {
  LOOP(n) output[i] = std::conj(output[i]);
}

template <>
void VectorConjInplace<std::complex<double>>(std::complex<double> *output,
                                             int n) {
  LOOP(n) output[i] = std::conj(output[i]);
}

template <> void VectorMove<float>(const float *x, float *output, int n) {
  std::copy(x, x + n, output);
}

template <> void VectorMove<double>(const double *x, double *output, int n) {
  std::copy(x, x + n, output);
}

template <>
void VectorMove<std::complex<float>>(const std::complex<float> *x,
                                     std::complex<float> *output, int n) {
  std::copy(x, x + n, output);
}

template <> void VectorZero<float>(float *output, int n) {
  std::fill(output, output + n, 0.0f);
}

template <>
void VectorZero<std::complex<float>>(std::complex<float> *output, int n) {
  std::fill(output, output + n, 0.0f);
}

template <> float VectorDot<float>(const float *x, const float *y, int n) {
  float sum = 0;
  LOOP(n) sum += x[i] * y[i];
  return sum;
}

template <> double VectorDot<double>(const double *x, const double *y, int n) {
  double sum = 0;
  LOOP(n) sum += x[i] * y[i];
  return sum;
}

template <>
void VectorReplaceNanInplace<float>(const float &c, float *x, int n) {
  LOOP(n) {
    if (std::isnan(x[i]))
      x[i] = c;
  }
}

template <> void VectorEnsureNonnegativeInplace<float>(float *x, int n) {
  LOOP(n) {
    if (x[i] < 0)
      x[i] = 0;
  }
}

template <> void VectorEnsureNonnegativeInplace<double>(double *x, int n) {
  LOOP(n) {
    if (x[i] < 0)
      x[i] = 0;
  }
}

template <>
void VectorBothThresholdInplace<float>(const float &c, float *x, int n) {
  LOOP(n) {
    if (x[i] < -c)
      x[i] = -c;
    if (x[i] > c)
      x[i] = c;
  }
}

template <>
void VectorConvert<float, float>(const float *x, float *output, int n) {
  if (x != output)
    std::copy(x, x + n, output);
}

template <>
void VectorConvert<double, double>(const double *x, double *output, int n) {
  if (x != output)
    std::copy(x, x + n, output);
}

// F16 stubs - assume simple cast for now (IPP conversion is complex)
// Users of this library might need float16 logic, but standard C++ doesn't have
// it easily. For now, these are likely unused in core logic or we can stub them
// if needed. NOTE: If compile fails, we can add a simple Float16 typedef alias
// to float in `ipp.h` if not present.

template <>
void VectorConvert<float, Float16>(const float *x, Float16 *output, int n) {
  // Stub: assuming Float16 is compatible with float or we just copy
  // Real IPP checks range.
  LOOP(n) output[i] = (Float16)x[i];
}

template <>
void VectorConvert<Float16, float>(const Float16 *x, float *output, int n) {
  LOOP(n) output[i] = (float)x[i];
}

template <>
void VectorConvert<std::complex<float>, ComplexFloat16>(
    const std::complex<float> *x, ComplexFloat16 *output, int n) {
  VectorConvert((const float *)x, (Float16 *)output, 2 * n);
}

template <>
void VectorConvert<ComplexFloat16, std::complex<float>>(
    const ComplexFloat16 *x, std::complex<float> *output, int n) {
  VectorConvert((const Float16 *)x, (float *)output, 2 * n);
}

template <>
void VectorRealToComplex<float>(const float *x, const float *y,
                                std::complex<float> *output, int n) {
  LOOP(n) output[i] = std::complex<float>(x[i], y[i]);
}

template <>
void VectorRealToComplex<double>(const double *x, const double *y,
                                 std::complex<double> *output, int n) {
  LOOP(n) output[i] = std::complex<double>(x[i], y[i]);
}

template <>
void VectorComplexToReal<float>(const std::complex<float> *x,
                                float *output_real, float *output_imag, int n) {
  LOOP(n) {
    output_real[i] = x[i].real();
    output_imag[i] = x[i].imag();
  }
}

template <>
void VectorComplexToReal<double>(const std::complex<double> *x,
                                 double *output_real, double *output_imag,
                                 int n) {
  LOOP(n) {
    output_real[i] = x[i].real();
    output_imag[i] = x[i].imag();
  }
}

template <>
void VectorConvolve<float>(const float *x, int nx, const float *y, int ny,
                           float *output) {
  // Naive convolution O(NM)
  int out_len = nx + ny - 1;
  std::fill(output, output + out_len, 0.0f);
  for (int i = 0; i < nx; ++i) {
    for (int j = 0; j < ny; ++j) {
      output[i + j] += x[i] * y[j];
    }
  }
}

template <>
void VectorConvolve<double>(const double *x, int nx, const double *y, int ny,
                            double *output) {
  int out_len = nx + ny - 1;
  std::fill(output, output + out_len, 0.0);
  for (int i = 0; i < nx; ++i) {
    for (int j = 0; j < ny; ++j) {
      output[i + j] += x[i] * y[j];
    }
  }
}
} // namespace bakuage

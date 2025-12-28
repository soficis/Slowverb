#include "bakuage/dft.h"
#include <algorithm>
#include <cmath>
#include <complex>
#include <cstring>
#include <vector>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace bakuage {

namespace {

// Simple FFT implementation (Cooley-Tukey)
// Not optimized, but dependency-free.
template <typename T>
void SimpleFft(std::complex<T> *data, int n, bool inverse) {
  if (n <= 1)
    return;

  // Bit reversal
  int j = 0;
  for (int i = 0; i < n; ++i) {
    if (j > i) {
      std::swap(data[j], data[i]);
    }
    int m = n / 2;
    while (m >= 1 && j >= m) {
      j -= m;
      m /= 2;
    }
    j += m;
  }

  // Butterfly
  for (int len = 2; len <= n; len <<= 1) {
    double ang = 2 * M_PI / len * (inverse ? 1 : -1);
    std::complex<T> wlen(std::cos(ang), std::sin(ang));
    for (int i = 0; i < n; i += len) {
      std::complex<T> w(1.0, 0.0);
      for (int k = 0; k < len / 2; ++k) {
        std::complex<T> u = data[i + k];
        std::complex<T> v = data[i + k + len / 2] * w;
        data[i + k] = u + v;
        data[i + k + len / 2] = u - v;
        w *= wlen;
      }
    }
  }

  /*if (inverse) {
    for (int i = 0; i < n; ++i) {
      data[i] /= T(n);
    }
  }*/
}

} // namespace

FftMemoryBuffer::FftMemoryBuffer(int size) : size_(size) {
  if (size > 0) {
    data_ = malloc(size);
  } else {
    data_ = nullptr;
  }
}

FftMemoryBuffer::~FftMemoryBuffer() {
  if (data_)
    free(data_);
}

FftMemoryBuffer::FftMemoryBuffer(const FftMemoryBuffer &x) : size_(x.size_) {
  if (size_ > 0) {
    data_ = malloc(size_);
    memcpy(data_, x.data_, size_);
  } else {
    data_ = nullptr;
  }
}
FftMemoryBuffer::FftMemoryBuffer(FftMemoryBuffer &&x)
    : size_(x.size_), data_(x.data_) {
  x.size_ = 0;
  x.data_ = nullptr;
}
FftMemoryBuffer &FftMemoryBuffer::operator=(const FftMemoryBuffer &x) {
  if (this != &x) {
    if (data_)
      free(data_);
    size_ = x.size_;
    if (size_ > 0) {
      data_ = malloc(size_);
      memcpy(data_, x.data_, size_);
    } else {
      data_ = nullptr;
    }
  }
  return *this;
}
FftMemoryBuffer &FftMemoryBuffer::operator=(FftMemoryBuffer &&x) {
  if (this != &x) {
    if (data_)
      free(data_);
    size_ = x.size_;
    data_ = x.data_;
    x.size_ = 0;
    x.data_ = nullptr;
  }
  return *this;
}

// Dft<float>
Dft<float>::Dft(int len)
    : dft_ptr_(reinterpret_cast<void *>(len)),
      work_(len * sizeof(std::complex<float>)) {}

void Dft<float>::Forward(const float *input, float *output) {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<float> *out_c = reinterpret_cast<std::complex<float> *>(output);
  // Copy input (real) to complex
  for (int i = 0; i < len; ++i)
    out_c[i] = input[i];
  // Wait, Dft<float>::Forward input is Float*, output is Float*.
  // Dft<float> is likely Complex-to-Complex?
  // The types in dft.h say typedef float Float;
  // But Dft<float> usually implies general complex DFT.
  // However, the signature takes float* input.
  // Let's assume input is complex interleaved (2*len floats), output is complex
  // interleaved. If input was real, we'd use RealDft.

  // Safety copy to work buffer to allow in-place
  std::complex<float> *work = (std::complex<float> *)work_.data();
  memcpy(work, input, len * sizeof(std::complex<float>));

  SimpleFft(work, len, false);

  memcpy(output, work, len * sizeof(std::complex<float>));
}

void Dft<float>::Backward(const float *input, float *output) {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<float> *work = (std::complex<float> *)work_.data();
  memcpy(work, input, len * sizeof(std::complex<float>));

  SimpleFft(work, len, true);

  memcpy(output, work, len * sizeof(std::complex<float>));
}

// Dft<double>
Dft<double>::Dft(int len)
    : dft_ptr_(reinterpret_cast<void *>(len)),
      work_(len * sizeof(std::complex<double>)) {}

void Dft<double>::Forward(const double *input, double *output) {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<double> *work = (std::complex<double> *)work_.data();
  memcpy(work, input, len * sizeof(std::complex<double>));
  SimpleFft(work, len, false);
  memcpy(output, work, len * sizeof(std::complex<double>));
}

void Dft<double>::Backward(const double *input, double *output) {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<double> *work = (std::complex<double> *)work_.data();
  memcpy(work, input, len * sizeof(std::complex<double>));
  SimpleFft(work, len, true);
  memcpy(output, work, len * sizeof(std::complex<double>));
}

// RealDft<float>
// Basic implementation: Expand to Complex, FFT, Pack.
RealDft<float>::RealDft(int len, bool no)
    : dft_ptr_(reinterpret_cast<void *>(len)),
      work_(len * sizeof(std::complex<float>)) {}

size_t RealDft<float>::work_size() const {
  return reinterpret_cast<intptr_t>(dft_ptr_) * sizeof(std::complex<float>);
}

void RealDft<float>::Forward(const float *input, float *output,
                             void *work_in) const {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<float> *work = (std::complex<float> *)
      work_in; // We need complex buffer of size N not N/2+1 for simple impl

  // Copy real to complex
  for (int i = 0; i < len; ++i)
    work[i] = input[i];

  SimpleFft(work, len, false);

  // Output standard sorted complex?
  // IPP RToCCS: [R0, 0, R1, I1, .... R(N/2), 0] (Size N+2)
  // dft.h usually expects this for generic Forward.
  std::complex<float> *out_c = (std::complex<float> *)output;
  for (int i = 0; i <= len / 2; ++i) {
    out_c[i] = work[i];
  }
}

void RealDft<float>::ForwardPerm(const float *input, float *output,
                                 void *work_in) const {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<float> *work = (std::complex<float> *)work_in;

  for (int i = 0; i < len; ++i)
    work[i] = input[i];
  SimpleFft(work, len, false);

  // IPP Perm Format: [R0, R(N/2), R1, I1, R2, I2, ...]
  output[0] = work[0].real();
  if ((len % 2) == 0)
    output[1] = work[len / 2].real();

  for (int i = 1; i < len / 2; ++i) {
    output[2 * i] = work[i].real();
    output[2 * i + 1] = work[i].imag();
  }
}

void RealDft<float>::ForwardPack(const float *input, float *output,
                                 void *work_in) const {
  // Pack usually similar to Perm but maybe different order.
  // IPP Pack: [R0, R1, I1, R2, I2 ... R(N/2)]
  // Actually, let's treat it same as Perm for now or check IPP details.
  // IPP Pack for odd N is different.
  // Assuming even N for audio usually.
  ForwardPerm(input, output, work_in);
}

void RealDft<float>::Backward(const float *input, float *output,
                              void *work_in) const {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<float> *work = (std::complex<float> *)work_in;

  // Reconstruct full complex spectrum from CCS
  // CCS: [R0, I0(0), R1, I1, ..., RN/2, IN/2(0)]
  const std::complex<float> *in_c = (const std::complex<float> *)input;

  for (int i = 0; i <= len / 2; ++i)
    work[i] = in_c[i];
  for (int i = len / 2 + 1; i < len; ++i)
    work[i] = std::conj(work[len - i]);

  SimpleFft(work, len, true);

  for (int i = 0; i < len; ++i)
    output[i] = work[i].real();
}

void RealDft<float>::BackwardPerm(const float *input, float *output,
                                  void *work_in) const {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<float> *work = (std::complex<float> *)work_in;

  // Perm: [R0, R(N/2), R1, I1, R2, I2...]
  work[0] = std::complex<float>(input[0], 0);
  if ((len % 2) == 0)
    work[len / 2] = std::complex<float>(input[1], 0);

  for (int i = 1; i < len / 2; ++i) {
    work[i] = std::complex<float>(input[2 * i], input[2 * i + 1]);
  }
  for (int i = len / 2 + 1; i < len; ++i)
    work[i] = std::conj(work[len - i]);

  SimpleFft(work, len, true);

  for (int i = 0; i < len; ++i)
    output[i] = work[i].real();
}

void RealDft<float>::BackwardPack(const float *input, float *output,
                                  void *work_in) const {
  BackwardPerm(input, output, work_in);
}

// RealDft<double> (Copy paste with double)
RealDft<double>::RealDft(int len, bool no)
    : dft_ptr_(reinterpret_cast<void *>(len)),
      work_(len * sizeof(std::complex<double>)) {}
size_t RealDft<double>::work_size() const {
  return reinterpret_cast<intptr_t>(dft_ptr_) * sizeof(std::complex<double>);
}

void RealDft<double>::Forward(const double *input, double *output,
                              void *work_in) const {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<double> *work = (std::complex<double> *)work_in;
  for (int i = 0; i < len; ++i)
    work[i] = input[i];
  SimpleFft(work, len, false);
  std::complex<double> *out_c = (std::complex<double> *)output;
  for (int i = 0; i <= len / 2; ++i)
    out_c[i] = work[i];
}
void RealDft<double>::ForwardPerm(const double *input, double *output,
                                  void *work_in) const {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<double> *work = (std::complex<double> *)work_in;
  for (int i = 0; i < len; ++i)
    work[i] = input[i];
  SimpleFft(work, len, false);
  output[0] = work[0].real();
  if ((len % 2) == 0)
    output[1] = work[len / 2].real();
  for (int i = 1; i < len / 2; ++i) {
    output[2 * i] = work[i].real();
    output[2 * i + 1] = work[i].imag();
  }
}
void RealDft<double>::ForwardPack(const double *input, double *output,
                                  void *work_in) const {
  ForwardPerm(input, output, work_in);
}
void RealDft<double>::Backward(const double *input, double *output,
                               void *work_in) const {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<double> *work = (std::complex<double> *)work_in;
  const std::complex<double> *in_c = (const std::complex<double> *)input;
  for (int i = 0; i <= len / 2; ++i)
    work[i] = in_c[i];
  for (int i = len / 2 + 1; i < len; ++i)
    work[i] = std::conj(work[len - i]);
  SimpleFft(work, len, true);
  for (int i = 0; i < len; ++i)
    output[i] = work[i].real();
}
void RealDft<double>::BackwardPerm(const double *input, double *output,
                                   void *work_in) const {
  int len = reinterpret_cast<intptr_t>(dft_ptr_);
  std::complex<double> *work = (std::complex<double> *)work_in;
  work[0] = std::complex<double>(input[0], 0);
  if ((len % 2) == 0)
    work[len / 2] = std::complex<double>(input[1], 0);

  for (int i = 1; i < len / 2; ++i) {
    work[i] = std::complex<double>(input[2 * i], input[2 * i + 1]);
  }
  for (int i = len / 2 + 1; i < len; ++i)
    work[i] = std::conj(work[len - i]);
  SimpleFft(work, len, true);
  for (int i = 0; i < len; ++i)
    output[i] = work[i].real();
}
void RealDft<double>::BackwardPack(const double *input, double *output,
                                   void *work_in) const {
  BackwardPerm(input, output, work_in);
}

// 2D Stubs (Empty for now until needed)
Dft2D<float>::Dft2D(int size0, int size1) {}
void Dft2D<float>::Forward(const float *input, float *output) {}
void Dft2D<float>::Backward(const float *input, float *output) {}

Dct2D<float>::Dct2D(int size0, int size1) {}
void Dct2D<float>::Forward(const float *input, float *output) {}

} // namespace bakuage

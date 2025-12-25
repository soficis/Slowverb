#pragma once

#include "bakuage/dft.h"
#include <complex>
#include <cstring>
#include <vector>

// Basic FFTW types
typedef double fftw_complex[2];
typedef float fftwf_complex[2];
typedef struct fftw_plan_s *fftw_plan;
typedef struct fftw_plan_s *fftwf_plan;

#define FFTW_ESTIMATE 0

// Stub implementation classes
struct fftw_plan_s {
  virtual ~fftw_plan_s() {}
  virtual void execute() = 0;
};

template <typename T> struct fftw_plan_r2c_impl : public fftw_plan_s {
  bakuage::RealDft<T> dft;
  T *in;
  T *out;
  std::vector<char> work;

  fftw_plan_r2c_impl(int n, T *in_, T *out_) : dft(n), in(in_), out(out_) {
    work.resize(dft.work_size());
  }

  void execute() override { dft.Forward(in, out, work.data()); }
};

template <typename T> struct fftw_plan_c2r_impl : public fftw_plan_s {
  bakuage::RealDft<T> dft;
  T *in;
  T *out;
  std::vector<char> work;

  fftw_plan_c2r_impl(int n, T *in_, T *out_) : dft(n), in(in_), out(out_) {
    work.resize(dft.work_size());
  }

  void execute() override { dft.Backward(in, out, work.data()); }
};

inline void *fftw_malloc(size_t n) { return malloc(n); }
inline void fftw_free(void *p) { free(p); }
inline void *fftwf_malloc(size_t n) { return malloc(n); }
inline void fftwf_free(void *p) { free(p); }

inline fftw_plan fftw_plan_dft_r2c_1d(int n, double *in, fftw_complex *out,
                                      unsigned flags) {
  return new fftw_plan_r2c_impl<double>(n, in, (double *)out);
}

inline fftw_plan fftw_plan_dft_c2r_1d(int n, fftw_complex *in, double *out,
                                      unsigned flags) {
  return new fftw_plan_c2r_impl<double>(n, (double *)in, out);
}

inline fftwf_plan fftwf_plan_dft_r2c_1d(int n, float *in, fftwf_complex *out,
                                        unsigned flags) {
  return new fftw_plan_r2c_impl<float>(n, in, (float *)out);
}

inline fftwf_plan fftwf_plan_dft_c2r_1d(int n, fftwf_complex *in, float *out,
                                        unsigned flags) {
  return new fftw_plan_c2r_impl<float>(n, (float *)in, out);
}

inline void fftw_execute(fftw_plan p) {
  if (p)
    p->execute();
}

inline void fftwf_execute(fftwf_plan p) {
  if (p)
    p->execute();
}

inline void fftw_destroy_plan(fftw_plan p) {
  if (p)
    delete p;
}

inline void fftwf_destroy_plan(fftwf_plan p) {
  if (p)
    delete p;
}

// FFTW class removed to avoid ambiguity with bakuage::FFTW

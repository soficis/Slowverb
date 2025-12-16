#pragma once

#include "bakuage/dft.h"
#include <complex>
#include <cstring>
#include <vector>


// Basic FFTW types
typedef double fftw_complex[2];
typedef struct fftw_plan_s *fftw_plan;

#define FFTW_ESTIMATE 0

// Stub implementation classes
struct fftw_plan_s {
  virtual ~fftw_plan_s() {}
  virtual void execute() = 0;
};

struct fftw_plan_r2c : public fftw_plan_s {
  bakuage::RealDft<double> dft;
  double *in;
  fftw_complex *out;
  std::vector<char> work;

  fftw_plan_r2c(int n, double *in_, fftw_complex *out_)
      : dft(n), in(in_), out(out_) {
    work.resize(dft.work_size());
  }

  void execute() override {
    // FFTW R2C output is standard CCS? Or half-complex?
    // fftw_plan_dft_r2c_1d outputs N/2+1 complex numbers.
    // My RealDft::Forward output is N/2 + 1 complex numbers (if standard)
    // Check my dft.cpp implementation of Forward (generic).
    // It outputs N/2+1 complex numbers.
    dft.Forward(in, (double *)out, work.data());
  }
};

struct fftw_plan_c2r : public fftw_plan_s {
  bakuage::RealDft<double> dft;
  fftw_complex *in;
  double *out;
  std::vector<char> work;

  fftw_plan_c2r(int n, fftw_complex *in_, double *out_)
      : dft(n), in(in_), out(out_) {
    work.resize(dft.work_size());
  }

  void execute() override { dft.Backward((double *)in, out, work.data()); }
};

inline void *fftw_malloc(size_t n) { return malloc(n); }
inline void fftw_free(void *p) { free(p); }

inline fftw_plan fftw_plan_dft_r2c_1d(int n, double *in, fftw_complex *out,
                                      unsigned flags) {
  return new fftw_plan_r2c(n, in, out);
}

inline fftw_plan fftw_plan_dft_c2r_1d(int n, fftw_complex *in, double *out,
                                      unsigned flags) {
  return new fftw_plan_c2r(n, in, out);
}

inline void fftw_execute(fftw_plan p) {
  if (p)
    p->execute();
}

inline void fftw_destroy_plan(fftw_plan p) {
  if (p)
    delete p;
}

// Mutex stub if needed (AutoMastering3 uses FFTW::mutex())
// We can just define a dummy struct
class FFTW {
public:
  static std::recursive_mutex &mutex() {
    static std::recursive_mutex m;
    return m;
  }
};

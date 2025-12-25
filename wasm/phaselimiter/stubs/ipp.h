#pragma once

#include <complex>
#include <cstdint>
#include <vector>

// Basic Types
typedef float Ipp32f;
typedef double Ipp64f;
typedef int8_t Ipp8u;
typedef int32_t Ipp32s;
typedef int64_t Ipp64s;

// Complex Types (Compatible with std::complex layout)
typedef struct {
  float re;
  float im;
} Ipp32fc;

typedef struct {
  double re;
  double im;
} Ipp64fc;

// Status
typedef int IppStatus;
#define ippStsNoErr 0

// Constants
typedef enum {
  ippAlgHintNone,
  ippAlgHintFast,
  ippAlgHintAccurate
} IppHintAlgorithm;

typedef enum { ippCmpLess, ippCmpGreater } IppCmpOp;

typedef enum { ippRndZero, ippRndNear, ippRndFinancial } IppRoundMode;

// Version
typedef struct {
  int major;
  int minor;
  int majorBuild;
  int build;
  char targetCpu[4];
  const char *Name;
  const char *Version;
  const char *BuildDate;
} IppLibraryVersion;

// Dummy Init/Version functions
inline IppStatus ippInit() { return ippStsNoErr; }
inline const IppLibraryVersion *ippGetLibVersion() {
  static IppLibraryVersion v = {1, 0, 0, 0, "gen", "IPP Stub", "1.0", "2024"};
  return &v;
}

// FFT Types (Opaque stubs, implementation will be in dft.cpp replacement)
// We define them as void* for now, or structs if we need size
struct IppsFFTSpec_R_32f;
struct IppsFFTSpec_R_64f;
struct IppsDFTSpec_R_32f;
struct IppsDFTSpec_R_64f;

// FFT Init constants
#define IPP_FFT_DIV_INV_BY_N 1
#define IPP_FFT_DIV_FWD_BY_N 2
#define IPP_FFT_DIV_BY_SQRTN 4
#define IPP_FFT_NODIV_BY_ANY 8

// FIR Filter Types
struct IppsFIRSpec_32f;
struct IppsFIRSpec_64f;
struct IppsFIRSpec_32fc;
struct IppsFIRSpec_64fc;

typedef enum { ipp32f, ipp64f, ipp32fc, ipp64fc } IppDataType;

// FIR functions (stubs)
inline IppStatus ippsFIRMRInit_32f(const Ipp32f *pTaps, int tapsLen,
                                   int upFactor, int upPhase, int downFactor,
                                   int downPhase, IppsFIRSpec_32f *pSpec) {
  return ippStsNoErr;
}
inline IppStatus ippsFIRMRInit_64f(const Ipp64f *pTaps, int tapsLen,
                                   int upFactor, int upPhase, int downFactor,
                                   int downPhase, IppsFIRSpec_64f *pSpec) {
  return ippStsNoErr;
}
inline IppStatus ippsFIRMRInit_32fc(const Ipp32fc *pTaps, int tapsLen,
                                    int upFactor, int upPhase, int downFactor,
                                    int downPhase, IppsFIRSpec_32fc *pSpec) {
  return ippStsNoErr;
}
inline IppStatus ippsFIRMRInit_64fc(const Ipp64fc *pTaps, int tapsLen,
                                    int upFactor, int upPhase, int downFactor,
                                    int downPhase, IppsFIRSpec_64fc *pSpec) {
  return ippStsNoErr;
}

inline IppStatus ippsFIRMR_32f(const Ipp32f *pSrc, Ipp32f *pDst, int numIters,
                               IppsFIRSpec_32f *pSpec, const Ipp32f *pDlySrc,
                               Ipp32f *pDlyDst, Ipp8u *pBuf) {
  return ippStsNoErr;
}
inline IppStatus ippsFIRMR_64f(const Ipp64f *pSrc, Ipp64f *pDst, int numIters,
                               IppsFIRSpec_64f *pSpec, const Ipp64f *pDlySrc,
                               Ipp64f *pDlyDst, Ipp8u *pBuf) {
  return ippStsNoErr;
}
inline IppStatus ippsFIRMR_32fc(const Ipp32fc *pSrc, Ipp32fc *pDst,
                                int numIters, IppsFIRSpec_32fc *pSpec,
                                const Ipp32fc *pDlySrc, Ipp32fc *pDlyDst,
                                Ipp8u *pBuf) {
  return ippStsNoErr;
}
inline IppStatus ippsFIRMR_64fc(const Ipp64fc *pSrc, Ipp64fc *pDst,
                                int numIters, IppsFIRSpec_64fc *pSpec,
                                const Ipp64fc *pDlySrc, Ipp64fc *pDlyDst,
                                Ipp8u *pBuf) {
  return ippStsNoErr;
}

// Memory Allocation
inline Ipp32f *ippsMalloc_32f(int size) {
  return (Ipp32f *)malloc(size * sizeof(Ipp32f));
}
inline Ipp64f *ippsMalloc_64f(int size) {
  return (Ipp64f *)malloc(size * sizeof(Ipp64f));
}
inline Ipp32fc *ippsMalloc_32fc(int size) {
  return (Ipp32fc *)malloc(size * sizeof(Ipp32fc));
}
inline Ipp64fc *ippsMalloc_64fc(int size) {
  return (Ipp64fc *)malloc(size * sizeof(Ipp64fc));
}
inline Ipp8u *ippsMalloc_8u(int size) {
  return (Ipp8u *)malloc(size * sizeof(Ipp8u));
}
inline void ippsFree(void *p) { free(p); }
inline void ippFree(void *p) { free(p); }

inline IppStatus ippsFIRMRGetSize(int fir_size, int up_factor, int down_factor,
                                  IppDataType dataType, int *pSpecSize,
                                  int *pBufSize) {
  *pSpecSize = 1024; // Dummy sizes
  *pBufSize = 1024;
  return ippStsNoErr;
}

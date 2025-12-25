#pragma once
#include <cstdlib>

inline void *scalable_aligned_malloc(size_t size, size_t alignment) {
  // Emscripten/WASM doesn't strictly need scalable_allocator for a single
  // thread, so we redirect to standard aligned allocation.
#ifdef _WIN32
  return _aligned_malloc(size, alignment);
#else
  void *ptr = nullptr;
  if (posix_memalign(&ptr, alignment, size) == 0)
    return ptr;
  return nullptr;
#endif
}

inline void scalable_aligned_free(void *ptr) {
#ifdef _WIN32
  _aligned_free(ptr);
#else
  free(ptr);
#endif
}

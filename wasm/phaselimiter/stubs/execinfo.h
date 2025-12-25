#pragma once
#include <cstddef>

#ifdef __cplusplus
extern "C" {
#endif

inline int backtrace(void **buffer, int size) { return 0; }

inline void backtrace_symbols_fd(void *const *buffer, int size, int fd) {}

#ifdef __cplusplus
}
#endif

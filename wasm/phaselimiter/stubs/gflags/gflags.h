#ifndef GFLAGS_GFLAGS_H_
#define GFLAGS_GFLAGS_H_

#include <string>

#define DECLARE_bool(name) extern bool FLAGS_##name
#define DECLARE_int32(name) extern int FLAGS_##name
#define DECLARE_double(name) extern double FLAGS_##name
#define DECLARE_string(name) extern std::string FLAGS_##name

#define DEFINE_bool(name, val, txt) bool FLAGS_##name = val
#define DEFINE_int32(name, val, txt) int FLAGS_##name = val
#define DEFINE_double(name, val, txt) double FLAGS_##name = val
#define DEFINE_string(name, val, txt) std::string FLAGS_##name = val

namespace gflags {
inline void ParseCommandLineFlags(int *argc, char ***argv, bool remove_flags) {}
} // namespace gflags

#endif

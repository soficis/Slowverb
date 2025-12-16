#pragma once

#include <cstddef>

namespace tbb {
template <typename Int>
class blocked_range {
 public:
  blocked_range(Int begin, Int end) : begin_(begin), end_(end) {}
  Int begin() const { return begin_; }
  Int end() const { return end_; }

 private:
  Int begin_;
  Int end_;
};

template <typename Int, typename Body>
inline void parallel_for(Int begin, Int end, const Body& body) {
  for (Int i = begin; i < end; i++) {
    body(i);
  }
}

template <typename Range, typename Body>
inline void parallel_for(const Range& range, const Body& body) {
  for (auto i = range.begin(); i < range.end(); i++) {
    body(i);
  }
}
}  // namespace tbb


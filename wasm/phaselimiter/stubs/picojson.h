#pragma once
#include <iostream>
#include <map>
#include <string>
#include <vector>


namespace picojson {

class value;

typedef std::map<std::string, value> object;
typedef std::vector<value> array;

class value {
public:
  template <typename T> const T &get() const {
    static T dummy;
    return dummy;
  }

  bool is() const { return false; }
};

inline std::string parse(value &out, std::istream &is) { return ""; }

inline std::string parse(value &out, const std::string &s) { return ""; }

} // namespace picojson

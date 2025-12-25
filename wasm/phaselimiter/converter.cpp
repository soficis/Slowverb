#include "bakuage/sound_quality2.h"
#include "gflags/gflags.h"
#include <boost/archive/binary_iarchive.hpp>
#include <boost/archive/text_oarchive.hpp>
#include <fstream>
#include <iostream>


// Stubs for gflags used in bakuage
DEFINE_string(sound_quality2_cache, "", "");
DEFINE_string(mastering5_optimization_algorithm, "", "");
DEFINE_int32(mastering5_optimization_max_eval_count, 0, "");
DEFINE_double(mastering5_mastering_level, 0, "");
DEFINE_string(mastering5_mastering_reference_file, "", "");

int main(int argc, char **argv) {
  if (argc < 3) {
    std::cout << "Usage: converter <input_bin> <output_txt>" << std::endl;
    return 1;
  }
  const char *input_path = argv[1];
  const char *output_path = argv[2];

  try {
    bakuage::SoundQuality2Calculator calculator;
    {
      std::cout << "Loading binary cache from " << input_path << "..."
                << std::endl;
      std::ifstream ifs(input_path, std::ios::binary);
      if (!ifs) {
        std::cerr << "Failed to open input" << std::endl;
        return 1;
      }
      boost::archive::binary_iarchive ia(ifs);
      ia >> calculator;
    }
    {
      std::cout << "Saving text cache to " << output_path << "..." << std::endl;
      std::ofstream ofs(output_path);
      if (!ofs) {
        std::cerr << "Failed to open output" << std::endl;
        return 1;
      }
      boost::archive::text_oarchive oa(ofs);
      oa << calculator;
    }
    std::cout << "Success!" << std::endl;
  } catch (const std::exception &e) {
    std::cerr << "Exception: " << e.what() << std::endl;
    return 1;
  }
  return 0;
}

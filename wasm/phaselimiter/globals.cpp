#include "gflags/gflags.h"
#include <string>

// Standard PhaseLimiter flags (from main.cpp)
DEFINE_double(targetLufs, -14.0, "target lufs");
DEFINE_double(bassPreservation, 0.5, "bass preservation");

// Mastering 2
DEFINE_string(mastering2_config_file, "", "Mastering 2 config file path.");

// Mastering 3
DEFINE_int32(mastering3_iteration, 1000,
             "Mastering 3 optimization iteration count.");
DEFINE_double(mastering3_target_sn, 12,
              "Target S/N in dB used for Acoustic entropy calculation.");

// Mastering 5
DEFINE_string(sound_quality2_cache, "./sound_quality2_cache",
              "sound quality2 cache path.");
DEFINE_string(
    mastering5_optimization_algorithm, "de",
    "de / nm / pso / de_prmm / pso_dv (de recommended for TBB parallelism)");
DEFINE_int32(mastering5_optimization_max_eval_count, 4000,
             "Mastering5 optimization max eval count.");
DEFINE_int32(mastering5_early_termination_patience, 500,
             "Stop optimization if no improvement for this many evaluations.");
DEFINE_double(mastering5_mastering_level, 0.5, "Mastering5 mastering level.");
DEFINE_string(mastering5_mastering_reference_file, "",
              "Mastering reference json path.");

// Pre-compression
DEFINE_double(pre_compression_threshold, 6.0,
              "Pre-compression threshold relative to loudness.");
DEFINE_double(pre_compression_mean_sec, 0.2, "Pre-compression mean sec.");

// Other common flags if needed
DEFINE_int32(worker_count, 0, "worker count (0: auto detect)");
DEFINE_bool(erb_eval_func_weighting, false,
            "Enable eval function weighting by ERB");
DEFINE_bool(perf_src_cache, true,
            "use IFFT of src wave cache (performance option)");
DEFINE_double(absolute_min_noise, 1e-6,
              "absolute min noise (independent from noise weighting)");

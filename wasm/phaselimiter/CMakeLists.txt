cmake_minimum_required(VERSION 3.13)
project(phaselimiter_wasm)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(EM_LINK_FLAGS
  "-O3 -flto"
  "-sALLOW_MEMORY_GROWTH=1"
  "-sMAXIMUM_MEMORY=1GB"
  "-sMODULARIZE=1"
  "-sEXPORT_NAME=createPhaseLimiterModule"
  "-sENVIRONMENT=web,worker"
  "-sFILESYSTEM=0"
  "-sEXPORTED_FUNCTIONS=[\\\"_run_phase_limiter\\\",\\\"_malloc\\\",\\\"_free\\\"]"
  "-sEXPORTED_RUNTIME_METHODS=[\\\"ccall\\\"]"
)

add_executable(phaselimiter adapter.cpp)
target_compile_options(phaselimiter PRIVATE -O3 -flto)
target_link_options(phaselimiter PRIVATE ${EM_LINK_FLAGS})

target_include_directories(phaselimiter PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/stubs
)

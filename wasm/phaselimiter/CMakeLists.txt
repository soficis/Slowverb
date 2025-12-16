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

# PhaseLimiter Pro (Full Engine Port)
file(GLOB BAKUAGE_SRCS "${CMAKE_CURRENT_SOURCE_DIR}/src_original/deps/bakuage/src/*.cpp")
file(GLOB PHASELIMITER_PRO_SRCS "${CMAKE_CURRENT_SOURCE_DIR}/src_original/src/phase_limiter/auto_mastering3.cpp")

add_executable(phaselimiter_pro adapter_pro.cpp ${BAKUAGE_SRCS} ${PHASELIMITER_PRO_SRCS})

target_compile_options(phaselimiter_pro PRIVATE -O3 -flto)
target_compile_definitions(phaselimiter_pro PRIVATE PHASELIMITER_ENABLE_FFTW)

target_include_directories(phaselimiter_pro PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/stubs
  ${CMAKE_CURRENT_SOURCE_DIR}/src_original
  ${CMAKE_CURRENT_SOURCE_DIR}/src_original/deps/bakuage/include
)

target_link_options(phaselimiter_pro PRIVATE ${EM_LINK_FLAGS} "-sEXPORT_NAME=createPhaseLimiterProModule")

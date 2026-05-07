cmake_minimum_required(VERSION 3.10)
project(whisper_jni)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Suppress 64-bit pointer to 32-bit int casting errors from Flutter's C++ STL on ARM64
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-shorten-64-to-32 -Wno-error=shorten-64-to-32")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-shorten-64-to-32 -Wno-error=shorten-64-to-32")
add_compile_options(-fexceptions -funwind-tables -fno-omit-frame-pointer)

# ===========================
# WHISPER (original block)
# ===========================
# Disable aggressive warning flags that conflict with Flutter's C++ stdlib
set(WHISPER_ALL_WARNINGS OFF CACHE BOOL "whisper: enable all compiler warnings" FORCE)
set(WHISPER_FATAL_WARNINGS OFF CACHE BOOL "whisper: enable -Werror flag" FORCE)
add_subdirectory(whisper.cpp)

add_library(whisper_jni SHARED
    whisper_wrapper.cpp
)

target_include_directories(whisper_jni PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(whisper_jni
    whisper
    android
    log
)

# ==========================================
# Llama.cpp — Separate standalone CMake file
# ==========================================
include(${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists_llama.txt)

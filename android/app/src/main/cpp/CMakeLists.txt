cmake_minimum_required(VERSION 3.10)
project(whisper_jni)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_compile_options(-fexceptions -funwind-tables -fno-omit-frame-pointer)

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

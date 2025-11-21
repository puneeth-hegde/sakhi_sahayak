cmake_minimum_required(VERSION 3.10)

# Project name and languages
project(whisper_jni_project LANGUAGES C CXX)

# adjust this to your NDK / ABI flags as needed
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# path to the whisper_cpp sources relative to this CMakeLists
# (this assumes this file is android/native/whisper_jni/CMakeLists.txt)
set(WHISPER_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/whisper_cpp")
# If your third_party is somewhere else, update WHISPER_CPP_DIR accordingly.

# Source files we must compile and link:
set(WHISPER_SOURCES
    ${WHISPER_CPP_DIR}/whisper.cpp
    ${WHISPER_CPP_DIR}/ggml.c
)

# If your folder contains additional ggml implementation files (ggml-alloc.c, ggml-quants.c),
# add them too. For example:
if(EXISTS "${WHISPER_CPP_DIR}/ggml-alloc.c")
    list(APPEND WHISPER_SOURCES ${WHISPER_CPP_DIR}/ggml-alloc.c)
endif()
if(EXISTS "${WHISPER_CPP_DIR}/ggml-quants.c")
    list(APPEND WHISPER_SOURCES ${WHISPER_CPP_DIR}/ggml-quants.c)
endif()

# Add JNI wrapper sources (adjust path if your JNI wrapper source has a different name)
# assuming you have a jni source e.g. whisper_jni.cpp or jni.c in this folder:
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/whisper_jni.cpp")
    list(APPEND WHISPER_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/whisper_jni.cpp)
endif()
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/jni.c")
    list(APPEND WHISPER_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/jni.c)
endif()

# Build a shared library for Android
add_library( whisper_jni SHARED ${WHISPER_SOURCES} )

# Include directories
target_include_directories(whisper_jni PRIVATE
    ${WHISPER_CPP_DIR}
    ${WHISPER_CPP_DIR}/spm-headers   # if present
    ${CMAKE_CURRENT_SOURCE_DIR}      # for your JNI headers
)

# compile defines expected by whisper
target_compile_definitions(whisper_jni PRIVATE WHISPER_BUILD)

# Link with standard libraries (math, pthread if needed)
find_library(log-lib log)

target_link_libraries( whisper_jni PRIVATE ${log-lib} )

# Optional: set position independent code
set_target_properties(whisper_jni PROPERTIES POSITION_INDEPENDENT_CODE ON)

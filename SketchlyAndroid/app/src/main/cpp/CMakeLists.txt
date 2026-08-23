cmake_minimum_required(VERSION 3.22.1)
project(sketchly_ai_jni)

# ----------------------------------------------------------------
# Shares llama.cpp source with ~/Documents/GitHub/ReadAloudDescribe.
#
# Why an absolute path into a sibling repo instead of vendoring a
# second 154MB copy of third_party/llama.cpp into this repo: llama.cpp
# itself doesn't change per-app (same CPU-only Android build, same
# GGML backend flags), only the JNI glue on top of it does. Copying it
# would mean two checkouts to keep in sync on every upstream bump —
# real drift risk for zero benefit. Extracting a proper shared Gradle
# module (like PaywallKit-Android) was considered but rejected for
# this pass: it would require restructuring ReadAloudDescribe's
# working CMake/NDK build (this exact file, adapted) to live outside
# that repo, and the instructions for this change are explicit that
# ReadAloudDescribe's existing build must not be touched or risked.
# Pointing at its third_party/llama.cpp checkout read-only achieves
# the same "don't duplicate 150MB of C++" goal with zero risk to that
# app's build.
#
# Tradeoff, stated plainly: this makes SketchlyAndroid's native build
# depend on another repo being checked out at a fixed relative
# location on disk. That's fragile for CI/other machines. If this
# native path graduates past a first working pass, promoting it to a
# real shared Gradle module (e.g. ~/Documents/GitHub/OnDeviceVLM/)
# that both repos include via project(":ondevicevlm") is the right
# next step — this comment is the marker for that follow-up.
set(SHARED_LLAMA_CPP_ROOT "$ENV{HOME}/Documents/GitHub/ReadAloudDescribe/third_party/llama.cpp"
    CACHE PATH "Path to the shared llama.cpp checkout")

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(LLAMA_OPENSSL OFF CACHE BOOL "" FORCE)

set(GGML_OPENCL OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_HIPBLAS OFF CACHE BOOL "" FORCE)
set(GGML_BLAS OFF CACHE BOOL "" FORCE)
set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)

add_subdirectory(
    ${SHARED_LLAMA_CPP_ROOT}
    ${CMAKE_BINARY_DIR}/llama-cpp-build
    EXCLUDE_FROM_ALL
)

# Same private-mtmd-library approach as ReadAloudDescribe's CMakeLists
# (tools/mtmd's own CMakeLists pulls in CLI targets we don't want and
# can't link — see that file's comment for the full explanation).
set(MTMD_DIR  ${SHARED_LLAMA_CPP_ROOT}/tools/mtmd)
set(LLAMA_DIR ${SHARED_LLAMA_CPP_ROOT})

file(GLOB MTMD_MODEL_SOURCES ${MTMD_DIR}/models/*.cpp)

add_library(mtmd STATIC
    ${MTMD_DIR}/mtmd.cpp
    ${MTMD_DIR}/mtmd-audio.cpp
    ${MTMD_DIR}/mtmd-image.cpp
    ${MTMD_DIR}/mtmd-helper.cpp
    ${MTMD_DIR}/clip.cpp
    ${MTMD_MODEL_SOURCES}
)
target_link_libraries(mtmd PUBLIC ggml llama)
target_include_directories(mtmd PUBLIC  ${MTMD_DIR})
target_include_directories(mtmd PRIVATE ${LLAMA_DIR})
target_include_directories(mtmd PRIVATE ${LLAMA_DIR}/vendor)
target_compile_features(mtmd PRIVATE cxx_std_17)
target_compile_options(mtmd PRIVATE -Wno-missing-prototypes)

add_library(sketchly_ai_jni SHARED sketchly_ai_jni.cpp)

target_link_libraries(sketchly_ai_jni
    PRIVATE
        mtmd
        llama
        ggml
        ggml-base
        ggml-cpu
        android
        log
)

target_compile_features(sketchly_ai_jni PRIVATE cxx_std_17)

target_link_options(sketchly_ai_jni PRIVATE
    "-Wl,-z,max-page-size=16384"
    "-Wl,-z,common-page-size=16384"
)

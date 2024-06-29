include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(ARM32Emulator_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(ARM32Emulator_setup_options)
  option(ARM32Emulator_ENABLE_HARDENING "Enable hardening" ON)
  option(ARM32Emulator_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    ARM32Emulator_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    ARM32Emulator_ENABLE_HARDENING
    OFF)

  ARM32Emulator_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR ARM32Emulator_PACKAGING_MAINTAINER_MODE)
    option(ARM32Emulator_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(ARM32Emulator_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(ARM32Emulator_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(ARM32Emulator_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(ARM32Emulator_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(ARM32Emulator_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(ARM32Emulator_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(ARM32Emulator_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(ARM32Emulator_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(ARM32Emulator_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(ARM32Emulator_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(ARM32Emulator_ENABLE_PCH "Enable precompiled headers" OFF)
    option(ARM32Emulator_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(ARM32Emulator_ENABLE_IPO "Enable IPO/LTO" ON)
    option(ARM32Emulator_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(ARM32Emulator_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(ARM32Emulator_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(ARM32Emulator_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(ARM32Emulator_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(ARM32Emulator_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(ARM32Emulator_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(ARM32Emulator_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(ARM32Emulator_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(ARM32Emulator_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(ARM32Emulator_ENABLE_PCH "Enable precompiled headers" OFF)
    option(ARM32Emulator_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      ARM32Emulator_ENABLE_IPO
      ARM32Emulator_WARNINGS_AS_ERRORS
      ARM32Emulator_ENABLE_USER_LINKER
      ARM32Emulator_ENABLE_SANITIZER_ADDRESS
      ARM32Emulator_ENABLE_SANITIZER_LEAK
      ARM32Emulator_ENABLE_SANITIZER_UNDEFINED
      ARM32Emulator_ENABLE_SANITIZER_THREAD
      ARM32Emulator_ENABLE_SANITIZER_MEMORY
      ARM32Emulator_ENABLE_UNITY_BUILD
      ARM32Emulator_ENABLE_CLANG_TIDY
      ARM32Emulator_ENABLE_CPPCHECK
      ARM32Emulator_ENABLE_COVERAGE
      ARM32Emulator_ENABLE_PCH
      ARM32Emulator_ENABLE_CACHE)
  endif()

  ARM32Emulator_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (ARM32Emulator_ENABLE_SANITIZER_ADDRESS OR ARM32Emulator_ENABLE_SANITIZER_THREAD OR ARM32Emulator_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(ARM32Emulator_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(ARM32Emulator_global_options)
  if(ARM32Emulator_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    ARM32Emulator_enable_ipo()
  endif()

  ARM32Emulator_supports_sanitizers()

  if(ARM32Emulator_ENABLE_HARDENING AND ARM32Emulator_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR ARM32Emulator_ENABLE_SANITIZER_UNDEFINED
       OR ARM32Emulator_ENABLE_SANITIZER_ADDRESS
       OR ARM32Emulator_ENABLE_SANITIZER_THREAD
       OR ARM32Emulator_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${ARM32Emulator_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${ARM32Emulator_ENABLE_SANITIZER_UNDEFINED}")
    ARM32Emulator_enable_hardening(ARM32Emulator_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(ARM32Emulator_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(ARM32Emulator_warnings INTERFACE)
  add_library(ARM32Emulator_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  ARM32Emulator_set_project_warnings(
    ARM32Emulator_warnings
    ${ARM32Emulator_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(ARM32Emulator_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    ARM32Emulator_configure_linker(ARM32Emulator_options)
  endif()

  include(cmake/Sanitizers.cmake)
  ARM32Emulator_enable_sanitizers(
    ARM32Emulator_options
    ${ARM32Emulator_ENABLE_SANITIZER_ADDRESS}
    ${ARM32Emulator_ENABLE_SANITIZER_LEAK}
    ${ARM32Emulator_ENABLE_SANITIZER_UNDEFINED}
    ${ARM32Emulator_ENABLE_SANITIZER_THREAD}
    ${ARM32Emulator_ENABLE_SANITIZER_MEMORY})

  set_target_properties(ARM32Emulator_options PROPERTIES UNITY_BUILD ${ARM32Emulator_ENABLE_UNITY_BUILD})

  if(ARM32Emulator_ENABLE_PCH)
    target_precompile_headers(
      ARM32Emulator_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(ARM32Emulator_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    ARM32Emulator_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(ARM32Emulator_ENABLE_CLANG_TIDY)
    ARM32Emulator_enable_clang_tidy(ARM32Emulator_options ${ARM32Emulator_WARNINGS_AS_ERRORS})
  endif()

  if(ARM32Emulator_ENABLE_CPPCHECK)
    ARM32Emulator_enable_cppcheck(${ARM32Emulator_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(ARM32Emulator_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    ARM32Emulator_enable_coverage(ARM32Emulator_options)
  endif()

  if(ARM32Emulator_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(ARM32Emulator_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(ARM32Emulator_ENABLE_HARDENING AND NOT ARM32Emulator_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR ARM32Emulator_ENABLE_SANITIZER_UNDEFINED
       OR ARM32Emulator_ENABLE_SANITIZER_ADDRESS
       OR ARM32Emulator_ENABLE_SANITIZER_THREAD
       OR ARM32Emulator_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    ARM32Emulator_enable_hardening(ARM32Emulator_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()

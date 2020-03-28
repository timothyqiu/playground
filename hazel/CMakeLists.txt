cmake_minimum_required(VERSION 3.15)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_BINARY_DIR}")

project(Hazel LANGUAGES CXX)

if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
  set(CMAKE_CXX_EXTENSIONS OFF)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    message(STATUS "Setting build type to 'RelWithDebInfo' as none was specified.")
    set(CMAKE_BUILD_TYPE
        RelWithDebInfo
        CACHE STRING "Choose the type of build." FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel"
                                                 "RelWithDebInfo")
  endif()

  include(CheckIPOSupported)
  check_ipo_supported(RESULT result OUTPUT output)
  if(result)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
  else()
    message(STATUS "IPO is not supported: ${output}")
  endif()

  find_program(CCACHE_PROGRAM ccache)
  if(CCACHE_PROGRAM)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
  endif()

  find_program(CLANG_TIDY_PROGRAM clang-tidy)
  if(CLANG_TIDY_PROGRAM)
    set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_PROGRAM}")
  endif()
endif()

option(HAZEL_INSTALL "Generate the install target" ON)
if(HAZEL_INSTALL)
  include(GNUInstallDirs)
  list(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES
       "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}" isSystemDir)
  if("${isSystemDir}" STREQUAL "-1")
    set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
  endif("${isSystemDir}" STREQUAL "-1")
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
endif()

add_library(project_warnings INTERFACE)
target_compile_options(
  project_warnings
  INTERFACE $<$<CXX_COMPILER_ID:MSVC>:
            /W4
            /w14640>
            $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:
            -Wall
            -Wextra
            -pedantic
            -Wshadow
            -Wsign-conversion
            -Wswitch-enum
            -Wnon-virtual-dtor>)

find_package(spdlog REQUIRED)

add_subdirectory(src/hazel)
add_subdirectory(examples)

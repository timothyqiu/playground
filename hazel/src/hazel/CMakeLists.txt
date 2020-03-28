cmake_minimum_required(VERSION 3.15)

add_library(hazel SHARED)
add_library(hazel::hazel ALIAS hazel)

set(HAZEL_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../include)
set(HAZEL_HEADERS
    ${CMAKE_CURRENT_BINARY_DIR}/generated/hazel/export.hpp
    ${HAZEL_INCLUDE_DIR}/hazel/hazel.hpp ${HAZEL_INCLUDE_DIR}/hazel/application.hpp
    ${HAZEL_INCLUDE_DIR}/hazel/log.hpp)

target_sources(
  hazel
  PUBLIC ${HAZEL_HEADERS}
  PRIVATE application.cpp log.cpp)

include(GenerateExportHeader)
generate_export_header(
  hazel
  BASE_NAME
  HAZEL
  EXPORT_MACRO_NAME
  HAZEL_API
  EXPORT_FILE_NAME
  ${CMAKE_CURRENT_BINARY_DIR}/generated/hazel/export.hpp
  INCLUDE_GUARD_NAME
  HAZEL_EXPORT_HPP_)

target_include_directories(hazel PUBLIC ${HAZEL_INCLUDE_DIR}
                                        ${CMAKE_CURRENT_BINARY_DIR}/generated)

target_compile_features(hazel PRIVATE cxx_std_17)

target_link_libraries(hazel PUBLIC spdlog::spdlog)

set_target_properties(hazel PROPERTIES PUBLIC_HEADER "${HAZEL_HEADERS}")

if(HAZEL_INSTALL)
  install(
    TARGETS hazel
    RUNTIME COMPONENT Runtime
    LIBRARY COMPONENT Runtime
    ARCHIVE COMPONENT Development
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/hazel COMPONENT Development)
endif()

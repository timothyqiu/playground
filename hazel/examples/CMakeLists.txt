cmake_minimum_required(VERSION 3.15)

add_executable(sandbox)

target_sources(sandbox PRIVATE sandbox.cpp)

target_compile_features(sandbox PRIVATE cxx_std_14)

target_link_libraries(sandbox PRIVATE hazel::hazel)

if(HAZEL_INSTALL)
  install(TARGETS sandbox RUNTIME COMPONENT Runtime)
endif()

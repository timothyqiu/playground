add_executable(pe-dump
  main.cpp
  file.hpp file.cpp
  )

target_compile_features(pe-dump PRIVATE cxx_std_17)
target_link_libraries(pe-dump PRIVATE
  project_warnings
  Boost::boost
  spdlog::spdlog fmt::fmt CLI11::CLI11 magic_enum::magic_enum)

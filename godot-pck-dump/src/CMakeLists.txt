add_executable(pckdump
  main.cpp
  config.hpp config.cpp
  file.hpp file.cpp)

target_compile_features(pckdump PRIVATE cxx_std_17)
target_link_libraries(pckdump PRIVATE
  project_warnings
  Boost::boost
  spdlog::spdlog fmt::fmt CLI11::CLI11 magic_enum::magic_enum zstd::zstd)

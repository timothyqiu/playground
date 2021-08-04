add_executable(demo
  main.cpp
  scope_exit.hpp
  config.hpp config.cpp)

target_compile_features(demo PRIVATE cxx_std_17)
target_link_libraries(demo PRIVATE
  project_warnings
  spdlog::spdlog fmt::fmt CLI11::CLI11 SDL2::SDL2)

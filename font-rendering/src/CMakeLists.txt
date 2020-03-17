add_executable(
  demo
  main.cpp
  canvas.hpp
  canvas.cpp
  config.hpp
  config.cpp
  exceptions.hpp
  exceptions.cpp
  utils.hpp
  utils.cpp)
target_compile_features(demo PRIVATE cxx_std_17)
target_link_libraries(demo PRIVATE CLI11::CLI11 fmt::fmt spdlog::spdlog
                                   Freetype::Freetype)

add_executable(demo main.cpp config.hpp config.cpp)
target_compile_features(demo PRIVATE cxx_std_17)
target_link_libraries(demo PRIVATE CLI11::CLI11 fmt::fmt spdlog::spdlog
                                   Freetype::Freetype)

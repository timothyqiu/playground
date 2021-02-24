add_executable(blive
  main.cpp
  buffer.hpp
  inflator.hpp inflator.cpp
  options.hpp options.cpp)

target_compile_features(blive PRIVATE cxx_std_17)
target_link_libraries(blive PRIVATE
  project_warnings
  spdlog::spdlog ixwebsocket::ixwebsocket nlohmann_json::nlohmann_json Boost::boost
  ZLIB::ZLIB fmt::fmt CLI11::CLI11)

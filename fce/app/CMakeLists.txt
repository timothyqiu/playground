add_executable(fce-app main.cpp)
add_executable(fce::app ALIAS fce-app)

target_link_libraries(fce-app PRIVATE fce::fce spdlog::spdlog)

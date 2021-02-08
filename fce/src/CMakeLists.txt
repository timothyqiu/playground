set(HEADER_LIST
  "${FCEmu_SOURCE_DIR}/include/fce/fce.hpp"
  "${FCEmu_SOURCE_DIR}/include/fce/memory.hpp"
  "${FCEmu_SOURCE_DIR}/include/fce/cpu.hpp"
  "${FCEmu_SOURCE_DIR}/include/fce/types.hpp"
    )

add_library(fce-library
  ${HEADER_LIST}
  fce.cpp
  memory.cpp
  cpu.cpp)
add_library(fce::fce ALIAS fce-library)

set_target_properties(fce-library PROPERTIES PUBLIC_HEADER "${HEADER_LIST}")

target_include_directories(fce-library PUBLIC ../include)
target_compile_features(fce-library PUBLIC cxx_std_14)
target_link_libraries(fce-library PRIVATE project_warnings spdlog::spdlog)

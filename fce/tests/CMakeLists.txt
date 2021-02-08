add_executable(fce-tests
  main.cpp cpu.cpp
  op/load_store_operations.cpp
  op/register_transfers.cpp
  op/stack_operations.cpp
  op/logical.cpp
  op/arithmetic.cpp
  op/increments_decrements.cpp
  op/shifts.cpp
  op/jumps_calls.cpp
  op/branches.cpp
  op/status_flag_changes.cpp
  op/system.cpp
  )
add_executable(fce::tests ALIAS fce-tests)

target_compile_features(fce-tests PRIVATE cxx_std_17)
target_link_libraries(fce-tests PRIVATE Catch2::Catch2 fce::fce)

include(Catch)
catch_discover_tests(fce-tests)

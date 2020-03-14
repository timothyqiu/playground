# Font Rendering Demo

Playing with [FreeType](https://www.freetype.org/).

## Build

Build the project with [CMake](https://cmake.org/) and [Conan](https://conan.io/).

    # Install dependencies via Conan
    $ conan install -if /path/to/build-dir .

    # Configure the project via CMake
    $ cmake -B /path/to/build-dir -S .

    # Build the project
    $ cmake --build /path/to/build-dir

Note that Conan installs Release build by default (use `-s build_type=Debug` to change), and this CMake project builds RelWithDebInfo by default (use `-DCMAKE_BUILD_TYPE=Debug` to change when configuring for single-configuration generators, or `--config Debug` to change when building for multi-configuration generators). Type mismatch may result in link errors.

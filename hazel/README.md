# Hazel

Essentially following [the Hazel Engine series](https://www.youtube.com/playlist?list=PLlrATfBNZ98dC-V-N3m0Go4deliWHPFwT), but using CMake and some other conventions.

Todos:

- [ ] Test on a Linux machine

## Build

Build the project with [CMake](https://cmake.org/) and [Conan](https://conan.io/).

    # Install dependencies via Conan
    conan install -if /path/to/build-dir .

    # Configure the project via CMake
    cmake -B /path/to/build-dir -S .

    # Build the project
    cmake --build /path/to/build-dir

Note that Conan installs Release build by default (use `-s build_type=Debug` to change), and this CMake project builds RelWithDebInfo by default (use `-DCMAKE_BUILD_TYPE=Debug` to change when configuring for single-configuration generators, or `--config Debug` to change when building for multi-configuration generators). Type mismatch may result in link errors.

## Install

    cmake --install /path/to/build-dir

This will install the runtime binaries and development files to `CMAKE_INSTALL_PREFIX`, which has a reasonable default on different platforms.

Option `--component <NAME>` can be used to only install a specific component:

* `Runtime`: the executable and the shared library
* `Development`: the headers and the import library

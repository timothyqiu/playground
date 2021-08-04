#include "config.hpp"
#include <cstdlib>
#include <CLI/App.hpp>
#include <CLI/Config.hpp>
#include <CLI/Formatter.hpp>
#include <spdlog/spdlog.h>


Config::Config(int argc, char *argv[])
    : is_verbose{false}
{
    CLI::App app{"SDL Joystick Demo"};

    app.add_flag("-v,--verbose", is_verbose, "Verbose output");

    try {
        app.parse(argc, argv);
    }
    catch (CLI::ParseError const& e) {
        std::exit(app.exit(e));
    }

    spdlog::set_level(is_verbose ? spdlog::level::debug : spdlog::level::warn);
}

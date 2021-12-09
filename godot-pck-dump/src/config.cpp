#include "config.hpp"
#include <cstdlib>
#include <CLI/App.hpp>
#include <CLI/Config.hpp>
#include <CLI/Formatter.hpp>
#include <spdlog/spdlog.h>


Config::Config(int argc, char *argv[])
    : is_verbose{false}
    , file_path{"res://project.binary"}
{
    CLI::App app{"Godot PCK Dump"};

    app.add_flag("-v,--verbose", is_verbose, "Verbose output");

    app.add_option("path", path, "PCK file path")->required();
    app.add_option("file-path", file_path, "file path inside PCK");

    try {
        app.parse(argc, argv);
    }
    catch (CLI::ParseError const& e) {
        std::exit(app.exit(e));
    }

    spdlog::set_level(is_verbose ? spdlog::level::debug : spdlog::level::warn);
}

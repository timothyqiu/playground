#include "config.hpp"

#include <cstdlib>

#include <CLI/CLI.hpp>

Config::Config(int argc, char *argv[])
{
    CLI::App app{"Font Rendering Demo"};

    app.add_option("file", file, "Path to the font file")
        ->type_name("PATH")
        ->required();

    app.add_option("-o,--output", output, "Output file path")
        ->type_name("FILE")
        ->default_val(output);

    app.add_option("--size", pixel_size, "Pixel size")
        ->type_name("PIXEL_SIZE")
        ->default_val(pixel_size);

    try {
        app.parse(argc, argv);
    }
    catch (CLI::ParseError const& e) {
        std::exit(app.exit(e));
    }
}

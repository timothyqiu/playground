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
        ->default_val("render.pgm");

    app.add_option("--size", font_pixel_size, "Font pixel size")
        ->type_name("SIZE")
        ->default_val(100);

    app.add_option("--canvas-width", canvas_width, "Canvas width, zero means auto")
        ->type_name("SIZE")
        ->default_val(0);

    try {
        app.parse(argc, argv);
    }
    catch (CLI::ParseError const& e) {
        std::exit(app.exit(e));
    }
}

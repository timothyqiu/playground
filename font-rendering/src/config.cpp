#include "config.hpp"

#include <cstdlib>

#include <CLI/CLI.hpp>

Config::Config(int argc, char *argv[])
    : verbose{false}
{
    CLI::App app{"Font Rendering Demo"};

    app.add_option("file", file, "Path to the font file")
        ->type_name("PATH")
        ->required();

    app.add_option("-o,--output", output, "Output file path")
        ->type_name("FILE")
        ->default_val("render.pgm");

    app.add_option("--size", font_pixel_size, "Font pixel size")
        ->type_name("PIXELS")
        ->default_val(100);

    app.add_option("--content-width", content_width, "Canvas content width, zero means auto")
        ->type_name("PIXELS")
        ->default_val(0);

    app.add_option("--canvas-padding", canvas_padding, "Canvas padding")
        ->type_name("PIXELS")
        ->default_val(8);

    app.add_option("--line-gap", line_gap, "Line gap")
        ->type_name("PIXELS")
        ->default_val(4);

    app.add_flag("--kerning,!--no-kerning", enable_kerning, "Kerning switch")
        ->default_val(true);

    app.add_flag("--annotation,!--no-annotation", enable_annotation, "Annotation switch")
        ->default_val(true);

    app.add_flag("-v,--verbose", verbose, "Verbose output");

    try {
        app.parse(argc, argv);
    }
    catch (CLI::ParseError const& e) {
        std::exit(app.exit(e));
    }
}

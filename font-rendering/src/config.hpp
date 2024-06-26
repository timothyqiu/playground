#ifndef CONFIG_HPP_
#define CONFIG_HPP_

#include <cstddef>
#include <string>

struct Config
{
    std::string file;
    std::string output;
    size_t font_pixel_size;
    size_t content_width;
    size_t canvas_padding;
    size_t line_gap;
    bool enable_kerning;
    bool enable_annotation;
    bool verbose;

    Config(int argc, char *argv[]);
};

#endif  // CONFIG_HPP_

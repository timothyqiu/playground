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
    bool enable_kerning;

    Config(int argc, char *argv[]);
};

#endif  // CONFIG_HPP_

#ifndef CONFIG_HPP_
#define CONFIG_HPP_

#include <cstddef>
#include <string>

struct Config
{
    std::string file;
    std::string output{"render.pgm"};
    size_t pixel_size{48};

    Config(int argc, char *argv[]);
};

#endif  // CONFIG_HPP_

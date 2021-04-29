#ifndef CONFIG_HPP_
#define CONFIG_HPP_

#include <string>

struct Config
{
    bool is_verbose;

    std::string path;
    std::string file_path;

    Config(int argc, char *argv[]);
};

#endif  // CONFIG_HPP_

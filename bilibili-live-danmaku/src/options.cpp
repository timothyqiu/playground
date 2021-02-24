#include "options.hpp"
#include <cstdlib>
#include <CLI/App.hpp>
#include <CLI/Formatter.hpp>
#include <CLI/Config.hpp>


Options::Options(int argc, char *argv[])
    : room_id{1029}, show_entering{true}
{
    CLI::App app{"Bilibili Live Danmaku"};

    app.add_option("-r,--room", room_id, "Room ID");
    app.add_flag("!--no-enter", show_entering, "Disable entering message");

    try {
        app.parse(argc, argv);
    }
    catch (CLI::ParseError const& e) {
        std::exit(app.exit(e));
    }
}

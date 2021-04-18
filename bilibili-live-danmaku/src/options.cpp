#include "options.hpp"
#include <cstdlib>
#include <CLI/App.hpp>
#include <CLI/Formatter.hpp>
#include <CLI/Config.hpp>


Options::Options(int argc, char *argv[])
    : room_id{1029}, show_entering{true}, show_broadcast{true}, reconnect{true}, verbose{false}
{
    CLI::App app{"Bilibili Live Danmaku"};

    app.add_option("room", room_id, "Room ID");
    app.add_flag("!--no-broadcast", show_broadcast, "Disable broadcast message");
    app.add_flag("!--no-enter", show_entering, "Disable entering message");
    app.add_flag("--reconnect,!--no-reconnect", reconnect, "Auto reconnect");
    app.add_flag("-v,--verbose", verbose, "Verbose output");

    try {
        app.parse(argc, argv);
    }
    catch (CLI::ParseError const& e) {
        std::exit(app.exit(e));
    }
}

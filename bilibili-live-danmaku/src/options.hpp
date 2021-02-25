#ifndef BLD_OPTIONS_HPP_
#define BLD_OPTIONS_HPP_

struct Options
{
public:
    int room_id;
    bool show_entering;
    bool reconnect;
    bool verbose;

    explicit Options(int argc, char *argv[]);
};

#endif  // BLD_OPTIONS_HPP_

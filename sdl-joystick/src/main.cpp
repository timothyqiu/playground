#include <cassert>
#include <cstdlib>
#include <stdexcept>

#include <SDL2/SDL.h>
#include <spdlog/spdlog.h>

#include "config.hpp"
#include "scope_exit.hpp"


bool is_true(int sdl_bool)
{
    switch (sdl_bool) {
    case SDL_TRUE:
        return true;
    case SDL_FALSE:
        return false;
    }
    assert(sdl_bool < 0);
    throw std::runtime_error{SDL_GetError()};
}


int main(int argc, char *argv[])
try {
    Config config{argc, argv};

    if (SDL_Init(SDL_INIT_JOYSTICK | SDL_INIT_HAPTIC) < 0) {
        throw std::runtime_error{SDL_GetError()};
    }
    SCOPE_EXIT(SDL_Quit());

    int const n = SDL_NumJoysticks();
    if (n == 0) {
        fmt::print("No joystick found.\n");
        return EXIT_SUCCESS;
    }

    for (int i = 0; i < n; i++) {
        try {
            fmt::print("{}\n", SDL_JoystickNameForIndex(i));

            SDL_Joystick *joystick = SDL_JoystickOpen(i);
            if (joystick == nullptr) {
                throw std::runtime_error{SDL_GetError()};
            }
            SCOPE_EXIT(SDL_JoystickClose(joystick));

            if (!is_true(SDL_JoystickIsHaptic(joystick))) {
                fmt::print("This joystick is not haptic.\n");
                continue;
            }

            SDL_Haptic *haptic = SDL_HapticOpenFromJoystick(joystick);
            if (joystick == nullptr) {
                throw std::runtime_error{SDL_GetError()};
            }
            SCOPE_EXIT(SDL_HapticClose(haptic));

            if (!is_true(SDL_HapticRumbleSupported(haptic))) {
                fmt::print("This joystick does not support rumble.\n");
                continue;
            }

            if (SDL_HapticRumbleInit(haptic) < 0) {
                throw std::runtime_error{SDL_GetError()};
            }
            if (SDL_HapticRumblePlay(haptic, 1.0, 1000) < 0) {
                throw std::runtime_error{SDL_GetError()};
            }
            SDL_Delay(1000);
            if (SDL_HapticRumbleStop(haptic) < 0) {
                throw std::runtime_error{SDL_GetError()};
            }
        }
        catch (std::exception const& e) {
            spdlog::error("Error working with joystick {}: {}", i, e.what());
        }
    }
}
catch (std::exception const& e) {
    spdlog::error("Uncaught exception: {}", e.what());
}
